; Retro.Link network routines. Include this file in your game. main.asm shows how to use them.

; Retro.Link plugs into controller port 2. The console's built in serial port talks to the xPico
; at 4800 baud, the only rate the adapter uses. Below are the hardware registers you use to poke
; at the port. They are accessed a byte at a time.

PORT2_DATA  EQU $A10005      ; Port 2 data register (pin levels)
PORT2_CTRL  EQU $A1000B      ; Port 2 control register (pin directions)
SERIAL_TX   EQU $A10015      ; Transmit register
SERIAL_RX   EQU $A10017      ; Receive register
SERIAL_CTRL EQU $A10019      ; Serial control and status register
VDP_CTRL    EQU $C00004      ; VDP control port

; Port 2 pins and their bit in PORT2_DATA and PORT2_CTRL:
;   Pin 1 = Bit 0 = CLK  PS/2 keyboard clock. Held low between reads
;   Pin 2 = Bit 1 = DATA PS/2 keyboard data
;   Pin 3 = Bit 2 = CTS  Output  High makes the xPico hold data (flow control)
;   Pin 4 = Bit 3 = RTS  Input   Not used
;   Pin 6 = Bit 4 = TX   Output  Console to xPico
;   Pin 7 = Bit 6 = TH   Output  High allows inbound connections
;   Pin 9 = Bit 5 = RX   Input   xPico to console
;
; SERIAL_CTRL = $30 is 4800 baud with serial in and out on. $38 adds the RX interrupt.
; Status bits: Bit 0 = transmit busy, Bit 1 = byte received, Bit 2 = receive error.

; RAM used by these routines. Put them anywhere free that won't get stomped on by your game.

RX_BUFFER       EQU $FFFE00  ; 256 byte receive ring buffer
RX_HEAD         EQU $FFFF00  ; Ring buffer write index (the interrupt writes here)
RX_TAIL         EQU $FFFF01  ; Ring buffer read index (your code reads here)
adapter_present EQU $FFFF02  ; 1 = adapter found
kb_present      EQU $FFFF03  ; $FF = keyboard plugged in (Detect_KB)
kb_release      EQU $FFFF04  ; 1 = the next scan code is a key release
kb_shift        EQU $FFFF05  ; $FF while Shift is held

; Set up port 2 for serial. The data bits are set before the directions so the pins start low.

Init_Serial:
    move.b  #$00, PORT2_DATA  ; Pin 3 low lets data flow. Pin 7 low blocks inbound connections
    move.b  #$54, PORT2_CTRL  ; Pins 3, 6 and 7 are outputs. The rest are inputs
    move.b  #$30, SERIAL_CTRL ; 4800 baud 8-N-1, serial in and out on, RX interrupt off
    clr.b   RX_HEAD           ; Empty the ring buffer
    clr.b   RX_TAIL
    rts

; The adapter answers "C0.0.0.0/0" with its monitor prompt "0>". The xPico needs about 5 seconds
; after power on before it answers, so call this again until it does.

Detect_Adapter:
    bsr     Init_Serial
    lea     MONITOR_CMD,a0
    bsr     Send_String       ; Ask for the monitor prompt
    move.l  #200000,d1        ; Wait about 1 second
@Wait:
    btst    #1,SERIAL_CTRL    ; Byte waiting?
    beq.s   @Next
    cmp.b   #'>',SERIAL_RX    ; Is it the prompt?
    beq.s   @Found
@Next:
    subq.l  #1,d1
    bne.s   @Wait
    clr.b   adapter_present   ; No answer
    rts
@Found:
    bsr     Exit_Monitor      ; Leave the monitor
    move.b  #1,adapter_present
    rts

; The monitor also answers NC (network settings) and GM (MAC address). These poll the port, so
; use them while the RX interrupt is off.

Enter_Monitor:
    bsr     Flush_Port
    lea     MONITOR_CMD,a0
    bsr     Send_String       ; Ask for the monitor prompt
Wait_Prompt:
    bsr     Receive_Byte      ; Wait for the '>' of "0>"
    cmp.b   #'>',d0
    bne.s   Wait_Prompt
    rts

Exit_Monitor:
    lea     QUIT_CMD,a0
    bsr     Send_String       ; Leave the monitor
@Echo:
    bsr     Receive_Byte      ; The xPico echoes "QU" then CR LF
    cmp.b   #$0A,d0
    bne.s   @Echo
    rts

Get_IP:                       ; Copies the adapter's IP address to a1 as text
    bsr     Enter_Monitor
    lea     NC_CMD,a0
    bsr     Send_String       ; "IP 010.077.000.002 GW ..."
@Loop:
    bsr     Receive_Byte
    cmp.b   #'G',d0           ; The gateway comes after the IP address
    beq.s   @Done
    cmp.b   #'.',d0           ; Keep only dots and digits
    beq.s   @Keep
    cmp.b   #'0',d0
    blo.s   @Loop
    cmp.b   #'9',d0
    bhi.s   @Loop
@Keep:
    move.b  d0,(a1)+
    bra.s   @Loop
@Done:
    clr.b   (a1)              ; Zero ends the text
    bsr     Wait_Prompt       ; Skip the rest of the reply
    bra     Exit_Monitor

Get_MAC:                      ; Copies the adapter's MAC address to a1 as text
    bsr     Enter_Monitor
    lea     GM_CMD,a0
    bsr     Send_String       ; "GM" CR LF "00:80:A3:70:FA:90"
    moveq   #4-1,d1
@Echo:
    bsr     Receive_Byte      ; Skip the echo
    dbra    d1,@Echo
    moveq   #17-1,d1
@Loop:
    bsr     Receive_Byte
    move.b  d0,(a1)+
    dbra    d1,@Loop
    clr.b   (a1)              ; Zero ends the text
    bsr     Wait_Prompt       ; Skip the rest of the reply
    bra     Exit_Monitor

MONITOR_CMD:    dc.b 'C0.0.0.0/0',$0A,0
QUIT_CMD:       dc.b 'QU',$0D,0
NC_CMD:         dc.b 'NC',$0D,0
GM_CMD:         dc.b 'GM',$0D,0
    even

; Pin 7 (TH) controls inbound TCP connections on port 5364. Setting it high allows them.
; Setting it low blocks them and drops the current connection, inbound or outbound.

Allow_Connections:
    bset    #6, PORT2_DATA    ; Pin 7 high. Allow inbound connections on port 5364
    rts

Deny_Connections:
    bclr    #6, PORT2_DATA    ; Pin 7 low. Drop the connection and deny inbound
    rts

; Hardware flow control uses pin 3 (CTS). Pin 3 high makes the xPico stop sending and hold
; incoming data in its 2K buffer. Pin 3 low lets it send again. Hold data while your buffer is
; full or the console is busy, like during a long DMA. Units without flow control ignore pin 3.

Flow_On:
    bset    #2, PORT2_DATA    ; Pin 3 high. xPico holds data
    rts

Flow_Off:
    bclr    #2, PORT2_DATA    ; Pin 3 low. xPico sends data
    rts

; To make a connection to another device via TCP you will need to send a connection
; command string to the XPICO with an IP address and port, ending in a line feed:
; "C70.13.153.10:5364". You can also use DNS in place of the IP address as well
; "Cwebsite.com:80". All Retro.link adapters use the port 5364 for incoming connections.

Connect:                      ; Dials the zero terminated "address:port" at a0
    moveq   #'C',d0
    bsr     Send_Byte         ; Connect command
    bsr     Send_String       ; Address and port
    moveq   #$0A,d0
    bra     Send_Byte         ; A line feed ends it

; This will either return a single 'C' character if a connection was successfully made or an 'N'
; character which means it could not connect to the supplied address. Once connected you can read
; or write serial data to the other device immediately.

; Inbound connections on port 5364 are only accepted while pin 7 is high (see Allow_Connections).

; When the device disconnects or is disconnected it will return a 'D' character.

; Sending or receiving data is done a byte at a time by checking SERIAL_CTRL. The port holds only
; 1 byte and a new one arrives about every 2ms, so poll often or use the RX interrupt below.

Send_Byte:
    btst    #0,SERIAL_CTRL    ; Transmitter busy?
    bne.s   Send_Byte         ; Wait until it is free
    move.b  d0,SERIAL_TX      ; Send a byte
    rts                       ; Return

Receive_Byte:
    btst    #1,SERIAL_CTRL    ; Data available?
    beq.s   Receive_Byte      ; No. So wait and check until data arrives
    move.b  SERIAL_RX,d0      ; Read in byte from the port to d0
    rts                       ; Return

Send_String:                  ; Sends the zero terminated string at a0
    move.b  (a0)+,d0          ; Next byte
    beq.s   @Done             ; Zero ends the string
    bsr     Send_Byte         ; Send byte in d0
    bra.s   Send_String
@Done:
    rts                       ; Return

Flush_Port:
    btst    #1,SERIAL_CTRL    ; Data available?
    beq.s   @Done             ; No. Port is empty
    tst.b   SERIAL_RX         ; Read the byte and throw it away
    bra.s   Flush_Port
@Done:
    rts                       ; Return

; Instead of polling, the port can raise a level 2 interrupt for each byte it receives. Point the
; level 2 vector ($68) at RX_Interrupt. It stores bytes in a 256 byte ring buffer, so the byte
; sized indexes wrap around on their own. RX_HEAD equal to RX_TAIL means the buffer is empty.
; The VDP must already be in mode 5 (normal Genesis mode) to pass the interrupt along.

Enable_Interrupt:
    move.w  #$8B08,VDP_CTRL   ; VDP register 11: external interrupts on (keep your scroll bits)
    move.b  #$38,SERIAL_CTRL  ; 4800 baud 8-N-1, serial in and out on, RX interrupt on
    move.w  #$2100,sr         ; 68000 interrupt mask 1. Level 2 and up can interrupt
    rts

Disable_Interrupt:
    move.b  #$30,SERIAL_CTRL  ; RX interrupt off
    rts

RX_Interrupt:
    movem.l d0/a0,-(sp)       ; Save registers
    lea     RX_BUFFER,a0
@Loop:
    btst    #1,SERIAL_CTRL    ; Byte waiting?
    beq.s   @Done             ; No. All done
    moveq   #0,d0
    move.b  RX_HEAD,d0        ; Where to store it
    move.b  SERIAL_RX,(a0,d0.w) ; Store the byte
    addq.b  #1,RX_HEAD        ; Next slot
    bra.s   @Loop
@Done:
    movem.l (sp)+,d0/a0       ; Restore registers
    rte

Read_Buffer:                  ; Returns the next ring buffer byte in d0. Waits for one. Uses a0
    moveq   #0,d0
    move.b  RX_TAIL,d0
    cmp.b   RX_HEAD,d0        ; Anything new?
    beq.s   Read_Buffer       ; No. Wait for the interrupt to store one
    lea     RX_BUFFER,a0
    move.b  (a0,d0.w),d0      ; Get the byte
    addq.b  #1,RX_TAIL        ; Next slot
    rts                       ; Return

; The PS/2 keyboard plugs into the adapter and uses pins 1 (CLK) and 2 (DATA). Let go, its CLK
; rises in a few us. With nothing plugged in it floats low.

Detect_KB:                    ; Sets kb_present when a keyboard is plugged in. Uses d1
    andi.b  #$FE,PORT2_CTRL   ; Let go of CLK
    moveq   #21,d1
@Rise:
    btst    #0,PORT2_DATA     ; Did it rise?
    dbne    d1,@Rise
    sne     kb_present        ; $FF when it rose, 0 when not
    ori.b   #$01,PORT2_CTRL   ; Hold it again
    rts

; Between reads the keyboard is held (CLK low) and keeps its keys. Once a frame, right after
; VBlank, let it go and it sends 1 byte. It can take a few ms to start, so that wait runs with
; interrupts on. They are off only for its bits, about 1ms, less than one 4800 baud byte.

Read_Keyboard:                ; d0 = next byte from the keyboard or 0. Uses d1, d2, a0
    lea     PORT2_DATA,a0
    andi.b  #$FC,PORT2_CTRL   ; Let go of CLK and DATA so the keyboard can send
    moveq   #0,d0
    moveq   #21,d1            ; Wait for CLK to rise
@Rise:
    btst    #0,(a0)           ; CLK high?
    dbne    d1,@Rise
    beq.s   @Hold             ; No. Nothing is plugged in
    move.w  #1700,d1          ; Start bit within about 5ms?
@Start:
    btst    #0,(a0)           ; CLK low?
    dbeq    d1,@Start
    bne.s   @Hold             ; No. Nothing to send
    move    sr,-(sp)
    move    #$2700,sr         ; Interrupts off for the bits
    moveq   #10-1,d2          ; 8 data bits (LSB first), parity, stop
@Bit:
    moveq   #21,d1            ; About 63us per half clock
@High:
    btst    #0,(a0)           ; Wait for CLK high
    dbne    d1,@High
    beq.s   @Fail             ; Clock stopped
    moveq   #21,d1
@Low:
    btst    #0,(a0)           ; Then CLK low
    dbeq    d1,@Low
    bne.s   @Fail
    move.b  (a0),d1           ; DATA is bit 1
    lsr.b   #2,d1             ; DATA into X
    roxr.w  #1,d0             ; X into the top of d0
    dbra    d2,@Bit
    lsr.w   #6,d0             ; The 8 data bits are now at the bottom
    andi.w  #$FF,d0
    bra.s   @Done
@Fail:
    moveq   #0,d0             ; Clock stopped. Drop the byte
@Done:
    move    (sp)+,sr          ; Interrupts back on
@Hold:
    move.b  (a0),d1
    andi.b  #$FE,d1           ; CLK low
    ori.b   #$02,d1           ; DATA high
    move.b  d1,(a0)
    ori.b   #$03,PORT2_CTRL   ; Both outputs. The keyboard holds its keys
    rts

; Read_Key turns scan codes (set 2) into ASCII with KEY_TABLE. Letters are upper case, Enter is
; $0A and Backspace is $08. Shift gives the symbols in SHIFT_TABLE. Releases ($F0 then the key)
; are skipped.

Read_Key:                     ; d0 = ASCII key pressed or 0. Uses d1, d2, a0
    bsr     Read_Keyboard
    tst.b   d0
    beq.s   @Done             ; Nothing sent
    cmp.b   #$F0,d0           ; The next code is a key release?
    beq.s   @Release
    cmp.b   #$12,d0           ; Left Shift?
    beq.s   @Shift
    cmp.b   #$59,d0           ; Right Shift?
    beq.s   @Shift
    tst.b   kb_release
    bne.s   @Skip             ; This is the released key
    cmp.w   #$80,d0
    bhs.s   @None             ; Not in the table
    lea     SHIFT_TABLE,a0
    tst.b   kb_shift
    beq.s   @Key              ; Shift is up
    tst.b   (a0,d0.w)         ; A shifted symbol?
    bne.s   @Get
@Key:
    lea     KEY_TABLE,a0
@Get:
    move.b  (a0,d0.w),d0
@Done:
    rts
@Release:
    move.b  #1,kb_release
    moveq   #0,d0
    rts
@Shift:
    tst.b   kb_release        ; Pressed or released?
    seq     kb_shift          ; Pressed = $FF, released = 0
@Skip:
    clr.b   kb_release
@None:
    moveq   #0,d0
    rts

KEY_TABLE:                    ; PS/2 scan code to ASCII. 0 = not used
    dc.b    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0  ; $00-$0F
    dc.b    0,0,0,0,0,'Q','1',0,0,0,'Z','S','A','W','2',0  ; $10-$1F
    dc.b    0,'C','X','D','E','4','3',0,0,' ','V','F','T','R','5',0  ; $20-$2F
    dc.b    0,'N','B','H','G','Y','6',0,0,0,'M','J','U','7','8',0  ; $30-$3F
    dc.b    0,$2C,'K','I','O','0','9',0,0,'.','/','L',$3B,'P','-',0  ; $40-$4F
    dc.b    0,0,$27,0,'[','=',0,0,0,0,$0A,']',0,$5C,0,0  ; $50-$5F
    dc.b    0,0,0,0,0,0,$08,0,0,0,0,0,0,0,0,0  ; $60-$6F
    dc.b    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0  ; $70-$7F

SHIFT_TABLE:                  ; The same keys with Shift held. 0 = no symbol
    dc.b    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0  ; $00-$0F
    dc.b    0,0,0,0,0,0,'!',0,0,0,0,0,0,0,'@',0  ; $10-$1F
    dc.b    0,0,0,0,0,'$','#',0,0,0,0,0,0,0,'%',0  ; $20-$2F
    dc.b    0,0,0,0,0,0,'^',0,0,0,0,0,0,'&','*',0  ; $30-$3F
    dc.b    0,'<',0,0,0,')','(',0,0,'>','?',0,':',0,'_',0  ; $40-$4F
    dc.b    0,0,$22,0,'{','+',0,0,0,0,0,'}',0,$7C,0,0  ; $50-$5F
    dc.b    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0  ; $60-$6F
    dc.b    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0  ; $70-$7F
    even

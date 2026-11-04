; Retro.Link example ROM. It does the same as the SGDK example: finds the adapter, shows its IP and
; MAC, fetches a web page and fetches any site you type on the PS/2 keyboard. The network routines
; it calls are in network.asm.
; Build it with asm68k:  asm68k /p main.asm, main.bin

PORT1_DATA  EQU $A10003      ; Port 1 data register (joypad)
PORT1_CTRL  EQU $A10009      ; Port 1 control register
VDP_DATA    EQU $C00000      ; VDP data port

; RAM used by the demo. network.asm uses $FFFE00-$FFFF05. The stack starts just below that.

text_pal    EQU $FFFF10      ; Text color. $0000 = white, $2000 = red, $4000 = green
pad_prev    EQU $FFFF12      ; Buttons held last frame
site_len    EQU $FFFF14      ; Length of the site you type
NET_PANE    EQU $FFFF20      ; Network pane
KEY_PANE    EQU $FFFF28      ; Keyboard pane
SITE        EQU $FFFF30      ; The site you type
TEXT        EQU $FFFF60      ; IP or MAC address text

; A pane is rows of text on screen. Text goes on the bottom row. Each field is a word.

P_TOP       EQU 0            ; Top row
P_ROWS      EQU 2            ; Number of rows
P_X         EQU 4            ; Column of the next character

; The ROM starts with the 68000 vectors and the cartridge header. Vector $68 is the level 2
; interrupt, which the port 2 receive interrupt uses.

    dc.l    RX_BUFFER,Start   ; Stack, start of code
    dcb.l   24,Halt           ; Errors
    dc.l    RX_Interrupt      ; $68 Level 2. Port 2 receive interrupt
    dcb.l   5,No_Interrupt    ; Other interrupts (not used)
    dcb.l   32,Halt           ; Traps

    dc.b    'SEGA GENESIS    '                                  ; Console
    dc.b    '(C)RETRO.LINK   '                                  ; Copyright
    dc.b    'Retro.Link Example                              '  ; Domestic name
    dc.b    'Retro.Link Example                              '  ; Overseas name
    dc.b    'GM 00000000-00'                                    ; Serial number
    dc.w    0                                                   ; Checksum
    dc.b    'J               '                                  ; Joypad
    dc.l    0,ROM_END-1                                         ; ROM start and end
    dc.l    $FF0000,$FFFFFF                                     ; RAM start and end
    dc.b    '                        '                          ; No save RAM or modem
    dc.b    'Retro.Link Example                      '          ; Notes
    dc.b    'JUE             '                                  ; Regions

; Power on. Unlock the VDP, clear RAM and video memory, then load the colors and font.

Start:
    move    #$2700,sr         ; Interrupts off
    move.b  $A10001,d0        ; Console version
    andi.b  #$0F,d0
    beq.s   @NoTMSS           ; Older consoles have no lock
    move.l  #'SEGA',$A14000   ; Newer ones lock the VDP until 'SEGA' is written here
@NoTMSS:
    lea     $FF0000,a0
    move.w  #$4000-1,d0
@ClearRAM:
    clr.l   (a0)+             ; 64K of RAM
    dbra    d0,@ClearRAM

    move.w  VDP_CTRL,d0       ; Clear any half written VDP command
    lea     VDP_REGS,a0
    moveq   #13-1,d0
@Regs:
    move.w  (a0)+,VDP_CTRL    ; Set the VDP registers
    dbra    d0,@Regs

    move.l  #$40000000,VDP_CTRL ; Write VRAM from address 0
    move.w  #$8000-1,d0
@ClearVRAM:
    move.w  #0,VDP_DATA       ; 64K of video memory
    dbra    d0,@ClearVRAM
    move.l  #$40000010,VDP_CTRL ; Write VSRAM (vertical scroll)
    moveq   #40-1,d0
@ClearVSRAM:
    move.w  #0,VDP_DATA
    dbra    d0,@ClearVSRAM

    move.l  #$C0000000,VDP_CTRL ; Palette 0, color 0
    move.l  #$06000EEE,VDP_DATA ; Blue background, white text
    move.l  #$C0220000,VDP_CTRL ; Palette 1, color 1
    move.w  #$000E,VDP_DATA     ; Red text
    move.l  #$C0420000,VDP_CTRL ; Palette 2, color 1
    move.w  #$00E0,VDP_DATA     ; Green text

    move.l  #$44000000,VDP_CTRL ; Write VRAM at $0400. Tile $20 is the space
    lea     FONT,a0
    move.w  #64*8-1,d2        ; 64 characters of 8 rows
@Row:
    move.b  (a0)+,d0          ; 8 pixels at 1 bit each
    moveq   #8-1,d3
@Pixel:
    lsl.l   #4,d1             ; Room for the next pixel at 4 bits each
    add.b   d0,d0             ; Next pixel into carry
    bcc.s   @Empty
    addq.b  #1,d1             ; Color 1
@Empty:
    dbra    d3,@Pixel
    move.l  d1,VDP_DATA
    dbra    d2,@Row

    move.b  #$40,PORT1_DATA   ; Port 1 TH high
    move.b  #$40,PORT1_CTRL   ; Port 1 TH is an output for reading the joypad

; The same steps as main.c in the SGDK example.

Main:
    move.l  #$0008000B,NET_PANE ; Network pane, rows 8-18
    move.l  #$00160004,KEY_PANE ; Keyboard pane, rows 22-25

    moveq   #0,d1
    moveq   #1,d2
    lea     ADAPTER_TEXT,a0
    bsr     Draw_Text         ; "Adapter  [  ]"
    moveq   #0,d1
    moveq   #2,d2
    lea     KB_TEXT,a0
    bsr     Draw_Text         ; "Keyboard [  ]"

    moveq   #10-1,d4          ; Find the adapter first. The xPico takes about 5 seconds to start
@Detect:
    bsr     Detect_Adapter    ; About 1 second each. Ask for up to 10
    tst.b   adapter_present
    dbne    d4,@Detect
    move.b  adapter_present,d0
    moveq   #1,d2
    lea     XX_TEXT,a0
    bsr     Show_Status
    tst.b   adapter_present
    bne.s   @Found
    moveq   #0,d1
    moveq   #3,d2
    lea     MISSING_TEXT,a0
    bsr     Draw_Text         ; "Adapter not present"
@Stop:
    bra.s   @Stop
@Found:
    bsr     Show_KB           ; Then the keyboard

    moveq   #0,d1
    moveq   #3,d2
    lea     IP_TEXT,a0
    bsr     Draw_Text         ; "IP Address:"
    lea     TEXT,a1
    bsr     Get_IP
    moveq   #12,d1
    lea     TEXT,a0
    bsr     Draw_Text

    moveq   #0,d1
    moveq   #4,d2
    lea     MAC_TEXT,a0
    bsr     Draw_Text         ; "MAC:"
    lea     TEXT,a1
    bsr     Get_MAC
    moveq   #5,d1
    lea     TEXT,a0
    bsr     Draw_Text

    moveq   #0,d1
    moveq   #5,d2
    lea     LINE_TEXT,a0
    bsr     Draw_Text         ; "-----"
    moveq   #0,d1
    moveq   #6,d2
    lea     NETWORK_TEXT,a0
    bsr     Draw_Text         ; "NETWORK  (A pause, B resume, C hang up)"
    moveq   #0,d1
    moveq   #7,d2
    lea     LINE_TEXT,a0
    bsr     Draw_Text
    moveq   #0,d1
    moveq   #20,d2
    lea     KEYBOARD_TEXT,a0
    bsr     Draw_Text         ; "KB INPUT - (EX: EXAMPLE.COM:80, ENTER)"
    moveq   #0,d1
    moveq   #21,d2
    lea     LINE_TEXT,a0
    bsr     Draw_Text

    bsr     Enable_Interrupt  ; From here the level 2 interrupt fills the ring buffer
    lea     FIRST_SITE,a0
    bsr     Fetch             ; "example.com:80"

; Loop forever. Type a site, press A, B or C, and print what arrives.

Main_Loop:
    bsr     Wait_VBlank
    bsr     Read_Key          ; Poll the PS/2 keyboard once a frame, right after VBlank
    lea     KEY_PANE,a2
    lea     SITE,a1
    move.w  site_len,d1
    cmp.b   #$0A,d0           ; Enter fetches the site
    beq.s   @Enter
    cmp.b   #$08,d0           ; Backspace erases the last key
    beq.s   @Back
    cmp.b   #' ',d0
    blo.s   @Status           ; No key
    cmp.w   #36,d1
    bhs.s   @Status           ; Site is full
    move.b  d0,(a1,d1.w)      ; Add the key to the site
    addq.w  #1,site_len
    bsr     Print
    bra.s   @Status
@Enter:
    tst.w   d1
    beq.s   @Status           ; Nothing typed
    clr.b   (a1,d1.w)         ; Zero ends the site
@Find:
    move.b  (a1)+,d2          ; Did you type a port?
    beq.s   @Port             ; No
    cmp.b   #':',d2
    bne.s   @Find
    bra.s   @Go               ; Yes
@Port:
    subq.l  #1,a1             ; Back to the zero
    lea     PORT_80,a0
@Copy:
    move.b  (a0)+,(a1)+       ; Web sites use port 80
    bne.s   @Copy
@Go:
    clr.w   site_len
    bsr     Print             ; New row
    lea     SITE,a0
    bsr     Fetch
    bra.s   @Status
@Back:
    tst.w   d1
    beq.s   @Status           ; Nothing typed
    subq.w  #1,site_len
    subq.w  #1,P_X(a2)
    move.w  P_X(a2),d1
    moveq   #25,d2
    moveq   #' ',d0
    bsr     Draw_Char         ; Erase the last key

@Status:
    bsr     Show_KB           ; Still plugged in?

    bsr     Read_Pad          ; d0 = buttons held
    move.b  pad_prev,d1
    move.b  d0,pad_prev
    tst.b   d1
    bne.s   @Receive          ; Only act when no button was held last frame
    btst    #6,d0             ; A. The xPico holds data in its 2K buffer
    beq.s   @B
    bsr     Flow_On
@B:
    btst    #4,d0             ; B. The xPico sends the held data
    beq.s   @C
    bsr     Flow_Off
@C:
    btst    #5,d0             ; C. Drop the call
    beq.s   @Receive
    bsr     Hang_Up
    lea     NET_PANE,a2
    lea     DISCONNECT_TEXT,a0
    bsr     Print_Text        ; "Disconnected"

@Receive:
    lea     NET_PANE,a2
@Next:
    move.b  RX_TAIL,d0
    cmp.b   RX_HEAD,d0        ; Anything in the ring buffer?
    beq     Main_Loop
    bsr     Read_Buffer
    bsr     Print             ; Show what arrives
    bra.s   @Next

Halt:                         ; Errors stop here
    bra.s   Halt

No_Interrupt:
    rte

; Show Ok in green, or the fail mark at a0 in red, inside the status [  ] on row d2. d0 = 0 fails.

Show_Status:
    move.w  #$2000,text_pal   ; Red text
    tst.b   d0
    beq.s   @Show
    move.w  #$4000,text_pal   ; Green text
    lea     OK_TEXT,a0
@Show:
    moveq   #10,d1
    bsr     Draw_Text
    clr.w   text_pal          ; White text
    rts

Show_KB:                      ; Keyboard [Ok] or [--]
    bsr     Detect_KB
    move.b  kb_present,d0
    moveq   #2,d2
    lea     NO_TEXT,a0
    bra.s   Show_Status

; Hang up. Pin 7 (xPico CP3) going low drops the call. Uses d0, d4

Hang_Up:
    bsr     Flow_Off          ; Let anything held come out
    bsr     Deny_Connections  ; Pin 7 low hangs up the site
@Quiet:
    move.b  RX_HEAD,RX_TAIL   ; Drop the rest until it goes quiet
    moveq   #6-1,d4
@Wait:
    bsr     Wait_VBlank       ; 100ms
    dbra    d4,@Wait
    move.b  RX_TAIL,d0
    cmp.b   RX_HEAD,d0
    bne.s   @Quiet
    rts

; Mini curl. Hangs up the last site, then asks a web site ("name:80") at a0 for its home page.
; The main loop prints the reply. HTTP/1.1 keeps the call up after the page. The xPico throws away
; what it still holds when a call ends, so a site that hung up at once would cut the page short.

Fetch:
    movea.l a0,a4             ; Keep the site
    bsr     Hang_Up
    bsr     Allow_Connections ; Pin 7 high for the new call

    lea     NET_PANE,a2
    lea     CONNECTING_TEXT,a0
    bsr     Print_Text        ; "Connecting to "
    movea.l a4,a0
    bsr     Print_Text
    moveq   #$0A,d0
    bsr     Print
    movea.l a4,a0
    bsr     Connect
    bsr     Read_Buffer       ; 'C' = connected
    cmp.b   #'C',d0
    bne.s   @Fail
    lea     GET_TEXT,a0
    bsr     Send_String       ; "GET / HTTP/1.1" and "Host: "
    movea.l a4,a0
    bsr     Send_String
    lea     END_TEXT,a0
    bra     Send_String       ; A blank line ends the request
@Fail:
    lea     UNREACHABLE_TEXT,a0
    bra     Print_Text

; Text panes. Print scrolls a pane up when a new row starts: the VDP copies its rows up one row
; (a VRAM copy DMA) and the bottom row is cleared.

Print:                        ; Prints character d0 in the pane at a2. Uses d1, d2, d3, a3
    move.w  P_TOP(a2),d2
    add.w   P_ROWS(a2),d2
    subq.w  #1,d2             ; Bottom row
    cmp.b   #$0A,d0           ; New row?
    beq.s   @Scroll
    cmp.w   #40,P_X(a2)       ; Row full?
    bne.s   @Draw
@Scroll:
    bsr.s   Scroll
    clr.w   P_X(a2)
@Draw:
    cmp.b   #' ',d0           ; Skip CR and other control bytes
    blo.s   @Done
    cmp.b   #'~',d0
    bhi.s   @Done
    move.w  P_X(a2),d1
    bsr     Draw_Char
    addq.w  #1,P_X(a2)
@Done:
    rts

Print_Text:                   ; Prints the zero terminated string at a0 in the pane at a2
    move.b  (a0)+,d0
    beq.s   @Done
    bsr.s   Print
    bra.s   Print_Text
@Done:
    rts

Scroll:                       ; Scrolls the pane at a2 up one row. d2 = its bottom row. Uses d1, d3, a3
    lea     VDP_CTRL,a3
    move.w  #$8F01,(a3)       ; Copy 1 byte at a time
    move.w  P_ROWS(a2),d3
    subq.w  #1,d3
    lsl.w   #7,d3             ; Bytes to copy. A plane row is 128 bytes
    move.w  #$9300,d1
    move.b  d3,d1
    move.w  d1,(a3)           ; Length low byte
    lsr.w   #8,d3
    move.w  #$9400,d1
    move.b  d3,d1
    move.w  d1,(a3)           ; Length high byte
    move.w  P_TOP(a2),d3
    lsl.w   #7,d3
    addi.w  #$C080,d3         ; From the second row of the pane in Plane A ($C000)
    move.w  #$9500,d1
    move.b  d3,d1
    move.w  d1,(a3)           ; Source low byte
    move.w  d3,d1
    lsr.w   #8,d1
    ori.w   #$9600,d1
    move.w  d1,(a3)           ; Source high byte
    move.w  #$97C0,(a3)       ; VRAM copy
    subi.w  #$8080,d3         ; To the top row: $4000 + its offset in Plane A
    move.w  d3,(a3)
    move.w  #$00C3,(a3)       ; Go
@Busy:
    btst    #1,1(a3)          ; Wait for the copy to finish
    bne.s   @Busy
    move.w  #$8F02,(a3)       ; Back to 2 bytes at a time
    moveq   #0,d1
    bsr.s   Set_Cursor        ; Clear the bottom row
    moveq   #40-1,d3
@Clear:
    move.w  #' ',VDP_DATA
    dbra    d3,@Clear
    rts

; Text. The font tiles sit at their ASCII codes in VRAM, so each character is its own tile.

Set_Cursor:                   ; Points the VDP at column d1, row d2 of Plane A. Uses d3
    move.w  d2,d3
    lsl.w   #6,d3             ; Row * 64 tiles
    add.w   d1,d3             ; + column
    add.w   d3,d3             ; 2 bytes each
    addi.w  #$4000,d3         ; VRAM write to Plane A at $C000
    swap    d3
    move.w  #$0003,d3
    move.l  d3,VDP_CTRL
    rts

Draw_Text:                    ; Draws the zero terminated string at a0 from column d1, row d2
    move.b  (a0)+,d0
    beq.s   @Done
    bsr.s   Draw_Char
    addq.w  #1,d1             ; Next column
    bra.s   Draw_Text
@Done:
    rts

Draw_Char:                    ; Draws character d0 at column d1, row d2 in the text_pal color
    movem.l d0/d3,-(sp)
    bsr.s   Set_Cursor
    andi.w  #$FF,d0
    cmp.b   #$60,d0           ; Lower case?
    blo.s   @Upper
    subi.b  #$20,d0           ; The font has upper case only
@Upper:
    or.w    text_pal,d0       ; Color
    move.w  d0,VDP_DATA
    movem.l (sp)+,d0/d3
    rts

Wait_VBlank:                  ; Waits for the start of the next VBlank. Uses d0
    move.w  VDP_CTRL,d0
    btst    #3,d0             ; Still in the last one?
    bne.s   Wait_VBlank
@Wait:
    move.w  VDP_CTRL,d0
    btst    #3,d0             ; Wait for the next one
    beq.s   @Wait
    rts

; The joypad in port 1. TH high reads C, B and the d-pad. TH low reads START and A.

Read_Pad:                     ; d0 = buttons held. Bit 7 START, 6 A, 5 C, 4 B. Uses d1
    move.b  #$40,PORT1_DATA   ; TH high
    nop
    nop
    move.b  PORT1_DATA,d1     ; C B Right Left Down Up
    move.b  #$00,PORT1_DATA   ; TH low
    nop
    nop
    move.b  PORT1_DATA,d0     ; START A
    lsl.b   #2,d0             ; START and A into bits 7 and 6
    andi.b  #$C0,d0
    andi.b  #$3F,d1
    or.b    d1,d0
    not.b   d0                ; Buttons read 0 when pressed. Flip them
    rts

ADAPTER_TEXT:     dc.b 'Adapter  [  ]',0
KB_TEXT:          dc.b 'Keyboard [  ]',0
LINE_TEXT:        dc.b '----------------------------------------',0
OK_TEXT:          dc.b 'Ok',0
NO_TEXT:          dc.b '--',0
XX_TEXT:          dc.b 'XX',0
MISSING_TEXT:     dc.b 'Adapter not present',0
IP_TEXT:          dc.b 'IP Address:',0
MAC_TEXT:         dc.b 'MAC:',0
NETWORK_TEXT:     dc.b 'NETWORK  (A pause, B resume, C hang up)',0
KEYBOARD_TEXT:    dc.b 'KB INPUT - (EX: EXAMPLE.COM:80, ENTER)',0
CONNECTING_TEXT:  dc.b $0A,'Connecting to ',0
UNREACHABLE_TEXT: dc.b 'Host unreachable',$0A,0
DISCONNECT_TEXT:  dc.b $0A,'Disconnected',$0A,0
FIRST_SITE:       dc.b 'example.com:80',0
PORT_80:          dc.b ':80',0
GET_TEXT:         dc.b 'GET / HTTP/1.1',$0D,$0A,'Host: ',0
END_TEXT:         dc.b $0D,$0A,$0D,$0A,0
    even

VDP_REGS:
    dc.w    $8004             ; HBlank interrupt off
    dc.w    $8154             ; Display on, VBlank interrupt off, DMA on, mode 5
    dc.w    $8230             ; Plane A at $C000
    dc.w    $8407             ; Plane B at $E000
    dc.w    $8578             ; Sprites at $F000
    dc.w    $8700             ; Background is palette 0, color 0
    dc.w    $8B00             ; External interrupt off, full screen scroll
    dc.w    $8C81             ; 40 columns (320 pixels)
    dc.w    $8D3F             ; Horizontal scroll at $FC00
    dc.w    $8F02             ; VRAM address goes up 2 each write
    dc.w    $9001             ; Planes are 64x32 tiles
    dc.w    $9100             ; No window
    dc.w    $9200

FONT:                         ; Characters $20-$5F. 8x8 pixels, 1 bit each
    dc.b    $00,$00,$00,$00,$00,$00,$00,$00  ; Space
    dc.b    $30,$30,$30,$30,$30,$00,$30,$00  ; !
    dc.b    $6C,$6C,$48,$00,$00,$00,$00,$00  ; "
    dc.b    $6C,$6C,$FE,$6C,$FE,$6C,$6C,$00  ; #
    dc.b    $30,$7E,$C0,$7C,$06,$FC,$30,$00  ; $
    dc.b    $C6,$CC,$18,$30,$60,$CC,$8C,$00  ; %
    dc.b    $78,$CC,$78,$76,$DC,$CC,$76,$00  ; &
    dc.b    $30,$30,$60,$00,$00,$00,$00,$00  ; '
    dc.b    $18,$30,$60,$60,$60,$30,$18,$00  ; (
    dc.b    $60,$30,$18,$18,$18,$30,$60,$00  ; )
    dc.b    $00,$6C,$38,$FE,$38,$6C,$00,$00  ; *
    dc.b    $00,$30,$30,$FC,$30,$30,$00,$00  ; +
    dc.b    $00,$00,$00,$00,$30,$30,$60,$00  ; ,
    dc.b    $00,$00,$00,$FC,$00,$00,$00,$00  ; -
    dc.b    $00,$00,$00,$00,$00,$30,$30,$00  ; .
    dc.b    $06,$06,$0C,$18,$30,$60,$60,$00  ; /
    dc.b    $7C,$C6,$CE,$D6,$E6,$C6,$7C,$00  ; 0
    dc.b    $30,$70,$30,$30,$30,$30,$FC,$00  ; 1
    dc.b    $7C,$C6,$06,$3C,$60,$C0,$FE,$00  ; 2
    dc.b    $7C,$C6,$06,$3C,$06,$C6,$7C,$00  ; 3
    dc.b    $1C,$3C,$6C,$CC,$FE,$0C,$0C,$00  ; 4
    dc.b    $FE,$C0,$FC,$06,$06,$C6,$7C,$00  ; 5
    dc.b    $3C,$60,$C0,$FC,$C6,$C6,$7C,$00  ; 6
    dc.b    $FE,$C6,$0C,$18,$30,$30,$30,$00  ; 7
    dc.b    $7C,$C6,$C6,$7C,$C6,$C6,$7C,$00  ; 8
    dc.b    $7C,$C6,$C6,$7E,$06,$0C,$78,$00  ; 9
    dc.b    $00,$30,$30,$00,$00,$30,$30,$00  ; :
    dc.b    $00,$30,$30,$00,$30,$30,$60,$00  ; ;
    dc.b    $0C,$18,$30,$60,$30,$18,$0C,$00  ; <
    dc.b    $00,$00,$FC,$00,$FC,$00,$00,$00  ; =
    dc.b    $60,$30,$18,$0C,$18,$30,$60,$00  ; >
    dc.b    $7C,$C6,$06,$1C,$30,$00,$30,$00  ; ?
    dc.b    $7C,$C6,$DE,$DE,$DC,$C0,$7C,$00  ; @
    dc.b    $38,$6C,$C6,$C6,$FE,$C6,$C6,$00  ; A
    dc.b    $FC,$C6,$C6,$FC,$C6,$C6,$FC,$00  ; B
    dc.b    $3C,$66,$C0,$C0,$C0,$66,$3C,$00  ; C
    dc.b    $F8,$CC,$C6,$C6,$C6,$CC,$F8,$00  ; D
    dc.b    $FE,$C0,$C0,$FC,$C0,$C0,$FE,$00  ; E
    dc.b    $FE,$C0,$C0,$FC,$C0,$C0,$C0,$00  ; F
    dc.b    $3E,$60,$C0,$CE,$C6,$66,$3E,$00  ; G
    dc.b    $C6,$C6,$C6,$FE,$C6,$C6,$C6,$00  ; H
    dc.b    $FC,$30,$30,$30,$30,$30,$FC,$00  ; I
    dc.b    $0E,$06,$06,$06,$C6,$C6,$7C,$00  ; J
    dc.b    $C6,$CC,$D8,$F0,$F8,$CC,$C6,$00  ; K
    dc.b    $C0,$C0,$C0,$C0,$C0,$C0,$FE,$00  ; L
    dc.b    $C6,$EE,$FE,$FE,$D6,$C6,$C6,$00  ; M
    dc.b    $C6,$E6,$F6,$DE,$CE,$C6,$C6,$00  ; N
    dc.b    $7C,$C6,$C6,$C6,$C6,$C6,$7C,$00  ; O
    dc.b    $FC,$C6,$C6,$FC,$C0,$C0,$C0,$00  ; P
    dc.b    $7C,$C6,$C6,$C6,$DE,$CC,$76,$00  ; Q
    dc.b    $FC,$C6,$C6,$FC,$D8,$CC,$C6,$00  ; R
    dc.b    $7C,$C6,$C0,$7C,$06,$C6,$7C,$00  ; S
    dc.b    $FC,$30,$30,$30,$30,$30,$30,$00  ; T
    dc.b    $C6,$C6,$C6,$C6,$C6,$C6,$7C,$00  ; U
    dc.b    $C6,$C6,$C6,$C6,$6C,$38,$10,$00  ; V
    dc.b    $C6,$C6,$D6,$FE,$FE,$EE,$C6,$00  ; W
    dc.b    $C6,$C6,$6C,$38,$6C,$C6,$C6,$00  ; X
    dc.b    $CC,$CC,$CC,$78,$30,$30,$30,$00  ; Y
    dc.b    $FE,$06,$0C,$18,$30,$60,$FE,$00  ; Z
    dc.b    $78,$60,$60,$60,$60,$60,$78,$00  ; [
    dc.b    $60,$60,$30,$18,$0C,$06,$06,$00  ; \
    dc.b    $78,$18,$18,$18,$18,$18,$78,$00  ; ]
    dc.b    $38,$6C,$C6,$00,$00,$00,$00,$00  ; ^
    dc.b    $00,$00,$00,$00,$00,$00,$FE,$00  ; _
    include 'network.asm'     ; The Retro.Link routines

ROM_END:

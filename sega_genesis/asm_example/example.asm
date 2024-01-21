; Below are the hardware registers you use to poke at the UART. Most of these registers are for 
; configuration and you more than likely wont use but a few after initialization. They are accessed
; a byte at a time.

UART_RHR    EQU $A130C1      ; Receive holding register
UART_THR    EQU $A130C1      ; Transmit holding register
UART_IER    EQU $A130C3      ; Interrupt enable register
UART_FCR    EQU $A130C5      ; FIFO control register
UART_LCR    EQU $A130C7      ; Line control register
UART_MCR    EQU $A130C9      ; Modem control register
UART_LSR    EQU $A130CB      ; Line status register
UART_DLL    EQU $A130C1      ; Div latch low byte
UART_DLM    EQU $A130C3      ; Div latch high byte
UART_DVID   EQU $A130C3      ; Device ID

; These registers are set in a specific order. This is important to note!

Detect_Adapter:
    move.b  #$80, UART_LCR
    move.b  #$00, UART_DLM
    move.b  #$00, UART_DLL
    cmp.b   #$10, UART_DVID  ; 0x10 = Present
    bne.s   @Not_Found
@Init_UART:
    move.b  #$83, UART_LCR   ; 8-N-1 (7th bit sets divisor latch registers for manipulation)
    move.b  #$00, UART_DLM   ; 921600 baud rate
    move.b  #$01, UART_DLL   ; 921600 baud rate
    move.b  #$03, UART_LCR   ; Unset 7th bit so we now use data registers instead of divisor registers
    move.b  #$08, UART_MCR   ; Tell xpico to block all incoming tcp connections on powerup (default state)
    move.b  #$07, UART_FCR   ; Enable and reset fifo pointers & data counters
    move.b  #1,cart_present
    rts
@Not_Found:
    clr.b   cart_present
    rts

; Allowing inbound TCP connections to the device is done by setting a
; the UART_MCR register to a value of $08. If you wish to drop the current connection
; and block future connections, write a value of $00 to UART_MCR. 

Allow_Connections:
    move.b  #$08, UART_MCR   ; Allow inbound connections on port 5364.
    rts

Deny_Connections:
    move.b  #$00, UART_MCR   ; Drop/Deny connections inbound
    rts

; To make a connection to another device via TCP you will need to send a connection
; command string through the UART to the XPICO by writing an IP address and port "C70.13.153.10:5364\n".
; You can also use DNS in place of the IP address as well "Cwebsite.com:80\n". All Retro.link 
; cartidges use the port 5364 for incoming connections.

Connect:
    lea     IP_ADDRESS,A0    ; Our string to send
    move.w  #21,D1           ; Number of bytes to send
@Write_Loop:
    move.b  (a0)+,d0         ; Move byte from string to d0
    bsr     Send_Byte        ; Send byte in d0
    dbra    d1,@Write_Loop   ; Decrement and branch until done
    rts                      ; return

IP_ADDRESS:     dc.b 'C000.000.000.000:5364\n',0

; This will either return a single 'C' character if a connection was successfully made or an 'N'
; character which means it could not connect to the supplied address. Once connected you can read
; or write serial data to the other device immediately. 

; When receiving an inbound connection, you will receive a string of text. This string contains 'CI'
; and then the IP address of the remote device connecting. 'CI192.168.1.150'. 

; When the device disconnects or is disconnected it will return a 'D' character.

; Sending or receving data is done a byte at a time querying the UART status register

Send_Byte:
	btst   #5,UART_LSR       ; Ok to send?
	beq.s  Send_Byte         ; Wait until ok
	move.b d0,UART_THR       ; Send a byte
	rts                      ; Return

Receive_Byte:
	btst   #0,UART_LSR       ; Data available?
	beq.s  Receive_Byte      ; No. So wait and check until data arrives
	move.b UART_RHR,d0       ; Read in byte from receive buffer to d0
	rts                      ; Return

Flush_Fifos:
    move.b  #$07, UART_FCR   ; reset/"flush" send/receive fifo buffer indexes
    rts                      ; Return

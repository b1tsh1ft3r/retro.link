; there is a bug with establish comms routine for some reason right now. unsure why
; immediately after a few matches it will just have the slave go right to "network timeout"
; message. Timeout logic commented out for now

;*******************************************************************************
;** ESTABLISH COMMUNICATION                                                   ** [OK]
;*******************************************************************************
ESTABLISH_COMMS:
    MOVEM.L D0-D6/A0-A6,-(A7)

    MOVE.B  #$07,UART_FCR         ; FLUSH FIFOS ON UART

    JSR     SETUP_VDP             ; RESET VDP, CLEAR VRAM, LOAD FONT FOR DISPLAYING TEXT

    MOVEQ   #0, D5                ; X POSISION
    MOVEQ   #14, D6               ; Y POSITION
    LEA     ESTABLISH_TXT,A6      ; TEXT STRING
    JSR     WriteText             ; DRAW TEXT

    CLR.L   D0                    ; CLEAR
    CLR.L   D1                    ; CLEAR
    CLR.L   D2                    ; CLEAR 
    CLR.L   D3                    ; CLEAR

    CMP.B   #'S',WHOAMI           ; ARE WE SLAVE?
    BEQ.W   ESTABLISH_SLAVE       ; THEN BRANCH AND DO SLAVE ROUTINE
;------------------------------------------------------------------------------
ESTABLISH_MASTER:
;------------------------------------------------------------------------------
    BTST    #5,UART_LSR           ; OK TO SEND DATA?
    BEQ.S   ESTABLISH_MASTER      ; NOPE, SO WAIT UNTIL IT IS
;   ADD.B   #1,D2                 ; INCREMENT TIMEOUT COUNTER
    MOVE.W  #$FFFF,D3             ; SETUP D3 WITH COUNTDOWN VALUE
    MOVE.B  #'?',UART_THR         ; SEND 'ARE YOU THERE' TOKEN
@LOOP1:
    BTST    #0,UART_LSR           ; DATA AVAILABLE?
    BNE.S   @GET_RESPONSE         ; IF DATA AVAILABLE, BRANCH AND GET IT
    NOP
    NOP
;   CMP.B   #32,D2                ; DID WE HIT TIMEOUT VALUE WAITING FOR SLAVE RESPONSE?
;   BGE.W   ESTABLISH_TIMEOUT     ; BRANCH TO ESTABLISH COMMUNICATIONS NETWORK TIMEOUT ROUTINE
    DBRA    D3,@LOOP1             ; OTHERWISE LOOP AROUND AGAIN
    BRA.S   ESTABLISH_MASTER      ; GO BACK AROUND
@GET_RESPONSE:
    MOVE.B  UART_RHR,D0           ; GET BYTE
    CMP.B   #'!',D0               ; RESPONSE FROM SLAVE?
    BNE.S   @LOOP1                ; IF NOT RIGHT RESPONSE, KEEP CHECKING...
@SETUP_MAIN:
    MOVE.W  #15,D1                ; NUMBER OF TIMES WE NEED TO PASS BYTES (16 AKA 0-15)
    MOVE.B  #$21,D2               ; SET OUR STARTING TOKEN VALUE TO SEND ('!' ASCII)
    MOVE.B  #$07,UART_FCR         ; FLUSH FIFOS ON UART
@MAIN:
    BTST    #5,UART_LSR           ; OK TO SEND?
    BEQ.S   ESTABLISH_SLAVE       ; KEEP WAITING UNTIL OK TO SEND
    MOVE.B  D2,UART_THR           ; SEND BYTE
@MAIN_LOOP:
    BTST    #0,UART_LSR           ; DATA AVAILABLE IN UART?
    BEQ.S   @MAIN_LOOP            ; NO SO KEEP CHECKING
    MOVE.B  UART_RHR,D0           ; GET BYTE
    CMP.B   D2,D0                 ; IS IT WHAT WE SENT?
    BNE.W   @SETUP_MAIN           ; NO SO RESTART!
    ADD.B   #$1,D2                ; INCREMENT TOKEN VALUE (CHANGE IT)
    DBRA    D1,@MAIN              ; DECREMENT UNTIL -1
@MAIN_DONE:
    BTST    #5,UART_LSR           ; OK TO SEND?
    BEQ.S   @MAIN_DONE            ; KEEP WAITING UNTIL OK TO SEND
    MOVE.B  #$FF,UART_THR         ; SEND TERMINATION BYTE
    BRA.S   ESTABLISH_DONE        ; EXIT!
    RTS
;------------------------------------------------------------------------------
ESTABLISH_SLAVE:
;------------------------------------------------------------------------------
;   ADD.B   #1,D2                 ; INCREMENT TIMEOUT COUNTER
    MOVE.L  #$FFFF,D3             ; SETUP D3 WITH COUNTDOWN VALUE
@LOOP1:
    BTST    #0,UART_LSR           ; DATA AVAILABLE?
    BNE.S   @GET_RESPONSE         ; IF DATA AVAILABLE, BRANCH AND GET IT
    NOP
    NOP
;   CMP.B   #32,D2                ; DID WE HIT TIMEOUT VALUE WAITING FOR MASTER?
;   BGE.S   ESTABLISH_TIMEOUT     ; BRANCH TO ESTABLISH COMMUNICATIONS NETWORK TIMEOUT ROUTINE
    DBRA    D3,@LOOP1             ; OTHERWISE LOOP AROUND AGAIN
    BRA.S   ESTABLISH_SLAVE       ; GO BACK AROUND
@GET_RESPONSE:
    MOVE.B  UART_RHR,D0           ; GET BYTE TO D0
    CMP.B   #'?',D0               ; AREYOUTHERE BYTE?
    BNE.S   ESTABLISH_SLAVE       ; NO! SO KEEP WAITING UNTIL TIMEOUT
@ECHO_RESPONSE:
    BTST    #5,UART_LSR           ; OTHERWISE OK TO SEND?
    BEQ.S   @ECHO_RESPONSE        ; WAIT UNTIL OK TO SEND
    MOVE.B  #$07,UART_FCR         ; FLUSH FIFOS ON UART
    MOVE.B  #'!',UART_THR         ; ECHO 'IMHERE' TO MASTER
@MAIN_LOOP:
    BTST    #0,UART_LSR           ; DATA AVAILABLE?
    BEQ.S   @MAIN_LOOP            ; NO SO KEEP CHECKING...
    MOVE.B  UART_RHR,D0           ; GET BYTE TO D0
    CMP.B   #$FF,D0               ; TERMINATION BYTE?
    BEQ.W   ESTABLISH_DONE        ; IF SO, EXIT
    MOVE.B  D0,UART_THR           ; OTHERWISE ECHO IT BACK
    BRA.S   @MAIN_LOOP            ; LOOP AROUND
;------------------------------------------------------------------------------
ESTABLISH_DONE: 
;------------------------------------------------------------------------------
    MOVEM.L (SP)+,D0-D6/A0-A6     ; RESTORE REGISTER DATA AND ADDRESSES
    RTS
;------------------------------------------------------------------------------
ESTABLISH_TIMEOUT:
;------------------------------------------------------------------------------
    MOVEQ   #0, D5                ; X POSISION
    MOVEQ   #14, D6               ; Y POSITION
    LEA     TIMEOUT_TXT,A6        ; PRINT TEXT
    JSR     WriteText
@TIMEOUT_LOOP:
    BRA     @TIMEOUT_LOOP

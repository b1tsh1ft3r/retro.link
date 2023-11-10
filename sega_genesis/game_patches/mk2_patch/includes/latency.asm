; Had good solid results with latency checks being 64 but it takes a while
; 48 seems ok and 32 is quicker
LATENCY_CHECKS      EQU 32        ; RANGE IS 2-255 (MUST BE EVEN)

;*******************************************************************************
;** GET_LATENCY                                                               ** [OK]
;*******************************************************************************
GET_LATENCY:
    MOVEM.L D0-D6/A0-A6,-(A7)

    MOVEQ   #0, D5                ; X POSISION
    MOVEQ   #14, D6               ; Y POSITION
    LEA     LATENCY_TXT,A6        ; TEXT STRING
    JSR     WriteText             ; DRAW TEXT

    CLR.L   D0                    ; CLEAR
    CLR.L   D1                    ; CLEAR
    CLR.L   D2                    ; CLEAR 
    CLR.L   D3                    ; CLEAR

    CMP.B   #'S',WHOAMI           ; WHOAMI
    BEQ.W   LATENCY_RECEIVE       ; SLAVE RECEIVES

;------------------------------------------------------------------------------
LATENCY_SEND:
;------------------------------------------------------------------------------
    MOVE.B  #LATENCY_CHECKS-1,D2  ; NUMBER OF TIMES WE ARE GOING TO SAMPLE LATENCY
@LATENCY_LOOP:
    MOVE.W  $C00004,D1            ; GET VDP STATUS
    AND.B   #$8,D1                ; IN VBLANK?
    BNE.S   @LATENCY_LOOP         ; YES, SO WAIT UNTIL WE ARENT IN VBLANK

    BTST    #5,UART_LSR           ; OK TO SEND?
    BEQ.S   @LATENCY_LOOP         ; NO, SO KEEP WAITING
    MOVE.B  #'@',UART_THR         ; SEND LATENCY TOKEN TO SLAVE
    CLR.W   VBL_COUNTER           ; RESET VBLANK COUNTER
@GET_RESPONSE:
    MOVE.W  $C00004,D1            ; GET VDP STATUS
    AND.B   #$8,D1                ; IN VBLANK?
    BNE.S   @GET_RESPONSE         ; YES, SO WAIT UNTIL WE ARENT IN VBLANK

    BTST    #0,UART_LSR           ; DATA AVAILABLE?
    BEQ.S   @GET_RESPONSE         ; IF NO DATA AVAILABLE, KEEP WAITING...
    MOVE.W  VBL_COUNTER,D1        ; GET CURRENT VBLANK COUNT VALUE AND STORE IN D1
    MOVE.B  UART_RHR,D0           ; GET BYTE
    CMP.B   #'@',D0               ; LATENCY BYTE?
    BNE.S   LATENCY_SEND          ; NOPE! SO START OVER...
@CHECK_VALUE:
    CMP.W   D3,D1                 ; IS RECEIVED VALUE LARGER THAN PREVIOUS VALUE?
    BGT.S   @BIGGER               ; BRANCH BECAUSE ITS LARGER
    BRA.S   @SMALLER              ; OTHERWISE ITS SMALLER
@BIGGER:
    MOVE.W  D1,D3                 ; STORE IT FOR NEXT GO AROUND
@SMALLER:
    SUB.B   #1,D2                 ; DECREMENT LATENCY CHECK COUNTER
    TST.B   D2                    ; DONE SAMPLING LATENCY?
    BEQ.S   @INSPECT_RESULT       ; IF SO THEN LETS INSPECT THE RESULT
    BRA.S   @LATENCY_LOOP         ; OTHERWISE WE LOOP AROUND AGAIN
@INSPECT_RESULT:
    MOVE.W  D3,FRAME_DELAY        ; STORE FRAME DELAY VALUE LOCALLY
@SEND_DONE:
    BTST    #5,UART_LSR           ; OK TO SEND?
    BEQ.S   @SEND_DONE            ; WAIT UNTIL OK TO SEND
    MOVE.B  #'%',UART_THR         ; SEND WAIT LATENCY LOOP TERMINATION BYTE TO OTHER CONSOLE       

    CMP.B   #'S',WHOAMI           ; SLAVE COMING THROUGH THIS LOOP?
    BEQ.S   LATENCY_DONE          ; THEN WE'RE DONE!

    ; MASTER FALLS THROUGH AUTOMATICALLY INTO RECEIVE AS IT SHOULD
;------------------------------------------------------------------------------
LATENCY_RECEIVE:
;------------------------------------------------------------------------------
    BTST    #0,UART_LSR           ; BYTE AVAILABLE?
    BEQ.S   LATENCY_RECEIVE       ; WAIT UNTIL AVAILABLE
    MOVE.B  UART_RHR,D0           ; GET BYTE
    CMP.B   #'%',D0               ; LATENCY LOOP TERMINATION TOKEN?
    BEQ.S   @RECEIVE_DONE         ; THEN WE'RE DONE!
@ECHO_RESPONSE:
    BTST    #5,UART_LSR           ; OK TO SEND?
    BEQ.S   @ECHO_RESPONSE        ; WAIT UNTIL OK TO SEND
    MOVE.B  D0,UART_THR           ; ECHO BACK RESPONSE
    BRA.S   LATENCY_RECEIVE       ; LOOP AROUND AGAIN
@RECEIVE_DONE:
    CMP.B   #'M',WHOAMI           ; IF MASTER WE'RE DONE...
    BEQ.S   LATENCY_DONE          ; EXIT
    BRA.W   LATENCY_SEND          ; OTHERWISE SLAVES TURN TO SEND
;------------------------------------------------------------------------------
LATENCY_DONE:
;------------------------------------------------------------------------------
    JSR     SETUP_JOYBUFFER       ; Setup our joystick input buffer size to reflect the latency value
    MOVEM.L (SP)+,D0-D6/A0-A6     ; RESTORE REGISTER DATA AND ADDRESSES
    RTS
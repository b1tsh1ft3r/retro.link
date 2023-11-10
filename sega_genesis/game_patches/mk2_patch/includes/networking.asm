; there is a bug with establish comms routine for some reason right now. unsure why
; immediately after a few matches it will just have the slave go right to "network timeout"
; message. Timeout logic commented out for now

;http://mauve.mizuumi.net/2012/07/05/understanding-fighting-game-networking/

NODATA              EQU $FFFF     ; RESTING VALUE FOR JOYPAD RAM REGISTER WHEN NO BUTTONS PRESSED

;*******************************************************************************
;** SETUP LOCAL JOYSTICK BUFFER                                               ** [OK]
;*******************************************************************************
SETUP_JOYBUFFER:
    CLR.W   BUFFER_PTR           ; CLEAR BUFFER POINTER
    LEA     JOY_BUFFER,A0        ; POINT A0 TO JOYSTICK BUFFER
    MOVE.W  FRAME_DELAY,D0       ; USE FRAME DELAY TO DETERMINE WHAT SIZE BUFFER TO CLEAR
@CLEAR_JOYBUFF:
    MOVE.W  #NODATA,(A0)+        ; FILL BUFFER WITH NODATA VALUE
    SUBQ.W  #1,D0                ; SUBTRACT 1 FROM FRAME DELAY VALUE
    TST.W   D0                   ; DONE?
    BNE.S   @CLEAR_JOYBUFF       ; NO, SO LOOP AROUND AND KEEP CHECKING
    MOVE.W  #NODATA,CTRL1_DATA   ; FLUSH CONTROLLER INPUT VARIABLE FOR P1
    MOVE.W  #NODATA,CTRL2_DATA   ; FLUSH CONTROLLER INPUT VARIABLE FOR P2
    RTS  

;*******************************************************************************
;** GET & PUT BUFFERED JOYSTICK DATA                                          ** [OK]
;*******************************************************************************
; D0 on entry is stored into the buffer. We return buffered data in D0 on exit
GETPUT_BUFFER:
    LEA     JOY_BUFFER,A0        ; LOAD BUFFER POINTER TO A0
    MOVE.W  BUFFER_PTR,D2        ; LOAD BUFFER POINTER TO D2
    MOVE.W  0(A0,D2),D1          ; GET BUFFERED ENTRY INT0 D1
    MOVE.W  D0,0(A0,D2)          ; STORE OUR NEW ENTRY TO BUFFER
    CLR.L   D0                   ; ENSURE D0 IS FULLY CLEAN
    MOVE.W  D1,D0                ; MOVE RETRIEVED BUFFERED DATA TO D0
    ADD.W   #2,D2                ; INCREMENT BUFFER POINTER (add 2 for a word of data, 1 for a single byte)
    CMP.W   FRAME_DELAY,D2       ; BUFFER WRAP?
    BLE.S   @NO_BUFFER_WRAP      ; MOVE ON IF NO BUFFER WRAP
@BUFFER_WRAP:
    CLR.W   D2                   ; RESET BUFFER POINTER
@NO_BUFFER_WRAP:
    MOVE.W  D2,BUFFER_PTR        ; UPDATE BUFFER POINTER
    RTS

;*******************************************************************************
;** NETWORKING                                                                **
;*******************************************************************************
NETWORKING:
    CMP.B   #'M',WHOAMI           ; IS THIS CONSOLE MASTER?
    BNE.S   NETWORK_SETUP_SLAVE   ; NOPE! SO WE ARE SLAVE
;---------------------------------
NETWORK_SETUP_MASTER:
    LEA     CTRL1_DATA,A1         ; POINTER TO CONTROLLER DATA
    LEA     CTRL2_DATA,A2         ; POINTER TO CONTROLLER DATA
    LEA     $FFFFF9D2,A3          ; FULL LONGWORD OF CONTROLLER DATA THAT MK2 LIKES TO SEE
    BRA.S   NETWORK_RECEIVE       ; START OFF RECEIVING FIRST
;---------------------------------
NETWORK_SETUP_SLAVE:
    LEA     CTRL1_DATA,A2         ; POINTER TO CONTROLLER DATA
    LEA     CTRL2_DATA,A1         ; POINTER TO CONTROLLER DATA
    LEA     $FFFFF9E0,A3          ; FULL LONGWORD OF CONTROLLER DATA THAT MK2 LIKES TO SEE
;---------------------------------
NETWORK_RECEIVE:
    BTST    #0,UART_LSR           ; DATA AVAILABLE?
    BEQ.W   NETWORK_NORECV        ; IF NOT, JUST EXIT
NETWORK_CHK_VBLANK:
    MOVE.W  $C00004,D0            ; GET VDP STATUS
    AND.B   #$8,D0                ; IN VBLANK?
RECV_SKIP_VBLCHK:
    BNE.S   NETWORK_CHK_VBLANK    ; YES, SO WAIT UNTIL WE ARENT IN VBLANK
    MOVE.B  $C00009,D0            ; GET LOCAL VCOUNT VALUE TO D0
    MOVE.B  UART_RHR,D1           ; GET REMOTE VCOUNT VALUE TO D1
GET_BYTE2:
    BTST    #0,UART_LSR           ; 1ST BYTE OF CONTROLLER DATA AVAILABLE?
    BEQ.S   GET_BYTE2             ; NO, SO EXIT
    MOVE.B  UART_RHR,(A2)+        ; YES, GET BYTE AND STORE IT!
GET_BYTE3:
    BTST    #0,UART_LSR           ; 2ND BYTE OF CONTROLLER DATA AVAILABLE?
    BEQ.S   GET_BYTE3             ; NO, SO WAIT FOR IT
    MOVE.B  UART_RHR,(A2)+        ; YES, GET BYTE AND STORE IT!

; Here we should look at remote vcount and our local vcount values
; and adjust video mode from interlace to non interlace or vice versa.
; If the vcount of the remote machine is larger or ahead of the local 
; vcount value, the remote machine should be set to interlaced video mode
; to slow it down. We should take into account allso READ_VCOUNT value which
; is the vcount value/time we want both machines to hopefully be able to
; read in remote data (hopefully it is there by then)

;   JSR     ADJUST_SYNC           ; INT/NON-INT MODE ADJUSTMENT

NETWORK_SEND:
    MOVE.W  $C00004,D0            ; GET VDP STATUS
    AND.B   #$8,D0                ; IN VBLANK?
    BNE.S   NETWORK_SEND          ; YES, SO WAIT UNTIL WE ARENT IN VBLANK
NETWORK_SEND_VCOUNT:
    BTST    #5,UART_LSR           ; OK TO SEND?
    BEQ.S   NETWORK_SEND_VCOUNT   ; KEEP WAITING
    MOVE.B  $C00009,UART_THR      ; SEND VCOUNT VALUE TO OTHER CONSOLE
SEND_BYTE2
    BTST    #5,UART_LSR           ; OK TO SEND?
    BEQ.S   SEND_BYTE2            ; IF NOT, KEEP CHECKING
    MOVE.B  (A1)+,UART_THR        ; SEND FIRST BYTE OF CONTROLLER DATA ASAP
SEND_BYTE3:
    BTST    #5,UART_LSR           ; OK TO SEND?
    BEQ.S   SEND_BYTE3            ; IF NOT, KEEP CHECKING
    MOVE.B  (A1)+,UART_THR        ; SEND SECOND BYTE OF OUR CONTROLLER DATA ASAP
;----------------------------------
GET_STORE:
    MOVE.W  -2(A1),D0             ; STORE OUR NEW CONTROLLER DATA FOR THIS FRAME INTO IN THE LOCAL JOY_BUFFER
    JSR     GETPUT_BUFFER         ; STORE NEW, AND GET OLDEST FROM BUFFER
    MOVE.L  D0,(A3)               ; STORE RETRIEVED BUFFERED JOYPAD DATA INTO PLACE FOR USE THIS GAME FRAME
SEND_DONE:
    RTS    

NETWORK_NORECV:
    MOVE.W  #NODATA,(A1)          ; KILL OUR INPUTS THIS FRAME BECAUSE WE DIDNT GET ANYTHING FROM THE REMOTE SIDE
    BRA.W   NETWORK_SEND_VCOUNT   ; SEND OUR DATA NOW
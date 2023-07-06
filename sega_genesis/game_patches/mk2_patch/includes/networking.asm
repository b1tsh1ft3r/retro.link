; there is a bug with establish comms routine for some reason right now. unsure why
; immediately after a few matches it will just have the slave go right to "network timeout"
; message. Timeout logic commented out for now

;http://mauve.mizuumi.net/2012/07/05/understanding-fighting-game-networking/

NODATA              EQU $FFFF     ; RESTING VALUE FOR JOYPAD RAM REGISTER WHEN NO BUTTONS PRESSED
READ_VCOUNT         EQU $5D       ; VCOUNT CONSIDERED NORMAL READ TIME
LATENCY_CHECKS      EQU 64        ; RANGE IS 2-255 (MUST BE EVEN)

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
    MOVE.W  D3,FRAME_DELAY        ; STORE FRAME DELAY VALUE
@SEND_DONE:
    BTST    #5,UART_LSR           ; OK TO SEND?
    BEQ.S   @SEND_DONE            ; WAIT UNTIL OK TO SEND
    MOVE.B  #'%',UART_THR         ; SEND WAIT LATENCY TERMINATION BYTE       
    CMP.B   #'S',WHOAMI           ; IF SLAVE IS COMING THROUGH HERE?
    BEQ.S   LATENCY_DONE          ; WE'RE DONE...
    ; MASTER FALLS THROUGH AUTOMATICALLY INTO RECEIVE AS IT SHOULD
;------------------------------------------------------------------------------
LATENCY_RECEIVE:
;------------------------------------------------------------------------------
    BTST    #0,UART_LSR           ; BYTE AVAILABLE?
    BEQ.S   LATENCY_RECEIVE       ; WAIT UNTIL AVAILABLE
    MOVE.B  UART_RHR,D0           ; GET BYTE
    CMP.B   #'%',D0               ; LATENCY RECEIVE TOKEN?
    BEQ.S   @RECEIVE_DONE
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

;*******************************************************************************
;** SYNCHRONIZE                                                               ** [OK]
;*******************************************************************************
SYNCHRONIZE:
    MOVEM.L D0-D6/A0-A6,-(A7)

    MOVEQ   #0, D5                ; X POSISION
    MOVEQ   #14, D6               ; Y POSITION
    LEA     SYNC_TXT,A6           ; TEXT STRING
    JSR     WriteText             ; DRAW TEXT

    CLR.L   D0                    ; CLEAR
    CLR.L   D1                    ; CLEAR
    CLR.L   D2                    ; CLEAR 
    CLR.L   D3                    ; CLEAR

    CMP.B   #'S',WHOAMI           ; ARE WE SLAVE?
    BEQ.W   SYNC_SLAVE            ; THEN BRANCH AND DO SLAVE ROUTINE
;------------------------------------------------------------------------------
SYNC_MASTER:
;------------------------------------------------------------------------------
    BTST    #0,UART_LSR           ; DATA AVAILABLE IN UART?
    BEQ.S   SYNC_MASTER           ; IF NOT, KEEP CHECKING
    MOVE.B  UART_RHR,D0           ; GET THE BYTE
    CMP.B   #'*',D0               ; IS IT THE OK BYTE FROM SLAVE?
    BNE.S   SYNC_MASTER           ; NO, SO WAIT FOR THE OK BYTE
@MASTE_VBLANK_SYNC:
    MOVE.W  #$8C81,$C00004        ; ENSURE NON INTERLACE VIDEO MODE
@SEND_VCOUNT:
    MOVE.W  $C00004,D1            ; GET VDP STATUS
    AND.B   #$8,D1                ; IN VBLANK?
    BNE.S   @SEND_VCOUNT          ; YES, SO WAIT UNTIL WE ARENT IN VBLANK
;   MOVE.W  $C00008,D1            ; GET HVCOUNTER VALUE
;   LSR.W   #8,D1                 ; SHIFT IT OVER TO POINT TO V-COUNTER
@SEND_VCHECK:
    BTST    #5,UART_LSR           ; OK TO SEND?
    BEQ.S   @SEND_VCHECK          ; KEEP WAITING
    MOVE.B  $C00009,UART_THR      ; SEND VCOUNT VALUE
;   MOVE.B  D1,UART_THR           ; SEND VCOUNT VALUE
@HV_RESPONSE:
    BTST    #0,UART_LSR           ; DATA AVAILABLE IN UART?
    BEQ.S   @HV_RESPONSE          ; NO SO KEEP CHECKING
    MOVE.B  UART_RHR,D0           ; GET BYTE
    CMP.B   #'$',D0               ; DID WE RECEIVE SYNCHED TOKEN?
    BEQ.W   SYNCHRONIZE_DONE      ; IF SO JUST EXIT!
    BRA.S   @SEND_VCOUNT          ; OTHERWISE WE JUST SEND OUT V-COUNT  
;------------------------------------------------------------------------------
SYNC_SLAVE:
;------------------------------------------------------------------------------
    BTST    #5,UART_LSR           ; OK TO SEND DATA?
    BEQ.S   SYNC_SLAVE            ; IF NOT, KEEP WAITING UNTIL OK
    MOVE.B  #'*',UART_THR         ; SEND OK RESPONSE TO SLAVE
    CLR.W   VBL_COUNTER           ; CLEAR VBLANK COUNTER
@SLAVE_DELAY:
    CMP.W   VBL_COUNTER,D1        ; COMPARE OUR VALUE TO VBL COUNTER         
    BNE.S   @SLAVE_DELAY          ; IF NOT EQUAL, KEEP CHECKING
    MOVE.W  #$8C81,$C00004        ; ENSURE NON INTERLACE VIDEO MODE
@SLAVE_VBLANK_SYNC:
    BTST    #0,UART_LSR           ; IS DATA AVAILABLE IN SEGA UART?
    BEQ.S   @SLAVE_VBLANK_SYNC    ; NO, SO KEEP CHECKING
    MOVE.B  UART_RHR,D0           ; FINALLY PUT REMOTE VCNT INTO D0
    MOVE.W  $C00004,D1            ; GET VDP STATUS
    AND.B   #$8,D1                ; IN VBLANK?
    BEQ.S   @VALID_READ           ; NOPE, SO OK TO GO AHEAD AND READ VCOUNTER
    MOVEQ   #0,D1                 ; OTHERWISE WE ARE IN VBLANK SO ZERO IT
    BRA.S   @OK                   ; BRANCH
@VALID_READ:

    MOVE.B  $C00009,D1            ; GET VCOUNTER VALUE TO D1 (NEW!)
;   MOVE.W  $C00008,D1            ; GET VCOUNTER IN D1
;   LSR.W   #8,D1                 ; SHIFT IT OVER (GET VERTICAL COUNT VALUE)

    CMP.B   #READ_VCOUNT,D1       ; BIGGER THAN MAX SCANLINE?
    BLE.S   @OK                   ; NOPE, SO WE'RE OK!
    MOVE.W  #READ_VCOUNT,D1       ; OTHERWISE SET AS MAX SCANLINE
@OK:
    SUB.B   D0,D1                 ; SUBTRACT RECEIVED VCNT FROM OUR LOCAL VCNT
    BPL.S   @POSITIVE             ; IF POSITIVE VALUE, BRANCH
    NEG.B   D1                    ; OTHERWISE INVERT VALUE
@POSITIVE:
    CMP.B   #2,D1                 ; LESS THAN 2 APART?
    BLT.S   @SLAVE_VBLANK_SYNCHED ; THEN WE ARE SYNCHED!
@VCNT_REQUEST:
    BTST    #5,UART_LSR           ; OK TO SEND?
    BEQ.S   @VCNT_REQUEST         ; IF NOT, KEEP WAITING
    MOVE.B  #'%',UART_THR         ; SEND OUT BYTE TO GET ANOTHER VCNT FROM SLAVE
    MOVE.W  #$8C83,$C00004        ; ENSURE INTERLACE VIDEO MODE (SLOW DOWN)
    BRA.S   @SLAVE_VBLANK_SYNC    ; TRY AGAIN TO SYNC
@SLAVE_VBLANK_SYNCHED:
    MOVE.W  #$8C81,$C00004        ; ENSURE NON INTERLACE VIDEO MODE ON EXIT (NORMAL VIDEO MODE)
    MOVE.B  FRAME_DELAY,D1        ; MOVE LATENCY VALUE TO D1
@CHECK_SYNC_SEND:
    BTST    #5,UART_LSR           ; OK TO SEND?
    BEQ.S   @CHECK_SYNC_SEND      ; NO SO KEEP WAITING
    MOVE.B  #'$',UART_THR         ; SEND SYNCH DONE TOKEN
    CLR.W   VBL_COUNTER           ; CLEAR VBLANK COUNTER
@SLAVE_SYNCHED_DELAY:
    CMP.W   VBL_COUNTER,D1        ; COMPARE OUR VALUE TO VBL COUNTER         
    BNE.S   @SLAVE_SYNCHED_DELAY  ; IF NOT EQUAL, KEEP CHECKING
;------------------------------------------------------------------------------
SYNCHRONIZE_DONE:
;------------------------------------------------------------------------------
    MOVE.B  #$07,UART_FCR         ; FLUSH FIFOS ON UART
    MOVEM.L (SP)+,D0-D6/A0-A6     ; RESTORE REGISTER DATA AND ADDRESSES
    RTS    

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
NETWORK_GET_VCOUNT:
    MOVE.W  $C00004,D0            ; GET VDP STATUS
    AND.B   #$8,D0                ; IN VBLANK?
RECV_SKIP_VBLCHK:
    BNE.S   NETWORK_GET_VCOUNT    ; YES, SO WAIT UNTIL WE ARENT IN VBLANK

    MOVE.B  $C00009,D0            ; GET LOCAL VCOOUNT VALUE TO D0
;   MOVE.W  $C00008,D0            ; GET LOCAL VCOUNTER VALUE TO D0
;   LSR.W   #8,D0                 ; SHIFT IT OVER TO POINT TO V-COUNTER

    MOVE.B  UART_RHR,D1           ; GET REMOTE VCOUNT VALUE TO D1
GET_BYTE2:
    BTST    #0,UART_LSR           ; DATA AVAILABLE?
    BEQ.S   GET_BYTE2             ; NO, SO EXIT
    MOVE.B  UART_RHR,(A2)+        ; YES, GET BYTE AND STORE IT!
GET_BYTE3:
    BTST    #0,UART_LSR           ; DATA AVAILABLE?
    BEQ.S   GET_BYTE3             ; NO, SO WAIT FOR IT
    MOVE.B  UART_RHR,(A2)+        ; YES, GET BYTE AND STORE IT!

NETWORK_SEND:
    MOVE.W  $C00004,D0            ; GET VDP STATUS
    AND.B   #$8,D0                ; IN VBLANK?
    BNE.S   NETWORK_SEND          ; YES, SO WAIT UNTIL WE ARENT IN VBLANK
SEND_SKIP_VBLCHK:
;   MOVE.W  $C00008,D0            ; GET HVCOUNTER VALUE
;   LSR.W   #8,D0                 ; SHIFT IT OVER TO POINT TO V-COUNTER
NETWORK_SEND_VCOUNT:
    BTST    #5,UART_LSR           ; OK TO SEND?
    BEQ.S   NETWORK_SEND_VCOUNT   ; KEEP WAITING
    MOVE.B  $C00009,UART_THR      ; SEND VCOUNT VALUE TO OTHER CONSOLE (NEW!)
;   MOVE.B  D0,UART_THR           ; SEND VCOUNT VALUE TO OTHER CONSOLE
SEND_BYTE2
    BTST    #5,UART_LSR           ; OK TO SEND?
    BEQ.S   SEND_BYTE2            ; IF NOT, KEEP CHECKING
    MOVE.B  (A1)+,UART_THR        ; SEND OUR CONTROLLER DATA ASAP
SEND_BYTE3:
    BTST    #5,UART_LSR           ; OK TO SEND?
    BEQ.S   SEND_BYTE3            ; IF NOT, KEEP CHECKING
    MOVE.B  (A1)+,UART_THR        ; SEND OUR CONTROLLER DATA ASAP
;----------------------------------
GET_STORE:
    MOVE.W  -2(A1),D0             ; STORE OUR NEW CONTROLLER DATA INTO IN THE LOCAL JOY_BUFFER
    JSR     GETPUT_BUFFER         ; STORE NEW, AND GET OLDEST
    MOVE.L  D0,(A3)               ; STORE BUFFERED JOYPAD DATA INTO PLACE FOR USE THIS GAME FRAME
SEND_DONE:
    RTS    

NETWORK_NORECV:
;   CMP.B   #1,MISSED_FRAMES      ; TOO MANY MISSED FRAMES?
;   BGE.S   FRAME_HOLD            ; WAIT UNTIL WE GET DATA
    MOVE.W  #NODATA,(A1)          ; KILL OUR INPUTS THIS FRAME BECAUSE WE DIDNT GET ANYTHING FROM THE REMOTE SIDE
;   ADD.B   #1,MISSED_FRAMES      ; INCREMENT MISSED FRAMES
    BRA.W   SEND_SKIP_VBLCHK      ; SKIP VBL CHECK, SEND OUR DATA NOW


FRAME_HOLD: ; WAIT HERE UNTIL DATA COMES IN..
    CMP.L   #$00020001,$FFF020    ; AFTER DEAD AFTER FATALITY
    BEQ.S   SEND_DONE
    BTST    #0,UART_LSR           ; DATA AVAIL?
    BEQ.S   FRAME_HOLD            ; NOPE SO WAIT UNTIL IT IS
    CLR.B   MISSED_FRAMES         ; DATA IS AVAIL, CLEAR MISSED FRAMES
FRAME_DONE:
    BRA.W   RECV_SKIP_VBLCHK

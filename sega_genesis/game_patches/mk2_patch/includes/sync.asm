READ_VCOUNT         EQU $5D       ; VCOUNT CONSIDERED NORMAL READ TIME

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
    MOVE.W  $C00008,D1            ; GET HVCOUNTER VALUE
    LSR.W   #8,D1                 ; SHIFT IT OVER TO POINT TO V-COUNTER
@SEND_VCHECK:
    BTST    #5,UART_LSR           ; OK TO SEND?
    BEQ.S   @SEND_VCHECK          ; KEEP WAITING
    MOVE.B  D1,UART_THR           ; SEND VCOUNT VALUE
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
    MOVE.W  $C00008,D1            ; GET VCOUNTER IN D1
    LSR.W   #8,D1                 ; SHIFT IT OVER (GET VERTICAL COUNT VALUE)

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

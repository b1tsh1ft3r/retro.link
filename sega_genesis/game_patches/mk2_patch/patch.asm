;*****************************************************************
;** Project    : Mortal Kombat II                               **
;** Platform   : Sega Genesis - Retro.Link                      **
;** Programmer : b1tsh1ft3r                                     **
;** Version    : 0.9                                            **
;*****************************************************************

; This current version works, but our text status updates when syncing
; or determining latency does not show for some reason. Also seems that
; games de-sync from randomness eventually. Unsure why at this point.
; Needs more investigation.

; * we need proper 6 button detection and support

    ORG     $00000000
    INCBIN  "MK2.BIN"

AI_ENABLED          EQU 0            ; PLAYER 2 AI ENABLED DURING GAMEPLAY FOR DEBUGGING RNG STUFF

;*****************************************************************
;** DEFINES                                                     **
;*****************************************************************

UART_RHR            EQU $A130C1      ; Receive holding register
UART_THR            EQU $A130C1      ; Transmit holding register
UART_IER            EQU $A130C3      ; Interrupt enable register
UART_FCR            EQU $A130C5      ; FIFO control register
UART_LCR            EQU $A130C7      ; Line control register
UART_MCR            EQU $A130C9      ; Modem control register
UART_LSR            EQU $A130CB      ; Line status register
UART_SPR            EQU $A130CF      ; Scratchpad register
UART_DLL            EQU $A130C1      ;
UART_DLM            EQU $A130C3      ;
UART_DVID           EQU $A130C3      ; DEVICE ID
UART_OP2            EQU $A130C9      ; OP2 GPIO

;------------------------------------
; GAME RAM VARIABLES
;------------------------------------
CTRL1_DATA          EQU $FFF9D4      ; Controller 1 RAM (W) (3 OR 6 BUTTON DATA)
PLAYER1_XPOS:       EQU $FFB6C8      ; (W)
PLAYER1_YPOS:       EQU $FFB6CC      ; (W)
PLAYER1_FACING      EQU $FFB6D3      ; (B) (Which direction player is facing)
PLAYER1_ANIM        EQU $FFB608      ; (W)

CTRL2_DATA          EQU $FFF9E2      ; Controller 2 RAM (W) (3 OR 6 BUTTON DATA)
PLAYER2_XPOS:       EQU $FFB7B8      ; (W)
PLAYER2_YPOS:       EQU $FFB7BC      ; (W)
PLAYER2_FACING      EQU $FFB7C3      ; (B) (Which direction player is facing)
PLAYER2_ANIM        EQU $FFB6F8      ; (W)

VBL_COUNTER         EQU $FF8892      ; (W) GAME VBLANK COUNTER

;------------------------------------
; CUSTOM RAM VARIABLES
;------------------------------------
RAMBASE             EQU $FFFA60      ; BASE LOCATION FOR OUR CUSTOM RAM VARIABLES
WHOAMI              EQU RAMBASE+0    ; (B) WHOAMI VARIABLE (MASTER/SLAVE)
PRACTICE_FLAG       EQU RAMBASE+1    ; (B) FLAG TO SIGNIFY PRACTICE MODE
NUM_GAMES           EQU RAMBASE+2    ; (B) NUMBER OF GAMES PLAYED
MISSED_FRAMES       EQU RAMBASE+3    ; (B) MISC FLAG FOR USE
RANDOM_SEED         EQU RAMBASE+4    ; (L) RANDOM SEED VALUE
FRAME_DELAY         EQU RAMBASE+8    ; (W) NUMBER OF FRAMES DELAYED LOCALLY BASED ON OUR LATNECY TO OTHER CONSOLE
PACKET_BUFFER       EQU RAMBASE+10   ; (X) 16 BYTE PACKET BUFFER
BUFFER_PTR          EQU RAMBASE+26   ; (W) CURRENT POINTER INTO JOYSTICK BUFFER 1
JOY_BUFFER          EQU RAMBASE+28   ; (X) LOCAL JOYSTICK INPUT BUFFER. MAX OF 892 BYTES (447 WORDS) (END IS $FFFDE0)

;******************************************
; VBLANK                                 **
;******************************************
    ORG     $00000078
    DC.L    RLINK_VBLANK
;******************************************
; TRAP VECTORS                           **
;******************************************
    ORG     $00000080
    DC.L    STARTUP                  ; TRAP0  (OK)
    DC.L    SKIP_TITLE               ; TRAP1  (OK)
    DC.L    SELECT_SYNC              ; TRAP2  (OK)
    DC.L    NO_RANDOM                ; TRAP3  (OK)
    DC.L    SELECT_NETWORKING        ; TRAP4  (OK)
    DC.L    ROUND_SYNC               ; TRAP5  (OK)
    DC.L    GAME_NETWORKING          ; TRAP6  (OK)
    DC.L    FORCE_REPLAY             ; TRAP7  (OK)
    DC.L    JOYPAD_READING           ; TRAP8  (OK)
    DC.L    NORESET_SCORE            ; TRAP9  (OK)

;******************************************
; TRAP HOOKPOINTS                        **
;******************************************
    ORG     $00029B3C                ; STARTUP
    TRAP    #0
    ORG     $00029B48                ; SKIP TITLE
    TRAP    #1
    ORG     $00003D3C                ; SELECT SYNC
    TRAP    #2
    ORG     $00003712                ; NO RANDOM SELECT
    TRAP    #3
    ORG     $000034BA                ; SELECT NETWORKING
    TRAP    #4
    ORG     $00003FC2                ; ROUND SYNC
    TRAP    #5
    ORG     $00004076                ; GAME NETWORKING (game main loop)
    TRAP    #6
    ORG     $00003FD0                ; FORCE REPLAY
    TRAP    #7
    ORG     $0000031E                ; JOYPAD_READING
    TRAP    #8
    ORG     $0000459A                ; NO RESET SCORE
    TRAP    #9

    ORG     $0000555A                ; RANDOM NUMBER GENERATOR
    JMP     RANDOM_GENERATOR     
    NOP

    ORG     $00892A
    JMP     RANDOM1000
    NOP

    ORG     $00008912
    JMP     RANGED_RANDOM
    NOP

; UNSURE IF THIS IS ACTUALLY MODIFYING RNG VALUE OR NOT. APPEARS TO REFERENCE IT
    ORG     $3FF72
    NOP
    NOP
    NOP

;*******************************************************************************
;** END OF ROM                                                                **
;*******************************************************************************

    ORG     $002FFEBC                ; LOCATION AT END OF ROM FOR ALL NEW CODE

;*******************************************************************************
;** RANDOM GENERATOR                                                          **
;*******************************************************************************
RANDOM_GENERATOR:
    move.l  RANDOM_SEED,d0
    JMP     $5582

RANGED_RANDOM:
    MOVE.W   #1,D0
    JMP      $8928

RANDOM1000:
    move.w  #0,d0
    move.w  #1,d2
    cmp.w   d2,d0
    JMP     $8940

;*******************************************************************************
;** STARTUP                                                                   **
;*******************************************************************************
STARTUP:
    ADDQ.L  #6,A7                    ; FORGET TRAP EVER HAPPENED
    MOVEM.L D0-D7/A0-A6,-(A7)        ; SAVE
@DETECT_UART:
    MOVE.B  #$80, UART_LCR           ; SETUP VARS TO READ DEVICE ID ON UART
    MOVE.B  #$00, UART_DLM           ;
    MOVE.B  #$00, UART_DLL           ;
    CMP.B   #$10, UART_DVID          ; EXPECTED VALUE?
    BNE.S   @NOT_FOUND               ; IF NOT, JUST EXIT AND DO NORMAL GAME
@INIT_UART:
    MOVE.B  #$83, UART_LCR           ; INIT UART
    MOVE.B  #$00, UART_DLM           ;
    MOVE.B  #$01, UART_DLL           ;
    MOVE.B  #$03, UART_LCR           ;
    MOVE.B  #$00, UART_MCR           ;
    MOVE.B  #$01, UART_FCR           ;
    MOVE.B  #$07, UART_FCR           ;
    MOVE.B  #$00, UART_IER           ;
    MOVE.B  #$08, UART_MCR           ; BLOCK ALL INCOMING CONNECTIONS (0x00 = ALLOW)
    JSR     SETUP_RLINK              ; DO RETRO.LINK USER INTERFACE
    MOVE.L  #$12345678,RANDOM_SEED   ; SET RANDOM SEED INITIAL START VALUE
    CLR.B   NUM_GAMES                ; CLEAR NUMBER OF GAMES PLAYED
@NOT_FOUND:
    MOVEM.L (SP)+,D0-D7/A0-A6        ; RESTORE
    JSR     $2AE9A                   ; MK II info screen, Acclaim splash sceen
    JMP     $029B42                  ; JUMP BACK AND CONTINUE AS NORMAL GAME

;*******************************************************************************
;** SKIP TITLE SCREEN                                                         **
;*******************************************************************************
SKIP_TITLE:
    ADDQ.L  #4,A7                    ; FORGET TRAP HAPPENED
    MOVEM.L D0-D7/A0-A6,-(A7)        ; SAVE
    TST.B   WHOAMI                   ; WHOAMI VARIABLE SET?
    BEQ.S   DO_TITLE                 ; IF NOT, JUST EXIT

    MOVE.W  #0x4,0xFFFFF472          ; ENABLE PLAYER 1 ON CHARACTER SELECT SCREEN
    MOVE.W  #0x1,0xFFFFF46E          ; ENABLE PLAYER 2 ON CHARACTER SELECT SCREEN
    MOVE.W  #0000,$FFFFF9D0          ; FORCE 3 BUTTON JOYPADS FOR BOTH PLAYERS

    MOVEM.L (SP)+,D0-D7/A0-A6        ; RESTORE
    JMP     $00003D26                ; JUMP TO SELECT YOUR SELECT YOUR FIGHTER ROUTINE
DO_TITLE:
    MOVEM.L (SP)+,D0-D7/A0-A6        ; RESTORE
    JMP     $00003CE6                ; JUMP TO ATTRACT SEQUENCE

;*******************************************************************************
;** SELECT SYNC                                                               ** OK
;*******************************************************************************
SELECT_SYNC:
    ADDQ.L  #4,A7                    ; FORGET TRAP HAPPENED
    MOVEM.L D0-D7/A0-A6,-(A7)        ; SAVE
    TST.B   WHOAMI                   ; WHOAMI VARIABLE SET?
    BEQ.W   @NO_SYNC                 ; IF NOT, JUST DO NORMAL SELECT SCREEN

    JSR     ESTABLISH_COMMS          ; ESTABLISH COMMUNICATIONS BETWEEN CONSOLES
    JSR     GET_LATENCY              ; GET LATENCY BETWEEN CONSOLES
    JSR     SYNCHRONIZE              ; SYNCHRONIZE CONSOLES

    MOVE.L  RANDOM_SEED,D0           ; RANDOM SEE VALUE TO D0
    MOVE.L  D0,$FFFFAA98             ; STORE IT FOR GAME TO USE

@NO_SYNC:
    MOVEM.L (SP)+,D0-D7/A0-A6        ; RESTORE
    JSR     $00003F92                ; RESET A BUNCH OF STATE
    JMP     $00003D42                ; RETURN

;*******************************************************************************
;** NO RANDOM CHARACTER SELECT                                                ** OK
;*******************************************************************************
NO_RANDOM:
    ADDQ.L  #2,A7                    ; FORGET TRAP HAPPENED
    MOVEM.L D0-D7/A0-A6,-(A7)        ; SAVE
    TST.B   WHOAMI                   ; WHOAMI SET?
    BEQ.S   DO_RANDOM                ; IF NOT SET THEN ALLOW RANDOM SELECT
    SF      (A1)                     ; SET RANDOM SELECT FLAG FALSE!
    MOVEM.L (SP)+,D0-D7/A0-A6        ; RESTORE
    JMP     $00003740                ; RETURN
DO_RANDOM:
    MOVEM.L (SP)+,D0-D7/A0-A6        ; RESTORE
    ST      (A1)                     ; RUN HIJACKED INSTRUCTION
    JMP     $00003714                ; RETURN

;*******************************************************************************
;** SELECT NETWORKING                                                         **
;*******************************************************************************
SELECT_NETWORKING:
    ADDQ.L  #6,A7                    ; FORGET TRAP HAPPENED
    MOVEM.L D0-D7/A0-A6,-(A7)        ; SAVE
    TST.B   WHOAMI                   ; WHOAMI VARIABLE SET?
    BEQ.S   SELECT_NORMAL            ; IF NOT, JUST DO NORMAL SELECT SCREEN
    JSR     NETWORKING               ; SEND/RECEIVE JOYPAD DATA
SELECT_NORMAL:
    MOVEM.L (SP)+,D0-D7/A0-A6        ; RESTORE
    JSR     $00004AD0                ; RUN HACKED INSTRUCTION
    JMP     $000034C0                ; JUMP BACK

;*******************************************************************************
;** ROUND SYNC                                                                **
;*******************************************************************************
ROUND_SYNC:
    ADDQ.L  #4,A7                    ; FORGET TRAP HAPPENED
    MOVEM.L D0-D7/A0-A6,-(A7)        ; SAVE
    TST.B   WHOAMI                   ; WHOAMI VARIABLE SET?
    BEQ.S   NORMAL_ROUND             ; IF NOT, JUST EXIT

    JSR     ESTABLISH_COMMS          ; ESTABLISH COMMUNICATIONS BETWEEN CONSOLES
    JSR     GET_LATENCY              ; GET LATENCY BETWEEN CONSOLES
    JSR     SYNCHRONIZE              ; SYNCHRONIZE CONSOLES

    MOVE.L  RANDOM_SEED,D0           ; RANDOM SEE VALUE TO D0
    MOVE.L  D0,$FFFFAA98             ; LOAD IT FOR GAME USE
 
    CLR.W   VBL_COUNTER              ; CLEAR GAME VBLANK COUNTER
    CLR.B   MISSED_FRAMES

NORMAL_ROUND:
    MOVEM.L (SP)+,D0-D7/A0-A6        ; RESTORE
    JSR     $00004026                ; PLAY A ROUND
    JMP     $00003FC6                ; JUMP BACK INTO FUNCTION

;*******************************************************************************
;** GAME NETWORKING                                                           **
;*******************************************************************************
GAME_NETWORKING
    ADDQ.L  #6,A7                    ; FORGET TRAP HAPPENED
    MOVEM.L D0-D7/A0-A6,-(A7)        ; SAVE
    TST.B   WHOAMI                   ; WHOAMI VARIABLE SET?
    BEQ.S   GAME_NORMAL              ; IF NOT, JUST DO NORMAL GAME

; this code below seems to help control our data spray so to speak
@FIGHT_CHECK:
    CMP.L   #$00000001,$FFF020       ; DURING GAME (JUST AFTER FIGHT)
    BEQ.S   DONET
    CMP.L   #$00030001,$FFF020       ; DURING FATALITY
    BEQ.S   DONET
;   CMP.L   #$00020001,$FFF020       ; AFTER DEAD AFTER FATALITY
;   BEQ.S   SOMEWHERE...

;   If not fight time, kill all controller inputs to keep odd things from happening
    MOVE.W  #NODATA,CTRL1_DATA       ; FLUSH CONTROLLER INPUT VARIABLE FOR P1
    MOVE.W  #NODATA,CTRL2_DATA       ; FLUSH CONTROLLER INPUT VARIABLE FOR P2
    BRA.S   GAME_NORMAL

DONET:
    IF      AI_ENABLED
    MOVE.B  #0,$FFB747               ; FORCE PLAYER 2 TO BE AI! (Waits until p1 hits p2 for it to "turn on")
    ENDIF
    JSR     NETWORKING               ; SEND/RECEIVE JOYPAD DATA
GAME_NORMAL:
    MOVEM.L (SP)+,D0-D7/A0-A6        ; RESTORE
    CLR.W   $FFFFF45A.w              ; RUN HIJACKED INSTRUCTION
    JMP     $0000407A                ; RETURN

;*******************************************************************************
;** FORCE REPLAY                                                              **
;*******************************************************************************
FORCE_REPLAY:
    ADDQ.L  #2,A7                    ; FORGET TRAP HAPPENED
    MOVEM.L D0-D7/A0-A6,-(A7)        ; SAVE
    TST.B   WHOAMI                   ; WHOAMI VARIABLE SET
    BEQ.S   REPLAY_NORMAL            ; DO NORMAL REPLAY
    ADD.B   #1,NUM_GAMES             ; INCREMENT NUMBER OF GAMES
    MOVE.W  #0x1,0xFFFFF46E          ; ENABLE PLAYER 2 ON CHARACTER SELECT SCREEN
    MOVE.W  #0,$FFF470
    MOVE.W  #0x4,0xFFFFF472          ; ENABLE PLAYER 1 ON CHARACTER SELECT SCREEN
    MOVE.W  #0,$FFF474
;   CLR.B   $FFFFEEA4                ; CLEAR PLAYER 1 SCORE
;   CLR.B   $FFFFEEA6                ; CLEAR PLAYER 2 SCORE
    JMP     $00003D26                ; JUMP BACK TO CHOOSE FIGHTER SCREEN
REPLAY_NORMAL:
    MOVEM.L (SP)+,D0-D7/A0-A6        ; RESTORE
    JMP     $00003DAC                ; RETURN

;*******************************************************************************
;** JOYPAD READING                                                            **
;*******************************************************************************
JOYPAD_READING:
    ADDQ.L  #6,A7                    ; FORGET TRAP HAPPENED
    MOVEM.L D0-D7/A0-A6,-(A7)        ; SAVE
    TST.B   WHOAMI                   ; WHOAMI BYTE SET?
    BNE.S   @NETWORK_READ            ; IF SO, WE MUST BE DOING NETWORKED GAME. BRANCH OFF!
@NORMAL_READ:
    JSR     $6012                    ; OTHERWISE READ JOYPADS NORMALLY VIA GAME JOYPAD READ ROUTINE
    BRA.S   @JOYPAD_DONE             ; RETURN
@NETWORK_READ:
    TST.B   $FFEF83                  ; IS THIS BYTE SET TO 0? IF SO WE ARE ON INTRO SEQUENCE
    BEQ.S   @KILL_INPUT              ; KILL INPUTS FROM CONTROLLER PORTS
@READ_JOYPAD:
    MOVEQ   #0,D0                    ; POINT TO JOYSTICK PORT 1
    JSR     $00006220                ; read 3 button controller
@WHOAMI_CHECK:
    CMP.B   #'S',WHOAMI              ; 
    BEQ.S   @SLAVE
@MASTER:
    MOVE.L  D0,$FFFFF9D2.w           ; STORE RESULTS
    BRA.S   @JOYPAD_DONE             ; RETURN
@SLAVE:
    MOVE.L  D0,$FFFFF9E0.w           ; STORE RESULTS
    BRA.S   @JOYPAD_DONE             ; RETURN
@KILL_INPUT:
    MOVE.W  #$FFFF,CTRL1_DATA        ; CLEAR ANY INPUT FOR P1
    MOVE.W  #$FFFF,CTRL2_DATA        ; CLEAR ANY INPUT FOR P2
@JOYPAD_DONE:
    MOVEM.L (SP)+,D0-D7/A0-A6        ; RESTORE
    JMP     $00000324                ; RETURN

;*******************************************************************************
;** NO RESET SCORE                                                            **
;*******************************************************************************
NORESET_SCORE:
    ADDQ.L  #6,A7                    ; FORGET TRAP HAPPENED
    MOVEQ   #0,D0                    ; RUN HIJACKED INSTRUCTION
    MOVEM.L D0-D6/A0-A6,-(A7)        ; SAVE REGS/DATA
    CMPI.B  #0,NUM_GAMES             ; HAVENT PLAYED ANY GAMES YET?
    MOVEM.L (SP)+,D0-D6/A0-A6        ; RESTORE
    BEQ.S   @RESET_SCORES
    move.w  d0,$ffffeeac             ; DONT RESET SCORES BUT RESET OTHER THINGS
    JMP     $45A8
@RESET_SCORES:
    JMP     $459C                    ; NORMAL INIT

;*******************************************************************************
;** RLINK VBLANK                                                              **
;*******************************************************************************
RLINK_VBLANK:
    MOVEM.L D0-D7/A0-A6,-(A7)        ; SAVE
    TST.B   WHOAMI                   ; IS WHOAMI VALUE SET?
    BEQ.S   NORMAL_VBLANK            ; IF NOT THEN DO NORMAL VBLANK

    MOVE.L  RANDOM_SEED,D0           ; RANDOM SEED VALUE TO D0
    MOVE.L  D0,$FFFFAA98             ; STORE IT FOR GAME USE EVERY FRAME

WAIT4DMA:
    MOVE.W  $400004,D0               ; GET DMA STATUS
    AND.W   #1,D0                    ; IS DMA ACTIVE?
    BNE.S   WAIT4DMA                 ; IF ACTIVE, WAIT UNTIL COMPLETE

NORMAL_VBLANK:
    MOVEM.L (SP)+,D0-D7/A0-A6        ; RESTORE
    JMP     $0000030E                ; NORMAL GAME VBLANK

;*******************************************************************************
;** INCLUDES                                                                  **
;*******************************************************************************

    EVEN
    include  includes/networking.asm
    EVEN
    include  includes/rlink.asm

;*******************************************************************************
;** END                                                                       **
;*******************************************************************************

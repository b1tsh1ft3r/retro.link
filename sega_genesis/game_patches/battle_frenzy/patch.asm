;*****************************************************************
;** Project    : Battle Frenzy                                  **
;** Platform   : Sega Genesis - Retro.Link                      **
;*****************************************************************

; This patch comes with the IPS patch to correct the textures that
; are corrupted in the original game. Credits go to Diogo Rieberio.
; You can apply this patch to the BattleFrenzy rom up front
; and then compiled this patch to make patched.bin which is the 
; modified rom file with the networking code compiled in place.

; This example is not perfect by any means, but it shows that you
; can hack in networking support to an existing game provided that
; you dis-assemble the rom and have quite a bit of seat time with
; an emulator to find points to hook into the existing game.

; Current issues found during local testing
; -----------------------------------------

; Pause happened randomly in game and caused one machines to be paused 
; while the other was not. This could be due to our manipulation of the
; joypad data to supress the start button possibly.

; End of match gets out of sync sometimes (both playes dont end up on the same screen)
; This needs support code hacked into the game

; Ocassionally have seen the game drop into co-op mode when starting a 
; multiplayer VS game from the main menu. This requires probably finding 
; a ram value to force set the game to Versus mode

    ORG     $00000000

    INCBIN  "BLOODSHOT.BIN"          ; Rom file (MD5 (BLOODSHOT.BIN) = 018dfe74603334a17296505ac3c6e599)

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
UART_DLL            EQU $A130C1      ;
UART_DLM            EQU $A130C3      ;
UART_DVID           EQU $A130C3      ; DEVICE ID

;-----------------------------------
; GAME RAM VARIABLES
;-----------------------------------
P1_CTRL         EQU $FF80A2         ; (W)
P1_ZAXIS        EQU $FF80C6         ; (L)
P1_ANGLE        EQU $FF80CA         ; (L)
P1_LIVES        EQU $FF81C3         ; (B)
P1_LIFEBAR      EQU $FF81C9         ; (L)
P1_SLOT1_AMMO   EQU $FF812C         ; (L) SLOT 1 AMMO
P1_SLOT2_AMMO   EQU $FF8134         ; (L) SLOT 2 AMMO
P1_SLOT3_AMMO   EQU $FF813C         ; (L) SLOT 3 AMMO
P1_SLOT4_AMMO   EQU $FF8144         ; (L) SLOT 4 AMMO
P1_SLOT5_AMMO   EQU $FF814C         ; (L) SLOT 5 AMMO
P1_SLOT6_AMMO   EQU $FF8154         ; (L) SLOT 6 AMMO
;-----------------------------------
P2_CTRL         EQU $FF80A6         ; (W)
P2_ZAXIS        EQU $FF8236         ; (L)
P2_ANGLE        EQU $FF823A         ; (L)
P2_LIVES        EQU $FF8333         ; (B)
P2_LIFEBAR      EQU $FF8339         ; (L)
P2_SLOT1_AMMO   EQU $FF829C         ; (L) SLOT 1 AMMO
P2_SLOT2_AMMO   EQU $FF82A4         ; (L) SLOT 2 AMMO
P2_SLOT3_AMMO   EQU $FF82AC         ; (L) SLOT 3 AMMO
P2_SLOT4_AMMO   EQU $FF82B4         ; (L) SLOT 4 AMMO
P2_SLOT5_AMMO   EQU $FF82BC         ; (L) SLOT 5 AMMO
P2_SLOT6_AMMO   EQU $FF82C4         ; (L) SLOT 6 AMMO
;-----------------------------------
MENU_POSITION   EQU $FFFFC89F       ; (B) 2=VS MODE
VBL_COUNTER     EQU $FFFF8066       ; (W) VBLANK COUNTER

SCREEN          EQU $ffff8430       ; (W) CURRENT SCREEN WE'RE ON
                                    ; SEGA LOGO = $1BE0
                                    ; DOMARK LOGO = $1BC0
                                    ; TITLE SCREEN = $75C0
                                    ; STORY = $4460
                                    ; MAIN MENU = $1400
                                    ; SINGLE PLAYER = $0E20
                                    ; VS GAME = $07A0
                                    ; COOP GAME = $11E0
;******************************************
; CUSTOM RAM VARIABLES                   **
;******************************************
RAMBASE             EQU $FFFA60      ; OUR CUSTOM RAM OFFSET
WHOAMI              EQU RAMBASE+0    ; (B) WHOAMI VARIABLE (MASTER/SLAVE)
TIMEOUT_COUNT       EQU RAMBASE+2    ; (W)

;******************************************
; TRAP VECTORS (IN ROM HEADER)           **
;******************************************
    ORG     $00000080
    DC.L    STARTUP                  ; TRAP0  (OK)
    DC.L    READ_JOYPAD              ; TRAP1  (??)

;******************************************
; TRAP HOOKPOINTS                        **
;******************************************
    ORG     $00001EA2                ; STARTUP
    TRAP    #0
    ORG     $00006BF8                ; READ_JOYPAD
    TRAP    #1

;*******************************************************************************
;** END OF ROM                                                                **
;*******************************************************************************

    ORG     $00200000                ; LOCATION AT END OF ROM FOR ALL NEW CODE

;*******************************************************************************
;** STARTUP                                                                   **
;*******************************************************************************
STARTUP:
    ADDQ.L  #6,A7                    ; FORGET TRAP EVER HAPPENED
    MOVEM.L D0-D7/A0-A6,-(A7)        ; SAVE REGS/DATA
@DETECT_UART:
    MOVE.B  #$80, UART_LCR           ; SETUP VARS TO READ DEVICE ID ON UART
    MOVE.B  #$00, UART_DLM           ;
    MOVE.B  #$00, UART_DLL           ;
;   CMP.B   #$10, UART_DVID          ; EXPECTED VALUE?
;   BNE.S   @NOT_FOUND               ; IF NOT, JUST EXIT AND DO NORMAL GAME
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
    JMP     $00000690
@NOT_FOUND:
    MOVEM.L (SP)+,D0-D7/A0-A6        ; RESTORE REGS/DATA
    RTS                              ; JUST RETURN (SKIPS CHECKSUM)

;*******************************************************************************
;** READ JOYPAD                                                               **
;*******************************************************************************
READ_JOYPAD:
    ADDQ.L  #6,A7                    ; FORGET TRAP EVER HAPPENED

    MOVE.L  #0xFFFFFFFF,0xFFFF8094   ; PART OF THEIR JOYPAD READ FUNCTION
    MOVE.L  #0xFFFFFFFF,0xFFFF8098   ; PART OF THEIR JOYPAD READ FUNCTION
    
    MOVEQ   #0,D1                    ; SIGNAL TO READ JOYPAD 1
    JSR     $0000E0EE                ; READ JOYPAD AND RETURN DATA IN D0.W

    CMP.W   #$1400,SCREEN            ; ARE WE ON THE MAIN MENU?
    BEQ.S   @MAIN_MENU

    CMP.W   #$07A0,SCREEN            ; ARE WE IN GAME?
    BEQ.S   @GAMEPLAY

;-------------------------------------
@MAIN_MENU:
    MOVE.B   #2,$FF6B05              ; DISABLE MUSIC ON MAIN MENU
    BSET     #7,D0                   ; HACK TO KILL START BUTTON INPUT
    BSET     #6,D0                   ; HACK TO KILL A BUTTON (WE THINK THIS STARTS IN COOP MODE?) ONLY C BUTTON WORKS
    BSET     #4,D0                   ; HACK TO KILL B BUTTON (WE THINK THIS STARTS IN COOP MODE?) ONLY C BUTTON WORKS
    BRA.S    @MAIN  
;-------------------------------------
@GAMEPLAY:
    BSET     #7,D0                   ; HACK TO KILL PAUSE IN GAME FOR NOW (THIS NEEDS DISABLING IF USING ABC+START )
;-------------------------------------
@MAIN:
    CMP.B    #'S',WHOAMI             ; IS THIS CONSOLE MASTER?
    BEQ.S    @SLAVE                  ; THEN RECEIVE DATA
@MASTER:
    JSR      NETWORK_SEND
    JSR      STORE_MASTER
    JSR      NETWORK_RECEIVE
    JSR      STORE_SLAVE
    BRA.S    @JOYPAD_DONE
@SLAVE:
    JSR      NETWORK_SEND
    JSR      STORE_SLAVE
    JSR      NETWORK_RECEIVE
    JSR      STORE_MASTER   
@JOYPAD_DONE:
;   JMP      0x00006BFE              ; THIS WILL JUMP BACK LETTING ABC+START CHECK HAPPEN IN GAME
    JMP      $00006C10               ; JUMP BACK (SKIPPING OVER ABC+START RESET-CHECK IN GAME)

;-------------------------------------
STORE_MASTER:
    TST.W    D0                      ; value is returned in d0!
    BNE.S    @JR1                    ; if its not empty then goto 71fe
    MOVEQ    #-0x1,D0                ; null out d0 with FFFFFFFF
    MOVE.W   #0x14,$FFFF80A8 
    BRA.S    @JR2
@JR1:
    TST.W    $FFFF80A8
    BEQ      @JR2                    ; if its empty goto @JR2
    SUBQ.W   #1,$FFFF80A8
    MOVEQ    #-0x1,D0
@JR2:
    CMPI.B   #0xFF,D0                ; compare ff to d0 (no input)
    BEQ      @JR3                    ; if no Input goto @JR3
@JR3:
    AND.L    D0,$FFFF8094
    MOVE.L   D0,$FFFF8074
    AND.L    D0,$FFFF807C
    OR.L     $FFFF80A0,D0
    MOVE.L   D0,$FFFF8084
    AND.L    D0,$FFFF808C
    AND.L    D0,$FFFF8098
    MOVE.L   $FFFF8074,D0
    NOT.L    D0
    MOVE.L   D0,$FFFF80A0
    RTS
;-------------------------------------
STORE_SLAVE:
    TST.W    D0
    BNE      @JR1
    MOVEQ    #-0x1,D0
    MOVE.W   #0x14,$FFFF80AA
    BRA      @JR2
@JR1:
    TST.W    $FFFF80AA
    BEQ      @JR2
    SUBQ.W   #1,$FFFF80AA
    MOVEQ    #-0x1,D0
@JR2:
    CMPI.B   #$FF,D0
    BEQ      @JR3
@JR3:
    AND.L    D0,$FFFF8094
    MOVE.L   D0,$FFFF8078
    AND.L    D0,$FFFF8080
    OR.L     $FFFF80A4,D0
    MOVE.L   D0,$FFFF8088
    AND.L    D0,$FFFF8090
    AND.L    D0,$FFFF8098
    MOVE.L   $FFFF8078,D0
    NOT.L    D0
    MOVE.L   D0,$FFFF80A4
    MOVE.L   $FFFF8098,D0
    AND.L    D0,$FFFF809C
    RTS

;*******************************************************************************
;** NETWORK SEND                                                              **
;*******************************************************************************
; This is blanket network tranfer/receive function. It has no real error
; handling and only times out if we haven't received data within a certain number
; of frames and locks the game with a red background.

NETWORK_SEND:
    CMP.B   #'M',WHOAMI
    BEQ.S   @MASTER_SETUP
    BRA.S   @SLAVE_SETUP
@MASTER_SETUP:
    LEA     P1_ZAXIS,A0
    LEA     P1_ANGLE,A1
    LEA     P1_LIVES,A2
    LEA     P1_LIFEBAR,A3
    BRA.S   @SEND_HEADER
@SLAVE_SETUP:
    LEA     P2_ZAXIS,A0
    LEA     P2_ANGLE,A1
    LEA     P2_LIVES,A2
    LEA     P2_LIFEBAR,A3
@SEND_HEADER:
    BTST    #5,UART_LSR
    BEQ.S   @SEND_BYTE1
    MOVE.B  #'@',UART_THR           ; SEND BYTE
;-----------------------------------
@SEND_BYTE1:                        ; [JOYDATA]
    BTST    #5,UART_LSR
    BEQ.S   @SEND_BYTE1
    MOVE.B  D0,UART_THR             ; SEND BYTE
;-----------------------------------
@SEND_BYTE2:                        ; Z-AXIS
    BTST    #5,UART_LSR
    BEQ.S   @SEND_BYTE2
    MOVE.B  (A0)+,UART_THR          ; SEND BYTE
@SEND_BYTE3:
    BTST    #5,UART_LSR
    BEQ.S   @SEND_BYTE3
    MOVE.B  (A0)+,UART_THR          ; SEND BYTE
@SEND_BYTE4:
    BTST    #5,UART_LSR
    BEQ.S   @SEND_BYTE4
    MOVE.B  (A0)+,UART_THR          ; SEND BYTE
@SEND_BYTE5:
    BTST    #5,UART_LSR
    BEQ.S   @SEND_BYTE5
    MOVE.B  (A0)+,UART_THR          ; SEND BYTE
;-----------------------------------
@SEND_BYTE6:                        ; [ANGLE]
    BTST    #5,UART_LSR
    BEQ.S   @SEND_BYTE6
    MOVE.B  (A1)+,UART_THR          ; SEND BYTE
@SEND_BYTE7:
    BTST    #5,UART_LSR
    BEQ.S   @SEND_BYTE7
    MOVE.B  (A1)+,UART_THR          ; SEND BYTE
@SEND_BYTE8:
    BTST    #5,UART_LSR
    BEQ.S   @SEND_BYTE8
    MOVE.B  (A1)+,UART_THR          ; SEND BYTE
@SEND_BYTE9:
    BTST    #5,UART_LSR
    BEQ.S   @SEND_BYTE9
    MOVE.B  (A1)+,UART_THR          ; SEND BYTE
;-----------------------------------
@SEND_BYTE10:                       ; [LIVES]
    BTST    #5,UART_LSR
    BEQ.S   @SEND_BYTE10
    MOVE.B  (A2),UART_THR           ; SEND BYTE
;-----------------------------------
@SEND_BYTE11:                       ; [LIFEBAR]
    BTST    #5,UART_LSR
    BEQ.S   @SEND_BYTE11
    MOVE.B  (A3)+,UART_THR          ; SEND BYTE
@SEND_BYTE12:
    BTST    #5,UART_LSR
    BEQ.S   @SEND_BYTE12
    MOVE.B  (A3)+,UART_THR          ; SEND BYTE
@SEND_BYTE13:
    BTST    #5,UART_LSR
    BEQ.S   @SEND_BYTE13
    MOVE.B  (A3)+,UART_THR          ; SEND BYTE
@SEND_BYTE14:
    BTST    #5,UART_LSR
    BEQ.S   @SEND_BYTE14
    MOVE.B  (A3)+,UART_THR          ; SEND BYTE
;-----------------------------------
@SEND_DONE:
    RTS

;*******************************************************************************
;** NETWORK RECEIVE                                                           **
;*******************************************************************************
; RECEIVE DATA INTO D0.W
NETWORK_RECEIVE:
    CMP.B   #'M',WHOAMI
    BEQ.S   @SETUP_MASTER
    BRA.S   @SETUP_SLAVE
@SETUP_MASTER:
    LEA     P2_ZAXIS,A0
    LEA     P2_ANGLE,A1
    LEA     P2_LIVES,A2
    LEA     P2_LIFEBAR,A3
    BRA.S   @RECEIVE_HEADER
@SETUP_SLAVE:
    LEA     P1_ZAXIS,A0
    LEA     P1_ANGLE,A1
    LEA     P1_LIVES,A2
    LEA     P1_LIFEBAR,A3
;-----------------------------------
@RECEIVE_HEADER:
    BTST    #0,UART_LSR             ; DATA AVAILABLE?
    BEQ.W   @NO_RECEIVE             ; NOPE, SO EXIT
    MOVE.B  UART_RHR,D0             ; OTHERWISE GET BYTE TO D0
    CMP.B   #'@',D0                 ; HEADER BYTE?
    BNE.S   @RECEIVE_HEADER         ; IF NOT HEADER BYTE KEEP CHECKING...
    CLR.W   TIMEOUT_COUNT           ; CLEAR TIMEOUT COUNTER VALUE
;-----------------------------------
@RECEIVE_BYTE1:                     ; SEE IF FIRST BYTE AVAILABLE, IF NOT THEN JUST EXIT
    BTST    #0,UART_LSR
    BEQ.W   @NO_RECEIVE
    MOVE.B  UART_RHR,D0             ; STORE JOYPAD DATA
;-----------------------------------
@RECEIVE_BYTE2:
    BTST    #0,UART_LSR
    BEQ.S   @RECEIVE_BYTE2
    MOVE.B  UART_RHR,(A0)+
@RECEIVE_BYTE3:
    BTST    #0,UART_LSR
    BEQ.S   @RECEIVE_BYTE3
    MOVE.B  UART_RHR,(A0)+
@RECEIVE_BYTE4:
    BTST    #0,UART_LSR
    BEQ.S   @RECEIVE_BYTE4
    MOVE.B  UART_RHR,(A0)+
@RECEIVE_BYTE5:
    BTST    #0,UART_LSR
    BEQ.S   @RECEIVE_BYTE5
    MOVE.B  UART_RHR,(A0)+
;-----------------------------------
@RECEIVE_BYTE6:
    BTST    #0,UART_LSR
    BEQ.S   @RECEIVE_BYTE6
    MOVE.B  UART_RHR,(A1)+
@RECEIVE_BYTE7:
    BTST    #0,UART_LSR
    BEQ.S   @RECEIVE_BYTE7
    MOVE.B  UART_RHR,(A1)+
@RECEIVE_BYTE8:
    BTST    #0,UART_LSR
    BEQ.S   @RECEIVE_BYTE8
    MOVE.B  UART_RHR,(A1)+
@RECEIVE_BYTE9:
    BTST    #0,UART_LSR
    BEQ.S   @RECEIVE_BYTE9
    MOVE.B  UART_RHR,(A1)+
;-----------------------------------
@RECEIVE_BYTE10:
    BTST    #0,UART_LSR
    BEQ.S   @RECEIVE_BYTE10
    MOVE.B  UART_RHR,(A2)
;-----------------------------------
@RECEIVE_BYTE11:
    BTST    #0,UART_LSR
    BEQ.S   @RECEIVE_BYTE11
    MOVE.B  UART_RHR,(A3)+
@RECEIVE_BYTE12:
    BTST    #0,UART_LSR
    BEQ.S   @RECEIVE_BYTE12
    MOVE.B  UART_RHR,(A3)+
@RECEIVE_BYTE13:
    BTST    #0,UART_LSR
    BEQ.S   @RECEIVE_BYTE13
    MOVE.B  UART_RHR,(A3)+
@RECEIVE_BYTE14:
    BTST    #0,UART_LSR
    BEQ.S   @RECEIVE_BYTE14
    MOVE.B  UART_RHR,(A3)+
;-----------------------------------
@RECEIVE_DONE:
    RTS
;-----------------------------------
@NO_RECEIVE:
    CLR     D0                      ; CLEAR INPUT ENTIRELY SO GAME ACTS APPROPRIATELY
    ADD.W   #1,TIMEOUT_COUNT
    CMP.W   #300,TIMEOUT_COUNT
    BGE.S   DIE
    RTS
DIE:
    MOVE.L  #$C0000000,$C00004
    MOVE.W  #$000E,$C00000          ; SET BORDER RED
    BRA     DIE

;*******************************************************************************
;** INCLUDES                                                                  **
;*******************************************************************************

    EVEN
    include  rlink.asm

;*******************************************************************************
;** END                                                                       **
;*******************************************************************************

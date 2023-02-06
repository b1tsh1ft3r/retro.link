; This is a *TERRIBLE* front-end, but it works fairly well for dev/testing
; as it doesnt require you to input the IP every time. It uses the pre-defined
; variable TEST_IP to connect to other unit.

;*******************************************************************************
;** HARD DEFINES                                                              **
;*******************************************************************************

JOY_UP              EQU 0
JOY_DOWN            EQU 1
JOY_LEFT            EQU 2
JOY_RIGHT           EQU 3
JOY_A               EQU 6
JOY_B               EQU 4
JOY_C               EQU 5
JOY_START           EQU 7

RLINK_RAMBASE       EQU $FFF500
JoyHold             EQU RLINK_RAMBASE+0  ; Buttons held down
JoyPress            EQU RLINK_RAMBASE+1  ; Buttons just pressed
MENU_CHOICE         EQU RLINK_RAMBASE+2  ; (B) MENU CHOICE
MISC                EQU RLINK_RAMBASE+3  ; (B) MISC
TEMP                EQU RLINK_RAMBASE+4  ; (W) TEMP STORAGE FOR SINGLE CHAR STRING WILL NULL TERMINATION
SCREEN_X            EQU RLINK_RAMBASE+6  ; (W) GLOBAL SCREEN X POSITION
SCREEN_Y            EQU RLINK_RAMBASE+8  ; (W) GLOBAL SCREEN Y POSITION
IP_ADDRESS          EQU RLINK_RAMBASE+10 ; (X) 16 BYTES
NEXT                EQU RLINK_RAMBASE+26 ; (B) 

;*******************************************************************************
;** SETUP_RLINK                                                               **
;*******************************************************************************
SETUP_RLINK:
    JSR      SETUP_VDP

    MOVE.W  #0,SCREEN_X                ; SET BASE SCREEN XPOS (34)
    MOVE.W  #0,SCREEN_Y                 ; SET BASE SCREEN YPOS (0)

;*******************************************************************************
;** RLINK MAIN                                                                **
;*******************************************************************************
RLINK_MAIN:
    MOVE.W  #15, D7                     ; X POSISION
    MOVE.W  #0, D6                      ; Y POSITION
    LEA     RLINK_TXT,A6
    JSR     WriteText

    MOVEQ   #16, D7                     ; X POSISION
    MOVEQ   #14, D6                     ; Y POSITION
    LEA     HOST_TXT,A6
    JSR     WriteText

    MOVEQ   #16, D7                     ; X POSISION
    MOVEQ   #16, D6                     ; Y POSITION
    LEA     JOIN_TXT,A6
    JSR     WriteText

    MOVEQ   #14, D7                     ; X POSISION
    MOVEQ   #14, D6                     ; Y POSITION
    LEA     CURSOR,A6
    JSR     WriteText

    MOVE.B  #1,MENU_CHOICE              ; SET MENU CHOICE DEFAULT

;*******************************************************************************
;** RLINK LOOP                                                                **
;*******************************************************************************
RLINK_LOOP:
    JSR     ReadJoypad                  ; Update joypad input
    MOVE.B  JoyPress, d7                ; Get button presses

@DOWN_CHK:    
    BTST    #JOY_DOWN, d7               ; DOWN PRESSED?
    BEQ.S   @UP_CHECK

    MOVEQ   #14, D7                     ; X POSISION
    MOVEQ   #14, D6                     ; Y POSITION
    LEA     ERASE_CURSOR,A6
    JSR     WriteText

    MOVE.B  #2,MENU_CHOICE
    MOVEQ   #14, D7                     ; X POSISION
    MOVEQ   #16, D6                     ; Y POSITION
    LEA     CURSOR,A6
    JSR     WriteText
    BRA     RLINK_LOOP

@UP_CHECK:
    BTST    #JOY_UP, d7                 ; UP PRESSED?
    BEQ.S   @B_CHK
    move.b  #1,MENU_CHOICE
    MOVEQ   #14, D7                     ; X POSISION
    MOVEQ   #14, D6                     ; Y POSITION
    LEA     CURSOR,A6
    JSR     WriteText
    MOVEQ   #14, D7                     ; X POSISION
    MOVEQ   #16, D6                     ; Y POSITION
    LEA     ERASE_CURSOR,A6
    JSR     WriteText

@B_CHK:
    BTST    #JOY_B, d7                  ; B PRESSED?
    BEQ.S   @RLINK_LOOP_END
    MOVEQ   #0, D7                      ; X POSISION
    MOVEQ   #14, D6                     ; Y POSITION
    LEA     BLANK_LINE,A6
    JSR     WriteText
    MOVEQ   #0, D7                      ; X POSISION
    MOVEQ   #16, D6                     ; Y POSITION
    LEA     BLANK_LINE,A6
    JSR     WriteText
    CMP.B   #1,MENU_CHOICE
    BEQ.S   HOST_GAME
    BRA.S   JOIN_GAME
@RLINK_LOOP_END:
    BRA     RLINK_LOOP

;****************************************************************************
;** HOST GAME
;****************************************************************************
HOST_GAME:
    JSR     CLEAR_SCREEN                ; CLEAR TEXT
    
    MOVEQ   #2, D7                      ; X POSISION
    MOVEQ   #14, D6                     ; Y POSITION
    LEA     WAITING,A6                  ; WAITING FOR OPPONENT TEXT
    JSR     WriteText

    MOVE.B  #$08, UART_MCR              ; ALLOW INCOMING CONNECTIONS

;!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!    
;   BRA.S   @CONNECTED
;!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!    

@WAIT_CONNECT:
    BTST    #0,UART_LSR                 ; DATA AVAILABLE?
    BEQ.S   @WAIT_CONNECT
@GET_RESPONSE:
    MOVE.B  UART_RHR,D0
    CMP.B   #'C',D0
    BEQ.S   @CONNECTED
    BRA.S   @WAIT_CONNECT
@CONNECTED:
    MOVE.B  #'M',WHOAMI                 ; SET WHOAMI BYTE
    RTS

;****************************************************************************
;** JOIN GAME
;****************************************************************************
JOIN_GAME:
    BRA     CONNECT                     ; FOR P2P HARD CODED TESTING

    MOVEQ   #7, D7                      ; X POSISION
    MOVEQ   #10, D6                     ; Y POSITION
    LEA     ENTER_IP,A6                 ; WAITING FOR OPPONENT TEXT
    JSR     WriteText

    MOVEQ   #12, D7                     ; X POSISION
    MOVEQ   #14, D6                     ; Y POSITION
    LEA     IP_TEMPLATE,A6              ; DRAW IP ADDRESS RESPRESENTATION
    JSR     WriteText

    MOVE.W  #0, D7                      ; X POSISION
    MOVEQ   #15, D6                     ; Y POSITION
    LEA     BLANK_LINE,A6               ; WAITING FOR OPPONENT TEXT
    JSR     WriteText

    MOVEQ   #5, D7                      ; X POSISION
    MOVEQ   #20, D6                     ; Y POSITION
    LEA     JOIN_INSTRUCTIONS,A6        ; WAITING FOR OPPONENT TEXT
    JSR     WriteText

    LEA     IP_TEMPLATE,A0              ; LOAD IP TEMPLATE TO RAM
    LEA     IP_ADDRESS,A1
    MOVE.W  #14,D0                      ; 15 CHARS (000.000.000.000)
FILL_LOOP:
    MOVE.B  (A0)+,(A1)+                 ; COPY! 
    DBRA    D0,FILL_LOOP
    MOVE.B  #$0A,(A1)                   ; TERMINATE IT WITH 0x0A CARRIDGE RETURN BYTE

    MOVE.W  #12,D0                      ; X POSITION FOR PRINTING TEXT
    MOVE.B  #$0,D1                      ; INDEX POSITION FOR IP ADDRESS
    MOVE.B  #0x30,D2                    ; INPUT DIGIT INDEX (STARTS ON 0)
    CLR.W   TEMP                        ; CLEAR TEMP SINGLE CHAR STRING BUFFER
    LEA     IP_ADDRESS,A0               ; POINT TO IP ADDRESS DATA IN RAM

    MOVE.B  D2,TEMP                     ; MOVE VALUE TO TEMP
    MOVE.B  #0x00,TEMP+1                ; TERMINATE IT WITH 0X00 ("NULL TERMINATED STRING")
    MOVE.W  D0, D7                      ; X POSISION
    MOVE.W  #14, D6                     ; Y POSITION
    LEA     TEMP,A6                     ; TEMP SINGLE CHAR STRING
    JSR     WriteText                   ; PRINT IT!

    MOVE.W  D0, D7                      ; X POSISION
    MOVEQ   #15, D6                     ; Y POSITION
    LEA     DOT_CURSOR,A6               ; DRAW DOT CURSOR
    JSR     WriteText

;****************************************
;** INPUT LOOP
;****************************************
INPUT_LOOP:
    JSR     ReadJoypad                  ; Update joypad input
    MOVE.B  JoyPress, D7                ; Get button presses
    CMP.B   #$F,D1                      ; DID WE ENTER ALL DIGITS?             
    BGE     C_CHK                       ; IF SO, THEN JUST SKIP UP/DOWN AND CHECK FOR START/C
UP_CHK:
    BTST    #JOY_UP,D7                  ; UP PRESSED?
    BEQ.S   DOWN_CHK                    ; IF NOT, CHECK DPAD DOWN
    CMP.B   #0x39,D2                    ; ARE WE ON "9"
    BEQ.S   UP_ROLLOVER
    ADD.B   #0x01,D2                    ; DECREMENT BY 1
    BRA     UPDATE_DIGIT
UP_ROLLOVER:
    MOVE.B  #0x30,D2                    ; SET "0" 
    BRA     UPDATE_DIGIT
;----------------------------------------    
DOWN_CHK:
    BTST    #JOY_DOWN, D7               ; DOWN PRESSED?
    BEQ.S   A_CHK                       ; IF NOT, CHECK A
    CMP.B   #0x30,D2                    ; ARE WE ON "9"?
    BEQ.S   DN_ROLLOVER
    SUB.B   #0x01,D2                    ; INCCREMENT BY 1
    BRA     UPDATE_DIGIT
DN_ROLLOVER:
    MOVE.B  #0x39,D2                    ; SET "9" 
    BRA     UPDATE_DIGIT
;----------------------------------------    
A_CHK:
    BTST    #JOY_A, D7                  ; A PRESSED?
    BEQ     C_CHK                       ; IF NOT, CHECK C
    CMP.B   #$E,D1                      ; ARE WE ON LAST DIGIT?
    BNE.S   NORMAL_INPUT                ; IF LESS THAN OR EQUAL TO LAST DIGIT, BRANCH
    MOVE.B  D2,(A0)+                    ; STORE THE DIGIT INTO RAM
    ADD.B   #$1,D1                      ; INCREMEMNT D1
    MOVEQ   #5, D7                      ; X POSISION
    MOVEQ   #20, D6                     ; Y POSITION
    LEA     PRESS_START,A6              ; PRINT "PRESS START TO CONNECT" TEXT
    JSR     WriteText
    BRA     INPUT_END                   ; EXIT
NORMAL_INPUT:
    CMP.B   #$2,D1                      ; ABOUT TO BE ON 1ST DECIMAL?
    BEQ.S   SKIP_DECIMAL_FWD
    CMP.B   #$6,D1                      ; ABOUT TO BE ON 2ND DECIMAL?
    BEQ.S   SKIP_DECIMAL_FWD
    CMP.B   #$A,D1                      ; ABOUT TO BE ON 3RD DECIMAL?
    BEQ.S   SKIP_DECIMAL_FWD
    MOVE.B  D2,(A0)+                    ; STORE DIGIT INDEX VALUE INTO IP ADDRESS AND ADVANCE INDEX
    ADD.B   #$1,D1                      ; INCREMENT INDEX POSITION COUNTER
    ADD.W   #1,D0                       ; INCREMENT TEXT DRAWING X POSITION
    MOVE.B  #0x30,D2                    ; SET D2 TO "0"
    MOVE.B  D2,TEMP                     ; MOVE VALUE TO TEMP
    MOVE.B  #0x00,TEMP+1                ; TERMINATE IT WITH 0X00 ("NULL TERMINATED STRING")
    MOVE.W  D0, D7                      ; X POSISION
    MOVE.W  #14, D6                     ; Y POSITION
    LEA     TEMP,A6                     ; TEMP SINGLE CHAR STRING
    JSR     WriteText                   ; PRINT IT!
    BRA     UPDATE_CURSOR
SKIP_DECIMAL_FWD:
    MOVE.B  D2,(A0)+                    ; STORE THE DIGIT
    MOVE.B  #'.',(A0)+                  ; THEN SET A DECIMAL PLACE
    ADD.B   #$2,D1                      ; INCREMENT INDEX POSITION COUNTER
    ADD.W   #2,D0                       ; INCREMENT TEXT DRAWING X POSITION
    MOVE.B  #0x30,D2                    ; SET D2 TO "0"
    MOVE.B  D2,TEMP                     ; MOVE VALUE TO TEMP
    MOVE.B  #0x00,TEMP+1                ; TERMINATE IT WITH 0X00 ("NULL TERMINATED STRING")
    MOVE.W  D0, D7                      ; X POSISION
    MOVE.W  #14, D6                     ; Y POSITION
    LEA     TEMP,A6                     ; TEMP SINGLE CHAR STRING
    JSR     WriteText                   ; PRINT IT!
    BRA     UPDATE_CURSOR
;----------------------------------------    
C_CHK:
    BTST    #JOY_C,D7 
    BEQ.S   START_CHK
    BRA     JOIN_GAME
;----------------------------------------    
START_CHK:
    BTST    #JOY_START,D7 
    BEQ.S   INPUT_END
    CMP.B   #$F,D1                      ; DID WE ENTER ALL DIGITS?
    BNE.S   INPUT_END
    JSR     CONNECT
;----------------------------------------    
UPDATE_CURSOR:
    MOVE.W  #0, D7                      ; X POSISION
    MOVEQ   #15, D6                     ; Y POSITION
    LEA     BLANK_LINE,A6               ; WAITING FOR OPPONENT TEXT
    JSR     WriteText
    MOVE.W  D0, D7                      ; X POSISION
    MOVEQ   #15, D6                     ; Y POSITION
    LEA     DOT_CURSOR,A6               ; WAITING FOR OPPONENT TEXT
    JSR     WriteText
    BRA     INPUT_END
;----------------------------------------
UPDATE_DIGIT:
    MOVE.B  D2,TEMP                     ; MOVE VALUE TO TEMP
    MOVE.B  #0x00,TEMP+1                ; TERMINATE IT WITH 0X00 ("NULL TERMINATED STRING")
    MOVE.W  D0, D7                      ; X POSISION
    MOVE.W  #14, D6                     ; Y POSITION
    LEA     TEMP,A6                     ; TEMP SINGLE CHAR STRING
    JSR     WriteText                   ; PRINT IT!
;----------------------------------------
INPUT_END:
    MOVE.L  #191750,D7                  ; DELAY AMOUNT
wait_loop:
    NOP
    DBF    D7,WAIT_LOOP                 ; LOOP UNTIL DELAY DONE
    BRA    INPUT_LOOP

;****************************************************************************
;** CONNECT TO OPPONENT
;****************************************************************************
CONNECT:
    JSR     CLEAR_SCREEN                ; CLEAR TEXT

    MOVEQ   #2, D7                      ; X POSISION
    MOVEQ   #14, D6                     ; Y POSITION
    LEA     CONNECTING,A6               ; PRINT "PRESS START TO CONNECT" TEXT
    JSR     WriteText

;!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
;   BRA.S   @CONNECTED                  ; HACK TO JUST START
;!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

    LEA     TEST_IP,A0
    MOVE.W  #21,D0                      ; NUMBER OF BYTES TO SEND (16)
@SEND_LOOP:
    BTST    #5,UART_LSR                 ; OK TO SEND?
    BEQ.S   @SEND_LOOP                  ; WAIT UNTIL OK TO SEND
    MOVE.B  (A0)+,UART_THR              ; SEND BYTE
    DBRA    D0,@SEND_LOOP               ; SEND UNTIL ALL BYTES SENT
@CHECK_RESPONSE:
    BTST    #0,UART_LSR
    BEQ.S   @CHECK_RESPONSE
@GET_RESPONSE_SLAVE:
    MOVE.B  UART_RHR,D0
    CMP.B   #'C',D0                     ; CONNECT RESPONSE?
    BEQ.S   @CONNECTED
    CMP.B   #'N',D0                     ; TIMEOUT RESPONSE?
    BEQ.S   @NOT_CONNECTED
    BRA.S   @CHECK_RESPONSE
@CONNECTED:
    MOVE.B  #'S',WHOAMI                 ; SET CONSOLE AS SLAVE
    RTS
@NOT_CONNECTED:
    ILLEGAL

;****************************************************************************
;** SETUP VDP
;****************************************************************************
SETUP_VDP:
    lea     ($C00004), a0
    lea     ($C00000), a1
    
    tst.w   (a0)                        ; Discard any pending VDP command
    
    move.w  #$8000|$04, (a0)     ; Set up VDP registers
    move.w  #$8100|$24, (a0)
    move.w  #$8C00|$81, (a0)
    move.w  #$8B00|$00, (a0)
    move.w  #$8200|$38, (a0)
    move.w  #$8400|$07, (a0)
    move.w  #$8300|$00, (a0)
    move.w  #$8500|$00, (a0)
    move.w  #$8D00|$00, (a0)
    move.w  #$9000|$01, (a0)
    move.w  #$9100|$00, (a0)
    move.w  #$9200|$00, (a0)
    move.w  #$8F00|$02, (a0)
    move.w  #$8700|$00, (a0)
    move.w  #$8A00|$FF, (a0)
    
    moveq   #0, d0                      ; Clear VRAM
    move.l  #$40000000, (a0)
    move.w  #($10000/$20)-1, d5
@ClearVram:
    move.l  d0, (a1)
    move.l  d0, (a1)
    move.l  d0, (a1)
    move.l  d0, (a1)
    move.l  d0, (a1)
    move.l  d0, (a1)
    move.l  d0, (a1)
    move.l  d0, (a1)
    dbf     d5, @ClearVram

    lea     (FontGfx), a6               ; Load font
    move.l  #$40200000, (a0)
    moveq   #37-1, d5

@LoadFont:
    move.l  (a6)+, (a1)
    move.l  (a6)+, (a1)
    move.l  (a6)+, (a1)
    move.l  (a6)+, (a1)
    move.l  (a6)+, (a1)
    move.l  (a6)+, (a1)
    move.l  (a6)+, (a1)
    move.l  (a6)+, (a1)
    dbf     d5, @LoadFont
    
    move.l  #$C0000000, (a0)            ; Load palette
    move.l  #$00000EEE, (a1)            ; White ; B;G;R
    move.w  #$0444, (a1)                ; Grey

    move.l  #$40000010, (a0)            ; Reset vscroll
    move.l  d0, (a1)

    move.w  #$8100|$64,($C00004)        ; Turn on display
    rts

;****************************************************************************
;** LOAD FONT
;****************************************************************************
LOAD_FONT:  
    lea     (FontGfx), a6               ; Load font
    move.l  #$40200000, (a0)
    moveq   #37-1, d5
@LoadFont:
    move.l  (a6)+, (a1)
    move.l  (a6)+, (a1)
    move.l  (a6)+, (a1)
    move.l  (a6)+, (a1)
    move.l  (a6)+, (a1)
    move.l  (a6)+, (a1)
    move.l  (a6)+, (a1)
    move.l  (a6)+, (a1)
    dbf     d5, @LoadFont
    
    move.l  #$C0000FFF, (a0)            ; Load palette
    move.l  #$00000EEE, (a1)            ; White ; B;G;R
    move.w  #$0444, (a1)                ; Grey

    rts

;****************************************************************************
;** READ JOYPAD
;****************************************************************************
ReadJoypad:
    lea     $A10003, a6    
    move.b  #$40, (a6)                  ; Read D-pad, B and C
    nop
    nop
    move.b  (a6), d7
    move.b  #$00, (a6)                  ; Read A and Start
    nop
    nop
    move.b  (a6), d6
    and.b   #$3F, d7                    ; Put all buttons together
    and.b   #$30, d6
    add.b   d6, d6
    add.b   d6, d6
    or.b    d6, d7
    not.b   d7                          ; Make buttons high logic
    lea     (JoyHold), a6               ; Update hold/press state
    move.b  (a6), d6
    move.b  d7, (a6)+
    not.b   d6
    and.b   d6, d7
    move.b  d7, (a6)+
    rts                                 ; End of subroutine

;****************************************************************************
;** CLEAR SCREEN
;****************************************************************************
CLEAR_SCREEN:
    MOVEQ   #27,D0                      ; 28 LINES
@ClearLoop:
    MOVE.W  #0, D7                      ; X POSISION
    MOVE.w  D0, D6                      ; Y POSITION
    LEA     BLANK_LINE,A6               ; WAITING FOR OPPONENT TEXT
    JSR     WriteText    
    DBRA    D0,@ClearLoop
    RTS

;****************************************************************************
;** WRITE TEXT
;****************************************************************************
WriteText:
    ADD.W   SCREEN_X,D7                 ; ADD OFFSET TO SCREEN.
    ADD.W   SCREEN_Y,D6

    lea     ($C00000), a5
    lea     @Table-$20(pc), a4          ; @Table-$20(pc) (SKIPPING 20)
    lsl.w   #6, d6                      ; Determine VRAM address
    add.w   d6, d7
    add.w   d7, d7
    add.w   #$E000, d7
    and.l   #$FFFF, d7                  ; Set up VRAM address
    lsl.l   #2, d7
    lsr.w   #2, d7
    or.w    #$4000, d7
    swap    d7
    move.l  d7, 4(a5)
@Loop:
    moveq   #0, d7                      ; Get next character (if any)
    move.b  (a6)+, d7
    beq.s   @End
    move.b  (a4,d7.w), d7               ; Convert from ASCII to tile ID
    move.w  d7, (a5)                    ; Put tile into tilemap
    bra.s   @Loop                       ; Keep drawing
@End:
    rts                                 ; End of subroutine
;----------------------------------------------------------------------------
@Table:
    dc.b     0, 0, 0, 0, 0, 0, 0, 0     ; U+0020..U+0027 20,21,22,23,24,25,26,27
    dc.b     0, 0, 0, 0, 0, 0,37, 0     ; U+0028..U+002F 28,29,2A,2B,2C,2D,2E,2F
    dc.b     1, 2, 3, 4, 5, 6, 7, 8     ; U+0030..U+0037 30,31,32,33,34,35,36,37
    dc.b     9,10, 0, 0, 0, 0, 0, 0     ; U+0038..U+003F 38,39,3A,3B,3C,3D,3E,3F
    dc.b     0,11,12,13,14,15,16,17     ; U+0040..U+0047 40,41,42,43,44,45,46,47
    dc.b    18,19,20,21,22,23,24,25     ; U+0048..U+004F 48,49,4A,4B,4C,4D,4E,4F
    dc.b    26,27,28,29,30,31,32,33     ; U+0050..U+0057 50,51,52,53,54,55,56,57
    dc.b    34,35,36, 0, 0, 0, 0, 0     ; U+0058..U+005F 58,59,5A,5B,5C,5D,5E,5F

;*******************************************************************************
;** INCLUDES                                                                  **
;*******************************************************************************

ENTER_IP:           DC.B 'ENTER OPPONENT IP ADDRESS',0
JOIN_INSTRUCTIONS:  DC.B 'A.NEXT  C.RESET  UP.DN SELECT',0
PRESS_START:        DC.B '    PRESS START TO CONNECT   ',0

IP_TEMPLATE:        DC.B '000.000.000.000',0

TEST_IP:            DC.B 'C192.168.001.161:5364',$0A

CURSOR:             dc.b '0',0
DOT_CURSOR:         DC.B '.',0
ERASE_CURSOR        DC.B ' ',0
BLANK_LINE          DC.B '                                        ',0

RLINK_TXT:          DC.B 'RETRO.LINK',0
HOST_TXT:           DC.B 'HOST GAME',0
JOIN_TXT:           DC.B 'JOIN GAME',0

CONNECTED:          DC.B '               CONNECTED                ',0 
CONNECTING:         DC.B '             CONNECTING...              ',0
WAITING:            DC.B '        WAITING FOR OPPONENT...         ',0

    EVEN

FontGfx:
    incbin  "font.4bpp"

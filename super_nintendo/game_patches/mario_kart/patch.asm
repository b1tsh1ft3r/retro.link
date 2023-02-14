//*****************************************************************
//** Project    : Super Mario Kart                               **
//** Platform   : Super Nintendo - Retro.Link                    **
//** Version    : 0.1                                            **
//*****************************************************************

    arch snes.cpu
    output "patched.sfc", create
    origin $000000
    insert "SMK.SFC"

macro seek(variable offset) {
  origin ((offset & $7F0000) >> 1) | (offset & $7FFF)
  base offset
}

//*****************************************************************
//** UART DEFINES (Not-Final)                                    **
//*****************************************************************
constant UART_RHR($21C1)        // Receive holding register    
constant UART_THR($21C1)        // Transmit holding register
constant UART_IER($21C3)        // Interrupt enable register
constant UART_FCR($21C5)        // Line control register
constant UART_LCR($21C7)        // Modem control register
constant UART_MCR($21C9)        // Line status register
constant UART_LSR($21CB)        // Line status register
constant UART_DLL($21C1)        // Baud Rate
constant UART_DLM($21C3)        // Baud Rate
constant UART_DVID($21C3)       // Device ID

//*******************************************************************************
// GAME RAM VARIABLES
//*******************************************************************************
constant REG_JOY1L($4218)       // Joypad 1 (Gameport 1, Pin 4) (Lower 8-Bit)  2B/R
constant JOYPAD_FIELD($0020)    // (X) BYTE FIELD LOCATION FOR CONTROLLER DATA

constant NMI_COUNTER($0034)     // (W) NMI COUNTER

constant GAME_MODE($002C)       // (W) 00=grandprix 02=VS, 04=Time trial, 06=Battle
constant NUM_PLAYERS($002E)     // (W) 00=2 players
constant RACE_CC($0030)         // (W) Race cc (00: 50cc, 02: 100cc, 04: 150cc)

constant GAME_STATE($003A)      // (?) 00 Init game mode
                                //     02=fade in
                                //     04=count down
                                //     06=normal
                                //     08=fade out

constant GAME_SCREEN($0032)     // (W) 00 non select
                                //     02=racing
                                //     04=title
                                //     06=kart select
                                //     08=name input
                                //     0a=results
                                //     0c=records
                                //     0e=battle

//*******************************************************************************
// CUSTOM RAM VARIABLES                                                        **
//*******************************************************************************
constant RAMBASE($0E58)         // LOCATION FOR CUSTOM RAM VARIABLES (6 BYTES)
constant WHOAMI(RAMBASE+0)      // (B) WHOAMI

//***********************************
// PATCH POINTS
//***********************************
    origin  $0843C              // Joypad routine in Vblank
    jsl     Rlink_Joypad        // Jump to our routine
    rts

//*******************************************************************************
//** END OF ROM                                                                **
//*******************************************************************************

    origin  $88000              // LOCATION AT END OF ROM FOR ALL NEW CODE
    base    $C88000

//*******************************************************************************
//** RLINK JOYPAD                                                              **
//*******************************************************************************
Rlink_Joypad:
    lda     WHOAMI              // Load WHOAMI into A
    cmp     #'S'                // Is this console Slave?
    beq     Slave_Read          // Branch if so, otherwise we're master. Fall into code below
//--------------------------------
Master_Read:
    ldx.w   #0                  // Zero X register for player 1 (offset into joypad bitfield)
    jsl     Read_Joypad         // Read joypad port 1 for player 1
    jsl     Networking          // Do Networking
    ldx.w   #2                  // Set X register to 2 for player 2 (offset we add to index into joypad bitfield) 
    bra     Store_Joypad        // Branch off and just store it whatever is in A 
//--------------------------------
Slave_Read:
    ldx.w   #2                  // Load 2 into register X for player 2 (offset into joypad bitfield)
    jsl     Read_Joypad         // Read joypad port 1 for player 2 and store results
    jsl     Networking          // Do Networking
    ldx.w   #0                  // Set X register to 0 for player 1 (offset we add to index into joypad bitfield) 
    bra     Store_Joypad        // Branch off and just store it whatever is in A 
//--------------------------------
Read_Joypad:
    lda.w   REG_JOY1L           // Read from joypad port1 only
Store_Joypad:
    sta.w   JOYPAD_FIELD,x      // Store new pad data immediately (padfield+offset)
    pha                         // Push new joydata in A onto stack
    eor.b   JOYPAD_FIELD+4,x    // Prev frame
    and.b   JOYPAD_FIELD,x      // Current
    sta.b   JOYPAD_FIELD+8,x    // New inputs
    ldy.w   $0E32               // Demo flag?
    beq     Continue_Scan
    ldy.w   $0E50               // Ending flag?
    bne     Continue_Scan
    ldy.w   $0032               // Game select?
    bne     Continue_Scan
    bit.w   #$9000              // B/Start buttons?
    beq     Continue_Scan
    pla                         // Pull stashed joypad value from stack into A
    jml     $8085FD             // Start title screen?
Continue_Scan:
    pla                         // pull new joydata off stack to A
    sta.b   JOYPAD_FIELD+4,x    // update prev frame value with the new data from this frame
    rtl

//*******************************************************************************
//** Networking                                                                **
//*******************************************************************************
Networking:
    rtl     // temporary for now because this freezes our patch

    lda     JOYPAD_FIELD,x      // Load local new joypad data to A
    cmp     #$0000              // Is it empty? (no joypad input)
    beq     Receive_Data        // Branch and check for remote data instead
//------------------------------
Send_Data:
    lda     UART_LSR            // Get UART status register value in A
    and     #$05                // mask to check bit 5
    beq     Send_Data           // Wait until ok to send data
    lda     JOYPAD_FIELD,x      // Point to our new joypad data in A
Send_Byte1:
    sta     UART_THR            // Send byte 1
    xba                         // swap
Send_Byte2:
    sta     UART_THR            // Send byte 2
    xba                         // swap back
//------------------------------
Receive_Data:
    lda     UART_LSR            // Get UART status register value in A
    and     #$00                // mask to check bit 0
    beq     No_Data             // if not set, no data. Just exit
Get_Data:
    lda     UART_RHR            // Get 1st byte of joypad data into A
    xba                         // swap
    lda     UART_RHR            // Get 2nd byte of joypad data into A
    xba                         // swap
    rtl                         // Return with remote joypad data (word) in A
//------------------------------
No_Data:
    lda.w   #$0000              // Null out joypad input value in A to store for use this frame
    rtl                         // Return

//*******************************************************************************
//** END                                                                       **
//*******************************************************************************



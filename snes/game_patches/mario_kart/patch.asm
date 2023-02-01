//*****************************************************************
//** Project    : Super Mario Kart                               **
//** Platform   : Super Nintendo - Retro.Link                    **
//** Version    : 0.1                                            **
//*****************************************************************

include "SNES.INC"

arch snes.cpu
output "patched.sfc", create

origin $000000
insert "SMK.SFC"

macro seek(variable offset) {
  origin ((offset & $7F0000) >> 1) | (offset & $7FFF)
  base offset
}

//***************************************
//RLINK VBLANK
//***************************************
//    origin $0843C
//    JSL    RLINK_VBLANK
//    rts

//*****************************************************************
//** DEFINES                                                     **
//*****************************************************************
constant UART_RHR($21C1)        // Receive holding register    
constant UART_THR($21C1)        // Transmit holding register
constant UART_IER($21C3)        // Interrupt enable register
constant UART_FCR($21C5)        // Line control register
constant UART_LCR($21C7)        // Modem control register
constant UART_MCR($21C9)        // Line status register
constant UART_SPR($21CF)
constant UART_DLL($21C1)
constant UART_DLM($21C3)
constant UART_DVID($21C3)       // Device ID
constant UART_OP2($21C9)        // OP2 GPIO

//------------------------------------
// GAME RAM VARIABLES
//------------------------------------
constant CTRL1_DATA($7E0020)       // (W) CONTROLLER 1 DATA CURRENT FRAME
constant CTRL2_DATA($7E0022)       // (W) CONTROLLER 2 DATA PREVIOUS FRAME
constant CTRL1_PREV($7E0024)       // (W) CONTROLLER 1 DATA CURRENT FRAME
constant CTRL2_PREV($7E0026)       // (W) CONTROLLER 2 DATA PREVIOUS FRAME
constant NMI_COUNTER($7E0034)      // (W) NMI COUNTER

constant GAME_MODE($7E002C)        // (W) 00=grandprix 02=VS, 04=Time trial, 06=Battle
constant NUM_PLAYERS($7E002E)      // (W) 00=2 players
constant RACE_CC($7E0030)          // (W) Race cc (00: 50cc, 02: 100cc, 04: 150cc)

constant GAME_STATE($7E0003A)      // (?) 00 Init game mode
                                   //     02=fade in
                                   //     04=count down
                                   //     06=normal
                                   //     08=fade out

constant GAME_SCREEN($7E0032)      // (W) 00 non select
                                   //     02=racing
                                   //     04=title
                                   //     06=kart select
                                   //     08=name input
                                   //     0a=results
                                   //     0c=records
                                   //     0e=battle

//------------------------------------
// CUSTOM RAM VARIABLES
//------------------------------------
constant RAMBASE($7E00E58)         // LOCATION FOR CUSTOM RAM VARIABLES (6 BYTES)

//*******************************************************************************
//** END OF ROM                                                                **
//*******************************************************************************

    origin $80000                 // LOCATION AT END OF ROM
    base   $C80000

//*******************************************************************************
//** STARTUP                                                                   **
//*******************************************************************************
STARTUP:
    rtl

//*******************************************************************************
//** RLINK VBLANK                                                              **
//*******************************************************************************
RLINK_VBLANK:
    rtl

//*******************************************************************************
//** INCLUDES                                                                  **
//*******************************************************************************

//*******************************************************************************
//** END                                                                       **
//*******************************************************************************

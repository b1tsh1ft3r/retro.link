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
//** DEFINES                                                     **
//*****************************************************************
constant UART_RHR($21C1)        // Receive holding register    
constant UART_THR($21C1)        // Transmit holding register
constant UART_IER($21C3)        // Interrupt enable register
constant UART_FCR($21C5)        // Line control register
constant UART_LCR($21C7)        // Modem control register
constant UART_MCR($21C9)        // Line status register
constant UART_LSR($21CB)        // Scratchpad register
constant UART_SPR($21CF)
constant UART_DLL($21C1)
constant UART_DLM($21C3)
constant UART_DVID($21C3)       // Device ID
constant UART_OP2($21C9)        // OP2 GPIO

//------------------------------------
// GAME RAM VARIABLES
//------------------------------------
constant CTRL1_DATA($0000)         // CONTROLLER 1 RAM
constant CTRL2_DATA($0000)         // CONTROLLER 2 RAM
constant VBL_COUNTER($0000)        // VBLANK COUNTER

// PLAYER 1 VARIABLES
constant P1_STATUS($7E10A0)       // 1 UNSIGNED BYTE (JUMPING, SLIDING, ECT...)
constant P1_YAXIS($7E008C)        // 2 UNSIGNED BYTES
constant P1_XAXIS($7E0088)        // 2 UNSIGNED BYTES
constant P1_CAMERA_ANGLE($7E0095) // 2 UNSIGNED BYTES CAMERA ANGLE
constant P1_KART_ANGLE($7E10AA)   // 2 SIGNED BYTES  KART FACING ANGLE
constant P1_SPEED_YAXIS($7E1024)  // 2 SIGNED BYTES  SPEED TO SOUTH
constant P1_SPEED_XAXIS($7E1022)  // 2 SIGNED BYTES  SPEED TO EAST
constant P1_TOTAL_SPEED($7E10EA)  // 2 SIGNED BYTES  OVER ALL SPEED
constant P1_SURFACE_TYPE($7E10AE) // 1 UNSIGNED BYTE (WATER?DEEP WATER?ECT...)
constant P1_COLLISION($7E1052)    // 1 UNSIGNED BYTE (HIT SOMETHING OR NOT)
constant P1_SKID($7E10A6)         // 1 UNSIGNED BYTE (SKID OUT OF CONTROL TYPE)
constant P1_BOOST($7E104E)        // 1 UNSIGNED BYTE (MUSHROOM BOOST FLAG)
constant P1_ITEM($7E0D7C)         // 2 UNSIGNED BYTES (ITEM WE ROLLED OVER ON MAP)
constant P1_HEIGHT($7E101F)       // 2 UNSIGNED BYTES (ON GROUND OR IN AIR)

//------------------------------------
// CUSTOM RAM VARIABLES
//------------------------------------
constant RAMBASE($0000)           // LOCATION FOR CUSTOM RAM VARIABLES

//*******************************************************************************
//** END OF ROM                                                                **
//*******************************************************************************

    origin  $000000               // LOCATION AT END OF ROM

//*******************************************************************************
//** STARTUP                                                                   **
//*******************************************************************************
STARTUP:
    // UART check

//*******************************************************************************
//** INCLUDES                                                                  **
//*******************************************************************************

//*******************************************************************************
//** END                                                                       **
//*******************************************************************************

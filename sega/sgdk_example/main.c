#include <genesis.h>
#include "network.h"

int main()
{
    SYS_disableInts();                      // Disable interrupts
    VDP_setScreenWidth320();                // Set screen Width
    VDP_setScreenHeight224();               // Set screen Height
    VDP_setBackgroundColor(0);              // Set background black
    VDP_setTextPlane(BG_B);                 // Use PLANE B for text rendering
    VDP_setTextPalette(0);                  // Use palette 0 for text color
    SYS_enableInts();                       // Enable interrupts

    int cursor_x = 1;
    int cursor_y = 1;

    PAL_fadeOutPalette(PAL0,1,FALSE);
    VDP_setBackgroundColor(2);
    PAL_fadeInPalette(PAL0, palette_grey, 16, FALSE);

    VDP_drawText("______________________________________", cursor_x, cursor_y); cursor_y++;
    VDP_drawText("          Retro.Link Test ROM         ", cursor_x, cursor_y); cursor_y++;
    VDP_drawText("______________________________________", cursor_x, cursor_y); cursor_y+=2;

    VDP_drawText("Detecting cartridge...", cursor_x, cursor_y); cursor_x+=23; 

    NET_initialize(); // Detect cartridge and set boolean variable

    if(cart_present)
    {
        VDP_setTextPalette(2); // Green text
        VDP_drawText("[OK]", cursor_x, cursor_y); cursor_x=1; cursor_y++;
        VDP_setTextPalette(0); // White text
        VDP_drawText("Network initialized", cursor_x, cursor_y); cursor_x=1; cursor_y++;
        NET_printLocalIP(cursor_x-2, cursor_y); cursor_y++;
    }
    else
    {
        VDP_setTextPalette(1); // Red text
        VDP_drawText("[X]", cursor_x, cursor_y); cursor_x=1; cursor_y++;
        VDP_setTextPalette(0); // White text
        VDP_drawText("Adapter not detected", cursor_x, cursor_y);
    }

//------------------------------------------------------------------
// MAIN LOOP
//------------------------------------------------------------------

    cursor_x = 1;
    cursor_y = 9;
    u8 buttons, buttons_prev;

    NET_flushBuffers(); // Flush hardware fifos (send/receive) and software receive buffer

    UART_MCR = 0x08; // Allow inbound TCP connections to device (Listens on port 5364).
                     // A value of 0x00 will DROP a current connection and deny future connections.

    VDP_drawText("Press START to send 'ABC' text",cursor_x, cursor_y); cursor_x=0; cursor_y++;
    while(1) // Loop forever and print out any data we receive in the hardware receive fifo
    { 
        buttons = JOY_readJoypad(JOY_1);

        if(buttons & BUTTON_START && buttons_prev == 0x00) { NET_sendMessage("AB"); NET_sendByte('C'); }

        while(NET_RXReady()) // while data in hardware receive FIFO
        {   
            u8 byte = NET_readByte(); // Retrieve byte from RX hardware Fifo directly
            switch(byte)
            {
                case 0x0A: // a line feed?
                    cursor_y++;
                    cursor_x=1;
                    break;              
                case 0x0D: // a carridge Return?
                    cursor_x=1;
                    break; 
                default:   // print
                    if (cursor_x >= 38) { cursor_x=1; cursor_y++; }
                    if (cursor_y >= 22) { VDP_clearTextAreaBG(BG_B, 0, 9, 40, 14); cursor_x=1; cursor_y=9; }
                    sprintf(str, "%c", byte); // Convert
                    VDP_drawText(str, cursor_x, cursor_y); cursor_x++;
                    break;
            }
        }
        buttons_prev = buttons;
        SYS_doVBlankProcess(); 
    }

//------------------------------------------------------------------
    return(0);
}

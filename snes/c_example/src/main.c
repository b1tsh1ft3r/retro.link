#include <snes.h>
#include <stdlib.h>
#include "network.h"

extern char tilfont, palfont;

int i, cursor_x, cursor_y;
u8 buttons, buttons_prev;

int main(void)
{
    consoleInit();
    consoleSetTextVramBGAdr(0x6800);
    consoleSetTextVramAdr(0x3000);
    consoleSetTextOffset(0x0100);
    consoleInitText(0, 16 * 2, &tilfont, &palfont);
    bgSetGfxPtr(0, 0x2000);
    bgSetMapPtr(0, 0x6800, SC_32x32);
    setMode(BG_MODE1, 0);
    bgSetDisable(1);
    bgSetDisable(2);
    setScreenOn();

    cursor_x = 0;
    cursor_y = 1;

    consoleDrawText(cursor_x, cursor_y, "Detecting adapter...[  ]"); cursor_x+=21; 
    NET_initialize(); // Detect cartridge and set boolean variable

    if(cart_present)
    {
        consoleDrawText(cursor_x, cursor_y, "Ok"); cursor_x=0; cursor_y+=2;
    }
    else
    {
        consoleDrawText(cursor_x, cursor_y, "XX"); cursor_x=0; cursor_y+=2;
        consoleDrawText(cursor_x, cursor_y, "Adapter not present");
        while(1) { WaitForVBlank(); }
    }

//------------------------------------------------------------------
// MAIN LOOP
//------------------------------------------------------------------

    consoleDrawText(cursor_x, cursor_y, "IP Address:"); 
    NET_printIP(cursor_x+12, cursor_y); cursor_y++;

    consoleDrawText(cursor_x, cursor_y, "MAC:"); 
    NET_printMAC(cursor_x+5, cursor_y); cursor_y+=2;

    for(i=0; i<2000; i++) { WaitForVBlank(); }

    NET_pingIP(cursor_x, cursor_y, 4, "8.8.8.8"); cursor_y+=6;

    for(i=0; i<2000; i++) { WaitForVBlank(); }

    consoleDrawText(cursor_x, cursor_y, "Rebooting adapter..."); cursor_y+=2;
    NET_resetAdapter();

    NET_connect(cursor_x, cursor_y, "irc.efnet.org:6667"); cursor_x=0; cursor_y++;

    while(1) // Loop forever and print out any data we receive in the hardware receive fifo
    { 
        buttons = padsCurrent(0);
        if(buttons & KEY_START && buttons_prev == 0x00) { NET_sendMessage("PONG\n"); }
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
                    if (cursor_x >= 32) { cursor_x=0; cursor_y++; }
                    if (cursor_y >= 28) { cursor_x=0; cursor_y=0; }
                    sprintf(str, "%c", byte); // Convert
                    consoleDrawText(cursor_x, cursor_y, str); cursor_x++;
                    break;
            }
        }
        buttons_prev = buttons;
        WaitForVBlank(); 
    }

    return 0;
}
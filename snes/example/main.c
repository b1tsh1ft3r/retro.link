//******************************************************************************
// Project:    Retro.Link Example
// Platform:   Super Nintendo (SNES)
//******************************************************************************

#include <snes.h>
#include "/src/network.h"

extern char snesfont;

//******************************************************************************
// MAIN
//******************************************************************************
int main(void) 
{
	consoleInit();                        // Initialize SNES 
	
    consoleInitText(0, 0, &snesfont);     // Initialize text console with our font
	
    setMode(BG_MODE1,0);  
    bgSetDisable(1);  
    bgSetDisable(2); 	                  // Now Put in 16 color mode and disable Bgs except current
	
    setScreenOn();                        // Screen on

    int cursor_x = 1;
    int cursor_y = 1;

    consoleDrawText(cursor_x, cursor_y, "_____________________________"); cursor_y++;
    consoleDrawText(cursor_x, cursor_y, "     Retro.Link Test Rom     "); cursor_y++;
    consoleDrawText(cursor_x, cursor_y, "_____________________________"); cursor_y+=2;

    consoleDrawText(cursor_x, cursor_y, "Detecting cartridge... "); cursor_x+=23;

    NET_initialize(); // Detect cartridge and set boolean variable

    if(cart_present)
    {
	    consoleDrawText(cursor_x, cursor_y, "[OK]"); cursor_x=1; cursor_y++;
	    consoleDrawText(cursor_x, cursor_y, "Network initialized"); cursor_y++;
    }
    else
    {
        consoleDrawText(cursor_x, cursor_y, "[X]"); cursor_x=1; cursor_y++;
	    consoleDrawText(cursor_x, cursor_y, "Adapter not detected"); cursor_y++;
    }

    while(1) { WaitForVBlank(); }

	return 0;
}




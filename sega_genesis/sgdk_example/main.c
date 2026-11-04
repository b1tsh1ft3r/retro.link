#include <genesis.h>
#include "network.h"

typedef struct { u16 top, rows, x; } Pane;  // Rows of text on screen. Text goes on the bottom row

Pane net  = { 8, 11, 0 };                   // Network pane, rows 8-18
Pane keys = { 22, 4, 0 };                   // Keyboard pane, rows 22-25
char site[40];                              // The site you type
u16 len;                                    // Its length
u8 buttons, buttons_prev;

//------------------------------------------------------------------
// Print a character in a pane. A new row scrolls the pane up: the VDP
// copies its rows up one row and the bottom row is cleared.
//------------------------------------------------------------------
void print(Pane *p, char c)
{
    u16 y = p->top + p->rows - 1;           // Bottom row
    if(c == '\n' || p->x == 40)
    {
        u16 top = VDP_getPlaneAddress(BG_B, 0, p->top);
        DMA_doVRamCopy(top + 128, top, (p->rows - 1) * 128, 1); // A plane row is 128 bytes
        DMA_waitCompletion();
        VDP_setAutoInc(2);
        VDP_clearTextLine(y);
        p->x = 0;
    }
    if(c < ' ' || c > '~') { return; }      // Skip CR and other control bytes
    str[0] = c; str[1] = 0;
    VDP_drawText(str, p->x++, y);
}

void printText(Pane *p, char *s) { while(*s) { print(p, *s++); } }

//------------------------------------------------------------------
// Show Ok in green, or the fail mark in red, inside a status [  ]
//------------------------------------------------------------------
void showStatus(u16 y, bool ok, char *fail)
{
    VDP_setTextPalette(ok ? 2 : 1);         // Green or red text
    VDP_drawText(ok ? "Ok" : fail, 10, y);
    VDP_setTextPalette(0);                  // White text
}

//------------------------------------------------------------------
// Hang up. Pin 7 (xPico CP3) going low drops the call.
//------------------------------------------------------------------
void hangUp(void)
{
    NET_flowControlOff();                   // Let anything held come out
    NET_BlockConnections();                 // Pin 7 low hangs up the site
    do { NET_flushBuffers(); waitMs(100); } while(NET_dataAvailable()); // Drop the rest until it goes quiet
}

//------------------------------------------------------------------
// Mini curl. Hangs up the last site, then asks a web site
// ("name:80") for its home page. The main loop prints the reply.
// HTTP/1.1 keeps the call up after the page. The adapter throws away
// what it still holds when a connection ends, so a site that hung up at
// once would cut the page short.
//------------------------------------------------------------------
void fetch(char *host)
{
    hangUp();
    NET_allowConnections();                 // Pin 7 high for the new connection

    printText(&net, "\nConnecting to "); printText(&net, host); print(&net, '\n');
    if(NET_connect(host))
    {
        NET_sendMessage("GET / HTTP/1.1\r\nHost: "); NET_sendMessage(host);
        NET_sendMessage("\r\n\r\n");        // A blank line ends the request
    }
    else { printText(&net, "Host unreachable\n"); }
}

int main()
{
    SYS_disableInts();                      // Disable interrupts
    VDP_setScreenWidth320();                // Set screen Width
    VDP_setScreenHeight224();               // Set screen Height
    VDP_setBackgroundColor(0);              // Set background black
    VDP_setTextPlane(BG_B);                 // Use PLANE B for text rendering
    VDP_setTextPalette(0);                  // Use palette 0 for text color
    SYS_enableInts();                       // Enable interrupts (allows our callback routine to print data)

    PAL_fadeOutPalette(PAL0,1,FALSE);
    VDP_setBackgroundColor(51);             // Blue background
    PAL_fadeInPalette(PAL0, palette_grey, 16, FALSE);

    VDP_drawText("Adapter  [  ]", 0, 1);
    VDP_drawText("Keyboard [  ]", 0, 2);

    bool adapter = NET_initialize();        // Find the adapter first
    showStatus(1, adapter, "XX");
    if(!adapter)
    {
        VDP_drawText("Adapter not present", 0, 3);
        while(1) { SYS_doVBlankProcess(); }
    }
    showStatus(2, NET_detectKB(), "--");    // Then the keyboard

    VDP_drawText("IP Address:", 0, 3); NET_printIP(12, 3);
    VDP_drawText("MAC:", 0, 4);        NET_printMAC(5, 4);
    VDP_drawText("----------------------------------------", 0, 5);
    VDP_drawText("NETWORK  (A pause, B resume, C hang up)", 0, 6);
    VDP_drawText("----------------------------------------", 0, 7);

    VDP_drawText("KB INPUT - (EX: EXAMPLE.COM:80, ENTER)", 0, 20);
    VDP_drawText("----------------------------------------", 0, 21);

    NET_enableInterrupt(); // From here the level 2 interrupt fills the software receive buffer

    fetch("example.com:80");

//------------------------------------------------------------------
// MAIN LOOP
//------------------------------------------------------------------

    while(1)
    {
        char key = NET_readKey(); // Poll the PS/2 keyboard once a frame, right after VBlank
        if(key == '\n' && len)
        {
            u16 i = 0;
            while(i < len && site[i] != ':') { i++; } // Did you type a port?
            strcpy(site + len, i < len ? "" : ":80"); // If not, web sites use port 80
            len = 0; print(&keys, '\n'); fetch(site);
        }
        else if(key == '\b' && len) { len--; VDP_drawText(" ", --keys.x, 25); } // Erase the last key
        else if(key >= ' ' && len < 36) { site[len++] = key; print(&keys, key); }

        showStatus(2, NET_detectKB(), "--");    // Still plugged in?

        buttons = JOY_readJoypad(JOY_1);
        if(buttons & BUTTON_A && buttons_prev == 0x00) { NET_flowControlOn(); }  // adapter holds data in its 2K buffer
        if(buttons & BUTTON_B && buttons_prev == 0x00) { NET_flowControlOff(); } // adapter sends the held data
        if(buttons & BUTTON_C && buttons_prev == 0x00) { hangUp(); printText(&net, "\nDisconnected\n"); } // Drop the connection
        buttons_prev = buttons;

        while(NET_dataAvailable()) { print(&net, NET_readBuffer()); } // Show what arrives
        SYS_doVBlankProcess();
    }

//------------------------------------------------------------------
    return(0);
}

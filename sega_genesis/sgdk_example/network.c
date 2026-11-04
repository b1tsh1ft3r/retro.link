#include <genesis.h>
#include "network.h"

char str[8];                            // For data conversions and display (debug mostly)

volatile u16 readIndex, writeIndex;     // Receive buffer Read/Write indexes
char receive_buffer[BUFFER_SIZE];       // Our circular network receive buffer

//****************************************************************
// Initialize Network Adapter
//****************************************************************
// Sets up controller port 2 for serial and detects the adapter.
// Returns TRUE or FALSE boolean value. The xPico takes about 4-5
// seconds to start after power on, so this waits up to 8 seconds.
bool NET_initialize()
{
    JOY_setSupport(PORT_2, JOY_SUPPORT_OFF); // Stop SGDK reading port 2 as a joypad

    PORT2_DATA  = 0x00;     // Pin 3 low lets data flow. Pin 7 low blocks inbound connections
    PORT2_CTRL  = 0x54;     // Pins 3, 6 and 7 are outputs. The rest are inputs
    SERIAL_CTRL = 0x30;     // 4800 Baud 8-N-1, serial in and out on, RX interrupt off

    for(int i=0; i<8; i++)  // Ask once a second until the adapter answers
    {
        NET_flushBuffers();
        NET_sendMessage("C0.0.0.0/0\n");    // Ask for the monitor prompt "0>"
        u32 timeout = getTick() + TICKPERSECOND;
        while(getTick() < timeout)
        {
            NET_update();
            if(NET_dataAvailable() && NET_readBuffer() == '>')
            {
                NET_exitMonitorMode();
                return TRUE;
            }
        }
    }
    return FALSE;
}

//****************************************************************
// Flush Buffer
//****************************************************************
void NET_flushBuffers(void)
{
    SYS_disableInts();      // Keep the receive interrupt out while we reset
    while(NET_RXReady()) { NET_readByte(); } // Empty the port
    readIndex  = 0;         // reset read index for software receive buffer
    writeIndex = 0;         // reset write index for software receive buffer
    SYS_enableInts();
    return;
}

//****************************************************************
// Write Buffer
//****************************************************************
// Stores a byte in the software receive buffer
void NET_writeBuffer(u8 data)
{
    receive_buffer[writeIndex++] = data;
    if (writeIndex == BUFFER_SIZE) { writeIndex = 0; }
}

//****************************************************************
// Read Buffer
//****************************************************************
// Returns a byte from the software receive buffer
u8 NET_readBuffer(void)
{
    u8 data = receive_buffer[readIndex++];
    if (readIndex == BUFFER_SIZE) { readIndex = 0; }
    return data;
}

//****************************************************************
// Data Available
//****************************************************************
// Returns boolean value on data presence in the software receive buffer
u8 NET_dataAvailable(void)
{
    return writeIndex != readIndex;
}

//****************************************************************
// Bytes Available
//****************************************************************
// Return the number of bytes currently in the software recieve buffer
u16 NET_bytesAvailable(void)
{
    return (writeIndex + BUFFER_SIZE - readIndex) % BUFFER_SIZE;
}

//****************************************************************
// Network TX Ready
//****************************************************************
// Returns boolean value if the port is clear to send data
bool NET_TXReady()
{
    return !(SERIAL_CTRL & 0x01);
}

//****************************************************************
// Network RX Ready
//****************************************************************
// Returns boolean value if there is a byte waiting in the port
bool NET_RXReady()
{
    return (SERIAL_CTRL & 0x02);
}

//****************************************************************
// Network Send
//****************************************************************
// Sends a single byte
void NET_sendByte(u8 data)
{
    while(!NET_TXReady());
    SERIAL_TX = data;
    return;
}

//****************************************************************
// Network Read Byte
//****************************************************************
// Returns a single byte from the port directly
u8 NET_readByte(void)
{
    return SERIAL_RX;
}

//****************************************************************
// Network Wait Byte                                            **
//****************************************************************
// Waits for the next byte and returns it from the software receive
// buffer. Works with the receive interrupt on or off.
u8 NET_waitByte(void)
{
    while(!NET_dataAvailable()) { NET_update(); }
    return NET_readBuffer();
}

//****************************************************************
// Network Send Message                                         **
//****************************************************************
// Sends a string of ascii
void NET_sendMessage(char *str)
{
    int i=0;
    while (str[i] != '\0') { NET_sendByte(str[i]); i++; }
}

//****************************************************************
// Network Update                                               **
//****************************************************************
// Moves waiting bytes from the port into the software receive
// buffer. The port holds 1 byte and a new one arrives every 2ms,
// so call this often or use NET_enableInterrupt() instead.
void NET_update(void)
{
    SYS_disableInts();      // Keep the receive interrupt out while we read
    while(NET_RXReady())
    {
        u8 byte = NET_readByte();
        NET_writeBuffer(byte);
    }
    SYS_enableInts();
}

//****************************************************************
// Receive Interrupt                                            **
//****************************************************************
// Level 2 interrupt handler. Stores each byte that arrives in the
// software receive buffer.
static void NET_interrupt(void)
{
    while(NET_RXReady())
    {
        u8 byte = NET_readByte();
        NET_writeBuffer(byte);
    }
}

//****************************************************************
// Enable Receive Interrupt                                     **
//****************************************************************
// Each byte that arrives triggers a level 2 interrupt, which stores
// it in the software receive buffer for you.
void NET_enableInterrupt(void)
{
    SYS_setExtIntCallback(NET_interrupt);   // Our level 2 handler
    VDP_setExtInterrupt(TRUE);              // VDP passes external interrupts to the 68000
    SERIAL_CTRL = 0x38;                     // 4800 Baud 8-N-1, serial in and out on, RX interrupt on
    SYS_setInterruptMaskLevel(1);           // Allow level 2. SGDK default is 3, which blocks it
    return;
}

//****************************************************************
// Disable Receive Interrupt                                    **
//****************************************************************
// Back to polling the port with NET_update() or NET_readByte()
void NET_disableInterrupt(void)
{
    SERIAL_CTRL = 0x30;                     // RX interrupt off
    SYS_setInterruptMaskLevel(3);           // SGDK default
    VDP_setExtInterrupt(FALSE);
    SYS_setExtIntCallback(NULL);
    return;
}

//****************************************************************
// Flow Control On                                              **
//****************************************************************
// Pin 3 high. The xPico stops sending and holds incoming data in
// its 2K buffer. Use it when your buffer is full or the console is
// busy, like during long DMA transfers.
void NET_flowControlOn(void)
{
    PORT2_DATA |= 0x04;
    return;
}

//****************************************************************
// Flow Control Off                                             **
//****************************************************************
// Pin 3 low. The xPico sends again, starting with any held data.
void NET_flowControlOff(void)
{
    PORT2_DATA &= ~0x04;
    return;
}

//****************************************************************
// Enter Monitor Mode                                           **
//****************************************************************
void NET_enterMonitorMode(void)
{
    NET_flushBuffers();
    NET_sendMessage("C0.0.0.0/0\n");
    while (NET_waitByte() != '>') {}
}

//****************************************************************
// Exit Monitor Mode                                            **
//****************************************************************
void NET_exitMonitorMode(void)
{
    NET_sendMessage("QU\r");
    while (NET_waitByte() != '\n') {} // Wait for the end of the "QU" echo
    NET_flushBuffers();
}

//****************************************************************
// Allow Connections                                            **
//****************************************************************
// Allows inbound TCP connections on port 5364 (pin 7 high)
void NET_allowConnections(void)
{
    PORT2_DATA |= 0x40;
    return;
}

//****************************************************************
// Block Connections                                            **
//****************************************************************
// Drops any current connection and blocks future inbound connections (pin 7 low)
void NET_BlockConnections(void)
{
    PORT2_DATA &= ~0x40;
    return;
}

//****************************************************************
// Reboot Adapter                                               **
//****************************************************************
// Reboots adapter and waits until its back up before returning
void NET_resetAdapter(void)
{
    NET_enterMonitorMode();
    NET_sendMessage("RS\r");
    while (NET_waitByte() != 'D') {} // Sent when it is back up
    return;
}

//****************************************************************
// Connect                                                      **
//****************************************************************
// Make an outbound TCP connection to supplied DNS/IP
bool NET_connect(char *str)
{
    NET_sendByte('C');NET_sendMessage(str); NET_sendByte(0x0A);

    u8 byte = NET_waitByte();
    switch(byte)
    {
        case 'C': // Connected
            return TRUE;
        case 'N': // Host Unreachable
            NET_flushBuffers();
            return FALSE;
        default:
            NET_flushBuffers();
            return FALSE;
    }
}

//****************************************************************
// Print IP                                                     **
//****************************************************************
// Prints IP address of the adapter
void NET_printIP(int x, int y)
{
    NET_enterMonitorMode();
    NET_sendMessage("NC\r"); // Send command to get network information
    while(1)
    {
        u8 byte = NET_waitByte();
        if(byte == 'G') { break; }
        if ((byte >= '0' && byte <= '9') || byte == '.' || byte == '1')
        {
            sprintf(str, "%c", byte); VDP_drawText(str, x, y); x++;
        }
    }
    while (NET_waitByte() != '>') {} // Skip the rest of the reply
    NET_exitMonitorMode();
}

//****************************************************************
// Print MAC Address                                            **
//****************************************************************
// Prints MAC address of the adapter
void NET_printMAC(int x, int y)
{
    NET_enterMonitorMode();
    NET_sendMessage("GM\r");
    for(int i=1; i<22;i++)
    {
        u8 byte = NET_waitByte();
        if(i>4) { sprintf(str, "%c", byte); VDP_drawText(str, x, y); x++; }
    }
    while (NET_waitByte() != '>') {} // Skip the rest of the reply
    NET_exitMonitorMode();
}

//****************************************************************
// Ping IP Address                                              **
//****************************************************************
// Only accepts an IP address to ping
void NET_pingIP(int x, int y, int ping_count, char *ip)
{
    int ping_counter = 0;
    int byte_count = 0;
    int tmp = x;

    VDP_drawText("Pinging:", x, y); x+=8;

    NET_enterMonitorMode();
    NET_sendMessage("PI ");
    NET_sendMessage(ip);
    NET_sendMessage("\r");

    while(1)
    {
        u8 byte = NET_waitByte();
        byte_count++;
        if(byte_count > 2)
        {
            sprintf(str, "%c", byte);
            VDP_drawText(str, x, y); x++;
            if(byte == '\n') { x=tmp; y++; ping_counter++; }
            if(ping_counter >= ping_count+1) { break; }
        }
    }
    NET_sendByte(0x0D);              // Any byte stops the ping
    while (NET_waitByte() != '>') {} // Wait for the prompt
    NET_exitMonitorMode();
}

//****************************************************************
// Keyboard Clock Wait                                          **
//****************************************************************
// Waits for the PS/2 clock (pin 1) to reach a level. Returns FALSE
// if it takes more than the given number of looks (about 6us each).
static bool NET_waitClock(u8 level, u16 looks)
{
    while((PORT2_DATA & 0x01) != level) { if(--looks == 0) { return FALSE; } }
    return TRUE;
}

//****************************************************************
// Detect Keyboard                                              **
//****************************************************************
// Returns TRUE when a PS/2 keyboard is plugged in. Let go, its clock
// rises in a few us. With nothing plugged in it floats low.
bool NET_detectKB(void)
{
    PORT2_CTRL &= ~0x01;                        // Let go of CLK
    bool found = NET_waitClock(1, 20);          // Did it rise?
    PORT2_CTRL |= 0x01;                         // Hold it again
    return found;
}

//****************************************************************
// Read Scan Code                                               **
//****************************************************************
// Returns the next byte from the PS/2 keyboard, or 0 if none.
// Between calls the keyboard is held (clock low) and keeps its keys.
// Call once a frame right after SYS_doVBlankProcess(). Once let go
// a keyboard can take a few ms to start, so that wait runs with
// interrupts on. They are off only for its bits, about 1ms, less
// than one 4800 baud byte.
u8 NET_readScanCode(void)
{
    u16 bits = 0;
    PORT2_CTRL &= ~0x03;                        // Let go of CLK and DATA so the keyboard can send
    if(NET_waitClock(1, 20) && NET_waitClock(0, 800)) // Clock up, then a start bit within about 5ms?
    {
        SYS_disableInts();                      // Nothing may cut into the bits
        for(int i=0; i<10; i++)                 // 8 data bits (LSB first), parity, stop
        {
            if(!NET_waitClock(1, 20) || !NET_waitClock(0, 20)) { bits = 0; break; } // Clock stopped
            bits = (bits >> 1) | ((PORT2_DATA & 0x02) << 8);   // DATA into bit 9
        }
        SYS_enableInts();
    }
    PORT2_DATA = (PORT2_DATA & ~0x01) | 0x02;   // CLK low, DATA high
    PORT2_CTRL |= 0x03;                         // Both outputs. The keyboard holds its keys
    return bits & 0xFF;
}

//****************************************************************
// Read Key                                                     **
//****************************************************************
// Returns the ASCII key pressed, or 0 if none. Letters are upper
// case, Enter is '\n' and Backspace is '\b'. Shift gives the
// symbols in shifted[]. Releases are skipped.
static const char keymap[0x80] =                // PS/2 scan code (set 2) to ASCII
{
    [0x1C]='A', [0x32]='B', [0x21]='C', [0x23]='D', [0x24]='E', [0x2B]='F', [0x34]='G',
    [0x33]='H', [0x43]='I', [0x3B]='J', [0x42]='K', [0x4B]='L', [0x3A]='M', [0x31]='N',
    [0x44]='O', [0x4D]='P', [0x15]='Q', [0x2D]='R', [0x1B]='S', [0x2C]='T', [0x3C]='U',
    [0x2A]='V', [0x1D]='W', [0x22]='X', [0x35]='Y', [0x1A]='Z',
    [0x45]='0', [0x16]='1', [0x1E]='2', [0x26]='3', [0x25]='4',
    [0x2E]='5', [0x36]='6', [0x3D]='7', [0x3E]='8', [0x46]='9',
    [0x29]=' ', [0x41]=',', [0x49]='.', [0x4A]='/', [0x4C]=';', [0x52]='\'',
    [0x4E]='-', [0x55]='=', [0x54]='[', [0x5B]=']', [0x5D]='\\',
    [0x5A]='\n', [0x66]='\b'
};

static const char shifted[0x80] =               // The same keys with Shift held
{
    [0x45]=')', [0x16]='!', [0x1E]='@', [0x26]='#', [0x25]='$',
    [0x2E]='%', [0x36]='^', [0x3D]='&', [0x3E]='*', [0x46]='(',
    [0x41]='<', [0x49]='>', [0x4A]='?', [0x4C]=':', [0x52]='"',
    [0x4E]='_', [0x55]='+', [0x54]='{', [0x5B]='}', [0x5D]='|'
};

char NET_readKey(void)
{
    static bool release, shift;                 // release is set after $F0. The next code is a key release
    u8 code = NET_readScanCode();
    if(code == 0xF0) { release = TRUE; return 0; }
    if(code == 0x12 || code == 0x59) { shift = !release; release = FALSE; return 0; } // Left or right Shift
    if(release && code) { release = FALSE; return 0; }
    if(code >= 0x80) { return 0; }
    return (shift && shifted[code]) ? shifted[code] : keymap[code];
}
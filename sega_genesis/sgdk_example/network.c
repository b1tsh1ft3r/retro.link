#include <genesis.h>
#include "network.h"

//****************************************************************
// Initialize Network Adapter
//****************************************************************
// Sets boolean value cart_present to TRUE/FALSE
void NET_initialize()
{
    UART_LCR = 0x80;                // Setup registers so we can read device ID from UART
    UART_DLM = 0x00;                // to detect presence of hardware
    UART_DLL = 0x00;                // ..

    cart_present = (UART_DVID == 0x10);

    if (cart_present) // Init UART to 921600 Baud 8-N-1 no flow control
    {
        UART_LCR = 0x83;
        UART_DLM = 0x00;
        UART_DLL = 0x01;
        UART_LCR = 0x03;
        UART_MCR = 0x00;
        UART_FCR = 0x07;
        UART_IER = 0x00;
    }
}

//****************************************************************
// Flush Buffer
//****************************************************************
void NET_flushBuffers(void)
{
    int i;
    readIndex  = 0;         // reset read index for software receive buffer
    writeIndex = 0;         // reset write index for software receive buffer
    UART_FCR   = 0x07;      // Reset UART TX/RX hardware fifos
    for(i=0; i<BUFFER_SIZE; i++) { receive_buffer[i] = 0xFF; } // Software buffer
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
    return (writeIndex - readIndex);
}

//****************************************************************
// Network TX Ready
//****************************************************************
// Returns boolean value if transmit fifo is clear to send data
bool NET_TXReady() 
{
    return (UART_LSR & 0x20);
}

//****************************************************************
// Network RX Ready
//****************************************************************
// Returns boolean value if there is data in hardware receive fifo
bool NET_RXReady() 
{
    return (UART_LSR & 0x01);
}

//****************************************************************
// Network Send
//****************************************************************
// Sends a single byte
void NET_sendByte(u8 data) 
{
    while(!NET_TXReady());
    UART_RHR = data;
    return;
}

//****************************************************************
// Network Read Byte
//****************************************************************
// Returns a single byte from the hardware UART receive buffer directly
u8 NET_readByte(void)
{
    return UART_RHR;
}

//****************************************************************
// Network Send Message                                         **
//****************************************************************
// Sends a string of ascii 
void NET_sendMessage(char *str)
{
  int i=0;
  int length=0; 
  length = strlen(str);
  char data[128];
  strncpy(data, str, length);
  data[length] = '\0';
  while (i<length) { NET_sendByte(data[i]); i++; }
}

//****************************************************************
// Enter Monitor Mode                                           **
//****************************************************************
void NET_enterMonitorMode(void)
{
    NET_flushBuffers();
    NET_sendMessage("C0.0.0.0/0\n");
    while (!NET_RXReady() || NET_readByte() != '>') {}
}

//****************************************************************
// Exit Monitor Mode                                            **
//****************************************************************
void NET_exitMonitorMode(void)
{
    NET_sendMessage("QU\n");
    while (!NET_RXReady() || NET_readByte() != '>') {}
    NET_flushBuffers();
}

//****************************************************************
// Allow Connections                                            **
//****************************************************************
// Allows inbound TCP connections on port 5364
void NET_allowConnections(void)
{
    UART_MCR = 0x08;
    while(UART_MCR != 0x08);
    return;
}

//****************************************************************
// Block Connections                                            **
//****************************************************************
// Drops any current connection and blocks future inbound connections
void NET_BlockConnections(void)
{
    UART_MCR = 0x00;
    while(UART_MCR != 0x00);
    return;
}

//****************************************************************
// Reboot Adapter                                               **
//****************************************************************
// Reboots Xpico and waits until its back up before returning
void NET_resetAdapter(void)
{
    NET_enterMonitorMode();
    NET_sendMessage("RS\n");
    while(1)
    { 
        while(!NET_RXReady());
        u8 byte = NET_readByte();
        if(byte == 'D') { break; }
    }
    return;
}

//****************************************************************
// Connect                                                      **
//****************************************************************
// Make an outbound TCP connection to supplied DNS/IP
void NET_connect(int x, int y, char *str)
{
    NET_sendByte('C');
    NET_sendMessage(str);
    NET_sendByte(0x0A);

    while(!NET_RXReady());
    u8 byte = NET_readByte();
    switch(byte)
    {
        case 'C': // Connected
            VDP_drawText("Connected:", x, y); VDP_drawText(str, x+11, y);
            break;
        case 'N': // Host Unreachable
            VDP_drawText("Error: Host unreachable", x, y);
            NET_flushBuffers();
            break;
    }
}

//****************************************************************
// Print IP                                                     **
//****************************************************************
// Prints IP address of cartridge adapter
void NET_printIP(int x, int y)
{
    NET_enterMonitorMode();
    NET_sendMessage("NC\n"); // Send command to get network information
    while(1)
    {
        while(!NET_RXReady());
        u8 byte = NET_readByte();
        if(byte == 'G') { break; }
        if ((byte >= '0' && byte <= '9') || byte == '.' || byte == '1')
        { 
            sprintf(str, "%c", byte); VDP_drawText(str, x, y); x++;
        }
    }
    NET_exitMonitorMode();
}

//****************************************************************
// Print MAC Address                                            **
//****************************************************************
// Prints MAC address of cartridge hardware (Xpico)
void NET_printMAC(int x, int y)
{
    NET_enterMonitorMode();
    NET_sendMessage("GM\n");
    for(int i=1; i<22;i++)
    {
        while(!NET_RXReady());
        u8 byte = NET_readByte();
        if(i>4) { sprintf(str, "%c", byte); VDP_drawText(str, x, y); x++; }        
    }
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
    NET_sendMessage("\n");

    while(1)
    {
        while(!NET_RXReady());
        u8 byte = NET_readByte();
        byte_count++;
        if(byte_count > 2)
        {
            sprintf(str, "%c", byte);
            VDP_drawText(str, x, y); x++;
            if(byte == '\n') { x=tmp; y++; ping_counter++; }
            if(ping_counter >= ping_count+1) { break; }
        }
    }
    NET_exitMonitorMode();
}


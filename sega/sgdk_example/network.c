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
    readIndex  = 0;         // reset read index for software receive buffer
    writeIndex = 0;         // reset write index for software receive buffer
    UART_FCR   = 0x07;      // Reset UART TX/RX hardware fifos
    for(int i=0; i<BUFFER_SIZE; i++) { receive_buffer[i] = 0xFF; } // Software buffer
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
// Read Buffer
//****************************************************************
// Returns a single byte from the hardware UART receive buffer directly
u8 NET_readByte(void)
{
    u8 data = UART_RHR;
    return data;
}

//****************************************************************
// Network Send Message                                         **
//****************************************************************
// Sends a string of data
void NET_sendMessage(char *str)
{
  int i=0;
  int length = strlen(str);
  char data[length+1];
  strcpy(data,str);
  while (i<length) { NET_sendByte(data[i]); i++; }  
}

//****************************************************************
// Print Local IP                                               **
//****************************************************************
void NET_printLocalIP(int x, int y)
{
    int i;

    NET_flushBuffers();      // Flush hardware fifos and software buffer

    NET_sendMessage("C0.0.0.0/0\n"); // Send command to connect locally to get into monitor mode
    while (!NET_RXReady() || NET_readByte() != '>') {} // Wait forever until we get '>' char to signify we're in monitor mode

    NET_sendMessage("NC\n"); // Send command to get network information
    waitMs(25);              // Wait for echo of command to show up in fifo (more than enough time)
    NET_readByte();          // eat the bytes
    NET_readByte();          // 

    while(1)
    {
        if (NET_RXReady()) // Get response but cheaply filter out IP address from response
        {   
            u8 response = NET_readByte();
            if(response == 'G') { i=0; break; } // G char in 'GW' ?
            if(response == 'I') { i=1; }        // I char in 'IP' ?
            if(i == 1) { char str[1]; sprintf(str, "%c", response); VDP_drawText(str, x, y); x+=1; }
        }       
    }

    NET_sendMessage("QU\n"); // Quit monitor mode back to normal operation
    waitMs(25);              // Wait for echo of command to show up in fifo (more than enough time)
    NET_readByte();          // eat the bytes
    NET_readByte();          // 

    while (!NET_RXReady() || NET_readByte() != '>') {} // Wait forever for '>' char to signify we're done
}


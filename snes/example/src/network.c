#include <snes.h>
#include "network.h"

//****************************************************************
// Initialize Network Adapter
//****************************************************************
// Sets boolean value cart_present to TRUE/FALSE
void NET_initialize()
{
    *(u8 *)UART_LCR = 0x80;                // Setup registers so we can read device ID from UART
    *(u8 *)UART_DLM = 0x00;                // to detect presence of hardware
    *(u8 *)UART_DLL = 0x00;                // ..

    cart_present = (*(u8 *)UART_DVID == 0x10);

    if(*(u8 *)UART_DVID == 0x10); // Init UART to 921600 Baud 8-N-1 no flow control
    {
        *(u8 *)UART_LCR = 0x83;
        *(u8 *)UART_DLM = 0x00;
        *(u8 *)UART_DLL = 0x01;
        *(u8 *)UART_LCR = 0x03;
        *(u8 *)UART_MCR = 0x00;
        *(u8 *)UART_FCR = 0x07;
        *(u8 *)UART_IER = 0x00;
    }
    return;
}

//****************************************************************
// Flush Buffer
//****************************************************************
void NET_flushBuffers(void)
{
    int i;
    readIndex  = 0;         // reset read index for software receive buffer
    writeIndex = 0;         // reset write index for software receive buffer
    *(u8 *)UART_FCR = 0x07; // Reset UART TX/RX hardware fifos
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
    return;
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
    *(u8 *)UART_RHR = data;
    return;
}

//****************************************************************
// Read Buffer
//****************************************************************
// Returns a single byte from the hardware UART receive buffer directly
u8 NET_readByte(void)
{
    return *(u8 *)UART_RHR;
}

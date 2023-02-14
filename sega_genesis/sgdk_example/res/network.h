#include <types.h>

#define UART_BASE   0xA130C1

#define UART_RHR    (*((volatile uint8_t*)(UART_BASE+0)))  // Receive holding register
#define UART_THR    (*((volatile uint8_t*)(UART_BASE+0)))  // Transmit holding register
#define UART_IER    (*((volatile uint8_t*)(UART_BASE+2)))  // Interrupt enable register
#define UART_FCR    (*((volatile uint8_t*)(UART_BASE+4)))  // FIFO control register
#define UART_LCR    (*((volatile uint8_t*)(UART_BASE+6)))  // Line control register
#define UART_MCR    (*((volatile uint8_t*)(UART_BASE+8)))  // Modem control register
#define UART_LSR    (*((volatile uint8_t*)(UART_BASE+10))) // Line status register
#define UART_DLL    (*((volatile uint8_t*)(UART_BASE+0)))  // Divisor latch LSB. Acessed only when LCR[7] = 1
#define UART_DLM    (*((volatile uint8_t*)(UART_BASE+2)))  // Divisor latch MSB. Acessed only when LCR[7] = 1
#define UART_DVID   (*((volatile uint8_t*)(UART_BASE+2)))  // Device ID 

#define BUFFER_SIZE     64          // Size of software receive buffer in bytes.
                                    // UART Send/Receive hardware buffers are 128 Bytes each

char str[8];                        // For data conversions and display (debug mostly)
bool cart_present;                  // Flag indicating presense of hardware

u16  readIndex, writeIndex;         // Receive buffer Read/Write indexes
char receive_buffer[BUFFER_SIZE];   // Our circular network receive buffer

u8   NET_readByte(void);
u8   NET_readBuffer(void);
u8   NET_dataAvailable(void);
u16  NET_bytesAvailable(void);
bool NET_TXReady();
bool NET_RXReady();
void NET_sendByte(u8 data);
void NET_writeBuffer(u8 data);
void NET_sendMessage(char *str);
void NET_initialize(void);
void NET_flushBuffers(void);
void NET_enterMonitorMode(void);
void NET_exitMonitorMode(void);
void NET_allowConnections(void);
void NET_BlockConnections(void);
void NET_resetAdapter(void);
void NET_printIP(int x, int y);
void NET_printMAC(int x, int y);
void NET_connect(int x, int y, char *str);
void NET_pingIP(int x, int y, int ping_count, char *ip);

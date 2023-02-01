#define UART_RHR    0x20C1          // Receive holding register
#define UART_THR    0x20C1          // Transmit holding register
#define UART_IER    0x20C3          // Interrupt enable register
#define UART_FCR    0x20C5          // FIFO control register
#define UART_LCR    0x20C7          // Line control register
#define UART_MCR    0x20C9          // Modem control register
#define UART_LSR    0x20CB          // Line status register
#define UART_DLL    0x20C1          // Div latch low byte
#define UART_DLM    0x20C3          // Div latch high byte
#define UART_DVID   0x20C3          // Device ID
#define UART_OP2    0x20C9          // OP2

#define BUFFER_SIZE     64          // Size of software receive buffer in bytes.
                                    // UART Send/Receive hardware buffers are 128 Bytes each

char str[8];                        // For data conversions and display (debug mostly)
bool cart_present;                  // Flag indicating presense of hardware

u16  readIndex, writeIndex;         // Receive buffer Read/Write indexes
char receive_buffer[BUFFER_SIZE];   // Our circular network receive buffer

#define NET_TXReady() (UART_LSR & 0x20) // Returns TRUE if ok to send
#define NET_RXReady() (UART_LSR & 0x01) // Returns TRUE if a byte is available in the hardware receive buffer

u8   NET_readByte(void);
u8   NET_readBuffer(void);
u8   NET_dataAvailable(void);
u16  NET_bytesAvailable(void);
void NET_sendByte(u8 data);
void NET_writeBuffer(u8 data);
void NET_initialize(void);
void NET_flushBuffers(void);
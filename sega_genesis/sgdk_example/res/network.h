#include <types.h>

#define PORT2_DATA  (*((volatile uint8_t*)0xA10005))  // Port 2 data register (pin levels)
#define PORT2_CTRL  (*((volatile uint8_t*)0xA1000B))  // Port 2 control register (pin directions)
#define SERIAL_TX   (*((volatile uint8_t*)0xA10015))  // Port 2 serial transmit register
#define SERIAL_RX   (*((volatile uint8_t*)0xA10017))  // Port 2 serial receive register
#define SERIAL_CTRL (*((volatile uint8_t*)0xA10019))  // Port 2 serial control register

// PORT2_DATA and PORT2_CTRL bits used by the adapter
//  Bit 0 = Pin 1 (CLK)  PS/2 keyboard clock. Held low between reads
//  Bit 1 = Pin 2 (DATA) PS/2 keyboard data
//  Bit 2 = Pin 3 (CTS)  Output  High = xPico holds data (flow control)
//  Bit 3 = Pin 4 (RTS)  Input
//  Bit 4 = Pin 6 (TX)   Output  Console to adapter
//  Bit 5 = Pin 9 (RX)   Input   adapter to console
//  Bit 6 = Pin 7 (TH)   Output  High = allow inbound connections

// SERIAL_CTRL bits
//  Bit 7-6 = Baud rate. 00 = 4800, the only rate the adapter uses
//  Bit 5   = Serial in on pin 9
//  Bit 4   = Serial out on pin 6
//  Bit 3   = RX interrupt enable (level 2)
//  Bit 2   = RX error   (read only)
//  Bit 1   = RX ready   (read only)
//  Bit 0   = TX full    (read only)

#define BUFFER_SIZE     64                  // Size of software receive buffer in bytes.
                                            // The port holds 1 byte. The xPico holds 2K while flow control is on

extern char str[8];                         // For data conversions and display (debug mostly)

extern volatile u16 readIndex, writeIndex;  // Receive buffer Read/Write indexes
extern char receive_buffer[BUFFER_SIZE];    // Our circular network receive buffer

u8   NET_readByte(void);
u8   NET_readBuffer(void);
u8   NET_waitByte(void);
u8   NET_dataAvailable(void);
u16  NET_bytesAvailable(void);
u8   NET_readScanCode(void);
char NET_readKey(void);

bool NET_connect(char *str);
bool NET_initialize(void);
bool NET_detectKB(void);
bool NET_TXReady();
bool NET_RXReady();

void NET_sendByte(u8 data);
void NET_sendMessage(char *str);

void NET_writeBuffer(u8 data);
void NET_flushBuffers(void);

void NET_enableInterrupt(void);
void NET_disableInterrupt(void);
void NET_flowControlOn(void);
void NET_flowControlOff(void);

void NET_enterMonitorMode(void);
void NET_exitMonitorMode(void);
void NET_allowConnections(void);
void NET_BlockConnections(void);
void NET_resetAdapter(void);
void NET_update(void);

void NET_printIP(int x, int y);
void NET_printMAC(int x, int y);
void NET_pingIP(int x, int y, int ping_count, char *ip);
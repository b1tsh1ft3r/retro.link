# Retro.Link

Retro.Link is an Ethernet cartridge adapter for the Sega Genesis video game console. It facilitates the use of networking functions in homebrew and existing games, but only if the software has been programmed to interact with the hardware.

# Hardware Details
The adapter is built using an XR16C850 UART chip and a Lantronix XPICO module. These components provide the adapter with 128-byte hardware send and receive buffers, allowing for efficient data transmission at 921600 baud.

# Key Characteristics
 * The adapter is pre-configured to make TCP connections to any domain or IP address, but is set to listen specifically on port 5364 for incoming connections.

* The user has the ability to drop, deny, or allow incoming connections by writing a byte to a designated register.

* By default, all incoming TCP connections are blocked upon boot, but this setting can be changed.

* The adapter's hardware offloads resource-intensive network functions, freeing up the console's processing power.

* The UART maps in the range of $A130C1-$A130CF on the Sega Genesis.

# Example Programs
We've provided some example programs written in C for SGDK and 68000 Assembly to assist developers in understanding the adapter's functionality. These examples are intended to serve as a starting point for further programming efforts.

# Support
For support or additional information, a Discord community dedicated to Retro.Link is available.

![Discord Banner 2](https://discordapp.com/api/guilds/783087214162346024/widget.png?style=banner2)

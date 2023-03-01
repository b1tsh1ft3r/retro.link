# Retro.Link

Retro.Link is an Ethernet cartridge adapter. It facilitates the use of networking functions in homebrew and existing games, but only if the software has been programmed to interact with the hardware. Currently the Sega Genesis is supported officially but the Super Nintendo is being investigated currently.

# What can this be used for?
The adapter can be used for a wide range of things including but not limited to:
 * Head to head multiplayer gaming (2-Players)
 * Large multiplayer games (3+ Players using a centralized server)
 * Chat/Messaging
 * High score upload / Leaderboards / Achievements
 * Updates for games
 * Downloadable content for games
 * Upload/Download of save files for games.
 * Sending debug data to TCP Endpoint on LAN/WAN

# Hardware Details
The adapter is built using an [XR16C850](https://www.mouser.com/datasheet/2/146/16c850_231_080905-1889024.pdf) UART chip and a Lantronix [Xpico](https://cdn.lantronix.com/wp-content/uploads/pdf/xPico_UG.pdf) module. These components provide the adapter with 128-byte hardware send and receive buffers, allowing for efficient data transmission at 921600 baud.

# Key Characteristics
* The device can open a direct byte stream with a TCP endpoint. You can define your own protocol, encryption or packet format that fits your needs and TCP will ensure the data arrives in order.

* The adapter is configured to be able to make a single TCP connection by default to any domain or IP address. The adapter is set to listen specifically on port 5364 for a single incoming conection.

* By default, all incoming TCP connections are blocked upon bootup and during runtime until reconfigured via a designated register.

* The user has the ability to drop, deny, or allow incoming connections by writing a byte to a designated register.

* The adapter's hardware offloads resource-intensive network functions, freeing up the console to do other tasks.

* The UART maps in the memory range $A130C1-$A130CF on the Sega Genesis and it can transfer about 1536 Bytes/frame.

* The UART will likely map in the memory range $21C0-$21CF on the Super Nintendo. 

# Example Programs
We've provided some examples in C and assembly to assist developers in understanding how to use the adapter. These examples are intended to serve as a starting point for further efforts.

* Sega Genesis - Example program written in [C](https://github.com/b1tsh1ft3r/retro.link/tree/main/sega_genesis/sgdk_example) for [SGDK](https://github.com/Stephane-D/SGDK) and [68000 Assembly](https://github.com/b1tsh1ft3r/retro.link/tree/main/sega_genesis/asm_example).

* Super Nintendo - Example program written in [C](https://github.com/b1tsh1ft3r/retro.link/tree/main/super_nintendo/c_example) for [PVSnesLib](https://github.com/alekmaul/pvsneslib) and [65816 Assembly](https://github.com/b1tsh1ft3r/retro.link/tree/main/super_nintendo/game_patches).

# Support
For support or additional information, or if you would like to help, join our [Discord](https://discord.gg/T9qUEtMRBA) server
or check out our [Twitter](https://twitter.com/retrolink10) for updates.



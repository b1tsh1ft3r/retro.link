# Retro.Link

Retro.Link is an Ethernet cartridge adapter. It facilitates the use of networking functions in homebrew and existing games, but only if the software has been programmed to interact with the hardware. Currently the Sega Genesis is supported officially but the Super Nintendo is being investigated currently.

# Hardware Details
The adapter is built using an XR16C850 UART chip and a Lantronix XPICO module. These components provide the adapter with 128-byte hardware send and receive buffers, allowing for efficient data transmission at 921600 baud.

# Key Characteristics
* The adapter is configured to be able to make a single TCP connection to any domain or IP address. The adapter is set to listen specifically on port 5364 for a single incoming connection.

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
For support or additional information, or if you would like to help, join our [Discord](https://discord.gg/T9qUEtMRBA) server!

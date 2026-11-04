# Retro.Link

Retro.Link is a network adapter for the sega genesis video game console. It plugs into controller port 2 and facilitates the use of networking functions in homebrew and existing 
games, but only if the software has been programmed to interact with the hardware. 

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
The adapter is built using a Lantronix [Xpico](https://cdn.lantronix.com/wp-content/uploads/pdf/xPico_UG.pdf) module. It uses the built in serial capabilities of the console on controller port 2 at 4800 baud, the only rate the adapter uses and the fastest the console can communicate at. The xPico holds up to 2K of incoming data while flow control is on. The adapter also has a PS/2 keyboard port which can be used for keyboard input. Mouse input can also work if code is written to poll the mouse via the same PS/2 port. Only one PS/2 device can be plugged in at a time.

# Key Characteristics
* The device can open a direct byte stream with a TCP endpoint. You can define your own protocol, encryption or packet format that fits your needs and TCP will ensure the data arrives in order.

* The adapter is configured to be able to make a single TCP connection by default to any domain or IP address. The adapter is set to listen specifically on port 5364 for a single incoming
  conection.

* By default, all incoming TCP connections are blocked upon bootup and during runtime unless set otherwise.

* The user has the ability to drop/deny the connection, or allow incoming connections overall. via toggling a single bit.

* The adapter's hardware offloads resource-intensive network functions, freeing up the console to do other tasks.

* The device can be used on any controller port on the console. It can transfer about 8 Bytes/frame. Bytes can be polled or received with the level 2 interrupt into a ring buffer.

* Hardware flow control is available for high DMA parts of code which inhibit the level 2 interrupt receiver. Setting it makes the xPico hold incoming data in its 2K buffer until 
  it is cleared.

# Example Programs
We've provided some examples in C and assembly to assist developers in understanding how to use the adapter. These examples are intended to serve as a starting point for further efforts.
and showcase the basic functionality.

* Example program written in [C](https://github.com/b1tsh1ft3r/retro.link/tree/main/sega_genesis/sgdk_example) for [SGDK](https://github.com/Stephane-D/SGDK) 2.11 and [68000 Assembly](https://github.com/b1tsh1ft3r/retro.link/tree/main/sega_genesis/asm_example). Both do the same thing: find the adapter, show its IP and MAC address, fetch example.com, then fetch any site typed on the PS/2 keyboard. A pauses the incoming data with flow control, B resumes it and C disconnects.

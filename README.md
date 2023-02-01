# Retro.Link


Retro.Link is a pass through style ethernet cartridge adapter for the Sega Genesis 
that allows homebrew and existing games to have the ability to use networking functions
for multiplayer or other general uses. This assumes the software has code to interact
with the hardware.

# The Hardware
The hardware is built on an XR16C850 UART chip and Lantronix XPICO module. The UART has 128 
byte hardware send and receive buffers. The XR16C850 operates at 921600 Buad 8-N-1. This is 
the fastest serial speed we can communicate with the XPICO module, however the XR16C850 can 
transmit at faster speeds than the XPICO allows for. 

# General overview points

* The board is configured to make TCP connections to any domain or IP with port number,
  but listens explcitly on port 5364 for receiving an inbound connection.
  
* Drop/Deny or Allow inbound connections via writing a byte to a register. 
  
* Blocks all inbound TCP connections on boot until changed.

* All resource intensive network functions/operations are offloaded to the cartridge adapter hardware and UART/XPICO.

* UART Maps in $A130C1-$A130CF range on the Sega Genesis. 


# Example Code
An Example program written in C for SGDK is provided to show how to use the network
adapter. Additionaly an example written in 68000 Assembly is provided as well.
While both are very simple examples, it hopefully gives the foundation/framework
that other functions can be built on to exchange packets of information or parse data. 

# Contact

![Discord Banner 2](https://discordapp.com/api/guilds/783087214162346024/widget.png?style=banner2)

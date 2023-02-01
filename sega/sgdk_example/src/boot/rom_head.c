#include "genesis.h"

__attribute__((externally_visible))
const ROMHeader rom_header = {
    "SEGA GENESIS    ",
    "(C)SGDK 2023    ",
    "SGDK Networking Example                         ",
    "SGDK Networking Example                         ",
    "GM 00000000-00",
    0x000,
    "JD              ",
    0x00000000,
#if (ENABLE_BANK_SWITCH != 0)
    0x003FFFFF,
#else
    0x000FFFFF,
#endif
    0xE0FF0000,
    0xE0FFFFFF,
    "RA",
    0xF820,
    0x00200000,
    0x0020FFFF,
    "            ",
    "DEMONSTRATION PROGRAM                   ",
    "JUE             "
};

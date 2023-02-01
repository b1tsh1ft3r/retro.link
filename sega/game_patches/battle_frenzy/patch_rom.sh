#!/bin/bash
#wine asm68k.exe /p patch.asm, patched.bin
docker run -v $(pwd):/src -it rhargreaves/asm68k /p patch.asm, patched.bin
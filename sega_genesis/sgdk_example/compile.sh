#/bin/bash
rm -f out/rom.bin
docker run --rm -v $PWD:/m68k -t registry.gitlab.com/doragasu/docker-sgdk:v1.90 clean
docker run --rm -v $PWD:/m68k -t registry.gitlab.com/doragasu/docker-sgdk:v1.90

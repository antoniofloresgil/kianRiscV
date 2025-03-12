#!/bin/bash
DEVICE=${1:-85k}
make -f Makefile clean
make -f Makefile DEVICE=$DEVICE
fujprog -l 2 soc.bit 


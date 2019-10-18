#!/bin/bash

# This is: https://raw.githubusercontent.com/ArneDoe/ioBroker/libload/libloader.sh

LIB_NAME="instlib.sh"
LIB_URL="https://raw.githubusercontent.com/ArneDoe/ioBroker/libload/$LIB_NAME"
echo "curl -L $LIB_URL"
curl -L $LIB_URL > $LIB_NAME
if test -f ./$LIB_NAME; then echo "library found"; else echo "library not found"; exit -2; fi
if test -f ./$LIB_NAME; then source ./$LIB_NAME; else echo "library not found"; exit -2; fi
echo "library was loaded. GOOD."
# test one function of the library
RET=$(libtestfunction)
if [ "$RET" == "ok" ]; then echo "library works. GOOD"; else echo "library does not work. BAD"; fi

#
# Build the OpenVPN down-root plugin module.
#

# This directory is where we will look for openvpn-plugin.h
INCLUDE=-I../..

CC=gcc
MACOSX_DEPLOYMENT_TARGET=10.6
SDKROOT=/Developer/SDKs/MacOSX10.6.sdk

CC_FLAGS=-Wall -isysroot $(SDKROOT) -Os -mmacosx-version-min=$(MACOSX_DEPLOYMENT_TARGET) -arch i386

down-root.so : down-root.o
	$(CC) ${CC_FLAGS} -fPIC -bundle -Wl,-dylib_install_name,openvpn-down-root.so -o openvpn-down-root.so down-root.o -lc

down-root.o : down-root.c
	$(CC) ${CC_FLAGS} -fPIC -c ${INCLUDE} down-root.c

clean :
	rm -f *.o *.so

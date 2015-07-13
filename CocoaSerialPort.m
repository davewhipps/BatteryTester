//
//  CocoaSerialPort.m
//  Fuel Cell Monitors Combined
//
//  Created by Dave Sopchak on 11/10/05.
//  Copyright 2005 UltraCell Corporation. All rights reserved.
//

#import "CocoaSerialPort.h"


@implementation CocoaSerialPort

- (SerialPort *)getPortList
{
	return GetPorts();
}
- (void)findAndListModems
{
	FindAndListModems();
}
- (int)setAndOpenPort:(int)index
{
	return SetAndOpenPort(index);
}
- (int)readAndWrite:(short)writeLength :(short)readLength :(unsigned char *)sendPacket :(unsigned char *) receivePacket :(int)port
{
	int success = PortWrite(writeLength,sendPacket,port);
	
	if(success)
	{
		int theLength =  PortRead(readLength,receivePacket,port);
			return theLength;
	}
	else if(errno == 6)	// unplugged
	{
		NSBeep();
		return -errno;
	}
	else
		return -errno;
}

- (int)writePort:(short)length :(unsigned char *)packet :(int)port
{
	return PortWrite(length,packet,port);
}
- (int)readPort:(short)length :(unsigned char *)packet :(int)port
{
	return PortRead(length, packet, port);
}
- (void)closePort:(int)port
{
	CloseSerialPort(port);
	NSLog(@"CocoaSerialPort %d closed",port);
}

@end

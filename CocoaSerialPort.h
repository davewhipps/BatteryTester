//
//  CocoaSerialPort.h
//  Fuel Cell Monitors Combined
//
//  Created by Dave Sopchak on 11/10/05.
//  Copyright 2005 UltraCell Corporation. All rights reserved.
//

//#include "BatteryTester_Prefix.pch"


@interface CocoaSerialPort : NSObject 
{

}

- (SerialPort *)getPortList;
- (void)findAndListModems;
- (int)setAndOpenPort:(int)index;
- (int)readAndWrite:(short)writeLength :(short)readLength :(unsigned char *)sendPacket :(unsigned char *) receivePacket :(int)port;
- (int)writePort:(short)length :(unsigned char *)packet :(int)port;
- (int)readPort:(short)length :(unsigned char *)packet :(int)port;
- (void)closePort:(int)port;

@end

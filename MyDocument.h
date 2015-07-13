//
//  MyDocument.h
//  BatteryTester
//
//  Created by ted on 7/3/15.
//  Copyright 2015 __MyCompanyName__. All rights reserved.
//
#define WAITFORPAR 300000


#import <Cocoa/Cocoa.h>
#import "CocoaSerialPort.h"
#import "Graph.h"
#import "OldStep.h"

@interface MyDocument : NSDocument
{
	IBOutlet NSWindow *introSheet,*newSerialSheet, *serialNumberSheet, *timeSheet;
	IBOutlet Graph *graph;
	IBOutlet NSPopUpButton *newSerialMenu;
	IBOutlet NSButton *startButton, *loadButton, *okButton, *cancelButton;
	IBOutlet NSTextField *menuDescription;
	
	//battery tester
    NSTimer *theTimer;
	NSMutableArray *steps;
	IBOutlet NSTableView *theTable;
	IBOutlet NSTextField *statusText1, *statusText2, *ampsField, *voltsField, *wattsField;
	IBOutlet NSTextField *commandField, *responseField;
	NSString *serialPortString;
	NSOpenPanel *open;
	
	int currentStep, numberOfSteps;
	NSDate *runTime, *stepRunTime;
	float ampsSetpoint, voltsSetpoint, amps, volts, presentInterval;
	int lessEqualGreater;
	int loopStep, loopRepeats,totalLoopRepeats, currentLoop, loopDoneJumpToStep, userReadableLoopStep;
    int running, saveIterator, presentSaveIterations;

	int		selectedCommand;
	
	int		portAddress;
	char	portConnected;
	
	float	temp1,temp2,current,voltage,watts;
	int		testerPort;
	SerialPort		*portList;
	CocoaSerialPort *csp;
	NSFileHandle		*fyle;
	unsigned char receivePacket[100];
	NSDate *startTime;
	}

- (void)awakeFromNib;

# pragma mark battery tester methods

- (IBAction)openSequenceFile:(id)sender;
- (void)openSequenceFilePanelDidEnd:(NSOpenPanel *)panel returnCode:(int)returnCode contextInfo:(void *)contextInfo;

- (IBAction)start:(id)sender;
- (IBAction)stop:(id)sender;
- (void)doNextStep;
- (void)parseCurrentStep;

- (void)updateThings;
- (void)writeLatestDataToDisk;
- (void)writeToFile:(NSString*)writeString;

- (IBAction)nameAndStartSaveLogFile:(id)sender;
-(NSString *)readSmallTesterBinary;

# pragma mark commands

// new serial port sheet stuff
- (IBAction)closeNewSerialSheet:(id)sender;
- (IBAction)cancelNewSerialSheet:(id)sender;
- (void)showNewSerialSheet;
- (void)newSerialSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
- (void)refreshAvailablePorts;

- (unsigned char)hexChar:(NSString *)string;
- (NSString *)hexString:(unsigned char)v;
- (void)drawGraphs;

- (void)closePorts;

- (int)readWrite:(short)writeLength :(short)readLength :(unsigned char *)sendPacket;


@end

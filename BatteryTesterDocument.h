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
#import "BatteryTesterSequence.h"

@interface BatteryTesterDocument : NSDocument
{
	IBOutlet NSWindow *introSheet,*newSerialSheet, *serialNumberSheet, *timeSheet;
	IBOutlet Graph *graph;
	IBOutlet NSPopUpButton *newSerialMenu;
    
	IBOutlet NSButton *startButton, *loadButton, *okButton, *cancelButton;
	IBOutlet NSTextField *serialPortMenuLabel;
	IBOutlet NSTextField *serialPortErrorDescription;
	
	//battery tester
    NSTimer* theTimer;
    
    IBOutlet BatteryTesterSequence <NSTableViewDataSource> *sequence;
	
    IBOutlet NSTableView *theTable;
	IBOutlet NSTextField *statusText1, *statusText2, *ampsField, *voltsField, *wattsField;
	IBOutlet NSTextField *commandField, *responseField;
	NSString *serialPortString;
    	
	NSInteger currentStep;
	NSDate *runTime, *stepRunTime;
	float ampsSetpoint, voltsSetpoint, amps, volts, presentInterval;
	int lessEqualGreater;
	int loopStep, loopRepeats,totalLoopRepeats, currentLoop, loopDoneJumpToStep, userReadableLoopStep;
    int saveIterator, presentSaveIterations;
    
    BOOL    running;

	int		selectedCommand;
	
	int		portAddress;
	char	portConnected;
	
	float	temp1,temp2,current,voltage,watts;
	int		testerPort;
	SerialPort		*portList;
	CocoaSerialPort *csp;
	unsigned char receivePacket[100];
	NSDate *startTime;
    NSFileHandle *logFile;
}

- (void)awakeFromNib;

# pragma mark battery tester methods

- (IBAction)importSequenceFile:(id)sender;
- (IBAction)exportSequenceFile:(id)sender;

- (IBAction)start:(id)sender;
- (IBAction)stop:(id)sender;
- (IBAction)nextStep:(id)sender;

- (void)incrementStep;
- (void)doNextStep;
- (void)parseCurrentStep;

- (void)stopWithErrorForAttribute:(NSString*)attributeString atStep:(NSInteger) stepNumber;

- (void)updateThings;

- (void)writeLatestDataToDisk;
- (void)writeToFile:(NSString*)writeString;

- (IBAction)nameAndStartSaveLogFile:(id)sender;
- (NSString *)readSmallTesterBinary;

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

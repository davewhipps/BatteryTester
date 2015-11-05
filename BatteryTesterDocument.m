//
//  MyDocument.m
//  BatteryTester
//
//  Created by ted on 7/3/15.
//  Copyright 2015 __MyCompanyName__. All rights reserved.
//

#import "BatteryTesterDocument.h"

@implementation BatteryTesterDocument

- (id)init
{
	self = [super init];
    if (self) {
        sequence = [[BatteryTesterSequence alloc] init];

        //tester = [[SingleCellHardware alloc] init];
        //[tester setThingsUp];
        loopStep = -1;
        loopRepeats = -1;
        loopDoneJumpToStep = -1;
        
        running = NO;
    }

    return self;
}

- (NSString *)windowNibName
{
    return @"BatteryTesterDocument";
}

- (void)windowControllerDidLoadNib:(NSWindowController *) aController
{
	[super windowControllerDidLoadNib:aController];
    
    // TODO: How do we hook this up via Interface Builder?
    if (theTable)
        [theTable setDataSource:sequence];

	csp = [[CocoaSerialPort alloc] init];
	
	[aController setShouldCloseDocument:YES];
	serialPortString = @"no port";
	[serialPortString retain];
	
	
	startTime = 0;
	
	// this is a one shot timer, to give time for everyting else to init before showing the sheet
	[NSTimer scheduledTimerWithTimeInterval:0.4 target:self selector:@selector(showNewSerialSheet) userInfo:nil repeats:NO];

	theTimer = [[NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(refreshAvailablePorts) userInfo:nil repeats:YES] retain];
	
}

- (NSData *)dataOfType:(NSString *)typeName error:(NSError **)outError
{
    // Insert code here to write your document to data of the specified type. If the given outError != NULL, ensure that you set *outError when returning nil.

    // You can also choose to override -fileWrapperOfType:error:, -writeToURL:ofType:error:, or -writeToURL:ofType:forSaveOperation:originalContentsURL:error: instead.

    // For applications targeted for Panther or earlier systems, you should use the deprecated API -dataRepresentationOfType:. In this case you can also choose to override -fileWrapperRepresentationOfType: or -writeToFile:ofType: instead.

    if ( outError != NULL ) {
		*outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:unimpErr userInfo:NULL];
	}
	return nil;
}

- (BOOL)readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)outError
{
    // Insert code here to read your document from the given data of the specified type.  If the given outError != NULL, ensure that you set *outError when returning NO.

    // You can also choose to override -readFromFileWrapper:ofType:error: or -readFromURL:ofType:error: instead. 
    
    // For applications targeted for Panther or earlier systems, you should use the deprecated API -loadDataRepresentation:ofType. In this case you can also choose to override -readFromFile:ofType: or -loadFileWrapperRepresentation:ofType: instead.
    
    if ( outError != NULL ) {
		*outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:unimpErr userInfo:NULL];
	}
    return YES;
}
- (void)awakeFromNib
{
	
    NSLog(@"it's too early for me, man...");
}
/* battery tester methods*/


- (BOOL)validateToolbarItem:(NSToolbarItem *)toolbarItem;
{
    if ([toolbarItem action] == @selector(start:)) {
        return !running && sequence && ([sequence numberOfSteps] > 1);
    }
    else if ([toolbarItem action] == @selector(stop:)) {
        return running;
    }
    else if ([toolbarItem action] == @selector(importSequenceFile:)) {
        return !running;
    }    
    else if ([toolbarItem action] == @selector(exportSequenceFile:)) {
        return !running && sequence && ([sequence numberOfSteps] > 1);
    }    
    else if ([toolbarItem action] == @selector(nextStep:)) {
        return running;
    }
    
    return YES;
}


- (void)stopWithErrorForAttribute:(NSString*)attributeString atStep:(NSInteger) stepNumber
{
    [self stop:self];
    NSString* errorString = [NSString stringWithFormat:@"There was a problem parsing %@ at step %ld. Stopping.", attributeString, (long)stepNumber];
    [statusText1 setStringValue:errorString];
}


- (IBAction)start:(id)sender
{
	[self nameAndStartSaveLogFile:self];
}

- (IBAction)nextStep:(id)sender
{
    // TODO: Skip to next step
    
    // Is it running?
    // Is it looping?
    
    // If all is well, call:
    [self incrementStep];
}

- (void)incrementStep
{
    [stepRunTime release];
    stepRunTime = [[NSDate date] retain];
    NSBeep();
    ++currentStep;
    [self doNextStep];
}

- (void)doNextStep
{
	if (currentStep >= [sequence numberOfSteps])
        [self stop:self];
	else
		[self parseCurrentStep];
}

- (void)doPresentStep
{
	double stepElapsedTime = -[stepRunTime timeIntervalSinceNow];

    NSString* stepDuration = [sequence stringForAttribute:@"stepDuration" atIndex:currentStep];
    if (stepDuration == nil) {
        return [self stopWithErrorForAttribute:@"stepDuration" atStep:currentStep];
    }
    
    NSString* endTypeString = [sequence stringForAttribute:@"endType" atIndex:currentStep];
    if (endTypeString == nil) {
        return [self stopWithErrorForAttribute:@"endType" atStep:currentStep];
    }

    NSString* criterionString = [sequence stringForAttribute:@"criterion" atIndex:currentStep];
    if (criterionString == nil) {
        return [self stopWithErrorForAttribute:@"criterion" atStep:currentStep];
    }

    NSString* targetValueString = [sequence stringForAttribute:@"targetValue" atIndex:currentStep];
    if (targetValueString == nil) {
        return [self stopWithErrorForAttribute:@"targetValue" atStep:currentStep];
    }
    float targetVoltage = [targetValueString floatValue];
    
    NSString* stepID = [sequence stringForAttribute:@"stepID" atIndex:currentStep];
    if (stepID == nil) {
        return [self stopWithErrorForAttribute:@"stepID" atStep:currentStep];
    }
    
	double stepTime = [stepDuration doubleValue];
    NSString* statusString = [NSString stringWithFormat:@"Executing step %d, %2.1f s of %2.1f", [stepID intValue], stepElapsedTime, stepTime];
	
	NSIndexSet* theIndex = [NSIndexSet indexSetWithIndex:currentStep];
	[theTable selectRowIndexes:theIndex byExtendingSelection:FALSE];
	
	if (loopStep > -1)// if we are running a loop
		[statusText1 setStringValue:[NSString stringWithFormat:@"%@, Loop back to step %d, iteration %d of %d",statusString, userReadableLoopStep,totalLoopRepeats - loopRepeats + 1,totalLoopRepeats]];
	else
		[statusText1 setStringValue:statusString];
	
    BOOL incrementStep = NO;
	if ([endTypeString isEqualToString:@"Time"])	//time ended step
	{
		if (stepElapsedTime > stepTime)
            incrementStep = YES;
	}
	else if ([endTypeString isEqualToString:@"Voltage"])
	{
		if ([criterionString isEqualToString:@"LTE"]) {
			if (voltage <= targetVoltage)
				incrementStep = YES;
		}
		else if ([criterionString isEqualToString:@"GTE"]) {
			if (voltage >= targetVoltage)
				incrementStep = YES;
		}
		else
			incrementStep = YES;
	}
    else if ([endTypeString isEqualToString:@"TimeOrVoltage"])
    {
        if (stepElapsedTime > stepTime ) {
            incrementStep = YES;
        }
        else if ([criterionString isEqualToString:@"LTE"]) {
			if (voltage <= targetVoltage)
				incrementStep = YES;
		}
		else if ([criterionString isEqualToString:@"GTE"]) {
			if (voltage >= targetVoltage)
				incrementStep = YES;
		}
		else
			incrementStep = YES; // Yikes! I guess we bail
    }
    else if ([endTypeString isEqualToString:@"TimeAndVoltage"])
    {
        if (stepElapsedTime > stepTime)
        {
            if ([criterionString isEqualToString:@"LTE"]) {
                if (voltage <= targetVoltage)
                    incrementStep = YES;
            }
            else if ([criterionString isEqualToString:@"GTE"]) {
                if (voltage >= targetVoltage)
                    incrementStep = YES;
            }
            else
                incrementStep = YES; // Yikes! I guess we bail
        }
    }
	else if ([endTypeString isEqualToString:@"loop"])
        incrementStep = YES;
	else
        incrementStep = YES;
    
    if (incrementStep) {
        [self incrementStep];
        return;
    }
}

- (void)parseCurrentStep
{
	NSString* commandString = [sequence stringForAttribute:@"command" atIndex:currentStep];
    if (commandString == nil)
        return [self stopWithErrorForAttribute:@"command" atStep:currentStep];

    NSString* argumentString = [sequence stringForAttribute:@"argument" atIndex:currentStep];
    if (argumentString == nil)
        return [self stopWithErrorForAttribute:@"argument" atStep:currentStep];
   
    NSString* setpointString = [sequence stringForAttribute:@"setpoint" atIndex:currentStep];
    if (setpointString == nil)
        return [self stopWithErrorForAttribute:@"setpoint" atStep:currentStep];

    NSString* logIntervalString = [sequence stringForAttribute:@"logInterval" atIndex:currentStep];
    if (setpointString == nil)
        return [self stopWithErrorForAttribute:@"logInterval" atStep:currentStep];
    
    double maybeAmps;
	unsigned char theReceive[100];
	int receiveLength;
	
	presentInterval = [logIntervalString floatValue];
    saveIterator = (int)(presentInterval + 0.3)/UPDATEINTERVAL;
    presentSaveIterations = 0;
    
	//NSLog (@"interval = %3.2f, %d",presentInterval,saveIterator);
    
    [self writeLatestDataToDisk];
    
	if ([commandString isEqualToString:@"rest"])	// open circuit- Turns off any driving current or potential.
	{
        unsigned char openSend[] = {'o','\r'};
		//NSLog(@"start open");
		
		receiveLength = [csp readAndWrite:2 :5 :openSend :theReceive :testerPort];

        ampsSetpoint = 0;
		[statusText2 setStringValue:@"open circuit"];

        if (receiveLength)
        {
             theReceive[receiveLength] = 0;
             // NSString * incomeString = [NSString stringWithCString:theReceive encoding:NSASCIIStringEncoding];
        }
		//NSLog(@"end open");

    }
    /*
     command to send to set current is
     
     c or d (µA/102.34)
     
     command to read stuff is
     
     get back 2 numbers
     
     first one is: µA = adc * 0.0051504 + .2517
     second one is cell volts = adc * 0.000117891 - 0.05284
     */
	else if([commandString isEqualToString:@"charge"])  // turn PAR to galvanostat mode
	{
        NSString* commandString = nil;
		//NSLog(@"start charge");

        maybeAmps = [setpointString doubleValue];
        
        ampsSetpoint = 1;
        
		ampsSetpoint *= [setpointString floatValue];
        
        commandString = [NSString stringWithFormat:@"c%1.4f\r",ampsSetpoint*10000/1.0234];

		receiveLength = [csp readAndWrite:[commandString length] :5 :[commandString cStringUsingEncoding:NSASCIIStringEncoding] :theReceive :testerPort];
        [statusText2 setStringValue:commandString];
		//NSLog(@"end charge");

	}
	else if([commandString isEqualToString:@"discharge"])	
	{
		//NSLog(@"start discharge");
   
        maybeAmps = [setpointString doubleValue];
        
        ampsSetpoint = 1;
        
        ampsSetpoint *= [setpointString floatValue];
        
        commandString = [NSString stringWithFormat:@"d%1.4f\r",ampsSetpoint*10000/1.0234];
        
		receiveLength = [csp readAndWrite:[commandString length] :5 :[commandString cStringUsingEncoding:NSASCIIStringEncoding] :theReceive :testerPort];
        [statusText2 setStringValue:commandString];
		//NSLog(@"end discharge");

	}
	if ([commandString isEqualToString:@"loop"])
	{
		NSArray *parts = [argumentString componentsSeparatedByString:@";"];
		NSCharacterSet *setty = [NSCharacterSet characterSetWithCharactersInString:@"<>"];
		
		int foo;
		
		if (loopStep > -1)//handle loop
		{
			--loopRepeats;
			if(loopRepeats > 0)
				currentStep = loopStep;
			else
			{
				currentStep = loopDoneJumpToStep;
				loopDoneJumpToStep = -1;
				loopRepeats = -1;
				loopStep = -1;
			}
			//	NSLog(@"loopStep = %d, loopRepeats = %d, loopDoneJumpToStep = %d",loopStep, loopRepeats, loopDoneJumpToStep);
			
			[self doNextStep];
		}	
		else if([parts count] == 2) // first time we're encountering this command
		{
			loopStep = userReadableLoopStep = [[[parts objectAtIndex: 0] stringByTrimmingCharactersInSet:setty] intValue];
			loopRepeats = totalLoopRepeats = [[[parts objectAtIndex: 1] stringByTrimmingCharactersInSet:[NSCharacterSet punctuationCharacterSet]] intValue];
			loopDoneJumpToStep = currentStep + 1;
			//NSLog(@"loopStep = %d, loopRepeats = %d, loopDoneJumpToStep = %d",loopStep, loopRepeats, loopDoneJumpToStep);
			
			for (foo = 0; foo < [sequence numberOfSteps]; ++ foo)
			{
                NSString* stepID = [sequence stringForAttribute:@"stepID" atIndex:foo];
				if (stepID && ([stepID intValue] == loopStep))
				{	
					//NSLog (@" we have a  winner at step %d", foo);
					loopStep = foo;
					currentStep = loopStep;
					break;
				}
			}
			[self doNextStep];
		}
	}
}

- (IBAction)stop:(id)sender
{
	unsigned char openSend[] = {'o','\r'};
	unsigned char theReceive[100];
	int receiveLength = 1;	
	
	while(receiveLength > 0)
	{
		receiveLength = [csp readPort:10 :theReceive :testerPort]; // clear port
	}
	[csp writePort:2 :openSend :testerPort];
	
	receiveLength = [csp readPort:5 :theReceive :testerPort];
	ampsSetpoint = 0;
	[statusText2 setStringValue:@"open circuit"];
	
    if(logFile)
    {
        [logFile closeFile];
        logFile = 0;
    }
	[statusText1 setStringValue:@"Run Stopped"];
    running = NO;
    
    //NSLog(@"stop, goddamn it");
}

- (void)updateThings
{
    NSArray *valuesArray;
    NSString* receiver = [self readSmallTesterBinary];
	NSString* voltsString, *ampsString;
    float latestAmps, latestVolts;
	int success = 0;
	
	//NSLog(@"readSmallTesterBinary start");
    receiver = [self readSmallTesterBinary];
	//NSLog(@"readSmallTesterBinary end");

    valuesArray = [receiver componentsSeparatedByString:@","];
    
    if([valuesArray count] == 4)
    {
		voltsString = [valuesArray objectAtIndex:1];
		ampsString = [valuesArray objectAtIndex:0];
//		NSLog(ampsString);
		
		if([ampsString isEqualToString:@"errI"])
		{
			NSLog(@"amps error handled");
			success += 1;
		}
		
		if([voltsString isEqualToString:@"errE"])
		{
			NSLog(@"amps error handled");
			success += 2;
		}
		
        
		switch(success)
		{
			case 0:
				latestAmps = [ampsString floatValue]/200;// * 0.0051504 + 0.2517)/100;
				
				latestVolts = [voltsString floatValue]/1000;//*0.00017891-0.05284;
				if(1)//latestVolts > 0.1 || latestVolts < -0.1)	// this is a bit of a kludge to make sure no amps data sneaks
				{											// in under the guise of volts
					voltage = latestVolts;
					current = latestAmps;
					NSLog(@" current current = %f",current);
					
					//watts:latestAmps*latestVolts/10000;
					[ampsField setFloatValue:current];
					[voltsField setFloatValue:voltage];
					[wattsField setFloatValue:watts];
					switch([[valuesArray objectAtIndex:2] intValue])
					{
						case 0:
							[statusText2 setStringValue:@"open circuit"];
							break;
						case 1:
							[statusText2 setStringValue:@"discharging"];
							break;
						case 2:
							[statusText2 setStringValue:@"charging"];
							break;
						default:
							[statusText2 setStringValue:@"error on state"];
							break;
					}
							
				}
				else
				{
					NSLog(@"volts sucked, got %f",latestVolts);
					[statusText2 setStringValue:@"volts sucked"];

				}
				
				break;
			case 1:
				[statusText2 setStringValue:@"couldn't read amps"];
				break;
			case 2:
				[statusText2 setStringValue:@"couldn't read volts"];
				break;
			case 3:
				[statusText2 setStringValue:@"couldn't read amps or volts"];
				break;
			default:
				[statusText2 setStringValue:@"unknown tester condition"];
		}
	}
	else
		[statusText2 setStringValue:[NSString stringWithFormat:@"hmm, rcvd %ld, %@",(unsigned long)[receiver length], receiver]];
	
	if (running)
	{
		[self doPresentStep];
		++presentSaveIterations;
		
		//NSLog(@"present save is %d out of %d",presentSaveIterations,saveIterator);
		
		if( presentSaveIterations >= saveIterator)   // time to write to disk
		{
			presentSaveIterations = 0;
			//  NSLog(@"reset presentSaveIterations");
			[self writeLatestDataToDisk];
		}
	}
	//NSLog(@"start draw graph");
	[self drawGraphs];
	//	NSLog(@"end draw graph");
}
				

- (IBAction)exportSequenceFile:(id)sender
{
	NSSavePanel* savePanel = [NSSavePanel savePanel];
    
    // TODO: Set default filename
    // TODO: Set default directory
    
    NSWindow* appWindow = [[NSApplication sharedApplication] mainWindow];
    [savePanel  beginSheetModalForWindow:(NSWindow *)appWindow
                       completionHandler:^(NSInteger result)
        {
            if (result == NSFileHandlingPanelOKButton)
            {
                // Write to the file at the saved URL
                NSURL* theSequenceFile = [savePanel URL];
                if (sequence) {
                    [sequence writeToURL:theSequenceFile];
                }
            }
        }
    ];
}

- (IBAction)importSequenceFile:(id)sender
{
	NSOpenPanel* openPanel = [NSOpenPanel openPanel];
    
    // TODO: Set default filename
    // TODO: Set default directory

    NSWindow* appWindow = [[NSApplication sharedApplication] mainWindow];
    [openPanel  beginSheetModalForWindow:(NSWindow *)appWindow
                       completionHandler:^(NSInteger result)
        {
            if (result == NSFileHandlingPanelOKButton)
            {
                NSURL* theSequenceFile = [[openPanel URLs] objectAtIndex:0];
                [sequence initWithContentsOfURL:theSequenceFile];
                [theTable reloadData];
                [theTable deselectAll:self];
                [theTable selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
                
                loopStep = -1;
                loopRepeats = -1;
                loopDoneJumpToStep = -1;
            }
        }
    ];
	
}

- (void)writeLatestDataToDisk
{
    NSCalendarDate *now = [NSCalendarDate calendarDate];
    NSString *dateStr;
    dateStr = [now descriptionWithCalendarFormat:@"%m/%d/%y %I:%M:%S %p"];
    [self writeToFile:[NSString stringWithFormat:@"%@\t%.2f\t%1.3e\t%1.3e\t%@",dateStr,-[runTime timeIntervalSinceNow],voltage,current,[statusText1 stringValue]]];
}

-(void)writeToFile:(NSString*)writeString
{
    NSString *string;
    unsigned long long offset; // a variable to hold the file read/write position
    NSData *data;
    
	
    offset = [logFile seekToEndOfFile];    // set the write position to the end of the file (the variable offset doesn't actually do anything, it's just a receiver)
	
    string = [NSString stringWithFormat:@"\n"];     // put in a newline
    data = [string dataUsingEncoding:NSMacOSRomanStringEncoding];    // put it into ascii format
    [logFile writeData: data];             // write the data
    offset = [logFile seekToEndOfFile];    // set the write position to the end of the file
	
    data = [writeString dataUsingEncoding:NSMacOSRomanStringEncoding];
    [logFile writeData: data]; 
    offset = [logFile seekToEndOfFile];
	
	//	NSLog(@"wrote");
}

- (IBAction)nameAndStartSaveLogFile:(id)sender
{
    NSSavePanel *savePanel = [NSSavePanel savePanel];
    
    // Default to documents directory (If you really want the desktop, use this: NSDesktopDirectory instead)
    NSArray* userDocumentsFolders = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
	NSString* defaultDirectory = [userDocumentsFolders objectAtIndex:0];
    NSURL* defaultDirectoryURL = [NSURL fileURLWithPath:defaultDirectory isDirectory:YES];
    [savePanel setDirectoryURL:defaultDirectoryURL];
    
    // Default filename
    NSCalendarDate *now = [NSCalendarDate calendarDate];
    NSString* datestr = [now descriptionWithCalendarFormat:@"%m%d%y %I%M%S%p"];
    [savePanel setNameFieldStringValue:[NSString stringWithFormat:@"Log File %@.log",datestr]];
    
    // Ensure .txt format
	[savePanel setAllowedFileTypes:[NSArray arrayWithObject:(NSString*) kUTTypeUTF8PlainText]];
    
    // App main window
    NSWindow* appWindow = [[NSApplication sharedApplication] mainWindow];
    
    // Show the save panel in a sheet
    [savePanel beginSheetModalForWindow:appWindow completionHandler:^(NSInteger result)
        {
            if (result == NSFileHandlingPanelOKButton)
            {
                NSString* headerString = [NSString stringWithFormat:@"time\telapsed Time\tvolts\tamps"];
                NSData* data = [headerString dataUsingEncoding:NSUTF8StringEncoding];
                
                NSFileManager* fm = [NSFileManager defaultManager];
                BOOL success = [fm createFileAtPath: [[savePanel URL] path] contents: data attributes: nil];
                
                if (success)  // we were successful? Then party on!
                {
                    NSError* theError = nil;
                    logFile = [NSFileHandle fileHandleForWritingToURL:[savePanel URL] error:&theError];      // get the handle to the newly created file
                    [logFile retain];
                    
                    if (runTime) // we had a previous file created
                        [runTime release];
                    
                    runTime = [[NSDate date] retain];
                    stepRunTime = [[NSDate date] retain];
                    
                    running = YES;
                    [statusText1 setStringValue:@"Run Started"];
                    
                    currentStep = 0;
                    loopStep = -1;
                    loopRepeats = -1;
                    loopDoneJumpToStep = -1;
                    [self doNextStep];
                }
            }
        }
    ];
}

-(NSString *)readSmallTesterBinary
{
	unsigned char binSend[] = {'b','\r'};
	unsigned char binReceive[5];
    unsigned char theReceive[100];
    int success, receiveLength = 1;
    NSString *stringy = nil;
    
	success = 0;
	//NSLog(@"start read");
	while(receiveLength > 0)
    {
		receiveLength = [csp readPort:1 :theReceive :testerPort]; // clear port
		if(receiveLength != 0)
		{
			printf("%d,",theReceive[0]);
			++success;
		}
	}
//	printf("\n");
	
    if(success)
        NSLog(@"Cleanout before read gave %d bytes",success);
    receiveLength =	[csp readAndWrite:2 :5 :binSend :binReceive :testerPort];

	
    
    if(receiveLength == 5)
    {
        stringy = [NSString stringWithFormat:@"%d,%d,%d, ",(int)binReceive[2]*256+(int)binReceive[3],(int)binReceive[0]*256+(int)binReceive[1],(int)binReceive[4]];
    }
    else if(receiveLength > 5)
    {
        stringy = @"errI,errE";	// hey, you gotta pass an error somehow
		while(receiveLength > 0)
        {
            receiveLength = [csp readPort:10 :theReceive :testerPort]; // clear port
            usleep(WAITFORPAR/20);
        }
    }
	//NSLog(@"end read");

    return stringy;
}


- (NSString *)sendCommandToSmallTester:(unsigned char*)theSent length:(int)lengths
{
    unsigned char theReceive[100];
    
	[csp writePort:lengths :theSent :testerPort];
	int receiveLength = [csp readAndWrite:lengths :4 :theSent :theReceive :testerPort];

    theReceive[receiveLength] = 0;
    NSString* incomeString = [NSString stringWithCString:theReceive encoding:NSASCIIStringEncoding];

    return incomeString;
}


#pragma mark end battery tester methods

- (void)drawGraphs
{
	NSArray *points = [NSArray arrayWithObjects:
		[NSNumber numberWithFloat:temp1],	
		[NSNumber numberWithFloat:temp2],	
		[NSNumber numberWithFloat:current],	
		[NSNumber numberWithFloat:voltage],
		[NSNumber numberWithFloat:watts],		nil];
	
	[graph drawPoints: points];
}

// accepts hex bytes as caps and dec digits, returns unsigned char value
- (unsigned char)hexChar:(NSString *)string
{
	const char *str = [string cStringUsingEncoding:NSASCIIStringEncoding];
	unsigned char v = 0;
	
	if(str[0] > 57)
		v += (str[0] - 55) * 16;
	else
		v += (str[0] - 48) * 16;
		
	if(str[1] > 57)
		v += str[1] - 55;
	else
		v += str[1] - 48;
		
	return v;
}	

// accepts unsigned char and returns NSString as hex byte with trailing space
- (NSString *)hexString:(unsigned char)v
{
	NSString *string;
	
	if(v < 16) // one digit
		string = [NSString stringWithFormat:@"0%X ",(int)v];
	else
		string = [NSString stringWithFormat:@"%X ",(int)v];
		
	return string;
}


- (void)closePorts
{
	if(testerPort > -1)
		[csp closePort: testerPort];
}

- (int)readWrite:(short)writeLength :(short)readLength :(unsigned char *)sendPacket
{
	int actualLength = 0;

	if(writeLength == 26)	// kludge for fact that change vars command does not return a leading ack or nack
		actualLength = [csp readAndWrite:writeLength :readLength :sendPacket :&receivePacket[1] :testerPort];
	else
		actualLength = [csp readAndWrite:writeLength :readLength :sendPacket :receivePacket :testerPort];
		
	if(actualLength == -6) // port disconnected
	{
		[theTimer invalidate];
		[theTimer release];
		theTimer = [[NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(refreshAvailablePorts) userInfo:nil repeats:YES] retain];
		[self showNewSerialSheet];
	}
	return actualLength;
}

- (IBAction)closeNewSerialSheet:(id)sender
{
	//if(sender != self)
    [NSApp endSheet:newSerialSheet returnCode:NSOKButton];
}
- (IBAction)cancelNewSerialSheet:(id)sender
{
    [NSApp endSheet:newSerialSheet returnCode:NSCancelButton];
}

- (void)showNewSerialSheet
{
	NSWindow *theWin = 0;
	NSArray *theArray = 0;
	NSWindowController *winC = 0;
	
	theArray = [self windowControllers];
	winC = [theArray objectAtIndex:0];
	theWin = [winC window];
	
    [NSApp beginSheet: newSerialSheet
            modalForWindow: theWin
            modalDelegate: self
            didEndSelector: @selector(newSerialSheetDidEnd:returnCode:contextInfo:)
            contextInfo: nil];
}
- (void)newSerialSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	OSErr err;
	NSString *popupString = [[newSerialMenu selectedItem] title];
	int index = 0;
    portList = GetPorts();
	NSString *portName = @"";
	
	NSWindow *theWin = 0;
	NSArray *theArray = 0;
	NSWindowController *winC = 0;
	
	theArray = [self windowControllers];
	winC = [theArray objectAtIndex:0];
	theWin = [winC window];
	
	if(	returnCode == NSOKButton)
	{
		FindAndListModems();
		while(portList->portName[0] != 0 )
		{
			portName = [NSString stringWithCString:portList->portName encoding:NSASCIIStringEncoding];
			if(![popupString compare: portName])
				break;
			else
			{
				++portList;
				++index;
			}
		}	
		err = SetAndOpenPort(index);
		
		if(err < 0)
			NSLog(@"error on SetAndOpenPort");
		else
		{
			[serialPortString release];
			serialPortString = popupString;
			[serialPortString retain];
			testerPort =  err;
			[theWin setTitle:portName];
			theTimer = [[NSTimer scheduledTimerWithTimeInterval:UPDATEINTERVAL target:self selector:@selector(updateThings) userInfo:nil repeats:TRUE] retain];
        }
		[sheet orderOut:self];
		[self closeNewSerialSheet:self];
	}
	else
	{
		[sheet orderOut:self];
		[self closeNewSerialSheet:self];
		[self close];
	}
}
- (void)refreshAvailablePorts
{
	NSString	*portName;
	int i;	

	portAddress = 0;
    portList = [csp getPortList];
	[csp findAndListModems];
	
	for(i = 0; i < [newSerialMenu numberOfItems]; ++i)
		[newSerialMenu removeItemAtIndex:0]; //  remove the first, placeholder serial port menu item.

	while(portList->portName[0] != 0 )
	{
		portName = [NSString stringWithCString: portList->portName encoding: NSASCIIStringEncoding];
		[newSerialMenu addItemWithTitle: portName];
		++portList;
	}

	if ([newSerialMenu numberOfItems])	// we found some ports
	{
		[serialPortErrorDescription setHidden:true];

		[newSerialMenu setHidden: false];
        [serialPortMenuLabel setHidden:false];
		[okButton setHidden:false];

		[theTimer invalidate];	// if we've found a port, don't run this routine again. One port is enough for now!
		[theTimer release];
		theTimer = 0;
	}
	else
	{
		//NSLog(@"No ports!");
		
		NSMutableDictionary *attr = [NSMutableDictionary dictionary];

		[attr setObject: [NSColor yellowColor] forKey:NSForegroundColorAttributeName];
		[attr setObject: [NSColor redColor] forKey:NSBackgroundColorAttributeName];
		
		[serialPortErrorDescription setAttributedStringValue:[[NSAttributedString alloc] initWithString: @"USB-Serial converter has been unplugged! Please plug it back into computer!" attributes:attr]];
		[newSerialMenu setHidden: true];
        [serialPortMenuLabel setHidden:true];

		[okButton setHidden:true];
		[serialPortErrorDescription setHidden:false];
	}
}	
- (void)dealloc 
{
	NSLog(@"dealloc called");
	[self stop:self];
	[csp closePort:testerPort];
    [csp release];
    [super dealloc];
	
}

- (void)close
{
	NSLog(@"close called");
	if(logFile)
	{
		[logFile closeFile];
		[logFile release];
	}
	if(theTimer)
	{
		[theTimer invalidate];
		[theTimer release];
	}
	
	[self stop:self];
	[csp closePort:testerPort];
    [csp release];
//	[super close];
}

- (IBAction)terminate:(id)dummy
{
	NSLog(@"terminate called");

   [[NSApp orderedDocuments] makeObjectsPerformSelector:@selector(closeNewSerialSheet:) withObject:nil];
   [NSApp terminate:dummy];
}

@end

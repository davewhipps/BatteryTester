//
//  MyDocument.m
//  BatteryTester
//
//  Created by ted on 7/3/15.
//  Copyright 2015 __MyCompanyName__. All rights reserved.
//

#import "MyDocument.h"

@implementation MyDocument

- (id)init
{
    NSString *realString = @"StepID,Cmd,Arg,SP,Duration,EndType,Criterion,TargetVal,DaqIntrv,LogIntrv,Flag";
	NSArray *theArray = [realString componentsSeparatedByString:@","];
   
	[super init];

	steps = [[NSArray arrayWithObjects:[[OldStep alloc] initWithArray:theArray], nil] retain];
	//tester = [[SingleCellHardware alloc] init];
	//[tester setThingsUp];
    loopStep = -1;
	loopRepeats = -1;
	loopDoneJumpToStep = -1;
    running = 0;

    return self;
}

- (NSString *)windowNibName
{
    return @"MyDocument";
}

- (void)windowControllerDidLoadNib:(NSWindowController *) aController
{
	[super windowControllerDidLoadNib:aController];

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

- (IBAction)start:(id)sender
{
	[self nameAndStartSaveLogFile:self];
}

- (void)doNextStep
{
	if(currentStep > numberOfSteps)
        [self stop:self];
	else
		[self parseCurrentStep];
}

- (void)doPresentStep
{
	double stepElapsedTime = -[stepRunTime timeIntervalSinceNow];
	double stepTime = [[[steps objectAtIndex:currentStep] stepDuration] doubleValue];
	NSString *endTypeString = [[[steps objectAtIndex:currentStep] endType] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
	NSString *statusString = [NSString stringWithFormat:@"Executing step %d, %2.1f s of %2.1f", [[[steps objectAtIndex:currentStep] stepID] intValue ], stepElapsedTime, stepTime];
	
	NSIndexSet *theIndex = [NSIndexSet indexSetWithIndex:currentStep];
	
	[theTable selectRowIndexes:theIndex byExtendingSelection:FALSE];
	
	if(loopStep > -1)// if we are running a loop
		[statusText1 setStringValue:[NSString stringWithFormat:@"%@, Loop back to step %d, iteration %d of %d",statusString, userReadableLoopStep,totalLoopRepeats - loopRepeats + 1,totalLoopRepeats]];
	else
		[statusText1 setStringValue:statusString];
	
	if([endTypeString isEqualToString:@"Time"])	//time ended step
	{
		if(stepElapsedTime > stepTime )
		{
			[stepRunTime release];
			stepRunTime = [[NSDate date] retain];
			NSBeep();
			++currentStep;
			[self doNextStep];
		}
	}
	else if([endTypeString isEqualToString:@"Voltage"])
	{
		NSString *criterionString = [[[steps objectAtIndex:currentStep] criterion] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
		NSString *targetValueString = [[[steps objectAtIndex:currentStep] targetValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
		float target = [targetValueString floatValue];
		int getOut = 0;
		
		if([criterionString isEqualToString:@"LTE"])
		{
			//volts -=  .01;
			
			if(voltage <= target)// && voltage > 0.01) // kludge for poor error checking
				getOut = 1;
		}
		else if([criterionString isEqualToString:@"GTE"])
		{
			//volts += .01;
			
			if(voltage >= target)
				getOut = 1;
		}
		else
			getOut = 1;
		
		if(getOut)
		{
			[stepRunTime release];
			stepRunTime = [[NSDate date] retain];
			NSBeep();
			++currentStep;
			[self doNextStep];
		}
		
	}		
	else if([endTypeString isEqualToString:@"loop"])
	{
		[stepRunTime release];
		stepRunTime = [[NSDate date] retain];
		NSBeep();
		++currentStep;
		[self doNextStep];
	}		
	else 
	{
		[stepRunTime release];
		stepRunTime = [[NSDate date] retain];
		NSBeep();
		++currentStep;
		[self doNextStep];
	}		
}

- (void)parseCurrentStep
{
	NSString *commandString = [[[steps objectAtIndex:currentStep] command] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
	NSString *argumentString = [[[steps objectAtIndex:currentStep] argument] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
	//	NSString *endTypeString = [[[steps objectAtIndex:currentStep] endType] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
	NSString *setpointString = [[[steps objectAtIndex:currentStep] setpoint] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
	NSString *logIntervalString = [[[steps objectAtIndex:currentStep] logInterval] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    double maybeAmps;
	unsigned char theReceive[100];
	int receiveLength;
	
	presentInterval = [logIntervalString floatValue];
    saveIterator = (int)(presentInterval + 0.3)/UPDATEINTERVAL;
    presentSaveIterations = 0;
    
	//NSLog (@"interval = %3.2f, %d",presentInterval,saveIterator);
    
    [self writeLatestDataToDisk];
    
	if([commandString isEqualToString:@"rest"])	// open circuit- Turns off any driving current or potential.
	{
         unsigned char openSend[] = {'o','\r'};
		NSString *incomeString;
		//NSLog(@"start open");
		
		receiveLength = [csp readAndWrite:2 :5 :openSend :theReceive :testerPort];

        ampsSetpoint = 0;
		[statusText2 setStringValue:@"open circuit"];

        if(receiveLength)
         {
             theReceive[receiveLength] = 0;
             incomeString = [NSString stringWithCString:theReceive encoding:NSASCIIStringEncoding];
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
        NSString *commandString;
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
	if([commandString isEqualToString:@"loop"])	
	{
		NSArray *parts = [argumentString componentsSeparatedByString:@";"];
		NSCharacterSet *setty = [NSCharacterSet characterSetWithCharactersInString:@"<>"];
		
		int foo;
		
		if(loopStep > -1)//handle loop
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
			
			for (foo = 0; foo < numberOfSteps; ++ foo)
			{
				if([[[steps objectAtIndex:foo] stepID] intValue ] == loopStep)
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
	
    if(fyle)
    {
        [fyle closeFile];
        fyle = 0;
    }
	[statusText1 setStringValue:@"Run Stopped"];
    running = 0;
    
    //NSLog(@"stop, goddamn it");
}

- (void)updateThings
{
    NSArray *valuesArray;
    NSString *receiver = [self readSmallTesterBinary];
	NSString *voltsString, *ampsString;
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
					
					watts:latestAmps*latestVolts/10000;
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
		[statusText2 setStringValue:[NSString stringWithFormat:@"hmm, rcvd %d, %@",[receiver length], receiver]];
	
	if(running)
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
				
- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
	return (NSInteger)[steps count];
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
	NSString *isHeader = [[aTableColumn headerCell] stringValue];
	
	if([isHeader isEqualToString:@"Step"])
		return [[steps objectAtIndex:rowIndex] stepID];
	
	if([isHeader isEqualToString:@"Command"])
		return [[steps objectAtIndex:rowIndex] command];
	
	if([isHeader isEqualToString:@"Argument"])
		return [[steps objectAtIndex:rowIndex] argument];
	
	if([isHeader isEqualToString:@"Setpoint"])
		return [[steps objectAtIndex:rowIndex] setpoint];
	
	if([isHeader isEqualToString:@"Duration"])
		return [[steps objectAtIndex:rowIndex] stepDuration];
	
	if([isHeader isEqualToString:@"End Type"])
		return [[steps objectAtIndex:rowIndex] endType];
	
	if([isHeader isEqualToString:@"Criterion"])
		return [[steps objectAtIndex:rowIndex] criterion];
	
	if([isHeader isEqualToString:@"Target Value"])
		return [[steps objectAtIndex:rowIndex] targetValue];
	
	if([isHeader isEqualToString:@"Acquire interv"])
		return [[steps objectAtIndex:rowIndex] readInterval];
	
	if([isHeader isEqualToString:@"Log interv"])
		return [[steps objectAtIndex:rowIndex] logInterval];
	
	if([isHeader isEqualToString:@"Flag"])
		return [[steps objectAtIndex:rowIndex] flag];
}

- (void)tableView:(NSTableView *)aTableView setObjectValue:(id)anObject forTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
}


- (IBAction)openSequenceFile:(id)sender
{
    SEL selector;
	NSWindow *theWin = 0;
	NSArray *theArray = 0;
	NSWindowController *winC = 0;
	
	theArray = [self windowControllers];
	winC = [theArray objectAtIndex:0];
	theWin = [winC window];
	
	
	open = [[NSOpenPanel openPanel] retain];
	
    selector =  @selector(openSequenceFilePanelDidEnd:returnCode:contextInfo:);
	
	//	[open beginSheetForDirectory:nil file:nil types:nil modelessDelegate:self didEndSelector:selector contextInfo:(void *)nil];
	[open beginSheetForDirectory:nil file:nil types:nil modalForWindow:theWin modalDelegate:self didEndSelector:selector contextInfo:nil];
	//what = [open runModalForDirectory:nil file:nil];
	
}
- (void)openSequenceFilePanelDidEnd:(NSOpenPanel *)panel returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
    if (returnCode == NSOKButton) 
	{
		int i, foo, isInit = 0;
		NSError **whatError;
		NSString *theString = [[NSString stringWithContentsOfFile:[[panel filenames] objectAtIndex:0] encoding:NSUTF8StringEncoding error:whatError] stringByReplacingOccurrencesOfString:@"," withString:@", "];
		NSArray *lineArray = [theString componentsSeparatedByString:@"\r\n"];
		OldStep *stepWise;
		//NSString *lineString = [NSString stringWithString: [lineArray objectAtIndex:2]];
		NSArray *theArray;
		NSMutableArray *newArray, *oldArray;
		
		//NSLog(@"lineString = %@",lineString);
		
		//NSLog(@"%d objects in LineArray",[lineArray count]);
		
		foo = [lineArray count];
		
		numberOfSteps = foo - 3;
		
		for(i = 2; i < foo; ++i)
		{
			theArray = [[lineArray objectAtIndex:i]  componentsSeparatedByString:@","];
			if([theArray count] == 11)
			{
				stepWise = [[OldStep alloc] initWithArray:theArray];
				
				
				if(isInit)
					[newArray addObject:stepWise];
				else
				{
					newArray = [NSMutableArray arrayWithObject:stepWise];
					isInit = 1;
				}
				
				//NSLog(@"oops on line %d",i);
			}
			//else 
			//	NSLog(@"oops on line %d, %d objects",i, [theArray count]);
		}
		/* */
		oldArray = steps;
		steps = newArray;
		[newArray retain];
		[oldArray release];
		
		[theTable reloadData];
		[open release];
		
		[theTable selectRowIndexes:0 byExtendingSelection:FALSE];
		
		loopStep = -1;
		loopRepeats = -1;
		loopDoneJumpToStep = -1;
		
	}
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
    unsigned long long offset;                                  // a variable to hold the file read/write position
    NSData *data;
    
	
    offset = [fyle seekToEndOfFile];    // set the write position to the end of the file (the variable offset doesn't actually do anything, it's just a receiver)
	
    string = [NSString stringWithFormat:@"\n"];     // put in a newline
    data = [string dataUsingEncoding:NSMacOSRomanStringEncoding];    // put it into ascii format
    [fyle writeData: data];             // write the data
    offset = [fyle seekToEndOfFile];    // set the write position to the end of the file
	
    data = [writeString dataUsingEncoding:NSMacOSRomanStringEncoding];
    [fyle writeData: data]; 
    offset = [fyle seekToEndOfFile];
	
	//	NSLog(@"wrote");
}

- (IBAction)nameAndStartSaveLogFile:(id)sender
{
    NSFileManager *fm = [NSFileManager defaultManager];     // get the default file manager
    NSString *defaultDirectoryPath = @"~/Desktop";
    NSString  *defaultName = @"Log File";
    NSSavePanel *savePanel = [NSSavePanel savePanel];
    NSString *headerString;
    NSData *data;
    BOOL success = false;
    NSCalendarDate *now = [NSCalendarDate calendarDate];
    NSString *datestr;
    
    datestr = [now descriptionWithCalendarFormat:@"%m%d%y %I%M%S%p"];
    headerString = [NSString stringWithFormat:@"time\telapsed Time\tvolts\tamps"];
    data = [headerString dataUsingEncoding:NSUTF8StringEncoding];        // put it into ascii format
    defaultDirectoryPath = [defaultDirectoryPath stringByExpandingTildeInPath];
    defaultName = [NSString stringWithFormat:@"Log File %@",datestr];
    
    if( [savePanel runModalForDirectory:defaultDirectoryPath file:defaultName] == NSFileHandlingPanelOKButton )
    {
        NSString *fullFileName = [NSString stringWithFormat:@"%@.txt",[[savePanel URL] path]];
//        NSLog(fullFileName);
        
        success = [fm createFileAtPath: fullFileName contents: data attributes: nil];
        if(success)  // we were successful? Then party on!
        {
            fyle = [NSFileHandle fileHandleForWritingAtPath:fullFileName];      // get the handle to the newly created file
            [fyle retain];
            
            if(runTime) // we had a previous file created
                [runTime release];
            runTime = [[NSDate date] retain];
            stepRunTime = [[NSDate date] retain];
            running = 1;
            [statusText1 setStringValue:@"Run Started"];
            
            currentStep = 0;
            loopStep = -1;
            loopRepeats = -1;
            loopDoneJumpToStep = -1;
            [self doNextStep];
        }
    }
    else
        NSLog(@" Cancel!");
}
-(NSString *)readSmallTesterBinary
{
	unsigned char binSend[] = {'b','\r'};
	unsigned char binReceive[5];
    unsigned char theReceive[100];
    int success, receiveLength = 1;
    NSString *stringy;
    
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
    NSString *incomeString;
    unsigned char theReceive[100];
    int receiveLength;
    
	[csp writePort:lengths :theSent :testerPort];
	receiveLength = [csp readAndWrite:lengths :4 :theSent :theReceive :testerPort];

    theReceive[receiveLength] = 0;
    incomeString = [NSString stringWithCString:theReceive encoding:NSASCIIStringEncoding];

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
	NSString *portName;
	
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

	if([newSerialMenu numberOfItems])	// we found some ports
	{
		[menuDescription setStringValue:@"Choose a serial port:"];
		[newSerialMenu setHidden: false];
		[okButton setHidden:false];
		[menuDescription setHidden:false];

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
		
		[menuDescription setStringValue:[[NSAttributedString alloc] initWithString:
		@"USB-Serial converter has been unplugged! Please plug it back into computer!"
		attributes:attr]];
		[newSerialMenu setHidden: true];
		[okButton setHidden:true];
		[menuDescription setHidden:false];
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
	if(fyle)
	{
		[fyle closeFile];
		[fyle release];
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

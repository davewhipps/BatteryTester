//
//  BatteryTesterSequence.m
//  BatteryTester
//
//  Created by Dave Whipps on 2015-09-22.
//
//

#import "BatteryTesterSequence.h"


@implementation BatteryTesterSequence

// Constants
NSString* HeaderRow = @"StepID	cmd	arg	SP	time	endtyp	endamt	target log	comments,,,,,,,,,";
NSString* HeaderMarker = @"StepID	cmd	arg	SP	time	endtyp	endamt	target log	comments";
NSString* CommentRow = @"##Your comments here,,,,,,,,,";
NSString* CommentMarker = @"#";

- (id)init
{
    self = [super init];
    if (self) {
        NSString *realString = @"StepID,Cmd,Arg,SP,Duration,EndType,Criterion,TargetVal,DaqIntrv,LogIntrv,Flag";
        NSArray *theArray = [realString componentsSeparatedByString:@","];
        // We need this array around for the duration. Retain.
        steps = [[NSMutableArray arrayWithObjects:[[OldStep alloc] initWithArray:theArray], nil] retain];
    }
    
    return self;
}

- (void)dealloc
{
    [self clearAndReleaseAllSteps];
    [steps release],
    steps = nil;
    [super dealloc];
}

- (void) clearAndReleaseAllSteps
{
    if (steps) {
        for (OldStep* aStep in steps) {
            [aStep release];
            aStep = nil;
        }
        [steps removeAllObjects];
    }
}

-(NSString*) stringForAttribute:(NSString*)selectorString atIndex:(NSInteger)index {
    NSString* resultString = nil;
    if (steps) {
        SEL selector = NSSelectorFromString(selectorString);
       
        NSObject* step = nil;
        if (index < [steps count])
            step = [steps objectAtIndex:index];
        
        if (step && selector && [step respondsToSelector:selector]) {
            resultString = [[step performSelector:selector] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        }
    }
    return resultString;
}

- (void) writeToURL:(NSURL*)outURL
{
    NSMutableArray* stepsStringArray = [NSMutableArray arrayWithCapacity:[steps count]];
    
    // Add the comments and header rows
    [stepsStringArray addObject:CommentRow];
    [stepsStringArray addObject:HeaderRow];
    
    [steps enumerateObjectsUsingBlock:^(id object, NSUInteger idx, BOOL *stop) {
        [stepsStringArray addObject:[(OldStep*)object toCSVString]];
    }];
    
    NSString* csvString = [stepsStringArray componentsJoinedByString:@"\r\n"]; // Use old CR LF for backwards compatibility
    
    NSError* whatError = nil;
    [csvString writeToURL:outURL atomically:YES encoding:NSUTF8StringEncoding error:&whatError];
}


- (void)initWithContentsOfURL:(NSURL*)inURL;
{
    NSError* whatError = nil;
    NSString* theString = [[NSString stringWithContentsOfURL:inURL encoding:NSUTF8StringEncoding error:&whatError] stringByReplacingOccurrencesOfString:@"," withString:@", "];
    

    NSArray* lineArray = [theString componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    NSMutableArray* newArray = [NSMutableArray array];
    
    [self clearAndReleaseAllSteps];
    for (NSString* lineString in lineArray)
    {
        // Check for comment line(s)
        if ([lineString hasPrefix:CommentMarker])
            continue;
        
        // Check for header line
        if ([lineString hasPrefix:HeaderMarker])
            continue;
        
        // Otherwise we have a step row (ensure correct number of fields)
        NSArray* lineComponents = [lineString  componentsSeparatedByString:@","];
        if ([lineComponents count] == 11)
        {
            [newArray addObject:[[OldStep alloc] initWithArray:lineComponents]];
        }
    }
    
    [steps addObjectsFromArray:newArray];
}

- (NSInteger) numberOfSteps
{
    if (steps)
        return [steps count];
    return 0;
}


#pragma mark NSTableViewDataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
	return (NSInteger)[steps count];
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
	NSString* isHeader = [[aTableColumn headerCell] stringValue];
	
    if (!steps || [steps objectAtIndex:rowIndex] == nil)
        return nil;
    
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
    
    return nil;
}

- (void)tableView:(NSTableView *)aTableView setObjectValue:(id)anObject forTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
	NSString *isHeader = [[aTableColumn headerCell] stringValue];

    if (!steps || [steps objectAtIndex:rowIndex] == nil)
        return;
	
	if ([isHeader isEqualToString:@"Step"])
        [[steps objectAtIndex:rowIndex] setStepID: anObject];
	
	if ([isHeader isEqualToString:@"Command"])
		[[steps objectAtIndex:rowIndex] setCommand: anObject];
	
	if ([isHeader isEqualToString:@"Argument"])
		[[steps objectAtIndex:rowIndex] setArgument: anObject];
	
	if ([isHeader isEqualToString:@"Setpoint"])
		[[steps objectAtIndex:rowIndex] setSetpoint: anObject];
	
	if ([isHeader isEqualToString:@"Duration"])
		[[steps objectAtIndex:rowIndex] setStepDuration: anObject];
	
	if ([isHeader isEqualToString:@"End Type"])
		[[steps objectAtIndex:rowIndex] setEndType: anObject];
	
	if ([isHeader isEqualToString:@"Criterion"])
		[[steps objectAtIndex:rowIndex] setCriterion: anObject];
	
	if ([isHeader isEqualToString:@"Target Value"])
		[[steps objectAtIndex:rowIndex] setTargetValue: anObject];
	
	if ([isHeader isEqualToString:@"Acquire interv"])
		[[steps objectAtIndex:rowIndex] setReadInterval: anObject];
	
	if ([isHeader isEqualToString:@"Log interv"])
		[[steps objectAtIndex:rowIndex] setLogInterval: anObject];
	
	if ([isHeader isEqualToString:@"Flag"])
		[[steps objectAtIndex:rowIndex] setFlag: anObject];
}


@end

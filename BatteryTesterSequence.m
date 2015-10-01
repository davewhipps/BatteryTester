//
//  BatteryTesterSequence.m
//  BatteryTester
//
//  Created by Dave Whipps on 2015-09-22.
//
//

#import "BatteryTesterSequence.h"

@implementation BatteryTesterSequence

@synthesize numberOfSteps;

- (id)init
{
    NSString *realString = @"StepID,Cmd,Arg,SP,Duration,EndType,Criterion,TargetVal,DaqIntrv,LogIntrv,Flag";
	NSArray *theArray = [realString componentsSeparatedByString:@","];
	steps = [[NSMutableArray arrayWithObjects:[[OldStep alloc] initWithArray:theArray], nil] retain];

    return self;
}

-(NSString*) stringForAttribute:(NSString*)selectorString atIndex:(NSInteger)index {
    NSString* resultString = nil;
    if (steps) {
        SEL selector = NSSelectorFromString(selectorString);
        NSObject* step = [steps objectAtIndex:index];
        if (step && selector && [step respondsToSelector:selector]) {
            resultString = [[step performSelector:selector] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        }
    }
    return resultString;
}

- (void) writeToURL:(NSURL*)outURL
{
    NSMutableArray* stepsStringArray = [NSMutableArray arrayWithCapacity:[steps count]];
    
    [steps enumerateObjectsUsingBlock:^(id object, NSUInteger idx, BOOL *stop) {
        [stepsStringArray addObject:[(OldStep*)object toCSVString]];
    }];
    
    NSString* csvString = [stepsStringArray componentsJoinedByString:@"\n"];
    
    NSError* whatError = nil;
    [csvString writeToURL:outURL atomically:YES encoding:NSUTF8StringEncoding error:&whatError];
}


- (void)initWithContentsOfURL:(NSURL*)inURL;
{
    int i, foo, isInit = 0;

    NSError* whatError = nil;
    NSString *theString = [[NSString stringWithContentsOfURL:inURL encoding:NSUTF8StringEncoding error:&whatError] stringByReplacingOccurrencesOfString:@"," withString:@", "];
    
    NSArray *lineArray = [theString componentsSeparatedByString:@"\r\n"];
    OldStep *stepWise;
    //NSString *lineString = [NSString stringWithString: [lineArray objectAtIndex:2]];
    
    NSArray *theArray;
    NSMutableArray *newArray, *oldArray;
    
    //NSLog(@"lineString = %@",lineString);
    
    //NSLog(@"%d objects in LineArray",[lineArray count]);
    
    foo = [lineArray count];
    
    numberOfSteps = foo - 3;
    
    for (i = 2; i < foo; ++i)
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
    
}

#pragma mark NSTableViewDataSource

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
    
    return nil;
}

- (void)tableView:(NSTableView *)aTableView setObjectValue:(id)anObject forTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
	NSString *isHeader = [[aTableColumn headerCell] stringValue];
	
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

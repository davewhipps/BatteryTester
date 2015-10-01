//
//  OldStep.h
//  SingleCellFlowBatteryTester
//
//  Created by Dave Sopchak on 3/5/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface OldStep : NSObject
{
	NSString *readInterval, *logInterval;	// read as ints
	NSString  *stepID,*command, *argument,*endType, *criterion,*flag;
	NSString  *setpoint, *targetValue;	// read as floats
	NSString *loopStepID, *loopRepeatTimes;	// read as ints
	NSString *stepDuration;						// read as int
}

@property (copy, readwrite) NSString *stepID;
@property (copy,readwrite) NSString *command;
@property (copy,readwrite) NSString *argument;
@property (copy, readwrite) NSString *setpoint;
@property (copy, readwrite) NSString *stepDuration;
@property (copy,readwrite) NSString *endType;
@property (copy,readwrite) NSString *criterion;
@property (copy, readwrite) NSString *targetValue;
@property (copy, readwrite) NSString *readInterval;
@property (copy, readwrite) NSString *logInterval;
@property (copy,readwrite) NSString *flag;
@property (copy, readwrite) NSString *loopStepID;
@property (copy, readwrite) NSString *loopRepeatTimes;
/*
-(OldStep *)initWithStepID:(int)theID cmd:(NSString *)theCmd arg:(NSString *)theArg set:(float)theSetpoint time:(int)theDuration endType:(NSString *)theEnd crit:(NSString *)theCriterion target:(float)theTargetAmt readEvery:(int)readInt logEvery:(int)theLog flag:(NSString *)theFlag;
 */

-(OldStep *)initWithArray:(NSArray *)theArray;
-(NSString *)toCSVString;

@end

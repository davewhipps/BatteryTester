//
//  OldStep.m
//  SingleCellFlowBatteryTester
//
//  Created by Dave Sopchak on 3/5/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "OldStep.h"

@implementation OldStep

@synthesize stepID;
@synthesize command;
@synthesize argument;
@synthesize setpoint;
@synthesize stepDuration;
@synthesize endType;
@synthesize criterion;
@synthesize targetValue;
@synthesize readInterval;
@synthesize logInterval;
@synthesize flag;
@synthesize loopStepID;
@synthesize loopRepeatTimes;
/*
-(OldStep *)initWithStepID:(int)theID cmd:(NSString *)theCmd arg:(NSString *)theArg set:(float)theSetpoint time:(int)theDuration endType:(NSString *)theEnd crit:(NSString *)theCriterion target:(float)theTargetAmt readEvery:(int)readInt logEvery:(int)theLog flag:(NSString *)theFlag
{
	
	self.stepID = theID;
	self.command = [NSString stringWithString:theCmd];
	self.argument = [NSString stringWithString:theArg];
	self.setpoint = theSetpoint;
	self.duration = theDuration;
	self.endType = [NSString stringWithString:endType];
	self.criterion = [NSString stringWithString:criterion];
	self.targetValue = theTargetAmt;
	self.readInterval = readInt;
	self.logInterval = theLog;
	self.flag = [NSString stringWithString:theFlag];
	
	return self;
}
*/
-(OldStep *)initWithArray:(NSArray *)theArray
{
	
	self.stepID = [NSString stringWithString:[theArray objectAtIndex:0]];
	self.command = [NSString stringWithString:[theArray objectAtIndex:1]];
	self.argument = [NSString stringWithString:[theArray objectAtIndex:2]];
	self.setpoint = [NSString stringWithString:[theArray objectAtIndex:3]];
	self.stepDuration = [NSString stringWithString:[theArray objectAtIndex:4]];
	self.endType = [NSString stringWithString:[theArray objectAtIndex:5]];
	self.criterion = [NSString stringWithString:[theArray objectAtIndex:6]];
	self.targetValue = [NSString stringWithString:[theArray objectAtIndex:7]];
	self.readInterval = [NSString stringWithString:[theArray objectAtIndex:8]];
	self.logInterval = [NSString stringWithString:[theArray objectAtIndex:9]];
	self.flag = [NSString stringWithString:[theArray objectAtIndex:10]];
	
	return self;
}

@end

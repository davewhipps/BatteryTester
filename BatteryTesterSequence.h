//
//  BatteryTesterSequence.h
//  BatteryTester
//
//  Created by Dave Whipps on 2015-09-22.
//
//

#import <Foundation/Foundation.h>
#import "OldStep.h"

@interface BatteryTesterSequence : NSObject <NSTableViewDataSource>
{
    NSMutableArray* steps;
}

@property (atomic, readonly) NSInteger numberOfSteps;

- (void) initWithContentsOfURL:(NSURL*)inURL;
- (void) writeToURL:(NSURL*)outURL;

-(NSString*) stringForAttribute:(NSString*) selectorString atIndex:(NSInteger)index;

@end

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

- (void) clearAndReleaseAllSteps;
- (void) initWithContentsOfURL:(NSURL*)inURL;
- (void) writeToURL:(NSURL*)outURL;
- (NSInteger) numberOfSteps;

-(NSString*) stringForAttribute:(NSString*) selectorString atIndex:(NSInteger)index;

@end

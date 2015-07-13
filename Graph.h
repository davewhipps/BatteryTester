/* Graph */
#define UPDATEINTERVAL 2
#define GRAPHDATAMINUTES 50
#import <Cocoa/Cocoa.h>
#import "SM2DGraphView.h"

@class SM2DGraphView;

@interface Graph : NSObject
{
    IBOutlet SM2DGraphView	*theGraph;

    float				pointNumber;
	NSMutableArray		*arrayOfArrays;
//	NSMutableArray		*voltsArray,*ampsArray,*wattsArray,*netWattsArray,*parasiticArray,*fcTempArray,*fpTempArray,*timeArray;
//	NSMutableArray		*fuelFlowArray, *burnerFlowArray, *h2UtilArray, *o2UtilArray, *airFlowArray, *burnerStoichArray;
//	NSMutableArray		*minVoltsArray, *maxVoltsArray,*ambientTempArray, *batVoltsArray;
	
	float ourMinX, ourMinY, ourMaxX,ourMaxY;
	
	IBOutlet NSMatrix *toGraph;
	
	int isNotDashboard;
	
}

- (void)drawPoints:(NSArray *)points;

- (void)initGraphs;
- (void)autoRangeOneY:(NSArray *)array;
//- (void)maxValues:(NSArray *)array;
- (IBAction)autoRangeY:(id)sender;
- (IBAction)resetGraph:(id)sender;

- (float)ourMinY;
- (void)setOurMinY:(float)foo;
- (float)ourMaxY;
- (void)setOurMaxY:(float)foo;


@end

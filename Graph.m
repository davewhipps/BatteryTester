#import "Graph.h"

@implementation Graph

- (void)dealloc
{
    // Release our objects.
	[arrayOfArrays release];

    [ super dealloc ];
}

- (void)awakeFromNib
{
	[theGraph setNumberOfTickMarks:6 forAxis:0];
	[theGraph setNumberOfMinorTickMarks:4 forAxis:0];
	[theGraph setNumberOfTickMarks:6 forAxis:1];
	[theGraph setNumberOfMinorTickMarks:4 forAxis:1];
	[theGraph setDrawsGrid:TRUE];
	[theGraph setLabel:@"elapsed time(minutes)" forAxis:1]; 
	pointNumber = 0;
	ourMinX= 0;
	[self setOurMinY: 0]; 
	ourMaxX= 1;
	[self setOurMaxY: 5];
	[self initGraphs];
//		if([[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleSignature"] isEqualToString: @"Ucel"])// Dashboard
//			isNotDashboard = 0;
//		else 
			isNotDashboard = 1;
}

- (void)initGraphs
{
	int i = 0;
	
	arrayOfArrays = [[NSMutableArray arrayWithCapacity:5] retain];
	
	for(i = 0; i < 5 ; ++i)
		[arrayOfArrays addObject:[NSMutableArray arrayWithCapacity:0]];
}


- (void)drawPoints:(NSArray *)points
{
	NSRange homeOnTheRange = {0,1};
	int i, totalPoints =  GRAPHDATAMINUTES * 60/UPDATEINTERVAL;//[[NSUserDefaults standardUserDefaults] integerForKey:@"dataGraphMinutes"] * (60/UPDATEINTERVAL);
	int numberOfCurves = 5;

	
		for(i = 0; i < numberOfCurves; ++i)
			[[arrayOfArrays objectAtIndex:i] addObject: NSStringFromPoint(NSMakePoint(pointNumber/(60/UPDATEINTERVAL),[[points objectAtIndex:i] floatValue]))];
	
	pointNumber +=1;

	if([[arrayOfArrays objectAtIndex:0] count] > totalPoints)
	{
		homeOnTheRange.length = [[arrayOfArrays objectAtIndex:0] count] - totalPoints;
		for(i = 0; i < numberOfCurves; ++i)
			[[arrayOfArrays objectAtIndex:i] removeObjectsInRange:homeOnTheRange];
	}

	[ theGraph reloadData ];
	[ theGraph refreshDisplay:self];
}

- (void)autoRangeOneY:(NSArray *)array
{
	NSEnumerator *enumerator;
	NSNumber *maxY = [NSNumber numberWithDouble:[self ourMaxY]];
	NSNumber *minY = [NSNumber numberWithDouble:[self ourMinY]];
	NSNumber*valueY;
	NSString *stringPoint;
	NSPoint currentPoint;

	enumerator = [array objectEnumerator];
	
	if(stringPoint = [enumerator nextObject])
	{
		while(stringPoint)
		{
			currentPoint = NSPointFromString(stringPoint);
			valueY = [NSNumber numberWithFloat:currentPoint.y];
			if([maxY compare:valueY] == NSOrderedAscending)
				maxY = [NSNumber numberWithDouble:[valueY floatValue]];
			if([minY compare:valueY] == NSOrderedDescending)
				minY = [NSNumber numberWithDouble:[valueY floatValue]];
			stringPoint=[enumerator nextObject];		
		}

		if(ourMaxY < [maxY floatValue])
			ourMaxY = floor([maxY floatValue]) + 1;//floor([maxY floatValue] + (0.2 * [maxY floatValue] - ourMinY)) + 1;
		if(ourMinY > [minY floatValue])
			ourMinY = floor([minY floatValue]) - 1;//floor([minY floatValue] - (0.2 * ourMaxY - [minY floatValue])) - 1;
	}
	
	ourMinY = floor(ourMinY);
	ourMaxY = floor(ourMaxY);
}
- (IBAction)autoRangeY:(id)sender
{
	
	NSEnumerator *enumerator;
	NSString *stringPoint;
	NSPoint currentPoint;
    NSArray	*result = nil;
	int i, numberOfCurves = 5;
		
	// find first curve being drawn

	for(i = 0; i < numberOfCurves; ++i)
	{
		if([[toGraph cellAtRow:0 column:i] state])
		{	
			result = [arrayOfArrays objectAtIndex:i];
			NSLog(@"first curve found for first point, line %d",i);
			break;
		}
	}
	
	enumerator = [result objectEnumerator];
	stringPoint = [enumerator nextObject];
	currentPoint = NSPointFromString(stringPoint);

	[self setOurMaxY:currentPoint.y + 0.5];
	[self setOurMinY:currentPoint.y - 0.5];
	
	for(; i < numberOfCurves; ++i)
		if([[toGraph cellAtRow:0 column:i] state])
		{	
			[self autoRangeOneY:[arrayOfArrays objectAtIndex:i]];
			NSLog(@"curve found, line %d",i);
		}
		
	if(ourMaxY == ourMinY)
		ourMinY -=1;	// never have min and max equal!
	[self setOurMaxY:ourMaxY];
	[self setOurMinY:ourMinY];
}

- (IBAction)resetGraph:(id)sender
{
	[arrayOfArrays release];
	pointNumber = 0;
	[self initGraphs];
}
#pragma mark -
#pragma mark ¥ SM2DGRAPHVIEW DATASOURCE METHODS


- (unsigned int)numberOfLinesInTwoDGraphView:(SM2DGraphView *)inGraphView
{
        return 5;
}

- (NSArray *)twoDGraphView:(SM2DGraphView *)inGraphView dataForLineIndex:(unsigned int)inLineIndex
{
    NSArray	*result = nil;

	if([[toGraph cellAtRow:0 column:inLineIndex] state])
		result = [arrayOfArrays objectAtIndex:inLineIndex];
		
    return result;
}

- (double)twoDGraphView:(SM2DGraphView *)inGraphView maximumValueForLineIndex:(unsigned int)inLineIndex
            forAxis:(SM2DGraphAxisEnum)inAxis
{
	if ( inAxis == kSM2DGraph_Axis_X )
		return floor(pointNumber/(60/UPDATEINTERVAL)) + 1; //ourMaxX;
	else
		return ourMaxY;
}

- (double)twoDGraphView:(SM2DGraphView *)inGraphView minimumValueForLineIndex:(unsigned int)inLineIndex
            forAxis:(SM2DGraphAxisEnum)inAxis
{
    double result = 0;
	double totalPoints = GRAPHDATAMINUTES * 60/UPDATEINTERVAL;//[[NSUserDefaults standardUserDefaults] integerForKey:@"dataGraphMinutes"] * (60/UPDATEINTERVAL);	
//	[self minValues:fpTempArray];
	
	if ( inAxis == kSM2DGraph_Axis_X )
		result = pointNumber < totalPoints ? 0 : floor((pointNumber - totalPoints)/(60/UPDATEINTERVAL)) + 1;//ourMinX;
	else if(isNotDashboard)
		result = ourMinY;

    return result;
}

- (NSDictionary *)twoDGraphView:(SM2DGraphView *)inGraphView attributesForLineIndex:(unsigned int)inLineIndex
{
    NSDictionary	*result = nil;
	//NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

		switch(inLineIndex)
		{
			case 0:
				result = [NSDictionary dictionaryWithObjectsAndKeys:
					[NSColor blackColor], NSForegroundColorAttributeName,
					[ NSNumber numberWithInt:kSM2DGraph_Width_Wide ],
							SM2DGraphLineWidthAttributeName,
							nil ];
				break;
			case 1:
				result = [ NSDictionary dictionaryWithObjectsAndKeys:[NSColor greenColor], NSForegroundColorAttributeName,
					[ NSNumber numberWithInt:kSM2DGraph_Width_Wide ],SM2DGraphLineWidthAttributeName ,
                    nil ];
				break;
			case 2:
				result = [ NSDictionary dictionaryWithObjectsAndKeys:[NSColor blueColor], NSForegroundColorAttributeName,
						  [ NSNumber numberWithInt:kSM2DGraph_Width_Wide ],SM2DGraphLineWidthAttributeName ,nil ];
				break;
			case 3:
				result = [ NSDictionary dictionaryWithObjectsAndKeys:[NSColor colorWithDeviceRed:0.8 green:0 blue:0 alpha:1], NSForegroundColorAttributeName,
						  [ NSNumber numberWithInt:kSM2DGraph_Width_Wide ],SM2DGraphLineWidthAttributeName ,
                    nil ];
				break;
			case 4:
				result = [ NSDictionary dictionaryWithObjectsAndKeys:[NSColor magentaColor], NSForegroundColorAttributeName,
						  [ NSNumber numberWithInt:kSM2DGraph_Width_Wide ],SM2DGraphLineWidthAttributeName ,nil ];
				break;
			/**/		default:
				result = [ NSDictionary dictionaryWithObjectsAndKeys:
                    [NSColor orangeColor], NSForegroundColorAttributeName,
                    [ NSNumber numberWithBool:YES ], SM2DGraphDontAntialiasAttributeName,
					[ NSNumber numberWithInt:kSM2DGraph_Width_Normal ],SM2DGraphLineWidthAttributeName ,
                    nil ];
				break;
		}		
			return result;
}
- (float)ourMinY
{
	return ourMinY;
}
- (void)setOurMinY:(float)foo
{
	ourMinY = foo;
}
- (float)ourMaxY;
{
	return ourMaxY;
}
- (void)setOurMaxY:(float)foo
{
	ourMaxY = foo;
}

@end

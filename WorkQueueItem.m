//
//  WorkQueueItem.m
//  TiVo Butler
//
//  Created by Eric Baur on 2/7/08.
//  Copyright 2008 Eric Shore Baur. All rights reserved.
//

#import "WorkQueueItem.h"


@implementation WorkQueueItem

- (void)awakeFromInsert
{
	ENTRY;
	self.addedDate = [NSDate date];
}

#pragma mark -
#pragma mark Accessor methods

@dynamic active;
@dynamic addedDate;
@dynamic completedDate;
@dynamic name;
@dynamic startedDate;
@dynamic receivedBytes;

@dynamic program;

- (NSNumber *)active
{
	if ( nil==self.completedDate && nil!=self.startedDate )
		return [NSNumber numberWithBool:YES];
	else
		return [NSNumber numberWithBool:NO];
}

- (NSString *)name
{
	if ( nil != self.program) {
		return self.program.title;
	} else {
		return @"";
	}
}

- (void)addByteLength:(int)length
{
	[self willChangeValueForKey:@"receivedBytes"];
	receivedBytes += length;
	[self didChangeValueForKey:@"receivedBytes"];
}

@end

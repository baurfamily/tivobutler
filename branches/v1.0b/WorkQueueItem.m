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

- (BOOL)canRemove
{
	if ( [self.active boolValue] ) {
		return NO;
	} else {
		return YES;
	}
}

#pragma mark -
#pragma mark Accessor methods

@dynamic active;
@dynamic addedDate;
@dynamic completedDate;
@dynamic message;
@dynamic startedDate;
@dynamic savedPath;

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

@end

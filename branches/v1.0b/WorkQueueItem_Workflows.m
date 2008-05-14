//
//  WorkQueueItem_Workflows.m
//  TiVo Butler
//
//  Created by Eric Baur on 5/10/08.
//  Copyright 2008 Eric Shore Baur. All rights reserved.
//

#import "WorkQueueItem.h"

@implementation WorkQueueItem (Workflows)

- (void)completeWithMessage:(NSString *)message
{
	//TODO: need to cascade down to the current step
	if ( message )
		self.message = message;
	self.completedDate = [NSDate date];
}

@end

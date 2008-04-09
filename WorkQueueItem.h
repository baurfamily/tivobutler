//
//  WorkQueueItem.h
//  TiVo Butler
//
//  Created by Eric Baur on 2/7/08.
//  Copyright 2008 Eric Shore Baur. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "TiVoProgram.h"

@interface WorkQueueItem : NSManagedObject {
	int receivedBytes;
}

- (BOOL)canRemove;

@property (retain) NSNumber * active;
@property (retain) NSDate * addedDate;
@property (retain) NSDate * completedDate;
@property (retain) NSString * message;
@property (retain) NSDate * startedDate;
@property (retain) NSString * savedPath;

@property (retain) TiVoProgram * program;

@end


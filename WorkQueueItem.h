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
	NSURLDownload *programDownload;
	int receivedBytes;
}

- (void)beginDownload;

@property (retain) NSNumber * active;
@property (retain) NSDate * addedDate;
@property (retain) NSDate * completedDate;
@property (retain) NSString * name;
@property (retain) NSDate * startedDate;

@property (retain) TiVoProgram * program;

@end


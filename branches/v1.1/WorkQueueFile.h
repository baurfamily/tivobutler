//
//  WorkQueueFile.h
//  TiVo Butler
//
//  Created by Eric Baur on 5/8/08.
//  Copyright 2008 Eric Shore Baur. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "EntityToken.h"
#import "TiVoProgram.h"
#import "WorkQueueStep.h"

#import "EntityTokenFieldValueTransformer.h"

@class WorkQueueItem;
@class WorkQueueStep;

typedef enum {
	WQFileExistsAction_MIN = 0,
	WQFileExistsChangeNameAction = WQFileExistsAction_MIN,
	WQFileExistsFailAction,
	WQFileExistsOverwriteAction,
	WQFileExistsAction_MAX = WQFileExistsOverwriteAction
} WQFileExistsAction;


@interface WorkQueueFile : NSManagedObject {

}

@property (readonly) NSString * extension;
@property (readonly) NSString * filename;
@property (retain) NSString * path;

@property (retain) WorkQueueStep * readerStep;
@property (retain) WorkQueueStep * writerStep;

- (BOOL)checkAndCreateDirectories;
- (void)removeFile;

@end

@interface WorkQueueFile (CoreDataGeneratedPrimitiveAccessors)

- (NSString *)primitivePath;
- (void)setPrimitivePath:(NSString *)value;

@end

#import "WorkQueueItem.h"
#import "WorkQueueStep.h"
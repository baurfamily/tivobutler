//
//  WorkQueueItem.h
//  TiVo Butler
//
//  Created by Eric Baur on 2/7/08.
//  Copyright 2008 Eric Shore Baur. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "EntityHelper.h"

#import "SmartGroup.h"
#import "TiVoProgram.h"
#import "WorkQueueStep.h"

@class WorkQueueFile;

typedef enum {
	WQSourceType_MIN = 0,
	WQAutoGeneratedSourceType = WQSourceType_MIN,
	WQUserInitSourceType,
	WQScheduledSourceType,
	WQSourceType_MAX = WQScheduledSourceType
} WQSourceType;

#define WQAutoGeneratedSourceString	@"Auto Generated"
#define WQUserInitSourceString		@"User Initialized"
#define WQScheduledSourceString		@"Scheduled"

@interface WorkQueueItem : NSManagedObject {
	WorkQueueStep *firstStep;
}

- (BOOL)canRemove;

@property (retain) NSNumber * active;
@property (retain) NSDate * addedDate;
@property (retain) NSDate * completedDate;
@property (retain) NSString * message;
@property (readonly) NSString * sourceName;
@property (retain) NSNumber * sourceType;
@property (retain) NSDate * startedDate;
@property (retain) NSString * savedPath;
@property (retain) NSNumber * successful;

@property (retain) WorkQueueStep * currentStep;
@property (retain) TiVoProgram * program;
@property (retain) SmartGroup * smartGroup;
@property (retain) NSSet* steps;

@end

@interface WorkQueueItem (CoreDataGeneratedPrimitiveAccessors)

- (NSNumber *)primitiveSourceType;
- (void)setPrimitiveSourceType:(NSNumber *)value;

- (TiVoProgram *)primitiveProgram;
- (void)setPrimitiveProgram:(TiVoProgram *)value;

@end

@interface WorkQueueItem (Workflows)

- (void)beginProcessing;

- (void)completeWithMessage:(NSString *)message;

- (WorkQueueStep *)addStepOfType:(WQAction)action afterStep:(WorkQueueStep *)prevStep;

- (void)completedStep:(WorkQueueStep *)completedStep successful:(BOOL)successful;

@end

#import "WorkQueueFile.h"

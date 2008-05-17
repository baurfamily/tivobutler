//
//  WorkQueueStep.h
//  TiVo Butler
//
//  Created by Eric Baur on 5/13/08.
//  Copyright 2008 Eric Shore Baur. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "TiVoProgram.h"

@class WorkQueueItem;
@class WorkQueueFile;

typedef enum {
	WQAction_MIN = -1,
	WQNoAction = WQAction_MIN,
	WQDownloadAction,
	WQDecodeAction,
	WQConvertAction,
	WQPostProcessAction,
	WQAction_MAX = WQPostProcessAction
} WQAction;

#define WQNoActionExtension				@""
#define WQDownloadActionExtension		@".tivo"
#define WQDecodeActionExtension			@".mpg"
#define WQConvertActionExtension		@".mp4"
#define WQPostProcessActionExtension	nil

typedef enum {
	WQArgumentSubstitutionValue_MIN = 0,
	WQArgumentNone = WQArgumentSubstitutionValue_MIN,
	WQArgumentMAK,
	WQArgumentInputFile,
	WQArgumentOutputFile,
	WQArgumentSubstitutionValue_MAX = WQArgumentOutputFile
} WQArgumentSubstitutionValue;

@interface WorkQueueStep : NSManagedObject {
	NSURLDownload *programDownload;
	
	unsigned long long receivedBytes;
	unsigned long long expectedBytes;
	
	NSTask *queueTask;
	NSFileHandle *queueFileHandle;
}

@property (retain) NSNumber * actionType;
@property (retain) NSNumber * active;
@property (retain) NSDate * addedDate;
@property (retain) NSDate * completedDate;
@property (retain) NSNumber * currentActionPercent;
@property (retain) NSString * message;
@property (retain) NSNumber * shouldKeepInput;
@property (retain) NSDate * startedDate;

@property (retain) WorkQueueItem * item;
@property (retain) WorkQueueStep * nextStep;
@property (retain) WorkQueueStep * previousStep;
@property (retain) WorkQueueFile * readFile;
@property (retain) WorkQueueFile * writeFile;

- (void)setupWriteFile;

@end

@interface WorkQueueStep (CoreDataGeneratedPrimitiveAccessors)

- (NSNumber *)primitiveActionType;
- (void)setPrimitiveActionType:(NSNumber *)value;

- (WorkQueueItem *)primitiveItem;
- (void)setPrimitiveItem:(WorkQueueItem *)value;

@end

@interface WorkQueueStep (Workflows)

+ (NSDictionary *)workflowDefaults;

- (NSString *)stringForSubstitutionValue:(WQArgumentSubstitutionValue)substitutionValue;

- (void)beginProcessing;

- (void)beginDownload;
//- (void)setupDownloadPath;
- (void)removeFiles;
- (void)completeWithMessage:(NSString *)message;

- (void)beginDecode;
- (void)decodeReadAvailableData:(NSNotification *)notification;
- (void)decoderDidTerminate:(NSNotification *)notification;

- (void)beginConversion;
- (void)convertReadAvailableData:(NSNotification *)notification;
- (void)convertDidTerminate:(NSNotification *)notification;

@end

#import "WorkQueueFile.h"
#import "WorkQueueItem.h"

//
//  WorkQueueController.h
//  TiVo Butler
//
//  Created by Eric Baur on 2/7/08.
//  Copyright 2008 Eric Shore Baur. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "EntityHelper.h"

#import "TiVoProgram.h"
#import "SmartGroup.h"
#import "WorkQueueItem.h"

#import "WorkQueueDisplayController.h"

#import "EntityToken.h"
#import "EntityTokenFieldValueTransformer.h"
/*
typedef enum {
	WQFileExistsChangeNameAction = 0,
	WQFileExistsFailAction,
	WQFileExistsOverwriteAction
} WQFileExistsAction;
*/
typedef enum {
	WQAddedDateOrder = 0,
	WQRecordedDateOrder
} WQDateOrder;

#define WQAddedDateString		@"addedDate"
#define WQRecordedDateString	@"program.captureDate"

#define WQConvertActionString	@"Converting..."
#define WQDecodeActionString	@"Decoding..."
#define WQDownloadActionString	@"Downloading..."

@interface WorkQueueController : NSObject {

	NSManagedObjectContext *managedObjectContext;
	
	NSTimer *downloadCheckTimer;
	
	IBOutlet NSArrayController *programArrayController;
	IBOutlet NSArrayController *workQueueItemArrayController;

	NSURLDownload *programDownload;
	
	WorkQueueItem *currentItem;
	WQAction finalAction;
	WQAction currentAction;

	int currentActionPercent;
	unsigned long long receivedBytes;
	unsigned long long expectedBytes;
/*
	bool keepIntermediateFiles;
	NSString *downloadPath;
	NSString *decodePath;
	NSString *convertPath;
	
	NSTask *decodeTask;
	NSFileHandle *decodeFileHandle;
	
	NSTask *convertTask;
	NSFileHandle *convertFileHandle;
*/
	IBOutlet WorkQueueDisplayController *workQueueDisplayController;
}

- (IBAction)addSelection:(id)sender;
- (IBAction)showWorkQueueWindow:(id)sender;
- (IBAction)cancelDownload:(id)sender;

- (void)addPendingItemWithProgram:(TiVoProgram *)program;
- (void)checkForPendingItems;
- (void)checkForAutoDownloads;

//- (NSString *)endingFilePath;
- (BOOL)okayToDownload;
- (NSString *)pendingItemsSortKey;

- (int)maxActionDisplay;
- (int)currentActionDisplay;
- (NSString *)currentActionString;
- (BOOL)showActionProgress;
- (BOOL)showProgress;

@end
/*
@interface WorkQueueController (Workflows)

- (void)beginDownload;
- (void)setupDownloadPath;
- (void)removeFiles;
- (void)completeWithMessage:(NSString *)message;

- (void)beginDecode;
- (void)decodeReadAvailableData:(NSNotification *)notification;
- (void)decoderDidTerminate:(NSNotification *)notification;

- (void)beginConversion;
- (void)convertReadAvailableData:(NSNotification *)notification;
- (void)convertDidTerminate:(NSNotification *)notification;

@end
*/
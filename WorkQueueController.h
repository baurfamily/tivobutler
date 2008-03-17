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

typedef enum {
	WQConvertAction = 0,
	WQDecodeAction,
	WQDownloadOnlyAction,
	WQNoAction
} WQDownloadAction;

typedef enum {
	WQPromptOverwriteAction = 0,
	WQDontOverwriteAction,
	WQDoOverwriteAction
} WQOverwriteAction;

typedef enum {
	WQAddedDateOrder = 0,
	WQRecordedDateOrder
} WQDateOrder;

#define WQAddedDateString		@"addedDate"
#define WQRecordedDateString	@"recordedDate"

#define WQConvertActionString	@"Converting..."
#define WQDecodeActionString	@"Decoding..."
#define WQDownloadOnlyString	@"Downloading..."

@interface WorkQueueController : NSObject {

	NSManagedObjectContext *managedObjectContext;
	
	NSTimer *downloadCheckTimer;
	
	IBOutlet NSArrayController *programArrayController;
	IBOutlet NSArrayController *workQueueItemArrayController;
	
	NSURLDownload *programDownload;
	
	WorkQueueItem *currentItem;
	WQDownloadAction finalAction;
	WQDownloadAction currentAction;

	int currentActionPercent;
	unsigned long receivedBytes;
	unsigned long expectedBytes;

	NSString *downloadPath;
	NSString *decodePath;
	NSString *convertPath;
	
	NSTask *decodeTask;
	NSFileHandle *decodeFileHandle;
	NSTimer *decodeTimer;
	
	NSTask *convertTask;
	NSFileHandle *convertFileHandle;
	NSTimer *convertTimer;

	IBOutlet WorkQueueDisplayController *workQueueDisplayController;
}

- (IBAction)addSelection:(id)sender;
- (IBAction)showWorkQueueWindow:(id)sender;
- (IBAction)cancelDownload:(id)sender;

- (void)addPendingItemWithProgram:(TiVoProgram *)program;
- (void)checkForPendingItems;
- (void)checkForAutoDownloads;
- (void)beginDownload;
- (void)setupDownloadPath;

- (void)beginDecode;
- (void)decoderDidTerminate:(NSNotification *)notification;
- (void)decodeCheckDataAvailable:(NSTimer *)timer;

- (void)beginConversion;
- (void)convertDidTerminate:(NSNotification *)notification;
- (void)convertCheckDataAvailable:(NSTimer *)timer;

- (void)removeFiles;
- (void)completeWithMessage:(NSString *)message;

- (NSString *)endingFilePath;

- (BOOL)okayToDownload;
- (int)maxActionDisplay;
- (int)currentActionDisplay;
- (NSString *)currentActionString;
- (BOOL)showActionProgress;
- (BOOL)showProgress;
- (NSString *)pendingItemsSortKey;

@end

//
//  WorkQueueController.h
//  TiVo Butler
//
//  Created by Eric Baur on 2/7/08.
//  Copyright 2008 Eric Shore Baur. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "EntityHelper.h"
#import "WorkQueueItem.h"

typedef enum {
	WQConvertAction = 0,
	WQDecodeAction,
	WQDownloadOnlyAction
} WQDownloadAction;

typedef enum {
	WQPromptOverwriteAction = 0,
	WQDontOverwriteAction,
	WQDoOverwriteAction
} WQOverwriteAction;

#define WQDefaultWindowHeight	285
#define WQDefaultWindowWidth	454

@interface WorkQueueController : NSObject {

	NSManagedObjectContext *managedObjectContext;
	
	IBOutlet NSArrayController *programArrayController;
	IBOutlet NSArrayController *workQueueItemArrayController;
	
	NSURLDownload *programDownload;
	
	WorkQueueItem *currentItem;
	WQDownloadAction finalAction;
	WQDownloadAction currentAction;
	int currentActionPercent;
	
	int receivedBytes;

	NSString *downloadPath;
	NSString *decodePath;
	NSString *convertPath;
	
	NSTask *decodeTask;
	NSFileHandle *decodeFileHandle;
	NSTimer *decodeTimer;
	
	NSTask *convertTask;
	NSFileHandle *convertFileHandle;
	NSTimer *convertTimer;
	
	BOOL showCompletedItems;
	BOOL showWorkQueue;
	
	IBOutlet NSScrollView *workQueueScrollView;
	IBOutlet NSButton *showCompletedItemsCheckBox;
	IBOutlet NSWindow *workQueueWindow;
	NSSize oldWindowSize;
}

- (IBAction)addSelection:(id)sender;

- (void)beginDownload;
- (void)setupDownloadPath;

- (void)beginDecode;
- (void)decoderDidTerminate:(NSNotification *)notification;
- (void)decodeCheckDataAvailable:(NSTimer *)timer;

- (void)beginConversion;
- (void)convertDidTerminate:(NSNotification *)notification;
- (void)convertCheckDataAvailable:(NSTimer *)timer;

- (NSString *)endingFilePath;

- (int)maxActionDisplay;
- (int)currentActionDisplay;
- (BOOL)showActionProgress;

- (NSPredicate *)workQueuePredicate;

- (void)setShowCompletedItems:(BOOL)newValue;
- (void)setShowWorkQueue:(BOOL)newValue;

@end

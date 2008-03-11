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

@interface WorkQueueController : NSObject {

	NSManagedObjectContext *managedObjectContext;
	
	IBOutlet NSArrayController *programArrayController;
	IBOutlet NSArrayController *workQueueItemArrayController;
	
	NSURLDownload *programDownload;
	
	WorkQueueItem *currentItem;
	
	int receivedBytes;

	NSString *downloadPath;
	NSString *decodePath;
	NSString *convertPath;
	
	NSTask *decodeTask;
	NSFileHandle *decodeFileHandle;
	NSTask *convertTask;
	NSFileHandle *convertFileHandle;
}

- (IBAction)addSelection:(id)sender;

- (void)beginDownload;
- (void)setupDownloadPath;

- (void)beginDecode;
- (void)decodeDataAvailable:(NSNotification *)notification;

- (void)beginConversion;
- (void)convertDataAvailable:(NSNotification *)notification;

- (NSString *)endingFilePath;

@end

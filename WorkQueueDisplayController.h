//
//  WorkQueueDisplayController.h
//  TiVo Butler
//
//  Created by Eric Baur on 3/13/08.
//  Copyright 2008 Eric Shore Baur. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "EntityHelper.h"

#import "WorkQueueItem.h"
#import "WorkQueueStep.h"

#define WQScopeControlActiveTag		0
#define WQScopeControlPendingTag	1
#define WQScopeControlCompletedTag	2

#define WQDefaultWindowHeight	285
#define WQDefaultWindowWidth	454

#define WQRowHeightTitle		17.0
#define WQRowHeightFull			100.0

@interface WorkQueueDisplayController : NSObject {
	IBOutlet id workQueueController;
	
	IBOutlet NSWindow *workQueueWindow;
	IBOutlet NSSegmentedControl *workQueueScopeControl;
	IBOutlet NSOutlineView *workQueueOutlineView;
	
	IBOutlet NSWindow *addItemWindow;
	IBOutlet NSPathControl *addItemPathControl;
	
	NSArray *sortDescriptors;
	NSArray *workQueueItems;
}

- (IBAction)showWindow:(id)sender;

- (IBAction)showAddItemWindow:(id)sender;
- (void)chooseItemPanelDidEnd:(NSOpenPanel *)panel returnCode:(int)returnCode contextInfo:(void  *)contextInfo;
- (IBAction)endAddItemSheet:(id)sender;
- (void)addItemSheetDidEnd:(NSWindow *)panel returnCode:(int)returnCode contextInfo:(void  *)contextInfo;

- (IBAction)refreshOutlineView:(id)sender;


- (NSAttributedString *)attributedStringForItem:(WorkQueueItem *)item;
- (NSAttributedString *)attributedStringForStep:(WorkQueueStep *)step;

@end

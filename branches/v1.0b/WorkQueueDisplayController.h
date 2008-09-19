//
//  WorkQueueDisplayController.h
//  TiVo Butler
//
//  Created by Eric Baur on 3/13/08.
//  Copyright 2008 Eric Shore Baur. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "EntityHelper.h"

#import "WorkQueueStep.h"

#define WQDefaultWindowHeight	285
#define WQDefaultWindowWidth	454

#define WQRowHeightTitle		17.0
#define WQRowHeightFull			100.0

@interface WorkQueueDisplayController : NSObject {
	BOOL showCompletedItems;
	BOOL showWorkQueue;

	IBOutlet id workQueueController;
	
	IBOutlet NSScrollView *workQueueScrollView;
	IBOutlet NSWindow *workQueueWindow;
	IBOutlet NSButton *removeItemButton;
	
	IBOutlet NSOutlineView *workQueueStepsOutlineView;
	
	NSSize oldWindowSize;
	
	NSArray *sortDescriptors;
}

- (IBAction)showWindow:(id)sender;

- (void)setShowWorkQueue:(BOOL)newValue;

- (void)setItemsHidden:(BOOL)value;

@end

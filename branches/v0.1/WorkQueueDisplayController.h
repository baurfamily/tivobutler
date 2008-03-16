//
//  WorkQueueDisplayController.h
//  TiVo Butler
//
//  Created by Eric Baur on 3/13/08.
//  Copyright 2008 Eric Shore Baur. All rights reserved.
//

#import <Cocoa/Cocoa.h>


#define WQDefaultWindowHeight	285
#define WQDefaultWindowWidth	454

@interface WorkQueueDisplayController : NSObject {
	BOOL showCompletedItems;
	BOOL showWorkQueue;
	
	IBOutlet NSScrollView *workQueueScrollView;
	IBOutlet NSButton *showCompletedItemsCheckBox;
	IBOutlet NSWindow *workQueueWindow;
	IBOutlet NSButton *removeItemButton;
	
	NSSize oldWindowSize;
}

- (IBAction)showWindow:(id)sender;

- (NSPredicate *)workQueuePredicate;

- (void)setShowCompletedItems:(BOOL)newValue;
- (void)setShowWorkQueue:(BOOL)newValue;

- (void)setItemsHidden:(BOOL)value;

@end

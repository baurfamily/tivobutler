//
//  WorkQueueDisplayController.m
//  TiVo Butler
//
//  Created by Eric Baur on 3/13/08.
//  Copyright 2008 Eric Shore Baur. All rights reserved.
//

#import "WorkQueueDisplayController.h"


@implementation WorkQueueDisplayController

- (void)awakeFromNib
{
	//- assume the window is at its larger size and shrink it to start with
	[self setShowWorkQueue:NO];
}

- (IBAction)showWindow:(id)sender
{
	ENTRY;
	[workQueueWindow makeKeyAndOrderFront:self];
}

- (NSPredicate *)workQueuePredicate
{
	if ( showCompletedItems ) {
		return [NSPredicate predicateWithValue:TRUE];
	} else {
		return [NSPredicate predicateWithFormat:@"completedDate = nil"];
	}
}

- (void)setShowCompletedItems:(BOOL)newValue
{
	//- need to look at keyPathsForValuesAffectingValueForKey:
	[self willChangeValueForKey:@"showCompletedItems"];
	[self willChangeValueForKey:@"workQueuePredicate"];
	showCompletedItems = newValue;
	[self didChangeValueForKey:@"showCompletedItems"];
	[self didChangeValueForKey:@"workQueuePredicate"];
}

- (void)setShowWorkQueue:(BOOL)newValue
{
	NSRect windowRect = [workQueueWindow frame];
	
	[self willChangeValueForKey:@"showWorkQueue"];
	if ( YES == newValue ) {
		windowRect.size = oldWindowSize;
		[workQueueWindow setFrame:windowRect display:YES animate:YES];
		[workQueueWindow setShowsResizeIndicator:YES];
		[workQueueScrollView setHidden:NO];
		[showCompletedItemsCheckBox setHidden:NO];
	} else {
		oldWindowSize = windowRect.size;
		windowRect.size.width = WQDefaultWindowWidth;
		windowRect.size.height = WQDefaultWindowHeight;
		[workQueueWindow setFrame:windowRect display:YES animate:YES];
		[workQueueWindow setShowsResizeIndicator:NO];
		[workQueueScrollView setHidden:YES];
		[showCompletedItemsCheckBox setHidden:YES];
	}
	showWorkQueue = newValue;
	[self didChangeValueForKey:@"showWorkQueue"];
}


@end

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
	[self willChangeValueForKey:@"sortDescriptors"];
	sortDescriptors = nil;
	[self didChangeValueForKey:@"sortDescriptors"];
}

- (IBAction)showWindow:(id)sender
{
	ENTRY;
	[workQueueWindow makeKeyAndOrderFront:self];
}

- (void)setShowWorkQueue:(BOOL)newValue
{
	NSRect windowRect = [workQueueWindow frame];
	
	[self willChangeValueForKey:@"showWorkQueue"];
	if ( YES == newValue ) {
		windowRect.origin.y += WQDefaultWindowHeight - oldWindowSize.height;
		windowRect.size = oldWindowSize;
		[workQueueWindow setFrame:windowRect display:YES animate:YES];
		[self setItemsHidden:NO];
	} else {
		[self setItemsHidden:YES];
		oldWindowSize = windowRect.size;
		windowRect.origin.y += windowRect.size.height - WQDefaultWindowHeight;
		windowRect.size.width = WQDefaultWindowWidth;
		windowRect.size.height = WQDefaultWindowHeight;
		[workQueueWindow setFrame:windowRect display:YES animate:YES];
	}
	showWorkQueue = newValue;
	[self didChangeValueForKey:@"showWorkQueue"];
}

- (void)setItemsHidden:(BOOL)value
{
	[workQueueScrollView		setHidden:value];
	[removeItemButton			setHidden:value];
	//- if the controls are hidden (YES), hide this (NO)
	//- except that re-sizing is wonky, so we'll ignore this for now.
	//[workQueueWindow setShowsResizeIndicator:!value];
}

- (NSArray *)sortDescriptors
{
	ENTRY;
	NSSortDescriptor *sortDescriptor = [[[NSSortDescriptor alloc]
		initWithKey:[workQueueController valueForKey:@"pendingItemsSortKey"] ascending:YES
	] autorelease];
	
	return [NSArray arrayWithObject:sortDescriptor];
}

- (void)setSortDescriptors:(NSArray *)newDescriptors
{
	[self willChangeValueForKey:@"sortDescriptors"];
	[sortDescriptors release];
	sortDescriptors = [newDescriptors retain];
	[self didChangeValueForKey:@"sortDescriptors"];
}

@end

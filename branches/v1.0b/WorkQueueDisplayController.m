//
//  WorkQueueDisplayController.m
//  TiVo Butler
//
//  Created by Eric Baur on 3/13/08.
//  Copyright 2008 Eric Shore Baur. All rights reserved.
//

#import "WorkQueueDisplayController.h"


@implementation WorkQueueDisplayController

- (id)init
{
	self = [super init];
	if ( self ) {
		NSSortDescriptor *sortDescriptor = [[[NSSortDescriptor alloc]
			initWithKey:[workQueueController valueForKey:@"pendingItemsSortKey"] ascending:NO
		] autorelease];
		
		sortDescriptors = [[NSArray arrayWithObject:sortDescriptor] retain];
	}
	return self;
}

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
	//[workQueueWindow makeKeyAndOrderFront:self];
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

#pragma mark -
#pragma mark OutlineView Datasource methods

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item
{
	if ( item && [item isKindOfClass:[WorkQueueItem class]] ) {
		//- we don't have any children, using outline view to control row height instead
		return [[item valueForKey:@"steps"] count];
		
	} else if ( item==nil ) {
		//- we're looking at the root item, so calculate the number of items
		return [[EntityHelper
			arrayOfEntityWithName:TiVoWorkQueueItemEntityName
			usingPredicate:[NSPredicate predicateWithValue:TRUE]
			withSortKeys:[NSArray arrayWithObject:@"addedDate"]
		] count];
		
	}
	//- if we got here, then it's an WorkQueueStep that we're looking at
	return 0;
}

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item
{
	if ( outlineView != workQueueStepsOutlineView ) {
		WARNING( @"call from an unknown outlineView" );
		return 0;
	}
	//- this should always be the first object, should I check?
	if ( item && [item isKindOfClass:[WorkQueueItem class]] ) {
		NSArray *stepArray = [EntityHelper
			arrayOfEntityWithName:TiVoWorkQueueStepEntityName
			usingPredicate:[NSPredicate predicateWithFormat:@"item = %@", item]
			withSortKeys:[NSArray arrayWithObject:@"addedDate"]
		 ];
		if ( [stepArray count] > index )
			return [stepArray objectAtIndex:index];
		else
			return nil;
		
	} else if ( item==nil ) {
		return [[EntityHelper
			arrayOfEntityWithName:TiVoWorkQueueItemEntityName
			usingPredicate:[NSPredicate predicateWithValue:TRUE]
			withSortKeys:[NSArray arrayWithObject:@"addedDate"]
		 ] objectAtIndex:index];
	}
	//- we shouldn't get here
	return nil;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
	//- we don't have any children, using outline view to control row height instead
	return YES;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldExpandItem:(id)item
{
	//- not sure I need to implement this one...
	return YES;
}

- (void)outlineViewItemDidCollapse:(NSNotification *)notification
{
    id item = [[notification userInfo] objectForKey:@"NSObject"];
    NSInteger row = [workQueueStepsOutlineView rowForItem:item];
    [workQueueStepsOutlineView noteHeightOfRowsWithIndexesChanged:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(row,1)]];
}

- (void)outlineViewItemDidExpand:(NSNotification *)notification
{
    id item = [[notification userInfo] objectForKey:@"NSObject"];
    NSInteger row = [workQueueStepsOutlineView rowForItem:item];
    [workQueueStepsOutlineView noteHeightOfRowsWithIndexesChanged:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(row,1)]];
}

- (CGFloat)outlineView:(NSOutlineView *)outlineView heightOfRowByItem:(id)item
{
    if ([outlineView isItemExpanded:item] && [item isKindOfClass:[WorkQueueStep class]] ) {
		return WQRowHeightFull;
	} else {
		return WQRowHeightTitle;
	}
}

- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
	if ( outlineView != workQueueStepsOutlineView ) {
		WARNING( @"call from an unknown outlineView" );
		return 0;
	}

	if ([[tableColumn identifier] isEqualToString:@"desc"]) {
		if ( [item isKindOfClass:[WorkQueueItem class]] ) {
			return [item valueForKeyPath:@"program.title"];
		} else if ( [item isKindOfClass:[WorkQueueStep class]] ) {
			return [item valueForKeyPath:@"actionName"];
		}
		
	} else if ([[tableColumn identifier] isEqualToString:@"icon"]) {
		return [NSImage imageNamed:@"in-progress-recording"];
		
	} else if ([[tableColumn identifier] isEqualToString:@"cancel"]) {
		return [NSImage imageNamed:@"NSStopProgressTemplate"];
	}
	return nil;
}


- (void)outlineView:(NSOutlineView *)outlineView willDisplayOutlineCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
	if ([outlineView isItemExpanded:item]) {
		[cell setImagePosition: NSImageAbove];
	} else {
		[cell setImagePosition: NSImageOnly];
	}
}

@end

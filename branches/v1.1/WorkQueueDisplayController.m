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
	[self willChangeValueForKey:@"sortDescriptors"];
	sortDescriptors = nil;
	[self didChangeValueForKey:@"sortDescriptors"];
}

- (IBAction)showWindow:(id)sender
{
	ENTRY;
	[workQueueWindow makeKeyAndOrderFront:self];
}

- (IBAction)showAddItemWindow:(id)sender
{
	ENTRY;
	NSOpenPanel *panel = [NSOpenPanel openPanel];

	[panel setCanChooseFiles:YES];
	[panel setResolvesAliases:YES];
	[panel setAllowsMultipleSelection:NO];

	[panel
		beginSheetForDirectory:nil
		file:nil
		types:[NSArray arrayWithObjects:@"tivo", @"mpg", nil]
		modalForWindow:workQueueWindow
		modalDelegate:self
		didEndSelector:@selector(chooseItemPanelDidEnd:returnCode:contextInfo:)
		contextInfo:NULL
	];
}

- (void)chooseItemPanelDidEnd:(NSOpenPanel *)panel returnCode:(int)returnCode contextInfo:(void  *)contextInfo
{
	if ( NSCancelButton==returnCode ) {
		RETURN( @"user canceled open panel" );
		return;
	}
	ENTRY;

	INFO( @"user selected file(s)...\n%@", [panel filenames] );
	[addItemPathControl setURL:[panel URL] ];
	
	[panel close];

	[NSApp
		beginSheet:addItemWindow
		modalForWindow:workQueueWindow
		modalDelegate:self
		didEndSelector:@selector(addItemSheetDidEnd:returnCode:contextInfo:)
		contextInfo:NULL
	];
}

- (IBAction)endAddItemSheet:(id)sender
{
	ENTRY;
	[NSApp endSheet:addItemWindow];
}

- (void)addItemSheetDidEnd:(NSWindow *)window returnCode:(int)returnCode contextInfo:(void  *)contextInfo
{
	ENTRY;
	[window orderOut:self];
	
	NSDictionary *optionsDict = [NSDictionary dictionaryWithObjectsAndKeys:
		[addItemPathControl URL],	@"URL",
		nil
	];
	
	[workQueueController performSelector:@selector(addPendingItemWithOptions:) withObject:optionsDict];
}

- (IBAction)refreshOutlineView:(id)sender
{
	ENTRY;
	//- collect new data
	[workQueueItems release];
	switch ( [workQueueScopeControl selectedSegment] ) {
		case WQScopeControlActiveTag:
			workQueueItems = [[EntityHelper
				arrayOfEntityWithName:TiVoWorkQueueStepEntityName
				usingPredicateString:@"active = 1"
				withSortKeys:[NSArray arrayWithObject:@"addedDate"]
			] retain];
			INFO( @"%d active items", [workQueueItems count] );
			break;
		case WQScopeControlPendingTag:
			workQueueItems = [[EntityHelper
				arrayOfEntityWithName:TiVoWorkQueueItemEntityName
				usingPredicateString:@"completedDate = nil"
				withSortKeys:[NSArray arrayWithObject:@"addedDate"]
			] retain];
			INFO( @"%d pending items", [workQueueItems count] );
			break;
		case WQScopeControlCompletedTag:
			workQueueItems = [[EntityHelper
					arrayOfEntityWithName:TiVoWorkQueueItemEntityName
					usingPredicateString:@"completedDate != nil"
					withSortKeys:[NSArray arrayWithObject:@"addedDate"]
				] retain];
			INFO( @"%d completed items", [workQueueItems count] );
			break;
		default:
			ERROR( @"didn't match segmented control setting" );
	}
	//- refresh data view
	[workQueueOutlineView reloadData];
}

#pragma mark -
#pragma mark OutlineView Datasource methods

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item
{
	if ( item && [item isKindOfClass:[WorkQueueItem class]] ) {
		return [[item valueForKey:@"steps"] count];
	} else if ( item==nil ) {
		//- we're looking at the root item, so return the number of items
		return [workQueueItems count];
	}
	//- if we got here, then it's an WorkQueueStep that we're looking at
	return 0;
}

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item
{
	if ( outlineView != workQueueOutlineView ) {
		WARNING( @"call from an unknown outlineView" );
		return 0;
	}
	//- this should always be the first object, should I check?
	if ( item && [item isKindOfClass:[WorkQueueItem class]] ) {
		NSArray *stepArray = [EntityHelper
			arrayOfEntityWithName:TiVoWorkQueueStepEntityName
			usingPredicate:[NSPredicate predicateWithFormat:@"item = %@", item]
			withSortKeys:[NSArray arrayWithObject:@"actionType"]
		 ];
		if ( [stepArray count] > index )
			return [stepArray objectAtIndex:index];
		else
			return nil;
		
	} else if ( item==nil ) {
		return [workQueueItems objectAtIndex:index];
	}
	//- we shouldn't get here
	return nil;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
	//- even the rows w/out children need a disclosure triangle
	return YES;
}

- (void)outlineViewItemDidCollapse:(NSNotification *)notification
{
    id item = [[notification userInfo] objectForKey:@"NSObject"];
    NSInteger row = [workQueueOutlineView rowForItem:item];
    [workQueueOutlineView noteHeightOfRowsWithIndexesChanged:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(row,1)]];
}

- (void)outlineViewItemDidExpand:(NSNotification *)notification
{
    id item = [[notification userInfo] objectForKey:@"NSObject"];
    NSInteger row = [workQueueOutlineView rowForItem:item];
    [workQueueOutlineView noteHeightOfRowsWithIndexesChanged:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(row,1)]];
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
	if ( outlineView != workQueueOutlineView ) {
		WARNING( @"call from an unknown outlineView" );
		return 0;
	}

	if ([[tableColumn identifier] isEqualToString:@"desc"]) {
		if ( [item isKindOfClass:[WorkQueueItem class]] ) {
			return [self attributedStringForItem:item];
		} else if ( [item isKindOfClass:[WorkQueueStep class]] ) {
			return [self attributedStringForStep:item];
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
		[cell setImagePosition:NSImageAbove];
	} else {
		[cell setImagePosition:NSImageOnly];
	}
}

#pragma mark -
#pragma mark OutlineView string methods

- (NSAttributedString *)attributedStringForItem:(WorkQueueItem *)item
{
	NSMutableAttributedString *returnString = [[[NSMutableAttributedString alloc] initWithString: @""] autorelease];

	NSDictionary *detailAttribute = [NSDictionary dictionaryWithObject:[NSFont systemFontOfSize:10.0] forKey:NSFontAttributeName];
	NSDictionary *titleAttribute = [NSDictionary dictionaryWithObject:[NSFont systemFontOfSize:[NSFont systemFontSize]] forKey:NSFontAttributeName];

	[returnString appendAttributedString:[[[NSAttributedString alloc]
		initWithString:[item valueForKeyPath:@"program.title"]
		attributes:titleAttribute
		] autorelease ]
	];
	[returnString appendAttributedString:[[[NSAttributedString alloc]
		initWithString:[NSString stringWithFormat:@" (Recorded: %@)", [item valueForKeyPath:@"program.captureDate"]]
		attributes:detailAttribute
		] autorelease ]
	];

	return [[returnString copy] autorelease];
}

- (NSAttributedString *)attributedStringForStep:(WorkQueueStep *)step
{
	NSMutableAttributedString *returnString = [[[NSMutableAttributedString alloc] initWithString: @""] autorelease];

	//- set typical attributes
	NSMutableParagraphStyle *paragraphStyle = [[[NSParagraphStyle defaultParagraphStyle] mutableCopy] retain];
	[paragraphStyle setHeadIndent: 40.0];
	[paragraphStyle setParagraphSpacing: 1.0];
	[paragraphStyle setTabStops:[NSArray array]];    // clear all tabs
	[paragraphStyle addTabStop: [[[NSTextTab alloc] initWithType: NSLeftTabStopType location: 20.0] autorelease]];
/*
	NSDictionary *detailAttribute = [NSDictionary dictionaryWithObjectsAndKeys:
		[NSFont systemFontOfSize:10.0],						NSFontAttributeName,
		paragraphStyle,										NSParagraphStyleAttributeName,
		nil
	];

	NSDictionary *detailBoldAttribute = [NSDictionary dictionaryWithObjectsAndKeys:
		[NSFont boldSystemFontOfSize:10.0],					NSFontAttributeName,
		paragraphStyle,										NSParagraphStyleAttributeName,
		nil
	];
*/
	NSDictionary *titleAttribute = [NSDictionary dictionaryWithObjectsAndKeys:
		[NSFont systemFontOfSize:[NSFont systemFontSize]],	NSFontAttributeName,
		paragraphStyle,										NSParagraphStyleAttributeName,
		nil
	];
/*
	NSDictionary *shortHeightAttribute = [NSDictionary dictionaryWithObjectsAndKeys:
		[NSFont systemFontOfSize:2.0],						NSFontAttributeName,
		nil
	];
*/	
	//- set the action as a title
	[returnString appendAttributedString:[[[NSAttributedString alloc]
		initWithString:step.actionName
		attributes:titleAttribute
		] autorelease ]
	];
	
	//- figure out the status
	NSColor *tempColor;
	NSString *tempString;
	if ( step.completedDate && step.successful.boolValue ) {
		//- if completed and successful...
		tempColor = [NSColor blackColor];
		tempString = @" completed";
	} else if ( step.completedDate && !step.successful.boolValue ) {
		//- if completed, but not successful...
		tempColor = [NSColor redColor];
		tempString = [NSString stringWithFormat:@" failed: %@", step.message];
	} else if ( [step.active boolValue] ) {
		//- if active and started...
		tempColor = [NSColor greenColor];
		tempString = [NSString stringWithFormat:@" %@%% done", step.currentActionPercent];
	} else if ( !step.startedDate ) {
		//- if not started...
		tempColor = [NSColor orangeColor];
		tempString = @" pending";
	}
	NSDictionary *attributeDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
		[NSFont systemFontOfSize:10.0],	NSFontAttributeName,
		paragraphStyle,					NSParagraphStyleAttributeName,
		tempColor,						NSForegroundColorAttributeName,
		nil
	];
	[returnString appendAttributedString:[[[NSAttributedString alloc]
		initWithString:tempString
		attributes:attributeDictionary
		] autorelease ]
	];


	return [[returnString copy] autorelease];
}

@end

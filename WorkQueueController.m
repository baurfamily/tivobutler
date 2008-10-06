//
//  WorkQueueController.m
//  TiVo Butler
//
//  Created by Eric Baur on 2/7/08.
//  Copyright 2008 Eric Shore Baur. All rights reserved.
//

#import "WorkQueueController.h"

static BOOL loaded = NO;

@implementation WorkQueueController

+ (void)initialize 
{
	if ( self != [WorkQueueController class] ) {
		WARNING( @"return early, not my class" );
		return;
	}
	ENTRY;
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSDictionary *tempDefaults;

	tempDefaults = [NSDictionary dictionaryWithObjectsAndKeys:
		@"~/Downloads/",										@"downloadFolder",
		[NSNumber numberWithBool:YES],							@"createSeriesSubFolders",
		[NSNumber numberWithInt:WQConvertAction],				@"downloadAction",
		[NSNumber numberWithInt:WQAddedDateOrder],				@"downloadOrder",
		[NSNumber numberWithBool:YES],							@"restartDownloads",
		[NSNumber numberWithBool:NO],							@"cancelDownloadsOnStartup",
		[NSNumber numberWithBool:NO],							@"restrictDownloadTimes",
		[NSNumber numberWithInt:WQFileExistsChangeNameAction],	@"fileExistsAction",
		[NSNumber numberWithInt:60],							@"downloadCheckInterval",
		[NSNumber numberWithBool:NO],							@"prependCaptureDate",
		[NSNumber numberWithBool:NO],							@"useIntermediateFolder",
		@"~/Downloads/",										@"intermediateFolder",
		[NSNumber numberWithBool:NO],							@"keepIntermediateFiles",
		[NSNumber numberWithBool:NO],							@"decodeWithExternalApp",
		[NSNumber numberWithBool:NO],							@"convertWithExternalApp",
		nil
	];
	
	[defaults registerDefaults:tempDefaults];
}

+ (NSSet *)keyPathsForValuesAffectingValueForKey:(NSString *)key
{
	NSSet *returnSet;
	if ( [key isEqualToString:@"maxActionDisplay"] ) {
		returnSet = [NSSet setWithObjects:@"currentItem", @"currentAction", @"finalAction", nil];

	} else if ( [key isEqualToString:@"currentActionDisplay"] ) {
		returnSet = [NSSet setWithObjects:@"currentItem", @"currentAction", @"finalAction", nil];

	} else if ( [key isEqualToString:@"currentActionString"] ) {
		returnSet = [NSSet setWithObjects:@"currentAction", nil];

	} else if ( [key isEqualToString:@"showActionProgress"] ) {
		returnSet = [NSSet setWithObjects:@"currentAction", @"finalAction", nil];

	} else if ( [key isEqualToString:@"showProgress"] ) {
		returnSet = [NSSet setWithObjects:@"currentAction", nil];

	} else if ( [key isEqualToString:@"maxActionProgress"] ) {
		returnSet = [NSSet setWithObjects:@"finalAction", nil];

	} else if ( [key isEqualToString:@"currentActionPercent"] ) {
		returnSet = [NSSet setWithObjects:@"currentAction", @"currentItem", nil];

	} else {
		returnSet = [NSSet set];
	}
	return returnSet;
}

- (void)awakeFromNib
{
	if ( loaded ) return;
	loaded = YES;
	[self willChangeValueForKey:@"managedObjectContext"];	
	managedObjectContext = [[[[NSApplication sharedApplication] delegate] managedObjectContext] retain];
	[self didChangeValueForKey:@"managedObjectContext"];
	
	[self willChangeValueForKey:@"currentAction"];
	currentAction = WQNoAction;
	[self didChangeValueForKey:@"currentAction"];
	
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	BOOL cancelDownloads = [[defaults valueForKey:@"cancelDownloadsOnStartup"] boolValue];

	if ( !cancelDownloads ) {
		//- we're assuming that anything without a completedDate should go away (since we just started)
		NSArray *abandonedDownloads = [EntityHelper 
			arrayOfEntityWithName:TiVoWorkQueueItemEntityName
			usingPredicateString:@"completedDate = nil and startedDate = nil"
		];
		[abandonedDownloads makeObjectsPerformSelector:@selector(completeWithMessage:) withObject:@"Abandoned"];
		//[abandonedDownloads makeObjectsPerformSelector:@selector(setSuccessful:) withObject:[NSNumber numberWithBool:NO] ];
		//[abandonedDownloads makeObjectsPerformSelector:@selector(setMessage:) withObject:@"Abandoned"];
		//[abandonedDownloads makeObjectsPerformSelector:@selector(setCompletedDate:) withObject:[NSDate date] ];
		INFO( @"abandoned %d downloads", [abandonedDownloads count] );
	}
	
	int downloadCheckInterval = [[defaults valueForKey:@"downloadCheckInterval"] intValue];
	INFO( @"setting download timer to check every %d minutes", downloadCheckInterval );
	downloadCheckTimer = [[NSTimer scheduledTimerWithTimeInterval:( 60 * downloadCheckInterval )
		target:self
		selector:@selector(checkForAutoDownloads)
		userInfo:nil
		repeats:YES
	] retain];
	
	[defaults addObserver:self
		forKeyPath:@"values.downloadCheckInterval" 
		options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) 
		context:NULL
	];
	
	[self checkForAutoDownloads];
	[self checkForPendingItems];
}

#pragma mark -
#pragma mark Action methods

- (IBAction)addSelection:(id)sender
{
	ENTRY;
	NSArray *selectedPrograms = [programArrayController selectedObjects];
	
	TiVoProgram *selectedProgram;
	for ( selectedProgram in selectedPrograms ) {
		[self addPendingItemWithProgram:selectedProgram];
	}
}

- (IBAction)addSelectionWithOptions:(id)sender
{
	WARNING( @"not implemented!" )
	return;	//only a stub, really...
	
	ENTRY;
	NSArray *selectedPrograms = [programArrayController selectedObjects];

	//open up a dialog for the settings...
	
	TiVoProgram *selectedProgram;
	for ( selectedProgram in selectedPrograms ) {
		[self addPendingItemWithProgram:selectedProgram];
	}
}

- (IBAction)showAddItemSheet:(id)sender
{
	if ( !workQueueDisplayController ) {
		if ( ![NSBundle loadNibNamed:@"WorkQueue" owner:self] ) {
			ERROR( @"could not load WorkQueue.nib" );
			return;
		} else { INFO( @"loaded WorkQueue.nib" ); }
	}
	[workQueueDisplayController showAddItemWindow:self];
}

- (IBAction)showWorkQueueWindow:(id)sender
{
	if ( !workQueueDisplayController ) {
		if ( ![NSBundle loadNibNamed:@"WorkQueue" owner:self] ) {
			ERROR( @"could not load WorkQueue.nib" );
			return;
		} else { INFO( @"loaded WorkQueue.nib" ); }
	}
	[workQueueDisplayController showWindow:self];
}

- (IBAction)cancelDownload:(id)sender
{
	[currentItem completeWithMessage:@"Canceled"];
}


#pragma mark -
#pragma mark Workflow methods

- (void)addPendingItemWithProgram:(TiVoProgram *)program
{
	ENTRY;	
	WorkQueueItem *newItem = [NSEntityDescription
		insertNewObjectForEntityForName:TiVoWorkQueueItemEntityName
		inManagedObjectContext:managedObjectContext
	];
	
	[newItem setValue:program forKey:@"program"];
	[workQueueItemArrayController addObject:newItem];
	
	//- this allows other items to complete before starting this one
	[self checkForPendingItems];
}

- (void)addPendingItemWithOptions:(NSDictionary *)options
{
	ENTRY;
	INFO( @"adding item with options:\n%@", options );
}

- (void)checkForPendingItems
{
	ENTRY;
	if ( currentItem ) {
		DEBUG( @"there is a current work queue item, won't check for pending items" );
		return;
	}
	
	if ( ![self okayToDownload] ) {
		INFO( @"won't download right now, it's not in the right window" );
	}
	
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	BOOL restartDownloads = [[defaults valueForKey:@"restartDownloads"] boolValue];

	if ( !restartDownloads ) {
		//- we're assuming that anything with a start date was abandoned
		//- we expect only one item with a startedDate if there is a currentItem, none otherwise
		NSArray *abandonedDownloads = [EntityHelper 
			arrayOfEntityWithName:TiVoWorkQueueItemEntityName
			usingPredicateString:@"completedDate = nil AND startedDate != nil"
		];
		[abandonedDownloads makeObjectsPerformSelector:@selector(setSuccessful:) withObject:[NSNumber numberWithBool:NO] ];
		[abandonedDownloads makeObjectsPerformSelector:@selector(setMessage:) withObject:@"Interrupted"];
		[abandonedDownloads makeObjectsPerformSelector:@selector(setCompletedDate:) withObject:[NSDate date] ];
		INFO( @"canceled %d interrupted downloads", [abandonedDownloads count] );
	}
	
	NSArray *pendingItems = [EntityHelper
		arrayOfEntityWithName:TiVoWorkQueueItemEntityName
		usingPredicateString:@"completedDate = nil"
		withSortKeys:[NSArray arrayWithObject:[self pendingItemsSortKey] ]
	];
	
	if ( [pendingItems count] ) {
		INFO( @"there are %d pending work queue items" );
		[self willChangeValueForKey:@"currentItem"];
		currentItem = [pendingItems objectAtIndex:0];
		[self didChangeValueForKey:@"currentItem"];
		[currentItem beginProcessing];
	}
}

- (void)checkForAutoDownloads
{
	ENTRY;
	NSArray *smartGroups = [EntityHelper
		arrayOfEntityWithName:TiVoSmartGroupEntityName 
		usingPredicateString:@"autoDownload = YES"
	];
	DEBUG( @"checking %d smart groups", [smartGroups count] );
	SmartGroup *tempGroup;
	for ( tempGroup in smartGroups ) {
		NSString *predicateString = [NSString stringWithFormat:@"(%@) AND %@ AND %@",
			tempGroup.predicateString,
			@"NONE workQueueItems.addedDate <> nil",
			@"deletedFromPlayer = NO"
		];
		DEBUG( @"using predicate string: %@", predicateString );
		NSArray *programs = [EntityHelper
			arrayOfEntityWithName:TiVoProgramEntityName
			usingPredicateString:predicateString
		];
		DEBUG( @"found %d candiate programs", [programs count] );
		TiVoProgram *tempProgram;
		for ( tempProgram in programs ) {
			DEBUG( @"adding pending item for: %@", tempProgram.title );
			[self addPendingItemWithProgram:tempProgram];
		}
	} 
}

#pragma mark -
#pragma mark Internal accessor type methods

- (BOOL)okayToDownload
{
	ENTRY;
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

	BOOL restrictTimes = [[defaults valueForKey:@"restrictDownloadTimes"] boolValue];
	if( !restrictTimes ) {
		return YES;
	}

	NSDate *startDate = [defaults valueForKey:@"downloadStartTime"];
	NSDate *endDate = [defaults valueForKey:@"downloadEndTime"];
	
	if ( nil==startDate || nil==endDate ) {
		WARNING( @"can't do date calculations, either the start or end date is nil" );
	}
	return YES;
}

- (NSString *)pendingItemsSortKey
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	WQDateOrder downloadOrder = [[defaults valueForKey:@"downloadOrder"] intValue];
	
	switch ( downloadOrder ) {
		case WQAddedDateOrder:		RETURN( WQAddedDateString );	return WQAddedDateString;		break;
		case WQRecordedDateOrder:	RETURN( WQRecordedDateString );	return WQRecordedDateString;	break;
		default:					DEBUG( @"using default: %@", WQAddedDateString ); return WQAddedDateString;
	}
}

#pragma mark -
#pragma mark External accessor type methods

- (int)maxActionDisplay
{
	DEBUG( @"finalAction: %d", finalAction );
	return 3 - finalAction;		//- ugly hack?
}

- (int)currentActionDisplay
{
	DEBUG( @"currentAction: %d", currentAction );
	return 3 - currentAction;	//- ugly hack?
}

- (NSString *)currentActionString
{
	switch( currentAction ) {
		case WQConvertAction:		return WQConvertActionString;	break;
		case WQDecodeAction:		return WQDecodeActionString;	break;
		case WQDownloadAction:		return WQDownloadActionString;	break;
		default:					return nil;						break;
	}
}

- (BOOL)showActionProgress
{
	if ( WQDownloadAction == finalAction || WQNoAction == finalAction ) {
		RETURN( @"NO" );
		return NO;
	} else {
		RETURN( @"YES" );
		return YES;
	}
}

- (BOOL)showProgress
{
	ENTRY;
	switch ( currentAction ) {
		case WQConvertAction:		RETURN( @"YES" );	return YES;		break;
		case WQDecodeAction:		RETURN( @"NO" );	return NO;		break;
		case WQDownloadAction:		RETURN( @"YES" );	return YES;		break;
		default:					RETURN( @"NO" );	return NO;		break;
	}
}

#pragma mark -
#pragma mark Observer methods

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if ([keyPath isEqual:@"values.downloadCheckInterval"]) {
			int downloadCheckInterval = [[object valueForKeyPath:keyPath] intValue];
			[downloadCheckTimer invalidate];
			[downloadCheckTimer release];
			downloadCheckTimer = [[NSTimer scheduledTimerWithTimeInterval:( 60 * downloadCheckInterval )
				target:self
				selector:@selector(checkForAutoDownloads)
				userInfo:nil
				repeats:YES
			] retain];
			INFO( @"updated check timer interval to %d minutes", downloadCheckInterval );
		}
}

@end

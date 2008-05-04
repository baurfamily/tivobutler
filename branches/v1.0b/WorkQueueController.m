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
	ENTRY;
	NSUserDefaultsController *defaults = [NSUserDefaultsController sharedUserDefaultsController];
	NSMutableDictionary *tempDefaults = [[[self workflowDefaults] mutableCopy] autorelease];

	[tempDefaults addEntriesFromDictionary:
		[NSDictionary dictionaryWithObjectsAndKeys:
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
		]
	];
	
	[defaults setInitialValues:tempDefaults];
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
	
	NSUserDefaultsController *defaults = [NSUserDefaultsController sharedUserDefaultsController];
	BOOL cancelDownloads = [[[defaults valueForKey:@"values"] valueForKey:@"cancelDownloadsOnStartup"] boolValue];

	if ( !cancelDownloads ) {
		//- we're assuming that anything without a completedDate should go away (since we just started)
		NSArray *abandonedDownloads = [EntityHelper 
			arrayOfEntityWithName:TiVoWorkQueueItemEntityName
			usingPredicateString:@"completedDate = nil and startedDate = nil"
		];
		[abandonedDownloads makeObjectsPerformSelector:@selector(setMessage:) withObject:@"Abandoned"];
		[abandonedDownloads makeObjectsPerformSelector:@selector(setCompletedDate:) withObject:[NSDate date] ];
		INFO( @"abandoned %d downloads", [abandonedDownloads count] );
	}
	
	int downloadCheckInterval = [[[defaults valueForKey:@"values"] valueForKey:@"downloadCheckInterval"] intValue];
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
	[self removeFiles];
	[self completeWithMessage:@"Canceled"];
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
	
	NSUserDefaultsController *defaults = [NSUserDefaultsController sharedUserDefaultsController];
	BOOL restartDownloads = [[[defaults valueForKey:@"values"] valueForKey:@"restartDownloads"] boolValue];

	if ( !restartDownloads ) {
		//- we're assuming that anything with a start date was abandoned
		//- we expect only one item with a startedDate if there is a currentItem, none otherwise
		NSArray *abandonedDownloads = [EntityHelper 
			arrayOfEntityWithName:TiVoWorkQueueItemEntityName
			usingPredicateString:@"completedDate = nil AND startedDate != nil"
		];
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
		[self beginDownload];
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

- (NSString *)fileName
{
	NSMutableString *tempString = [NSMutableString string];
	
	NSUserDefaultsController *defaults = [NSUserDefaultsController sharedUserDefaultsController];
	NSString *fileNamePattern = [[defaults valueForKey:@"values"] valueForKey:@"fileNamePattern"];
	EntityTokenFieldValueTransformer *transformer = [[[EntityTokenFieldValueTransformer alloc] init] autorelease];
	NSArray *tokenArray = [transformer transformedValue:fileNamePattern];
	
	id token;
	for ( token in tokenArray ) {
		if ( [token isKindOfClass:[EntityToken class]] ) {
			[tempString appendString:[token stringForProgram:currentItem.program] ];
		} else if ( [token isKindOfClass:[NSString class]] ) {
			[tempString appendString:token];
		} else {
			WARNING( @"unexpected clas when parsing fileNamePattern: %@", [token className] );
		}
	}
	
	RETURN( tempString );
	return [tempString copy];
}

- (NSString *)endingFilePath
{
	NSUserDefaultsController *defaults = [NSUserDefaultsController sharedUserDefaultsController];
	NSString *folder = [[defaults valueForKey:@"values"] valueForKey:@"downloadFolder"];
	BOOL createSubFolders = [[[defaults valueForKey:@"values"] valueForKey:@"createSeriesSubFolders"] boolValue];
	
	NSString *pathString;
	NSString *beginningPath;
	
	NSString *fileName = [self fileName];
	
	//- check preference and make sure there is a series title to use
	if ( createSubFolders && [currentItem valueForKeyPath:@"program.series.title"] ) {
		beginningPath = [[NSString
			stringWithFormat:@"%@/%@", folder, [currentItem valueForKeyPath:@"program.series.title"]
		] stringByExpandingTildeInPath ];
		
		BOOL hitError = NO;
		BOOL isDirectory;
		
		BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:beginningPath isDirectory:&isDirectory];
		if ( !exists ) {		
			NSError *error;
			BOOL succeeded = [[NSFileManager defaultManager]
				createDirectoryAtPath:beginningPath
				withIntermediateDirectories:YES
				attributes:nil
				error:&error
			];
			if ( !succeeded ) {
				ERROR( @"could not create directory: %@ (%@)", beginningPath, [error localizedDescription] );
				hitError = YES;
			}
		} else if ( !isDirectory ) {
			ERROR( @"can't save to '%@', not a directory (will try to use base path)", beginningPath );
			hitError = YES;
		}
		
		//- if we still couldn't create the path, fall back to just the name
		if ( hitError ) {
			pathString = [
				[NSString stringWithFormat:@"%@/%@", folder, fileName] stringByExpandingTildeInPath
			];
		} else {
			pathString = [
				[NSString stringWithFormat:@"%@/%@", beginningPath, fileName] stringByExpandingTildeInPath
			];
		}
	} else {
		pathString = [
			[NSString stringWithFormat:@"%@/%@", folder, fileName] stringByExpandingTildeInPath
		];
	}
	
	NSFileManager *fileManager = [NSFileManager defaultManager];
	
	if ( [fileManager fileExistsAtPath:[pathString stringByAppendingString:@".tivo"] ]
		|| [fileManager fileExistsAtPath:[pathString stringByAppendingString:@".mpg"] ]
		|| [fileManager fileExistsAtPath:[pathString stringByAppendingString:@".mp4"] ]
	) {
		WQFileExistsAction fileExistsAction = [[[defaults valueForKey:@"values"] valueForKey:@"fileExistsAction"] intValue];
		
		int i = 0;
		NSString *testPath = [pathString copy];
		
		switch ( fileExistsAction ) {
			case WQFileExistsFailAction:
				pathString = nil;
				break;
			case WQFileExistsOverwriteAction:
				//- existing path string is fine
				break;
			case WQFileExistsChangeNameAction:
			//default:
				while ( [fileManager fileExistsAtPath:[pathString stringByAppendingString:@".tivo"] ]
					|| [fileManager fileExistsAtPath:[pathString stringByAppendingString:@".mpg"] ]
					|| [fileManager fileExistsAtPath:[pathString stringByAppendingString:@".mp4"] ]
				) {
					i++;
					pathString = [testPath stringByAppendingFormat:@"-%d", i];
				}
				break;
		}
	}
	return pathString;
}

- (BOOL)okayToDownload
{
	ENTRY;
	NSUserDefaultsController *defaults = [NSUserDefaultsController sharedUserDefaultsController];

	BOOL restrictTimes = [[[defaults valueForKey:@"values"] valueForKey:@"restrictDownloadTimes"] boolValue];
	if( !restrictTimes ) {
		return YES;
	}

	NSDate *startDate = [[defaults valueForKey:@"values"] valueForKey:@"downloadStartTime"];
	NSDate *endDate = [[defaults valueForKey:@"values"] valueForKey:@"downloadEndTime"];
	
	if ( nil==startDate || nil==endDate ) {
		WARNING( @"can't do date calculations, either the start or end date is nil" );
	}
	return YES;
}

- (NSString *)pendingItemsSortKey
{
	NSUserDefaultsController *defaults = [NSUserDefaultsController sharedUserDefaultsController];
	WQDateOrder downloadOrder = [[[defaults valueForKey:@"values"] valueForKey:@"downloadOrder"] intValue];
	
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
		case WQDownloadOnlyAction:	return WQDownloadOnlyString;	break;
		default:					return nil;						break;
	}
}

- (BOOL)showActionProgress
{
	if ( WQDownloadOnlyAction == finalAction || WQNoAction == finalAction ) {
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
		case WQDownloadOnlyAction:	RETURN( @"YES" );	return YES;		break;
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

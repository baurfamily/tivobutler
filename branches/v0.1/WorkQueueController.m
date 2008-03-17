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
	NSUserDefaultsController *defaults = [NSUserDefaultsController sharedUserDefaultsController];
	[defaults setInitialValues:[NSDictionary dictionaryWithObjectsAndKeys:
			@"~/Downloads/",									@"downloadFolder",
			[NSNumber numberWithBool:YES],						@"createSeriesSubFolders",
			[NSNumber numberWithInt:WQDownloadOnlyAction],		@"downloadAction",
			[NSNumber numberWithInt:WQAddedDateOrder],			@"downloadOrder",
			[NSNumber numberWithBool:YES],						@"restartDownloads",
			[NSNumber numberWithBool:NO],						@"cancelDownloadsOnStartup",
			[NSNumber numberWithBool:NO],						@"restrictDownloadTimes",
			[NSNumber numberWithInt:WQPromptOverwriteAction],	@"overwriteAction",
			[NSNumber numberWithInt:60],						@"downloadCheckInterval",
			nil
		]
	];
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
	RETURN( @"looked at key: %@\n%@", key, [returnSet description] );
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
	downloadCheckTimer = [NSTimer scheduledTimerWithTimeInterval:( 60 * downloadCheckInterval )
		target:self
		selector:@selector(checkForAutoDownloads)
		userInfo:nil
		repeats:YES
	];
	
	[self checkForAutoDownloads];
	[self checkForPendingItems];
}

#pragma mark -
#pragma mark Action methods

- (IBAction)addSelection:(id)sender
{
	ENTRY;
	NSManagedObjectID *selectedProgramID = [[programArrayController selection] valueForKey:@"objectID"];
	if ( ! selectedProgramID ) {
		ERROR( @"could not find the selected items object ID\n%@", [programArrayController description] );
	}
	TiVoProgram *selectedProgram = (TiVoProgram *)[managedObjectContext objectWithID:selectedProgramID];
	
	[self addPendingItemWithProgram:selectedProgram];
}

- (IBAction)showWorkQueueWindow:(id)sender
{
	if ( ![NSBundle loadNibNamed:@"WorkQueue" owner:self] ) {
		ERROR( @"could not load WorkQueue.nib" );
		return;
	} else { INFO( @"loaded WorkQueue.nib" ); }
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
		usingPredicateString:@"autoDownload = YES AND ANY programs.deletedFromPlayer = NO"
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
		DEBUG( @"found %@ candiate programs", [programs count] );
		TiVoProgram *tempProgram;
		for ( tempProgram in programs ) {
			DEBUG( @"adding pending item for: %@", tempProgram.title );
			[self addPendingItemWithProgram:tempProgram];
		}
	} 
}

- (void)beginDownload
{
	ENTRY;
	NSString *tempURLString = currentItem.program.contentURL;
	if ( !tempURLString ) {
		ERROR( @"no URL string set" );
		return;
	}
	NSURL *url = [NSURL URLWithString:tempURLString];
	INFO( @"Downloading: %@", [url description] );
	
	NSURLRequest *request = [NSURLRequest requestWithURL:url];

	//- need to figure out what to do	
	NSUserDefaultsController *defaults = [NSUserDefaultsController sharedUserDefaultsController];
	[self willChangeValueForKey:@"finalAction"];
	finalAction = [[[defaults valueForKey:@"values"] valueForKey:@"downloadAction"] intValue];
	[self didChangeValueForKey:@"finalAction"];
	
	[downloadPath release];
	[decodePath release];
	[convertPath release];
	NSString *tempDirectory = NSTemporaryDirectory();
	switch ( finalAction ) {
		case WQConvertAction:
			downloadPath = [[NSString pathWithComponents:
				[NSArray arrayWithObjects:tempDirectory, [NSString stringWithFormat:@"%@.tivo", currentItem.program.programID, nil] ]
			] retain];
			decodePath = [[NSString pathWithComponents:
				[NSArray arrayWithObjects:tempDirectory, [NSString stringWithFormat:@"%@.mpg", currentItem.program.programID, nil] ]
			] retain];
			convertPath = [[NSString stringWithFormat:@"%@.mp4", [self endingFilePath]] retain];
			break;
		case WQDecodeAction:
			downloadPath = [[NSString pathWithComponents:
				[NSArray arrayWithObjects:tempDirectory, [NSString stringWithFormat:@"%@.tivo", currentItem.program.programID, nil] ]
			] retain];
			decodePath = [[NSString stringWithFormat:@"%@.mpg", [self endingFilePath]] retain];
			convertPath = nil;
			break;
		case WQDownloadOnlyAction:
			downloadPath = [[NSString stringWithFormat:@"%@.tivo", [self endingFilePath]] retain];
			decodePath = nil;
			convertPath = nil;
			break;
		default:
			WARNING( @"no download action set, downloading only" );
			downloadPath = [[NSString stringWithFormat:@"%@.tivo", [self endingFilePath]] retain];
			decodePath = nil;
			convertPath = nil;
			break;
	}
	INFO( @"downloading to: %@", downloadPath );
	INFO( @"decoding to: %@", decodePath );
	INFO( @"converting to: %@", convertPath );
	
	receivedBytes = 0;
	expectedBytes = [currentItem.program.sourceSize intValue];
	INFO( @"expecting %d bytes", expectedBytes );
	
	programDownload = [[NSURLDownload alloc] initWithRequest:request delegate:self];
	[self willChangeValueForKey:@"currentAction"];
	currentAction = WQDownloadOnlyAction;
	[self didChangeValueForKey:@"currentAction"];
	
	[self setupDownloadPath];
}

- (void)setupDownloadPath
{
	ENTRY;
	if ( !programDownload ) {
		ERROR( @"can't download program, download connection not created" );
		return;
	}
	[programDownload setDestination:downloadPath allowOverwrite:YES];	//TODO: make overwrite optional
	currentItem.startedDate = [NSDate date];
}

- (void)beginDecode
{
	ENTRY;

	[decodeTask release];
	decodeTask = [[NSTask alloc] init];
	
	NSPipe *pipe = [NSPipe pipe];
	[decodeFileHandle release];
	decodeFileHandle = [pipe fileHandleForReading];
	
	[decodeTask setStandardError:decodeFileHandle];
	
	NSString *launchPath = [[NSBundle mainBundle] pathForAuxiliaryExecutable:@"tivodecode"];
	if ( !launchPath ) {
		ERROR( @"launch path not set for decode task, can't continue" );
		[self removeFiles];
		[self completeWithMessage:@"Failed"];
		return;
	}
	DEBUG( @"using launchPath: %@", launchPath );
	[decodeTask setLaunchPath:launchPath ];
	
	NSArray *argumentArray = [NSArray arrayWithObjects:
		@"--no-verify",	//- makes it faster?
		@"--verbose",	//- prints out progress
		@"--mak",	[currentItem valueForKeyPath:@"program.player.mediaAccessKey"],
		@"--out",	decodePath,
		downloadPath,
		nil
	];
	INFO( @"decode task arguments:\n%@", [argumentArray description] );
	[decodeTask setArguments:argumentArray];
	
	decodeTimer = [[NSTimer
		scheduledTimerWithTimeInterval:1
		target:self
		selector:@selector(decodeCheckDataAvailable:)
		userInfo:nil
		repeats:YES
	] retain];
	
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		selector:@selector(decoderDidTerminate:)
		name:NSTaskDidTerminateNotification
		object:decodeTask
	];
	[decodeTask launch];
}

- (void)decoderDidTerminate:(NSNotification *)notification
{
	ENTRY;
	NSError *error;
	BOOL succeeded = [[NSFileManager defaultManager] removeItemAtPath:downloadPath error:&error];
	if ( !succeeded ) {
		ERROR( [error localizedDescription] );
	}
	[decodeTimer invalidate];
	[decodeTimer release];
	decodeTimer = nil;

	if ( [decodeTask terminationStatus] == 0 ) {
		DEBUG(@"Decode finished.");
	} else {
		ERROR(@"Decode failed.");
	}

	if ( convertPath ) {
		[self willChangeValueForKey:@"currentAction"];
		currentAction = WQConvertAction;
		[self didChangeValueForKey:@"currentAction"];
		[self beginConversion];
	} else {
		currentItem.savedPath = decodePath;
		[self completeWithMessage:nil];
	}
}

- (void)decodeCheckDataAvailable:(NSTimer *)timer
{
	ENTRY;
	NSData *data = [decodeFileHandle availableData];
	if ( [data length] ) {
		INFO( [data description] );
	}
}

- (void)beginConversion
{
	ENTRY;

	[convertTask release];
	convertTask = [[NSTask alloc] init];
	
	NSPipe *pipe = [NSPipe pipe];
	[convertFileHandle release];
	convertFileHandle = [pipe fileHandleForReading];

	[convertTask setStandardOutput:convertFileHandle];
	
	NSString *launchPath = [[NSBundle mainBundle] pathForAuxiliaryExecutable:@"mencoder"];
	if ( !launchPath ) {
		ERROR( @"launch path not set for conversion task, can't continue" );
		[self removeFiles];
		[self completeWithMessage:@"Failed"];
		return;
	}
	DEBUG( @"using launchPath: %@", launchPath );
	[convertTask setLaunchPath:launchPath];
	
	NSArray *argumentArray = [NSArray arrayWithObjects:
		@"-af", @"volume=13:1",
		@"-of", @"lavf",
		@"-lavfopts", @"i_certify_that_my_video_stream_does_not_use_b_frames",
		@"-demuxer", @"lavf",
		@"-lavfdopts", @"probesize=128",
		@"-oac", @"lavc",
		@"-ovc", @"lavc",
		@"-lavcopts", @"keyint=15:aglobal=1:vglobal=1:coder=1:vcodec=mpeg4:acodec=aac:vbitrate=1800:abitrate=128",
		@"-vf", @"pp=lb,scale=640:480,harddup",
		@"-o", convertPath,
		decodePath,
		nil
	];
	INFO( @"convert task arguments:\n%@", [argumentArray description] );
	[convertTask setArguments:argumentArray];
	
	convertTimer = [[NSTimer
		scheduledTimerWithTimeInterval:5
		target:self
		selector:@selector(convertCheckDataAvailable:)
		userInfo:nil
		repeats:YES
	] retain];
	
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		selector:@selector(convertDidTerminate:)
		name:NSTaskDidTerminateNotification
		object:convertTask
	];
	[convertTask launch];
}

- (void)convertDidTerminate:(NSNotification *)notification
{
	ENTRY;
	NSError *error;
	BOOL succeeded = [[NSFileManager defaultManager] removeItemAtPath:decodePath error:&error];
	if ( !succeeded ) {
		ERROR( [error localizedDescription] );
	}
	[convertTimer invalidate];
	[convertTimer release];
	convertTimer = nil;
	
	if ( [decodeTask terminationStatus] == 0 ) {
		DEBUG(@"Decode finished.");
	} else {
		ERROR(@"Decode failed.");
	}
	
	currentItem.savedPath = convertPath;
	[self completeWithMessage:nil];
}

- (void)convertCheckDataAvailable:(NSTimer *)timer
{
	ENTRY;
	NSData *data = [convertFileHandle availableData];
	if ( [data length] ) {
		INFO( [data description] );
	}
}

- (void)removeFiles
{
	[convertTask terminate];
	[[NSFileManager defaultManager] removeItemAtPath:convertPath error:NULL];
	[convertPath release];
	convertPath = nil;
	
	[decodeTask terminate];
	[[NSFileManager defaultManager] removeItemAtPath:decodePath error:NULL];
	[decodePath release];
	decodePath = nil;
	
	[programDownload cancel];
	[[NSFileManager defaultManager] removeItemAtPath:downloadPath error:NULL];
	[downloadPath release];
	downloadPath = nil;
}

- (void)completeWithMessage:(NSString *)message
{
	if ( message )
		currentItem.message = message;
	currentItem.completedDate = [NSDate date];
	
	[self willChangeValueForKey:@"currentItem"];
	[currentItem release];
	currentItem = nil;
	[self didChangeValueForKey:@"currentItem"];
	
	[self willChangeValueForKey:@"currentAction"];
	currentAction = WQNoAction;
	[self didChangeValueForKey:@"currentAction"];
	
	[self checkForPendingItems];
}

#pragma mark -
#pragma mark Accessor type methods

- (NSString *)endingFilePath
{
	NSUserDefaultsController *defaults = [NSUserDefaultsController sharedUserDefaultsController];
	NSString *folder = [[defaults valueForKey:@"values"] valueForKey:@"downloadFolder"];
	BOOL createSubFolders = [[[defaults valueForKey:@"values"] valueForKey:@"createSeriesSubFolders"] boolValue];
	
	NSString *pathString;
	
	//- check preference and make sure there is a series title to use
	if ( createSubFolders && [currentItem valueForKeyPath:@"program.series.title"] ) {
		NSString *beginningPath = [
			[NSString stringWithFormat:@"%@/%@",
				folder,
				[currentItem valueForKeyPath:@"program.series.title"]
			]
			stringByExpandingTildeInPath
		];
		
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
		
		if ( hitError ) {
			pathString = [NSString stringWithFormat:@"%@/%@", beginningPath, currentItem.program.title];
		} else {
			pathString = [
				[NSString stringWithFormat:@"%@/%@",
					beginningPath,
					currentItem.program.title
				]
				stringByExpandingTildeInPath
			];
		}
	} else {
		pathString = [
			[NSString stringWithFormat:@"%@/%@",
				folder,
				currentItem.program.title
			]
			stringByExpandingTildeInPath
		];
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
#pragma mark NSURLDownload delegate methods

- (void)download:(NSURLDownload *)download didFailWithError:(NSError *)error
{
	ERROR( @"download failed: %@\nfor URL: %@",
		[error localizedDescription],
		[[error userInfo] objectForKey:NSErrorFailingURLStringKey]
	);
	[programDownload release];
	programDownload = nil;
	
	[self removeFiles];
	[self completeWithMessage:@"Failed"];
}

- (void)download:(NSURLDownload *)download didCreateDestination:(NSString *)path
{
	//- I can see if the name changed from the suggested name here...
}

- (void)download:(NSURLDownload *)download didReceiveDataOfLength:(NSUInteger)length
{
	receivedBytes += length;
	int newActionPercent = ( 100.0 * receivedBytes ) / expectedBytes;
	if ( newActionPercent != currentActionPercent ) {
		[self willChangeValueForKey:@"currentActionPercent"];
		currentActionPercent = newActionPercent;
		INFO( @"currentActionPercent: %d for ( %d / %d )", currentActionPercent, receivedBytes, expectedBytes );
		[self didChangeValueForKey:@"currentActionPercent"];	
	}
}

- (void)downloadDidFinish:(NSURLDownload *)download
{
	INFO( @"download finished: %@", [programDownload description] );
	[programDownload release];
	programDownload = nil;
	
	if ( decodePath ) {
		[self willChangeValueForKey:@"currentAction"];
		currentAction = WQDecodeAction;
		[self didChangeValueForKey:@"currentAction"];
		[self beginDecode];
	} else {
		currentItem.savedPath = downloadPath;
		[self completeWithMessage:nil];
	}
}

- (void)download:(NSURLDownload *)download didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{
	ENTRY;
	NSString *mak = [currentItem valueForKeyPath:@"program.player.mediaAccessKey"];
	DEBUG( @"using MAK: %@", mak );
	if ( [challenge previousFailureCount] == 0 ) {
		NSURLCredential *newCredential = [NSURLCredential
			credentialWithUser:@"tivo"
			password:mak
			persistence:NSURLCredentialPersistenceNone
		];
		
		[[challenge sender] useCredential:newCredential forAuthenticationChallenge:challenge];
	} else {
		ERROR( @"the supplied MAK was incorrect for the given IP address" );
		[[challenge sender] cancelAuthenticationChallenge:challenge];
	}
}


@end

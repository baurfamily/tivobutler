//
//  WorkQueueController.m
//  TiVo Butler
//
//  Created by Eric Baur on 2/7/08.
//  Copyright 2008 Eric Shore Baur. All rights reserved.
//

#import "WorkQueueController.h"


@implementation WorkQueueController

+ (void)initialize 
{
	NSUserDefaultsController *defaults = [NSUserDefaultsController sharedUserDefaultsController];
	[defaults setInitialValues:[NSDictionary dictionaryWithObjectsAndKeys:
			@"~/Downloads/",									@"downloadFolder",
			[NSNumber numberWithInt:WQDownloadOnlyAction],			@"downloadAction",
			[NSNumber numberWithInt:WQPromptOverwriteAction],	@"overwriteAction",
			nil
		]
	];
}

- (void)awakeFromNib
{
	managedObjectContext = [[[[NSApplication sharedApplication] delegate] managedObjectContext] retain];
}

#pragma mark -
#pragma mark Action methods

- (IBAction)addSelection:(id)sender
{
	ENTRY;
	[self willChangeValueForKey:@"currentItem"];
	[currentItem release];
	currentItem = [NSEntityDescription
		insertNewObjectForEntityForName:TiVoWorkQueueItemEntityName
		inManagedObjectContext:managedObjectContext
	];
	[self willChangeValueForKey:@"currentItem"];
	NSManagedObjectID *selectedProgramID = [[programArrayController selection] valueForKey:@"objectID"];
	id selectedProgram = [managedObjectContext objectWithID:selectedProgramID];
	
	[currentItem setValue:selectedProgram forKey:@"program"];
	[currentItem setValue:[NSNumber numberWithBool:YES] forKey:@"active"];
	[workQueueItemArrayController addObject:currentItem];
	
	[self beginDownload];
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
	WQDownloadAction downloadAction = [[[defaults valueForKey:@"values"] valueForKey:@"downloadAction"] intValue];
	
	[downloadPath release];
	[decodePath release];
	[convertPath release];
	NSString *tempDirectory = NSTemporaryDirectory();
	switch ( downloadAction ) {
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
	
	programDownload = [[NSURLDownload alloc] initWithRequest:request delegate:self];
	
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
	
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		selector:@selector(decodeDataAvailable:)
		name:NSFileHandleDataAvailableNotification
		object:decodeFileHandle
	];
	[decodeFileHandle waitForDataInBackgroundAndNotify];
	[decodeTask setStandardError:decodeFileHandle];
	
	NSString *launchPath = [[NSBundle mainBundle] pathForAuxiliaryExecutable:@"tivodecode"];
	if ( !launchPath ) {
		ERROR( @"launch path not set for decode task, can't continue" );
		//TODO: cleanup
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
	DEBUG( @"decode task arguments:\n%@", [argumentArray description] );
	[decodeTask setArguments:argumentArray];
	
	[decodeTask launch];
	[decodeTask waitUntilExit];	//- this shouldn't take long
	
	NSError *error;
	[[NSFileManager defaultManager] removeItemAtPath:downloadPath error:&error];
	if ( error ) {
		ERROR( [error localizedDescription] );
	}
	
	if ( convertPath ) {
		[self beginConversion];
	} else {
		currentItem.completedDate = [NSDate date];
	}
}

- (void)decodeDataAvailable:(NSNotification *)notification
{
	NSFileHandle *fileHandle = [notification object];
	NSData *data = [fileHandle availableData];
	INFO( [data description] );
	[fileHandle waitForDataInBackgroundAndNotify];
}

- (void)beginConversion
{
	ENTRY;

	[convertTask release];
	convertTask = [[NSTask alloc] init];
	
	NSPipe *pipe = [NSPipe pipe];
	[convertFileHandle release];
	convertFileHandle = [pipe fileHandleForReading];
	
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		selector:@selector(convertDataAvailable:)
		name:NSFileHandleDataAvailableNotification
		object:convertFileHandle
	];
	[convertFileHandle waitForDataInBackgroundAndNotify];
	[convertTask setStandardError:convertFileHandle];
	
	NSString *launchPath = [[NSBundle mainBundle] pathForAuxiliaryExecutable:@"mencoder"];
	if ( !launchPath ) {
		ERROR( @"launch path not set for conversion task, can't continue" );
		//TODO: cleanup
		return;
	}
	DEBUG( @"using launchPath: %@", launchPath );
	[convertTask setLaunchPath:launchPath];
	
	NSArray *argumentArray = [NSArray arrayWithObjects:
		@"-af",
		@"volume=13:1",
		@"-of", @"lavf",
		@"-lavfopts", @"i_certify_that_my_video_stream_does_not_use_b_frames",
		@"-demuxer", @"lavf",
		@"-lavfdopts", @"probesize=128",
		@"-oac", @"lavc",
		@"-ovc", @"lavc",
		@"-lavcopts", @"keyint=15:aglobal=1:vglobal=1:coder=1:vcodec=mpeg4:acodec=aac:vbitrate=1800:abitrate=128",
		@"-vf", @"pp=lb,scale=640:480,harddup"
		@"-o", convertPath,
		decodePath,
		nil
	];
	DEBUG( @"convert task arguments:\n%@", [argumentArray description] );
	[convertTask setArguments:argumentArray];
	
	[convertTask launch];
}

- (void)convertDataAvailable:(NSNotification *)notification
{
	NSFileHandle *fileHandle = [notification object];
	NSData *data = [fileHandle availableData];
	INFO( [data description] );
	[fileHandle waitForDataInBackgroundAndNotify];
}

#pragma mark -
#pragma mark Accessor type methods

- (NSString *)endingFilePath
{
	NSUserDefaultsController *defaults = [NSUserDefaultsController sharedUserDefaultsController];
	NSString *folder = [[defaults valueForKey:@"values"] valueForKey:@"downloadFolder"];
	
	//TODO: allow for subfolders or filename changes, etc.
	NSString *pathString = [
		[NSString stringWithFormat:@"%@/%@", folder, currentItem.program.title]
		stringByExpandingTildeInPath
	];
	return pathString;
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
}

- (void)download:(NSURLDownload *)download didCreateDestination:(NSString *)path
{
	//- I can see if the name changed from the suggested name here...
	currentItem.startedDate = [NSDate date];
}

- (void)download:(NSURLDownload *)download didReceiveDataOfLength:(NSUInteger)length
{
	[currentItem addByteLength:length];
}

- (void)downloadDidFinish:(NSURLDownload *)download
{
	INFO( @"download finished: %@", [programDownload description] );
	[programDownload release];
	programDownload = nil;
	
	if ( decodePath ) {
		[self beginDecode];
	} else {
		currentItem.completedDate = [NSDate date];
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

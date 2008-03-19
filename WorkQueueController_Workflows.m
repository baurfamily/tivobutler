//
//  WorkQueueController_Workflows.m
//  TiVo Butler
//
//  Created by Eric Baur on 3/18/08.
//  Copyright 2008 Eric Shore Baur. All rights reserved.
//

#import "WorkQueueController.h"

@implementation WorkQueueController (Workflow)

#pragma mark -
#pragma mark Generic methods

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

	NSString *programID = currentItem.program.programID;
	if ( !programID ) {
		ERROR( @"could not determine filename, programID is nil" );
		[self completeWithMessage:@"Failed"];
		return;
	}
	switch ( finalAction ) {
		case WQConvertAction:
			downloadPath = [[NSString pathWithComponents:
				[NSArray arrayWithObjects:tempDirectory, [NSString stringWithFormat:@"%@.tivo", programID], nil ]
			] retain];
			decodePath = [[NSString pathWithComponents:
				[NSArray arrayWithObjects:tempDirectory, [NSString stringWithFormat:@"%@.mpg", programID], nil ]
			] retain];
			convertPath = [[NSString stringWithFormat:@"%@.mp4", [self endingFilePath]] retain];
			break;
		case WQDecodeAction:
			downloadPath = [[NSString pathWithComponents:
				[NSArray arrayWithObjects:tempDirectory, [NSString stringWithFormat:@"%@.tivo", programID], nil ]
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
#pragma mark Decoding methods

- (void)beginDecode
{
	ENTRY;

	[decodeTask release];
	decodeTask = [[NSTask alloc] init];
	
	NSPipe *pipe = [NSPipe pipe];
	[decodeTask setStandardError:pipe];
	
	[decodeFileHandle release];
	decodeFileHandle = [[pipe fileHandleForReading] retain];
	
	[[NSNotificationCenter defaultCenter]
		addObserver:self 
		selector:@selector(decodeReadAvailableData:) 
		name:NSFileHandleDataAvailableNotification 
		object:decodeFileHandle
	];
	[decodeFileHandle waitForDataInBackgroundAndNotify];
	
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
		//@"--verbose",	//- prints out progress
		@"--mak",	[currentItem valueForKeyPath:@"program.player.mediaAccessKey"],
		@"--out",	decodePath,
		downloadPath,
		nil
	];
	INFO( @"decode task arguments:\n%@", [argumentArray description] );
	[decodeTask setArguments:argumentArray];
	
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		selector:@selector(decoderDidTerminate:)
		name:NSTaskDidTerminateNotification
		object:decodeTask
	];
	[decodeTask launch];
}

- (void)decodeReadAvailableData:(NSNotification *)notification
{
	ENTRY;
	NSData *data = [decodeFileHandle availableData];
	if ( [data length] ) {
		NSString *tempString = [[[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding] autorelease];
		INFO( tempString );
	}
	[decodeFileHandle waitForDataInBackgroundAndNotify];
}

- (void)decoderDidTerminate:(NSNotification *)notification
{
	ENTRY;
	NSError *error;
	BOOL succeeded = [[NSFileManager defaultManager] removeItemAtPath:downloadPath error:&error];
	if ( !succeeded ) {
		ERROR( [error localizedDescription] );
	}

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
	
	[decodeTask release];
	decodeTask = nil;
	[decodeFileHandle release];
	decodeFileHandle = nil;
}


#pragma mark -
#pragma mark Conversion methods

- (void)beginConversion
{
	ENTRY;

	[convertTask release];
	convertTask = [[NSTask alloc] init];
	
	NSPipe *pipe = [NSPipe pipe];
	[convertTask setStandardOutput:pipe];
	
	[convertFileHandle release];
	convertFileHandle = [[pipe fileHandleForReading] retain];

	[[NSNotificationCenter defaultCenter]
		addObserver:self 
		selector:@selector(convertReadAvailableData:) 
		name:NSFileHandleDataAvailableNotification 
		object:convertFileHandle
	];
	[convertFileHandle waitForDataInBackgroundAndNotify];
	
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

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		selector:@selector(convertDidTerminate:)
		name:NSTaskDidTerminateNotification
		object:convertTask
	];
	[convertTask launch];
}

- (void)convertReadAvailableData:(NSNotification *)notification
{
	NSData *data = [convertFileHandle availableData];
	if ( [data length] ) {
		NSString *tempString = [[[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding] autorelease];
		NSScanner *scanner = [NSScanner scannerWithString:tempString];
		
		NSString *otherTempString;
		[scanner scanUpToString:@"(" intoString:&otherTempString];
		[scanner scanString:@"(" intoString:NULL];
		[scanner scanUpToString:@"%)" intoString:&otherTempString];
		int newActionPercent = [otherTempString intValue];
		if (  newActionPercent != currentActionPercent ) {
			[self willChangeValueForKey:@"currentActionPercent"];
			currentActionPercent = newActionPercent;
			if ( 0 == currentActionPercent % 10 ) {
				INFO( @"currentActionPercent: %d\n%@", currentActionPercent, tempString );
			}
			[self didChangeValueForKey:@"currentActionPercent"];	
			//- do I want to pull how much data has been processed?
		}
	}
	[convertFileHandle waitForDataInBackgroundAndNotify];
}

- (void)convertDidTerminate:(NSNotification *)notification
{
	ENTRY;
	NSError *error;
	BOOL succeeded = [[NSFileManager defaultManager] removeItemAtPath:decodePath error:&error];
	if ( !succeeded ) {
		ERROR( [error localizedDescription] );
	}
	
	[convertFileHandle release];
	convertFileHandle = nil;
	
	if ( [convertTask terminationStatus] == 0 ) {
		DEBUG(@"Convert finished.");
	} else {
		ERROR(@"Convert failed.");
	}
	
	currentItem.savedPath = convertPath;
	[self completeWithMessage:nil];
	
	[convertTask release];
	convertTask = nil;
	[convertFileHandle release];
	convertFileHandle = nil;
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
		if ( 0 == currentActionPercent % 10 ) {
			INFO( @"currentActionPercent: %d for ( %d / %d )", currentActionPercent, receivedBytes, expectedBytes );
		}
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

//
//  WorkQueueController_Workflows.m
//  TiVo Butler
//
//  Created by Eric Baur on 3/18/08.
//  Copyright 2008 Eric Shore Baur. All rights reserved.
//

#import "WorkQueueController.h"

@implementation WorkQueueController (Workflows)

+ (NSDictionary *)workflowDefaults
{
	ENTRY;
	return [NSDictionary dictionaryWithObjectsAndKeys:
		//decode arguments
		[NSArray arrayWithObjects:
			[NSDictionary dictionaryWithObject:@"--no-verify"									forKey:@"value"],
			//[NSDictionary dictionaryWithObject:@"--verbose"									forKey:@"value"],
			[NSDictionary dictionaryWithObject:@"--mak"											forKey:@"value"],
			[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:WQArgumentMAK]			forKey:@"variable"],
			[NSDictionary dictionaryWithObject:@"--out"											forKey:@"value"],
			[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:WQArgumentOutputFile]	forKey:@"variable"],
			[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:WQArgumentInputFile]		forKey:@"variable"],
			nil
		], @"decodeAppArguments",
		//convert arguments
		[NSArray arrayWithObjects:
			[NSDictionary dictionaryWithObject:@"-af"							forKey:@"value"],
			[NSDictionary dictionaryWithObject:@"volume=13:1"					forKey:@"value"],
			[NSDictionary dictionaryWithObject:@"-of"							forKey:@"value"],
			[NSDictionary dictionaryWithObject:@"lavf"							forKey:@"value"],
			[NSDictionary dictionaryWithObject:@"-lavfopts"						forKey:@"value"],
			[NSDictionary dictionaryWithObject:@"i_certify_that_my_video_stream_does_not_use_b_frames" forKey:@"value"],
			[NSDictionary dictionaryWithObject:@"-demuxer"						forKey:@"value"],
			[NSDictionary dictionaryWithObject:@"lavf"							forKey:@"value"],
			[NSDictionary dictionaryWithObject:@"-lavfdopts"					forKey:@"value"],
			[NSDictionary dictionaryWithObject:@"probesize=128"					forKey:@"value"],
			[NSDictionary dictionaryWithObject:@"-oac"							forKey:@"value"],
			[NSDictionary dictionaryWithObject:@"lavc"							forKey:@"value"],
			[NSDictionary dictionaryWithObject:@"-ovc"							forKey:@"value"],
			[NSDictionary dictionaryWithObject:@"lavc"							forKey:@"value"],
			[NSDictionary dictionaryWithObject:@"-lavcopts"						forKey:@"value"],
			[NSDictionary dictionaryWithObject:@"keyint=15:aglobal=1:vglobal=1:coder=1:vcodec=mpeg4:acodec=libfaac:vbitrate=1800:abitrate=128" forKey:@"value"],
			[NSDictionary dictionaryWithObject:@"-vf"							forKey:@"value"],
			[NSDictionary dictionaryWithObject:@"pp=lb,scale=640:480,harddup"	forKey:@"value"],
			[NSDictionary dictionaryWithObject:@"-o"							forKey:@"value"],
			[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:WQArgumentOutputFile]	forKey:@"variable"],
			[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:WQArgumentInputFile]		forKey:@"variable"],
			nil
		], @"convertAppArguments",
		nil
	];
}

#pragma mark -
#pragma mark Generic methods

- (NSString *)stringForSubstitutionValue:(WQArgumentSubstitutionValue)substitutionValue atStage:(WQDownloadAction)actionStage
{
	switch ( substitutionValue ) {
		case WQArgumentNone:
			return nil;
			break;
		case WQArgumentMAK:
			return [currentItem valueForKeyPath:@"program.player.mediaAccessKey"];
			break;
		case WQArgumentInputFile:
			if		( WQDecodeAction == actionStage )	{ return downloadPath; }
			else if	( WQConvertAction == actionStage )	{ return decodePath; }
			else										{ return nil; }
			break;
		case WQArgumentOutputFile:
			if		( WQDecodeAction == actionStage )	{ return decodePath; }
			else if	( WQConvertAction == actionStage )	{ return convertPath; }
			else										{ return nil; }
			break;
		default:
			return nil;
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
	
	BOOL useIntermediateFolder = [[[defaults valueForKey:@"values"] valueForKey:@"useIntermediateFolder"] boolValue];
	keepIntermediateFiles = [[[defaults valueForKey:@"values"] valueForKey:@"keepIntermediateFiles"] boolValue];

	[downloadPath release];
	[decodePath release];
	[convertPath release];
	NSString *tempDirectory;
	if ( useIntermediateFolder ) {
		tempDirectory = [[[defaults valueForKey:@"values"] valueForKey:@"intermediateFolder"] stringByExpandingTildeInPath];
	} else {
		tempDirectory = NSTemporaryDirectory();
		keepIntermediateFiles = NO;
	}

	NSString *endingPath = [self endingFilePath];
	if ( !endingPath ) {
		WARNING( @"no valid file path, probably set to fail in preferences" );
		[self completeWithMessage:@"File exists"];
		return;
	}
	NSString *fileName = [[endingPath pathComponents] lastObject];
	
	switch ( finalAction ) {
		case WQConvertAction:
			downloadPath = [[NSString pathWithComponents:
				[NSArray arrayWithObjects:tempDirectory, [NSString stringWithFormat:@"%@.tivo", fileName], nil ]
			] retain];
			decodePath = [[NSString pathWithComponents:
				[NSArray arrayWithObjects:tempDirectory, [NSString stringWithFormat:@"%@.mpg", fileName], nil ]
			] retain];
			convertPath = [[NSString stringWithFormat:@"%@.mp4", endingPath] retain];
			break;
		case WQDecodeAction:
			downloadPath = [[NSString pathWithComponents:
				[NSArray arrayWithObjects:tempDirectory, [NSString stringWithFormat:@"%@.tivo", fileName], nil ]
			] retain];
			decodePath = [[NSString stringWithFormat:@"%@.mpg", endingPath] retain];
			convertPath = nil;
			break;
		case WQDownloadOnlyAction:
			downloadPath = [[NSString stringWithFormat:@"%@.tivo", endingPath] retain];
			decodePath = nil;
			convertPath = nil;
			break;
		default:
			WARNING( @"no download action set, downloading only" );
			downloadPath = [[NSString stringWithFormat:@"%@.tivo", endingPath] retain];
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
	[programDownload setDestination:downloadPath allowOverwrite:YES];
	currentItem.startedDate = [NSDate date];
}

- (void)removeFiles
{
	[convertTask terminate];
	if ( !keepIntermediateFiles && convertPath )
		[[NSFileManager defaultManager] removeItemAtPath:convertPath error:NULL];
	[convertPath release];
	convertPath = nil;
	
	[decodeTask terminate];
	if ( !keepIntermediateFiles && decodePath )
		[[NSFileManager defaultManager] removeItemAtPath:decodePath error:NULL];
	[decodePath release];
	decodePath = nil;
	
	[programDownload cancel];
	if ( !keepIntermediateFiles && downloadPath )
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

	NSUserDefaultsController *defaults = [NSUserDefaultsController sharedUserDefaultsController];

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
	
	BOOL useExternalApp = [[[defaults valueForKey:@"values"] valueForKey:@"decodeWithExternalApp"] boolValue];
	
	NSString *launchPath;
	if ( useExternalApp ) {
		launchPath =  [[defaults valueForKey:@"values"] valueForKey:@"decodeAppPath"];
	} else {
		launchPath = [[NSBundle mainBundle] pathForAuxiliaryExecutable:@"tivodecode"];
	}
	if ( !launchPath ) {
		ERROR( @"launch path not set for decode task, can't continue" );
		[self removeFiles];
		[self completeWithMessage:@"Failed"];
		return;
	}
	DEBUG( @"using launchPath: %@", launchPath );
	[decodeTask setLaunchPath:launchPath ];
	
	NSMutableArray *arguments = [NSMutableArray array];
	NSArray *defaultsArgumentArray = [[defaults valueForKey:@"values"] valueForKey:@"decodeAppArguments"];
	NSDictionary *tempDict;
	for ( tempDict in defaultsArgumentArray ) {
		NSString *tempString = [tempDict valueForKey:@"value"];
		WQArgumentSubstitutionValue tempSub = [[tempDict valueForKey:@"variable"] intValue];
		
		if ( tempString && WQArgumentNone != tempSub && ![tempString isEqualToString:@""]) {
			[arguments addObject:
				[NSString stringWithFormat:@"%@ %@",
					tempString,
					[self stringForSubstitutionValue:tempSub atStage:currentAction]
				]
			];
		} else if ( WQArgumentNone != tempSub ) {
			[arguments addObject:[self stringForSubstitutionValue:tempSub atStage:currentAction] ];
		} else {
			[arguments addObject:tempString];
		}
	}
	//INFO( @"decode task arguments:\n%@", [arguments description] );	//- don't want to log the MAK
	[decodeTask setArguments:arguments];
	
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
	
	if ( [decodeTask terminationStatus] == 0 ) {
		DEBUG(@"Decode finished.");
		if ( !keepIntermediateFiles ) {
			NSError *error;
			BOOL succeeded = [[NSFileManager defaultManager] removeItemAtPath:downloadPath error:&error];
			if ( !succeeded ) {
				ERROR( [error localizedDescription] );
			}
		}
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

	NSUserDefaultsController *defaults = [NSUserDefaultsController sharedUserDefaultsController];

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
	
	BOOL useExternalApp = [[[defaults valueForKey:@"values"] valueForKey:@"convertWithExternalApp"] boolValue];
	
	NSString *launchPath;
	if ( useExternalApp ) {
		launchPath = [[defaults valueForKey:@"values"] valueForKey:@"convertAppPath"];
	} else {
		launchPath = [[NSBundle mainBundle] pathForAuxiliaryExecutable:@"mencoder"];
	}
	if ( !launchPath ) {
		ERROR( @"launch path not set for conversion task, can't continue" );
		[self removeFiles];
		[self completeWithMessage:@"Failed"];
		return;
	}
	
	NSMutableArray *arguments = [NSMutableArray array];
	NSArray *defaultsArgumentArray = [[defaults valueForKey:@"values"] valueForKey:@"convertAppArguments"];
	NSDictionary *tempDict;
	for ( tempDict in defaultsArgumentArray ) {
		NSString *tempString = [tempDict valueForKey:@"value"];
		WQArgumentSubstitutionValue tempSub = [[tempDict valueForKey:@"variable"] intValue];
		
		if ( tempString && WQArgumentNone != tempSub && ![tempString isEqualToString:@""]) {
			[arguments addObject:
				[NSString stringWithFormat:@"%@ %@",
					tempString,
					[self stringForSubstitutionValue:tempSub atStage:currentAction]
				]
			];
		} else if ( WQArgumentNone != tempSub ) {
			[arguments addObject:[self stringForSubstitutionValue:tempSub atStage:currentAction] ];
		} else {
			[arguments addObject:tempString];
		}
	}
	DEBUG( @"using launchPath: %@", launchPath );
	[convertTask setLaunchPath:launchPath];

	INFO( @"convert task arguments:\n%@", [arguments description] );
	[convertTask setArguments:arguments];

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
		
		NSString *otherTempString = nil;
		[scanner scanUpToString:@"(" intoString:NULL];
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
	[convertFileHandle release];
	convertFileHandle = nil;
	
	if ( [convertTask terminationStatus] == 0 ) {
		DEBUG(@"Convert finished.");
		if ( !keepIntermediateFiles ) {
			NSError *error;
			BOOL succeeded = [[NSFileManager defaultManager] removeItemAtPath:decodePath error:&error];
			if ( !succeeded ) {
				ERROR( [error localizedDescription] );
			}
		}
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
	if ( ![downloadPath isEqualToString:path] ) {
		WARNING( @"Changing download path:\nfrom '%@'\nto %@'", downloadPath, path );
		[downloadPath release];
		downloadPath = [path retain];
	}
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

	if ( [challenge previousFailureCount] == 0 ) {
		NSURLCredential *newCredential = [[NSURLCredential
			credentialWithUser:@"tivo"
			password:mak
			persistence:NSURLCredentialPersistenceNone
		] autorelease];
		
		[[challenge sender] useCredential:newCredential forAuthenticationChallenge:challenge];
	} else {
		ERROR( @"the supplied MAK was incorrect for the given IP address" );
		[[challenge sender] cancelAuthenticationChallenge:challenge];
	}
}


@end

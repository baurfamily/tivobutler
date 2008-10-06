//
//  WorkQueueStep_Workflows.m
//  TiVo Butler
//
//  Created by Eric Baur on 5/13/08.
//  Copyright 2008 Eric Shore Baur. All rights reserved.
//

#import "WorkQueueStep.h"


@implementation WorkQueueStep (Workflows)

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
			[NSDictionary dictionaryWithObject:@"-af volume=13:1"							forKey:@"value"],
			[NSDictionary dictionaryWithObject:@"-of lavf"						forKey:@"value"],
			[NSDictionary dictionaryWithObject:@"-demuxer lavf"					forKey:@"value"],
			[NSDictionary dictionaryWithObject:@"-lavfdopts probesize=128"					forKey:@"value"],
			[NSDictionary dictionaryWithObject:@"-oac lavc"						forKey:@"value"],
			[NSDictionary dictionaryWithObject:@"-ovc lavc"						forKey:@"value"],
			[NSDictionary dictionaryWithObject:@"-lavcopts keyint=15:aglobal=1:vglobal=1:coder=1:vcodec=mpeg4:acodec=libfaac:vbitrate=1800:abitrate=128" forKey:@"value"],
			[NSDictionary dictionaryWithObject:@"-vf pp=lb,scale=640:480,harddup" forKey:@"value"],
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

- (NSString *)stringForSubstitutionValue:(WQArgumentSubstitutionValue)substitutionValue
{
	switch ( substitutionValue ) {
		case WQArgumentNone:		return nil;																break;
		case WQArgumentMAK:			return [self valueForKeyPath:@"item.program.player.mediaAccessKey"];	break;
		case WQArgumentInputFile:	return self.readFile.path;												break;
		case WQArgumentOutputFile:	return self.writeFile.path;												break;
	}
	return nil;
}

- (void)beginProcessing
{
	ENTRY;
	
	[self setValue:self forKeyPath:@"item.currentStep"];
	int action = [self.actionType intValue];
	switch (action) {
		case WQDownloadAction:		[self beginDownload];		break;
		case WQDecodeAction:		[self beginDecode];			break;
		case WQConvertAction:		[self beginConversion];		break;
		//case WQPostProcessAction:	[self beginPostProcessing];	break;
		default:	WARNING( @"no action to take for actionType: %d", action );
	}
}

- (void)beginDownload
{
	ENTRY;
	NSString *tempURLString = self.item.program.contentURL;
	if ( !tempURLString ) {
		ERROR( @"no URL string set, can't download" );
		return;
	}
	NSURL *url = [NSURL URLWithString:tempURLString];
	INFO( @"Downloading from URL: %@", [url description] );
	INFO( @"Downloading to file: %@", self.writeFile.path );
	
	NSURLRequest *request = [NSURLRequest requestWithURL:url];
	
	receivedBytes = 0;
	expectedBytes = [self.item.program.sourceSize longLongValue];
	INFO( @"expecting %lld bytes", expectedBytes );
	
	programDownload = [[NSURLDownload alloc] initWithRequest:request delegate:self];
	if ( !programDownload ) {
		ERROR( @"can't download program, download connection not created" );
		[self completeWithMessage:@"Failed to create download request." successful:NO];
		return;
	}
	[programDownload setDestination:self.writeFile.path allowOverwrite:YES];
	self.startedDate = [NSDate date];
}

- (void)removeFiles
{
	[queueTask terminate];
	if ( [self.shouldKeepInput boolValue] ) {
		[self.readFile removeFile];
	}
}

- (void)completeWithMessage:(NSString *)message successful:(BOOL)successful
{
	if ( message )
		self.message = message;
	self.successful = [NSNumber numberWithBool:successful];
	self.completedDate = [NSDate date];
	[self.item completedStep:self successful:successful];
}

#pragma mark -
#pragma mark Decoding methods

- (void)beginDecode
{
	ENTRY;
	
	self.currentActionPercent = [NSNumber numberWithInt:0];
	
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	
	[queueTask release];
	queueTask = [[NSTask alloc] init];
	
	NSPipe *pipe = [NSPipe pipe];
	[queueTask setStandardError:pipe];
	
	[queueFileHandle release];
	queueFileHandle = [[pipe fileHandleForReading] retain];
	
	[[NSNotificationCenter defaultCenter]
		addObserver:self 
		selector:@selector(decodeReadAvailableData:) 
		name:NSFileHandleDataAvailableNotification 
		object:queueFileHandle
	];
	[queueFileHandle waitForDataInBackgroundAndNotify];
	
	BOOL useExternalApp = [[defaults valueForKey:@"decodeWithExternalApp"] boolValue];
	
	NSString *launchPath;
	if ( useExternalApp ) {
		launchPath =  [defaults valueForKey:@"decodeAppPath"];
	} else {
		launchPath = [[NSBundle mainBundle] pathForAuxiliaryExecutable:@"tivodecode"];
	}
	if ( !launchPath ) {
		ERROR( @"launch path not set for decode task, can't continue" );
		[self removeFiles];
		[self completeWithMessage:@"Failed" successful:NO];
		
		[queueTask release], queueTask = nil;
		[queueFileHandle release], queueFileHandle = nil;
		
		return;
	}
	DEBUG( @"using launchPath: %@", launchPath );
	[queueTask setLaunchPath:launchPath ];
	
	NSMutableArray *arguments = [NSMutableArray array];
	NSArray *defaultsArgumentArray = [defaults valueForKey:@"decodeAppArguments"];
	NSDictionary *tempDict;
	for ( tempDict in defaultsArgumentArray ) {
		NSString *tempString = [tempDict valueForKey:@"value"];
		WQArgumentSubstitutionValue tempSub = [[tempDict valueForKey:@"variable"] intValue];
		
		if ( tempString && WQArgumentNone != tempSub && ![tempString isEqualToString:@""]) {
			[arguments addObject:
			 [NSString stringWithFormat:@"%@ %@",
			  tempString,
			  [self stringForSubstitutionValue:tempSub]
			  ]
			 ];
		} else if ( WQArgumentNone != tempSub ) {
			[arguments addObject:[self stringForSubstitutionValue:tempSub] ];
		} else if ( tempString && ![tempString isEqualToString:@""] ) {
			[arguments addObject:tempString];
		} else {
			WARNING( @"encountered empty argument for decode task, skipping..." );
		}
	}
	INFO( @"decode task arguments:\n%@", [arguments description] );	//- don't want to log the MAK
	[queueTask setArguments:arguments];
	
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		selector:@selector(decoderDidTerminate:)
		name:NSTaskDidTerminateNotification
		object:queueTask
	];
	[queueTask launch];
}

- (void)decodeReadAvailableData:(NSNotification *)notification
{
	ENTRY;
	NSData *data = [queueFileHandle availableData];
	if ( [data length] ) {
		NSString *tempString = [[[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding] autorelease];
		INFO( tempString );
	}
	[queueFileHandle waitForDataInBackgroundAndNotify];
}

- (void)decoderDidTerminate:(NSNotification *)notification
{
	ENTRY;
	
	if ( [queueTask terminationStatus] == 0 ) {
		DEBUG(@"Decode finished.");
		if ( ! [self.shouldKeepInput boolValue] ) {
			[self.writeFile removeFile];
		}
		[self completeWithMessage:@"Decode complete." successful:YES];
	} else {
		ERROR(@"Decode failed.");
		[self completeWithMessage:@"Decode failed." successful:NO];
	}
	
	[queueTask release], queueTask = nil;
	[queueFileHandle release], queueFileHandle = nil;
}


#pragma mark -
#pragma mark Conversion methods

- (void)beginConversion
{
	ENTRY;
	
	self.currentActionPercent = [NSNumber numberWithInt:0];
	
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	
	[queueTask release];
	queueTask = [[NSTask alloc] init];
	
	NSPipe *pipe = [NSPipe pipe];
	[queueTask setStandardOutput:pipe];
	
	[queueFileHandle release];
	queueFileHandle = [[pipe fileHandleForReading] retain];
	
	[[NSNotificationCenter defaultCenter]
		addObserver:self 
		selector:@selector(convertReadAvailableData:) 
		name:NSFileHandleDataAvailableNotification 
		object:queueFileHandle
	];
	[queueFileHandle waitForDataInBackgroundAndNotify];
	
	BOOL useExternalApp = [[defaults valueForKey:@"convertWithExternalApp"] boolValue];
	
	NSString *launchPath;
	if ( useExternalApp ) {
		launchPath = [defaults valueForKey:@"convertAppPath"];
	} else {
		launchPath = [[NSBundle mainBundle] pathForAuxiliaryExecutable:@"mencoder"];
	}
	if ( !launchPath ) {
		ERROR( @"launch path not set for conversion task, can't continue" );
		[self removeFiles];
		[self completeWithMessage:@"Failed" successful:NO];
		
		[queueTask release], queueTask = nil;
		[queueFileHandle release], queueFileHandle = nil;
		return;
	}
	
	NSMutableArray *arguments = [NSMutableArray array];
	NSArray *defaultsArgumentArray = [defaults valueForKey:@"convertAppArguments"];
	NSDictionary *tempDict;
	for ( tempDict in defaultsArgumentArray ) {
		NSString *tempString = [tempDict valueForKey:@"value"];
		WQArgumentSubstitutionValue tempSub = [[tempDict valueForKey:@"variable"] intValue];
		
		if ( tempString && WQArgumentNone != tempSub && ![tempString isEqualToString:@""]) {
			[arguments addObject:
			 [NSString stringWithFormat:@"%@ %@",
			  tempString,
			  [self stringForSubstitutionValue:tempSub]
			  ]
			 ];
		} else if ( WQArgumentNone != tempSub ) {
			[arguments addObject:[self stringForSubstitutionValue:tempSub] ];
		} else if ( tempString && ![tempString isEqualToString:@""] ) {
			[arguments addObject:tempString];
		} else {
			WARNING( @"argument with empty value encountered for convert task, skipping" );
		}
	}
	DEBUG( @"using launchPath: %@", launchPath );
	[queueTask setLaunchPath:launchPath];
	
	INFO( @"convert task arguments:\n%@", [arguments description] );
	[queueTask setArguments:arguments];
	
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		selector:@selector(convertDidTerminate:)
		name:NSTaskDidTerminateNotification
		object:queueTask
	];
	[queueTask launch];
}

- (void)convertReadAvailableData:(NSNotification *)notification
{
	NSData *data = [queueFileHandle availableData];
	if ( [data length] ) {
		NSString *tempString = [[[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding] autorelease];
		NSScanner *scanner = [NSScanner scannerWithString:tempString];
		
		NSString *otherTempString = nil;
		if ( ![scanner scanString:@"Pos:" intoString:NULL] ) {
			//- didn't find a line with a % output in it, so we'll log the output
			INFO( tempString );
		} else {
			[scanner scanUpToString:@"f (" intoString:NULL];
			[scanner scanString:@"f (" intoString:NULL];
			[scanner scanUpToString:@"%)" intoString:&otherTempString];
			int newActionPercent = [otherTempString intValue];
			if (  newActionPercent != [self.currentActionPercent intValue] ) {
				self.currentActionPercent = [NSNumber numberWithInt:newActionPercent];
				if ( 0 == newActionPercent % 10 ) {
					INFO( @"currentActionPercent: %d\n%@", newActionPercent, tempString );
				}
				//- do I want to pull how much data has been processed?
			}
		}
	}
	[queueFileHandle waitForDataInBackgroundAndNotify];
}

- (void)convertDidTerminate:(NSNotification *)notification
{
	ENTRY;
	[queueFileHandle release];
	queueFileHandle = nil;
	
	if ( [queueTask terminationStatus] == 0 ) {
		DEBUG(@"Convert finished.");
		if ( ! [self.shouldKeepInput boolValue] ) {
			[self.writeFile removeFile];
		}
		[self completeWithMessage:@"Conversion completed." successful:YES];
	} else {
		ERROR(@"Convert failed.");
		[self completeWithMessage:@"Conversion failed." successful:NO];
	}
	
	[queueTask release], queueTask = nil;
	[queueFileHandle release], queueFileHandle = nil;
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
	[self completeWithMessage:[error localizedDescription] successful:NO];
}

- (void)download:(NSURLDownload *)download didCreateDestination:(NSString *)path
{
	if ( ![self.writeFile.path isEqualToString:path] ) {
		WARNING( @"Changing download path:\nfrom '%@'\nto %@'", self.writeFile.path, path );
		self.writeFile.path = path;
	}
}

- (void)download:(NSURLDownload *)download didReceiveDataOfLength:(NSUInteger)length
{
	receivedBytes += length;
	int newActionPercent = ( 100 * receivedBytes ) / expectedBytes;
	if ( newActionPercent != [self.currentActionPercent intValue] ) {
		self.currentActionPercent = [NSNumber numberWithInt:newActionPercent];
		if ( 0 == newActionPercent % 10 ) {
			INFO( @"currentActionPercent: %d for ( %lld / %lld )", newActionPercent, receivedBytes, expectedBytes );
		}
	}
}

- (void)downloadDidFinish:(NSURLDownload *)download
{
	INFO( @"download finished: %@", [programDownload description] );
	[programDownload release], programDownload = nil;
	
	[self completeWithMessage:@"Download completed." successful:YES];
}

- (void)download:(NSURLDownload *)download didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{
	ENTRY;
	NSString *mak = [self valueForKeyPath:@"item.program.player.mediaAccessKey"];
	
	if ( [challenge previousFailureCount] == 0 ) {
		NSURLCredential *newCredential =
			[[NSURLCredential
				credentialWithUser:@"tivo"
				password:mak
				persistence:NSURLCredentialPersistenceNone
			] autorelease
		];
		
		[[challenge sender] useCredential:newCredential forAuthenticationChallenge:challenge];
	} else {
		ERROR( @"The supplied MAK was incorrect for the given IP address" );
		[[challenge sender] cancelAuthenticationChallenge:challenge];
		[self completeWithMessage:@"The supplied MAK was incorrect for the given IP address." successful:NO];
	}
}

@end

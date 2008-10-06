// 
//  TiVoPlayer.m
//  TiVo Butler
//
//  Created by Eric Baur on 1/15/08.
//  Copyright 2008 Eric Shore Baur. All rights reserved.
//

#import "TiVoPlayer.h"

#import "TiVoProgram.h"

@implementation TiVoPlayer 

- (void)awakeFromInsert
{
	ENTRY;
    [super awakeFromInsert];
	anchor = 0;
	receivedData = [[NSMutableData alloc] init];
}

- (void)awakeFromFetch
{
	ENTRY;
    [super awakeFromInsert];
	anchor = 0;
	receivedData = [[NSMutableData alloc] init];
	[self connect];
	
	checkTimer = [[NSTimer
		scheduledTimerWithTimeInterval:(60 * [self.checkInterval intValue])
		target:self
		selector:@selector(connect)
		userInfo:nil
		repeats:YES
	] retain];
}

#pragma mark -
#pragma mark Action methods

- (void)connect
{
	if ( ! ( [self host] && [self mediaAccessKey] ) ) {
		WARNING( @"Can't connect, not enough information." );
		return;
	}
		
	if (urlConnection) {
		WARNING( @"already connected" );
		[urlConnection cancel];
		[urlConnection release], urlConnection = nil;
	}
	
	[self setDateLastChecked:[NSDate date] ];
	
	url = [NSURL URLWithString:[NSString stringWithFormat:
			@"https://%@/TiVoConnect?Command=QueryContainer&Container=%%2FNowPlaying&Recurse=Yes&AnchorOffset=%d",
			[self host],
			anchor
		]
	];

	urlConnection = [[NSURLConnection alloc]
		initWithRequest:[NSURLRequest requestWithURL:url]
		delegate:self
	];
	
	if (urlConnection) {
		INFO( @"Connecting to: %@", [url description] );
	} else {
		ERROR( @"Couldn't download the Now Playing list." );
	}
}

#pragma mark -
#pragma mark Accessor methods

@dynamic capacity;
@dynamic mediaAccessKey;
@dynamic host;
@dynamic dateLastChecked;
@dynamic dateLastUpdated;
@dynamic name;
@dynamic programs;
@dynamic checkInterval;

@dynamic url;


- (void)setHost:(NSString *)value 
{
    [self willChangeValueForKey:@"host"];
    [self setPrimitiveHost:value];

	NSString *tempValue = [self primitiveMediaAccessKey];
	if (tempValue) {
		[self connect];
	}

    [self didChangeValueForKey:@"host"];
}

- (void)setMediaAccessKey:(NSString *)value 
{
    [self willChangeValueForKey:@"mediaAccessKey"];
    [self setPrimitiveMediaAccessKey:value];

	NSString *tempValue = [self primitiveHost];
	if (tempValue) {
		[self connect];
	}

	[self didChangeValueForKey:@"mediaAccessKey"];
}

- (void)setCheckInterval:(NSNumber *)value
{
	[self willChangeValueForKey:@"checkInterval"];
	[self setPrimitiveCheckInterval:value];

	[checkTimer invalidate];
	[checkTimer release];
	checkTimer = [[NSTimer
		scheduledTimerWithTimeInterval:(60 * [self.checkInterval intValue])
		target:self
		selector:@selector(connect)
		userInfo:nil
		repeats:YES
	] retain];

	[self didChangeValueForKey:@"checkInterval"];
}

#pragma mark -
#pragma mark NSURLConnection delegate methods

- (void)connection:(NSURLConnection *)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{
	ENTRY;
	if ( [challenge previousFailureCount] == 0 ) {
		NSURLCredential *newCredential = [[NSURLCredential
			credentialWithUser:@"tivo"
			password:[self mediaAccessKey]
			persistence:NSURLCredentialPersistenceNone
		] autorelease];
		
		[[challenge sender] useCredential:newCredential forAuthenticationChallenge:challenge];
	} else {
		ERROR( @"the supplied MAK was incorrect for the given IP address" );
		[[challenge sender] cancelAuthenticationChallenge:challenge];
	}
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
	DEBUG( @"got %d bytes (%d total)...", [data length], [receivedData length] );
	[receivedData appendData:data];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
	ERROR( @"Connection failed! Error - %@ %@" ,
		[error localizedDescription],
		[[error userInfo] objectForKey:NSErrorFailingURLStringKey]
	);
	[urlConnection release], urlConnection = nil;
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
	ENTRY;
	[receivedData setLength:0];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
	INFO( @"Succeeded! Received %d bytes of data", [receivedData length] );
	CalypsoXMLParser *parser = [[[CalypsoXMLParser alloc] init] autorelease];
	
	BOOL reset = NO;
	//- if anchor is zero, just started, so reset the program list
	if (anchor==0) {
		reset = YES;
	}
	
	DEBUG( @"beginning parse" );
	int programsParsed = [parser parseData:receivedData fromPlayer:self resetPrograms:reset];
	DEBUG( @"ended parse of %d programs", programsParsed );
	
	[urlConnection release], urlConnection = nil;
	
	//- if we saw exactly 128 programs, connect again, or reset
	if ( programsParsed == TiVoPlayerMaxPrograms ) {
		anchor += TiVoPlayerMaxPrograms;
		[self connect];
	} else {
		anchor = 0;
	}
	
	EXIT;
}

- (NSURLRequest *)connection:(NSURLConnection *)connection willSendRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)redirectResponse
{
	ENTRY;
	DEBUG( @" - connection: %@", [connection description] );
	NSURLRequest *newRequest = request;
	DEBUG( @" - newRequest: %@", [request description] );
	if ( redirectResponse ) {
		DEBUG( @" - redirectResponse: %@", [redirectResponse description] );
		//newRequest = nil; //this would deny redirects!
	}
	return newRequest;
}

-(NSCachedURLResponse *)connection:(NSURLConnection *)connection willCacheResponse:(NSCachedURLResponse *)cachedResponse
{
	//don't allow caching in this application (we always want fresh data)
	return nil;
}
@end

#pragma mark -

@implementation NSURLRequest(NSHTTPURLRequestHack)

+ (BOOL)allowsAnyHTTPSCertificateForHost:(NSString *)host
{
	INFO( @"checking certificate for %@", host );
	return YES;
}

@end

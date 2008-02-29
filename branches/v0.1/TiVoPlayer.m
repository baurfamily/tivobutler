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
		urlConnection = nil;
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
@dynamic nowPlayingList;

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

#pragma mark -
#pragma mark NSURLConnection delegate methods

- (void)connection:(NSURLConnection *)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{
	ENTRY;
	if ( [challenge previousFailureCount] == 0 ) {
		NSURLCredential *newCredential = [NSURLCredential
			credentialWithUser:@"tivo"
			password:[self mediaAccessKey]
			persistence:NSURLCredentialPersistenceNone
		];
		
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
	//I shouldn't need to release because of GC
	ERROR( @"Connection failed! Error - %@ %@" ,
		[error localizedDescription],
		[[error userInfo] objectForKey:NSErrorFailingURLStringKey]
	);
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
	ENTRY;
	[receivedData setLength:0];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
	INFO( @"Succeeded! Received %d bytes of data", [receivedData length] );
	if ( !parser ) {
		parser = [[CalypsoXMLParser alloc] init];
	}	
	DEBUG( @"beginning parse" );
/*	[NSThread
		detachNewThreadSelector:@selector(beginParseThreadWithSettings:)
		toTarget:parser
		withObject:[NSDictionary dictionaryWithObjectsAndKeys:
			self,			@"player",
			receivedData,	@"data",
			nil
		]
	];
*/
	[parser parseData:receivedData fromPlayer:self];
	DEBUG( @"ended parse" );
	[urlConnection release];
	urlConnection = nil;
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

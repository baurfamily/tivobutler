//
//  WorkQueueItem.m
//  TiVo Butler
//
//  Created by Eric Baur on 2/7/08.
//  Copyright 2008 Eric Shore Baur. All rights reserved.
//

#import "WorkQueueItem.h"


@implementation WorkQueueItem

- (void)awakeFromInsert
{
	ENTRY;
	self.addedDate = [NSDate date];
	//[self beginDownload];
}

#pragma mark -
#pragma mark Action methods

- (void)beginDownload
{
	ENTRY;
	NSString *tempURLString = self.program.contentURL;
	if ( !tempURLString ) {
		ERROR( @"no URL string set" );
		return;
	}
	NSURL *url = [NSURL URLWithString:tempURLString];

	NSURLRequest *request = [NSURLRequest requestWithURL:url];

	programDownload = [[NSURLDownload alloc] initWithRequest:request delegate:self];

	if (programDownload) {
		INFO( @"Downloading: %@", [url description] );
		NSUserDefaultsController *defaults = [NSUserDefaultsController sharedUserDefaultsController];
		NSString *folder = [[defaults valueForKey:@"values"] valueForKey:@"downloadFolder"];
		NSString *pathString = [[NSString stringWithFormat:@"%@/%@", folder, self.program.title] stringByExpandingTildeInPath];
		DEBUG( @"setting download path: %@", pathString );
		[programDownload setDestination:pathString allowOverwrite:YES];	//TODO: make overwrite optional
		self.startedDate = [NSDate date];
	} else {
		ERROR( @"Couldn't download the video content." );
	}
}

#pragma mark -
#pragma mark Accessor methods

@dynamic active;
@dynamic addedDate;
@dynamic completedDate;
@dynamic name;
@dynamic startedDate;

@dynamic program;

- (NSNumber *)active
{
	if ( nil==self.completedDate && nil!=self.startedDate )
		return [NSNumber numberWithBool:YES];
	else
		return [NSNumber numberWithBool:NO];
}

- (NSString *)name
{
	if ( nil != self.program) {
		return self.program.title;
	} else {
		return @"";
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
}

- (void)download:(NSURLDownload *)download didReceiveDataOfLength:(NSUInteger)length
{
	receivedBytes += length;
}

- (void)downloadDidFinish:(NSURLDownload *)download
{
	if ( download == programDownload ) {
		INFO( @"download finished: %@", [programDownload description] );
		[programDownload release];
		programDownload = nil;
		self.completedDate = [NSDate date];
	}
}

- (void)download:(NSURLDownload *)download didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{
	ENTRY;
	NSString *mak = [self.program.player valueForKey:@"mediaAccessKey"];
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

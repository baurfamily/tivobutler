//
//  TiVo_FS_Filesystem.m
//  TiVo FS
//
//  Created by Eric Baur on 10/17/09.
//  Copyright 2009 Eric Shore Baur. All rights reserved.
//
#import <sys/xattr.h>
#import <sys/stat.h>

#import <stdio.h>

#import "TiVo_FS_Filesystem.h"
#import <MacFUSE/MacFUSE.h>

static NSString * TVFSPathProgramGroups = @"/Program Groups";
static NSString * TVFSPathPlayers = @"/Players";
static NSString * TVFSPathStations = @"/Stations";
static NSString * TVFSPathDates = @"/Dates";

// Methods to help modify strings for the way we deal with paths
@interface NSString (TVFSPathHelper)
- (NSString *)stringWithoutLeadingSlash;
- (NSString *)baseDirectory;
@end
@implementation NSString (TVFSPathHelper)
- (NSString *)stringWithoutLeadingSlash
{
	return [self stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"/"]];
}
- (NSString *)baseDirectory
{
	NSArray *components = [self pathComponents];
	if ( [[components objectAtIndex:0] isEqualToString:@"/"] && components.count > 1 )
	{
		return [NSString stringWithFormat:@"/%@", [components objectAtIndex:1]];
	}
	return nil;
}
@end

// Category on NSError to  simplify creating an NSError based on posix errno.
@interface NSError (POSIX)
+ (NSError *)errorWithPOSIXCode:(int)code;
@end
@implementation NSError (POSIX)
+ (NSError *)errorWithPOSIXCode:(int) code {
  return [NSError errorWithDomain:NSPOSIXErrorDomain code:code userInfo:nil];
}
@end

// NOTE: It is fine to remove the below sections that are marked as 'Optional'.

// The core set of file system operations. This class will serve as the delegate
// for GMUserFileSystemFilesystem. For more details, see the section on 
// GMUserFileSystemOperations found in the documentation at:
// http://macfuse.googlecode.com/svn/trunk/core/sdk-objc/Documentation/index.html
@implementation TiVo_FS_Filesystem

- (id)init
{
	self = [super init];
	if ( self ) {
		selectedPrograms = [[NSMutableDictionary alloc] init];
		selectedProgramDownloads = [[NSMutableDictionary alloc] init];
		selectedDownloadPaths = [[NSMutableDictionary alloc] init];
	}
	return self;
}

#pragma mark Directory Contents

- (NSArray *)contentsOfDirectoryAtPath:(NSString *)path error:(NSError **)error
{
	NSArray *returnArray;
	NSArray *components = [path pathComponents];

	switch ( components.count )
	{
		case 1:
			returnArray = [self baseDirectories];
			break;
		case 2:
			returnArray = [self groupDirectoriesForGroup:[components objectAtIndex:1] ];
			break;
		case 3:
			returnArray = [self programFilesForDirectory:[components objectAtIndex:2] inGroup:[components objectAtIndex:1] ];
		default:
			WARNING( @"Couldn't match number of components in path: %@", path );
	}
	return returnArray;
}

//this lists the standard groups that we have at the root of the filesystem
- (NSArray *)baseDirectories
{
	NSMutableArray *returnArray = [NSMutableArray array];
	[returnArray addObject:[TVFSPathProgramGroups stringWithoutLeadingSlash]];
	[returnArray addObject:[TVFSPathPlayers stringWithoutLeadingSlash]];
	[returnArray addObject:[TVFSPathDates stringWithoutLeadingSlash]];
	[returnArray addObject:[TVFSPathStations stringWithoutLeadingSlash]];
	return returnArray;
}

//this lists the folders in the grouping that was picked
- (NSArray *)groupDirectoriesForGroup:(NSString *)group
{
	NSMutableArray *returnArray = [NSMutableArray array];
	NSString *pathWithSlash = [NSString stringWithFormat:@"/%@", group];
	
	if ( [pathWithSlash isEqualToString:TVFSPathPlayers] )
	{
		NSArray *players = [EntityHelper arrayOfEntityWithName:TiVoPlayerEntityName usingPredicate:[NSPredicate predicateWithValue:YES] ];

		TiVoPlayer *player;
		for ( player in players ) {
			[returnArray addObject:player.name ];
		}
	}
	else if ( [pathWithSlash isEqualToString:TVFSPathProgramGroups] )
	{
		NSArray *programGroups = [EntityHelper
			arrayOfEntityWithName:TiVoSeriesEntityName
			usingPredicateString:@"ANY programs.deletedFromPlayer = NO"
			withSortKeys:[NSArray arrayWithObject:@"title"]
		];
		id series;
		for ( series in programGroups ) {
			[returnArray addObject:[series valueForKey:@"title"]];
		}
	}
	else if ( [pathWithSlash isEqualToString:TVFSPathStations] )
	{
		NSArray *stations = [EntityHelper
			arrayOfEntityWithName:TiVoStationEntityName
			usingPredicateString:@"ANY programs.deletedFromPlayer = NO"
			withSortKeys:[NSArray arrayWithObject:@"name"]
		];
		
		NSManagedObject *tempObject;
		for ( tempObject in stations ) {
			[returnArray addObject:
				[NSString stringWithFormat:@"%@ - %@", [tempObject valueForKey:@"name"], [tempObject valueForKey:@"channel"] ]
			];
		}

	}
	else if ( [pathWithSlash isEqualToString:TVFSPathDates] )
	{
		NSArray *programs = [EntityHelper
			arrayOfEntityWithName:TiVoProgramEntityName
			usingPredicateString:@"deletedFromPlayer = NO"
			withSortKeys:[NSArray arrayWithObject:@"captureDate"]
		];
		
		TiVoProgram *program;
		NSMutableSet *dateSet = [NSMutableSet set];
		for ( program in programs ) {
			[dateSet addObject:[program.captureDate descriptionWithCalendarFormat:@"%Y-%m-%d" timeZone:nil locale:nil]];
		}
		
		returnArray = [[dateSet allObjects] mutableCopy];
	}
	else
	{
		WARNING( @"Asked for unexpected group: ", group );
		return nil;
	}
	return [returnArray copy];
}

//this returns the actual programs for the chosen directory
- (NSArray *)programFilesForDirectory:(NSString *)dir inGroup:(NSString *)group
{
	NSString *pathWithSlash = [NSString stringWithFormat:@"/%@", group];
	NSArray *programs;
	
	if ( [pathWithSlash isEqualToString:TVFSPathPlayers] )
	{
		programs = [EntityHelper
			arrayOfEntityWithName:TiVoProgramEntityName
			usingPredicate:[NSPredicate predicateWithFormat:@"player.name = %@", dir]
			withSortKeys:[NSArray arrayWithObject:@"title"]
		];
	}
	else if ( [pathWithSlash isEqualToString:TVFSPathProgramGroups] )
	{
		programs = [EntityHelper
			arrayOfEntityWithName:TiVoProgramEntityName
			usingPredicate:[NSPredicate predicateWithFormat:@"series.title = %@", dir]
			withSortKeys:[NSArray arrayWithObject:@"title"]
		];
	}
	else if ( [pathWithSlash isEqualToString:TVFSPathStations] )
	{
		programs = [EntityHelper
			arrayOfEntityWithName:TiVoProgramEntityName
			usingPredicateString:@"ANY programs.deletedFromPlayer = NO"
			withSortKeys:[NSArray arrayWithObject:@"title"]
		];
	}
	else if ( [pathWithSlash isEqualToString:TVFSPathDates] )
	{
		NSDate *startDate = [NSDate dateWithNaturalLanguageString:dir];
		NSDate *endDate = [startDate addTimeInterval:60*60*24];
		
		programs = [EntityHelper
			arrayOfEntityWithName:TiVoProgramEntityName
			usingPredicate:[NSPredicate predicateWithFormat:@"captureDate >= %@ AND captureDate < %@", startDate, endDate]
			withSortKeys:[NSArray arrayWithObject:@"captureDate"]
		];
	}
	else
	{
		WARNING( @"Asked for unexpected group: ", group );
		return nil;
	}
	
	NSMutableArray *returnArray = [NSMutableArray array];
	TiVoProgram *program;
	for ( program in programs ) {
		[returnArray addObject:
			[NSString stringWithFormat:@"%@ (%@).tivo", program.title, program.internalID]
		];
	}	
	return returnArray;
}

- (TiVoProgram *)programWithFileName:(NSString *)filename
{
	NSScanner *scanner = [NSScanner scannerWithString:filename];
	NSString *programName;
	[scanner scanUpToString:@"(" intoString:&programName];
	[scanner setScanLocation:[scanner scanLocation]+1 ];
	NSString *internalID;
	[scanner scanUpToString:@")" intoString:&internalID];

	//for some reason, this breaks if I create a predicateWithFormat: ???
	NSString *predicateString = [NSString stringWithFormat:@"internalID == %@", internalID];
	NSArray *tempArray = [EntityHelper
		arrayOfEntityWithName:TiVoProgramEntityName
		usingPredicateString:predicateString
	];

	return [tempArray lastObject];
}

#pragma mark Getting Attributes

- (NSDictionary *)attributesOfItemAtPath:(NSString *)path userData:(id)userData error:(NSError **)error
{
	//DEBUG( @"attributes for path: %@ (count: %d)", path, [[path pathComponents] count] );
	NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
	
	NSArray *rootPaths = [NSArray arrayWithObjects:
		TVFSPathPlayers,
		TVFSPathProgramGroups,
		TVFSPathStations,
		TVFSPathDates,
		nil
	];
	
	if ( [rootPaths containsObject:path] )
	{
		[attributes setValue:NSFileTypeDirectory forKey:NSFileType];
		[attributes setValue:[NSNumber numberWithInt:0] forKey:NSFileSize];
	}
	else if ( [rootPaths containsObject:[path baseDirectory]] )
	{
		if ( [[path pathComponents] count]==4 )
		{
			TiVoProgram *program = [self programWithFileName:[path lastPathComponent] ];
			[attributes setValue:NSFileTypeRegular forKey:NSFileType];
			[attributes setValue:program.sourceSize forKey:NSFileSize];
			[attributes setValue:program.captureDate forKey:NSFileModificationDate];
		}
		else
		{
			[attributes setValue:NSFileTypeDirectory forKey:NSFileType];
			[attributes setValue:[NSNumber numberWithInt:0] forKey:NSFileSize];		
		}
	}
	else
	{
		if ( [path isEqualToString:@"/"] )
			return nil;
			
		WARNING( @"Couldn't find path: %@", path );
		*error = [NSError errorWithPOSIXCode:ENOENT];
		return nil;
	}
	//RETURN( [attributes description] );
	return attributes;
}

- (NSDictionary *)attributesOfFileSystemForPath:(NSString *)path
                                          error:(NSError **)error {
  return [NSDictionary dictionary];  // Default file system attributes.
}

#pragma mark File Contents

// TODO: There are two ways to support reading of file data. With the contentsAtPath
// method you must return the full contents of the file with each invocation. For
// a more complex (or efficient) file system, consider supporting the openFileAtPath:,
// releaseFileAtPath:, and readFileAtPath: delegate methods.
#define SIMPLE_FILE_CONTENTS 0
#if SIMPLE_FILE_CONTENTS

- (NSData *)contentsAtPath:(NSString *)path
{
	return nil;
}

#else

- (BOOL)openFileAtPath:(NSString *)path mode:(int)mode userData:(id *)userData error:(NSError **)error
{	
	ENTRY;
	
	if ( [selectedPrograms objectForKey:path] ) {
		WARNING( @"Already have a download for path: %@", path );
		return YES;
	}
	
	TiVoProgram *program = [self programWithFileName:[path lastPathComponent]];
	if ( !program )
		return nil;

	if ( !mak ) {
		mak = [program.player.mediaAccessKey retain];
	}
	
	NSArray *keys = [selectedPrograms allKeysForObject:program.internalID];
	if ( keys.count > 0 ) {
		DEBUG( @"We already have a program at another path, adding this new path: %@", path );
		[selectedPrograms setObject:program.internalID forKey:path];
		return YES;
	}
	
	[selectedPrograms setObject:program.internalID forKey:path];
	
	
	NSString *tempURLString = program.contentURL;
	if ( !tempURLString ) {
		ERROR( @"no URL string set, can't download" );
		return nil;
	}
	NSURL *url = [NSURL URLWithString:tempURLString];
	INFO( @"Downloading from URL: %@", [url description] );
	
	NSURLRequest *request = [NSURLRequest requestWithURL:url];
	
	NSString *tempDirectory = NSTemporaryDirectory();
	NSString *tempPath = [NSString pathWithComponents:[NSArray arrayWithObjects:tempDirectory, [NSString stringWithFormat:@"%d",program.internalID], nil] ];
	
	NSURLDownload *download = [[[NSURLDownload alloc] initWithRequest:request delegate:self] autorelease];
	if ( !download ) {
		ERROR( @"can't download program, download connection not created" );
		return nil;
	}
	DEBUG( @"Using download path: %@", tempPath );
	[download setDestination:tempPath allowOverwrite:YES];
	[download setDeletesFileUponFailure:YES];
	
	[selectedProgramDownloads setObject:download forKey:program.internalID];
	[selectedDownloadPaths setObject:tempPath forKey:[download description]];
	
	DEBUG( @"count of downloads: %d", selectedProgramDownloads.count );
}

- (void)releaseFileAtPath:(NSString *)path userData:(id)userData
{
	ENTRY;
	//we're going to close out of the download...
	NSNumber *internalID = [selectedPrograms objectForKey:path];
	NSURLDownload *download = [selectedProgramDownloads objectForKey:internalID];
	NSString *downloadPath = [selectedDownloadPaths objectForKey:[download description]];

	DEBUG( @"canceling download for program.internalID: %@", internalID );
	[download cancel];
	
	[selectedDownloadPaths removeObjectForKey:[download description]];
	[selectedProgramDownloads removeObjectForKey:internalID];
	NSArray *keys = [selectedPrograms allKeysForObject:internalID];
	[selectedPrograms removeObjectsForKeys:keys];
}

- (int)readFileAtPath:(NSString *)path userData:(id)userData buffer:(char *)buffer size:(size_t)size offset:(off_t)offset error:(NSError **)error
{
	ENTRY;
	return 0;
	
	FILE *file;
	unsigned long fileLen;
	
	NSNumber *internalID = [selectedPrograms objectForKey:path];
	NSURLDownload *download = [selectedProgramDownloads objectForKey:internalID];
	NSString *downloadPath = [selectedDownloadPaths objectForKey:[download description]];
	
	DEBUG( @"internalID: %@", internalID );
	DEBUG( @"download: %@", download );
	DEBUG( @"Using '%@' for download path.", downloadPath );
	
	//Open file
	file = fopen([downloadPath cStringUsingEncoding:NSASCIIStringEncoding], "rb");
	if (!file)
	{
		ERROR( @"Unable to open file %@", downloadPath);
		return 0;
	}
	
	//Get file length
	fseek(file, 0, SEEK_END);
	fileLen=ftell(file);
	fseek(file, 0, SEEK_SET);

	if ( fileLen < (size+offset) )
	{
		WARNING( @"area of the file requested that has not been downloaded yet..." );
		//we may want to wait until it's done downloading?
		return 0;
	}
	
	fseek(file, offset, SEEK_SET);
	//Read file contents into buffer
	fread(buffer, size, 1, file);
	fclose(file);

	return 1;
}

#endif  // #if SIMPLE_FILE_CONTENTS

#pragma mark Download delegate methods
- (void)download:(NSURLDownload *)download didFailWithError:(NSError *)error
{
	ERROR( @"download failed: %@\nfor URL: %@",
		[error localizedDescription],
		[[error userInfo] objectForKey:NSErrorFailingURLStringKey]
	);
	
	ERROR( [error localizedDescription] );
}

- (void)download:(NSURLDownload *)download didCreateDestination:(NSString *)path
{
	DEBUG( @"changing download path to: %@", path );
	[selectedDownloadPaths setObject:path forKey:[download description]];
}


- (void)download:(NSURLDownload *)download didReceiveDataOfLength:(NSUInteger)length
{
	INFO( @"downloaded %lld bytes for download: %@", length, download );
}

- (void)downloadDidFinish:(NSURLDownload *)download
{
	INFO( @"download finished: %@", [download description] );
}

- (void)download:(NSURLDownload *)download didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{
	ENTRY;

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
		//not sure what I need to do to finish this out...
	}
}


#pragma mark Symbolic Links (Optional)

- (NSString *)destinationOfSymbolicLinkAtPath:(NSString *)path
                                        error:(NSError **)error {
  *error = [NSError errorWithPOSIXCode:ENOENT];
  return NO;
}

#pragma mark Extended Attributes (Optional)

- (NSArray *)extendedAttributesOfItemAtPath:(NSString *)path error:(NSError **)error {
	return [NSArray array];  // No extended attributes.
}

- (NSData *)valueOfExtendedAttribute:(NSString *)name 
                        ofItemAtPath:(NSString *)path
                            position:(off_t)position
                               error:(NSError **)error {
  *error = [NSError errorWithPOSIXCode:ENOATTR];
  return nil;
}

#pragma mark FinderInfo and ResourceFork (Optional)

- (NSDictionary *)finderAttributesAtPath:(NSString *)path 
                                   error:(NSError **)error {
  return [NSDictionary dictionary];
}

- (NSDictionary *)resourceAttributesAtPath:(NSString *)path
                                     error:(NSError **)error {
  return [NSDictionary dictionary];
}

@end

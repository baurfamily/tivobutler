//
//  TiVo_FS_Filesystem.m
//  TiVo FS
//
//  Created by Eric Baur on 10/17/09.
//  Copyright 2009 Eric Shore Baur. All rights reserved.
//
#import <sys/xattr.h>
#import <sys/stat.h>
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

#pragma mark Directory Contents

- (NSArray *)contentsOfDirectoryAtPath:(NSString *)path error:(NSError **)error
{
	ENTRY;
	
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

#pragma mark Getting Attributes

- (NSDictionary *)attributesOfItemAtPath:(NSString *)path
                                userData:(id)userData
                                   error:(NSError **)error
{
	DEBUG( @"attributes for path: %@ (count: %d)", path, [[path pathComponents] count] );
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
			NSScanner *scanner = [NSScanner scannerWithString:[path lastPathComponent]];
			NSString *programName;
			[scanner scanUpToString:@"(" intoString:&programName];
			[scanner setScanLocation:[scanner scanLocation]+1 ];
			NSString *internalID;
			[scanner scanUpToString:@")" intoString:&internalID];
			
			//NSPredicate *predicate = [NSPredicate predicateWithFormat:@"title == %@", programName];
			NSPredicate *predicate = [NSPredicate predicateWithFormat:@"internalID == %@", internalID ];
			NSArray *tempArray = [EntityHelper
				arrayOfEntityWithName:TiVoProgramEntityName
				usingPredicate:predicate
			];
			
			TiVoProgram *program = [tempArray lastObject];
			if ( !program )
				return nil;
				
			DEBUG( @"found '%@' with ID: %d, expected ID: %@", [scanner string], program.internalID, internalID );
			
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
	RETURN( [attributes description] );
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
#define SIMPLE_FILE_CONTENTS 1
#if SIMPLE_FILE_CONTENTS

- (NSData *)contentsAtPath:(NSString *)path {
  return nil;  // Equivalent to ENOENT
}

#else

- (BOOL)openFileAtPath:(NSString *)path 
                  mode:(int)mode
              userData:(id *)userData
                 error:(NSError **)error {
  *error = [NSError errorWithPOSIXCode:ENOENT];
  return NO;
}

- (void)releaseFileAtPath:(NSString *)path userData:(id)userData {
}

- (int)readFileAtPath:(NSString *)path 
             userData:(id)userData
               buffer:(char *)buffer 
                 size:(size_t)size 
               offset:(off_t)offset
                error:(NSError **)error {
  return 0;  // We've reached end of file.
}

#endif  // #if SIMPLE_FILE_CONTENTS

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

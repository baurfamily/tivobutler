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
	
	NSMutableArray *returnArray = [NSMutableArray array];

	if ( [path isEqualToString:@"/"] )
	{
		[returnArray addObject:[TVFSPathProgramGroups stringWithoutLeadingSlash]];
		[returnArray addObject:[TVFSPathPlayers stringWithoutLeadingSlash]];
		[returnArray addObject:[TVFSPathDates stringWithoutLeadingSlash]];
		[returnArray addObject:[TVFSPathStations stringWithoutLeadingSlash]];
	}
	else if ( [path isEqualToString:TVFSPathPlayers] )
	{
		NSArray *players = [EntityHelper arrayOfEntityWithName:TiVoPlayerEntityName usingPredicate:[NSPredicate predicateWithValue:YES] ];

		TiVoPlayer *player;
		for ( player in players ) {
			[returnArray addObject:player.name ];
		}
	}
	else if ( [path isEqualToString:TVFSPathProgramGroups] )
	{
		//NSArray *programs 
	}
	else
	{
		WARNING( @"Asked for unexpected path: ", path );
		*error = [NSError errorWithPOSIXCode:ENOENT];
		return nil;
	}
	INFO( @"returning: %@", [returnArray description] );
	return returnArray;
}

#pragma mark Getting Attributes

- (NSDictionary *)attributesOfItemAtPath:(NSString *)path
                                userData:(id)userData
                                   error:(NSError **)error
{
	DEBUG( @"attributes for path: %@", path );
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
		//if we're at the second level, then these are guaranted to be folders
		if ( [[path pathComponents] count]==3 )
		{
			[attributes setValue:NSFileTypeDirectory forKey:NSFileType];
			[attributes setValue:[NSNumber numberWithInt:0] forKey:NSFileSize];		
		}
	}
	else
	{
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

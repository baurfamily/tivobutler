//
//  TiVo_FS_Filesystem.h
//  TiVo FS
//
//  Created by Eric Baur on 10/17/09.
//  Copyright 2009 Eric Shore Baur. All rights reserved.
//
// Filesystem operations.
//
#import <Foundation/Foundation.h>

#import "EntityHelper.h"

#import "TiVoPlayer.h"
#import "TiVoProgram.h"

// The core set of file system operations. This class will serve as the delegate
// for GMUserFileSystemFilesystem. For more details, see the section on 
// GMUserFileSystemOperations found in the documentation at:
// http://macfuse.googlecode.com/svn/trunk/core/sdk-objc/Documentation/index.html
@interface TiVo_FS_Filesystem : NSObject  {
	NSMutableDictionary *selectedPrograms;	//key => NSString(program path), value => TiVoProgram
	NSMutableDictionary *selectedProgramDownloads;	//key => TiVoProgram, value => NSURLDownload
	NSMutableDictionary *selectedDownloadPaths;	//key => NSURLDownload, value => NSString(download path)
}

- (NSArray *)baseDirectories;
- (NSArray *)groupDirectoriesForGroup:(NSString *)group;
- (NSArray *)programFilesForDirectory:(NSString *)dir inGroup:(NSString *)group;

@end

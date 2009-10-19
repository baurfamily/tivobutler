//
//  TiVo_FS_Controller.h
//  TiVo FS
//
//  Created by Eric Baur on 10/17/09.
//  Copyright 2009 Eric Shore Baur. All rights reserved.
//
#import <Cocoa/Cocoa.h>

#import "EntityHelper.h"

#import "TiVoPlayer.h"

#import "TiVoDurationValueTransformer.h"
#import "TiVoSizeValueTransformer.h"

#if __DEBUG__ 
#	define TiVoButlerDataFilename		@"tivobutler_debug.xml"
#	define TiVoButlerDataFileType		NSXMLStoreType
#else
#	define TiVoButlerDataFilename		@"TiVo Butler.sqlite"
#	define TiVoButlerDataFileType		NSSQLiteStoreType
#endif

@class GMUserFileSystem;
@class TiVo_FS_Controller;

@interface TiVo_FS_Controller : NSObject
{
	GMUserFileSystem* fs_;
	TiVo_FS_Controller* fs_delegate_;

	
    NSPersistentStoreCoordinator *persistentStoreCoordinator;
    NSManagedObjectModel *managedObjectModel;
    NSManagedObjectContext *managedObjectContext;
	
	//NSMutableArray *conversionPresetsArray;
}

- (NSString *)applicationSupportFolder;
- (NSPersistentStoreCoordinator *)persistentStoreCoordinator;
- (NSManagedObjectModel *)managedObjectModel;
- (NSManagedObjectContext *)managedObjectContext;

- (IBAction)saveAction:sender;

- (void)loadConversionPresets;
//- (IBAction)saveConversionPresets:(id)sender;

@end

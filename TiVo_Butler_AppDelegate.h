//
//  TiVo_Butler_AppDelegate.h
//  TiVo Butler
//
//  Created by Eric Baur on 1/15/08.
//  Copyright Eric Shore Baur 2008 . All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "TiVoDurationValueTransformer.h"
#import "TiVoSizeValueTransformer.h"

#if __DEBUG__ 
#	define TiVoButlerDataFilename		@"tivobutler_debug.xml"
#	define TiVoButlerDataFileType		NSXMLStoreType
#else
#	define TiVoButlerDataFilename		@"TiVo Butler.sqlite"
#	define TiVoButlerDataFileType		NSSQLiteStoreType
#endif

@interface TiVo_Butler_AppDelegate : NSObject 
{
    IBOutlet NSWindow *window;
	
    NSPersistentStoreCoordinator *persistentStoreCoordinator;
    NSManagedObjectModel *managedObjectModel;
    NSManagedObjectContext *managedObjectContext;
	
	NSMutableArray *conversionPresetsArray;
}

- (NSPersistentStoreCoordinator *)persistentStoreCoordinator;
- (NSManagedObjectModel *)managedObjectModel;
- (NSManagedObjectContext *)managedObjectContext;

- (IBAction)saveAction:sender;

- (void)loadConversionPresets;

@end

//
//  TiVo_Butler_AppDelegate.m
//  TiVo Butler
//
//  Created by Eric Baur on 1/15/08.
//  Copyright __MyCompanyName__ 2008 . All rights reserved.
//

#import "TiVo_Butler_AppDelegate.h"

@implementation TiVo_Butler_AppDelegate

+ (void)initialize
{
	ENTRY;
	[NSValueTransformer
		setValueTransformer:[[[TiVoDurationValueTransformer alloc] init] autorelease]
		forName:@"TiVoDuration"
	];
	[NSValueTransformer
		setValueTransformer:[[[TiVoSizeValueTransformer alloc] init] autorelease]
		forName:@"TiVoSize"
	];
	
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	
	[defaults registerDefaults:[NSDictionary dictionaryWithObjectsAndKeys:
		@"%{seriesTitle}@/%{title}@",	@"filenamePattern",
		nil ]
	];
}

- (void)awakeFromNib
{
	ENTRY;
	//- awakeFromNib is too late for this method
	[self loadConversionPresets];
}

/**
    Returns the support folder for the application, used to store the Core Data
    store file.  This code uses a folder named "TiVo Butler" for
    the content, either in the NSApplicationSupportDirectory location or (if the
    former cannot be found), the system's temporary directory.
 */

- (NSString *)applicationSupportFolder {

    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    NSString *basePath = ([paths count] > 0) ? [paths objectAtIndex:0] : NSTemporaryDirectory();
    return [basePath stringByAppendingPathComponent:@"TiVo Butler"];
}


/**
    Creates, retains, and returns the managed object model for the application 
    by merging all of the models found in the application bundle.
 */
 
- (NSManagedObjectModel *)managedObjectModel {

    if (managedObjectModel != nil) {
        return managedObjectModel;
    }
	
    managedObjectModel = [[NSManagedObjectModel mergedModelFromBundles:nil] retain];    
    return managedObjectModel;
}


/**
    Returns the persistent store coordinator for the application.  This 
    implementation will create and return a coordinator, having added the 
    store for the application to it.  (The folder for the store is created, 
    if necessary.)
 */

- (NSPersistentStoreCoordinator *) persistentStoreCoordinator {

    if (persistentStoreCoordinator != nil) {
        return persistentStoreCoordinator;
    }

    NSFileManager *fileManager;
    NSString *applicationSupportFolder = nil;
    NSURL *url;
    NSError *error;
    
    fileManager = [NSFileManager defaultManager];
    applicationSupportFolder = [self applicationSupportFolder];
    if ( ![fileManager fileExistsAtPath:applicationSupportFolder isDirectory:NULL] ) {
        [fileManager createDirectoryAtPath:applicationSupportFolder attributes:nil];
    }
    
    url = [NSURL fileURLWithPath: [applicationSupportFolder stringByAppendingPathComponent:TiVoButlerDataFilename]];
    persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel: [self managedObjectModel]];
    if (![persistentStoreCoordinator addPersistentStoreWithType:TiVoButlerDataFileType configuration:nil URL:url options:nil error:&error]){
        [[NSApplication sharedApplication] presentError:error];
    }    

    return persistentStoreCoordinator;
}


/**
    Returns the managed object context for the application (which is already
    bound to the persistent store coordinator for the application.) 
 */
 
- (NSManagedObjectContext *) managedObjectContext {

    if (managedObjectContext != nil) {
        return managedObjectContext;
    }

    NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
    if (coordinator != nil) {
        managedObjectContext = [[NSManagedObjectContext alloc] init];
        [managedObjectContext setPersistentStoreCoordinator: coordinator];
    }
    
    return managedObjectContext;
}


/**
    Returns the NSUndoManager for the application.  In this case, the manager
    returned is that of the managed object context for the application.
 */
 
- (NSUndoManager *)windowWillReturnUndoManager:(NSWindow *)window {
    return [[self managedObjectContext] undoManager];
}


/**
    Performs the save action for the application, which is to send the save:
    message to the application's managed object context.  Any encountered errors
    are presented to the user.
 */
 
- (IBAction) saveAction:(id)sender {

    NSError *error = nil;
    if (![[self managedObjectContext] save:&error]) {
        [[NSApplication sharedApplication] presentError:error];
    }
}


/**
    Implementation of the applicationShouldTerminate: method, used here to
    handle the saving of changes in the application managed object context
    before the application terminates.
 */
 
- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender {

    NSError *error;
    int reply = NSTerminateNow;
    
    if (managedObjectContext != nil) {
        if ([managedObjectContext commitEditing]) {
            if ([managedObjectContext hasChanges] && ![managedObjectContext save:&error]) {
				
                // This error handling simply presents error information in a panel with an 
                // "Ok" button, which does not include any attempt at error recovery (meaning, 
                // attempting to fix the error.)  As a result, this implementation will 
                // present the information to the user and then follow up with a panel asking 
                // if the user wishes to "Quit Anyway", without saving the changes.

                // Typically, this process should be altered to include application-specific 
                // recovery steps.  

                BOOL errorResult = [[NSApplication sharedApplication] presentError:error];
				
                if (errorResult == YES) {
                    reply = NSTerminateCancel;
                } 

                else {
					
                    int alertReturn = NSRunAlertPanel(nil, @"Could not save changes while quitting. Quit anyway?" , @"Quit anyway", @"Cancel", nil);
                    if (alertReturn == NSAlertAlternateReturn) {
                        reply = NSTerminateCancel;	
                    }
                }
            }
        } 
        
        else {
            reply = NSTerminateCancel;
        }
    }
    
    return reply;
}


/**
    Implementation of dealloc, to release the retained variables.
 */
 
- (void) dealloc {

    [managedObjectContext release], managedObjectContext = nil;
    [persistentStoreCoordinator release], persistentStoreCoordinator = nil;
    [managedObjectModel release], managedObjectModel = nil;
    [super dealloc];
}

#pragma mark -
#pragma mark Preferences methods

- (void)loadConversionPresets
{
	if (conversionPresetsArray) {
		EXIT;
		return;
	}
	ENTRY;
    NSFileManager *fileManager = [NSFileManager defaultManager];
	NSString *applicationSupportFolder = [self applicationSupportFolder];

    NSError *error;
    
	//- check and see if user presets exist, create if not
	NSString *userPresetsPath = [applicationSupportFolder stringByAppendingPathComponent:@"UserConversionPresets.plist"];
	if ( ![fileManager fileExistsAtPath:userPresetsPath] ) {
		DEBUG( @"didn't find a pre-existing user conversion presets file." );
		NSString *defaultPresetsPath = [[NSBundle mainBundle] pathForResource:@"ConversionPresets" ofType:@"plist"];
		if ( ![fileManager fileExistsAtPath:applicationSupportFolder isDirectory:NULL] ) {
			DEBUG( @"creating the application support folder: %@", applicationSupportFolder );
			[fileManager createDirectoryAtPath:applicationSupportFolder attributes:nil];
		}
		if ( ![fileManager copyItemAtPath:defaultPresetsPath toPath:userPresetsPath error:&error] ) {
			DEBUG( @"failed to copy the default user conversion presets file. (%@)", [error localizedDescription] );
			[[NSApplication sharedApplication] presentError:error];
		}
	}
	
	//- collect the presets from the user file
	//conversionPresetsArray = [[NSMutableArray arrayWithContentsOfFile:userPresetsPath] retain];
	
	NSData *data = [NSData dataWithContentsOfFile:userPresetsPath];
	CFStringRef errStr = NULL;
	if (!data) {
		ERROR( @"Failed to open user conversion presets." );
	} else {
		conversionPresetsArray = (NSMutableArray *)CFPropertyListCreateFromXMLData(
			kCFAllocatorDefault,
			(CFDataRef) data,
			kCFPropertyListMutableContainersAndLeaves,
			&errStr
		);
		if (errStr!=NULL) {
			ERROR( @"Couldn't create internal representation of user conversion presets. (%@)", (NSString *)errStr );
			CFRelease(errStr);
		}
	}
}

- (IBAction)saveConversionPresets:(id)sender
{
	ENTRY;
	[conversionPresetsArray
		writeToFile:[[self applicationSupportFolder] stringByAppendingPathComponent:@"UserConversionPresets.plist"]
		atomically:YES
	];
}

@end

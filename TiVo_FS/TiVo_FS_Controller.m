//
//  TiVo_FS_Controller.m
//  TiVo FS
//
//  Created by Eric Baur on 10/17/09.
//  Copyright 2009 Eric Shore Baur. All rights reserved.
//
#import "TiVo_FS_Controller.h"
#import "TiVo_FS_Filesystem.h"
#import <MacFUSE/MacFUSE.h>

@implementation TiVo_FS_Controller

- (void)mountFailed:(NSNotification *)notification
{
	ENTRY;
	NSDictionary* userInfo = [notification userInfo];
	NSError* error = [userInfo objectForKey:kGMUserFileSystemErrorKey];
	NSLog(@"kGMUserFileSystem Error: %@, userInfo=%@", error, [error userInfo]);  
	NSRunAlertPanel(@"Mount Failed", [error localizedDescription], nil, nil, nil);
	[[NSApplication sharedApplication] terminate:nil];
}

- (void)didMount:(NSNotification *)notification
{
	ENTRY;
	NSDictionary* userInfo = [notification userInfo];
	NSString* mountPath = [userInfo objectForKey:kGMUserFileSystemMountPathKey];
	NSString* parentPath = [mountPath stringByDeletingLastPathComponent];
	[[NSWorkspace sharedWorkspace] selectFile:mountPath
				   inFileViewerRootedAtPath:parentPath];
}

- (void)didUnmount:(NSNotification*)notification
{
	ENTRY;
	[[NSApplication sharedApplication] terminate:nil];
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
	ENTRY;
	NSNotificationCenter* center = [NSNotificationCenter defaultCenter];
	[center addObserver:self selector:@selector(mountFailed:)
		name:kGMUserFileSystemMountFailed object:nil];
	[center addObserver:self selector:@selector(didMount:)
		name:kGMUserFileSystemDidMount object:nil];
	[center addObserver:self selector:@selector(didUnmount:)
		name:kGMUserFileSystemDidUnmount object:nil];

	NSString* mountPath = @"/Volumes/TiVo FS";
	fs_delegate_ = [[TiVo_FS_Filesystem alloc] init];
	fs_ = [[GMUserFileSystem alloc] initWithDelegate:fs_delegate_ isThreadSafe:NO];

	NSMutableArray* options = [NSMutableArray array];
	NSString* volArg = 
		[NSString stringWithFormat:@"volicon=%@", 
		[[NSBundle mainBundle] pathForResource:@"TiVo FS" ofType:@"icns"]
	];
	[options addObject:volArg];
	[options addObject:@"volname=TiVos"];
	[options addObject:@"rdonly"];
	[fs_ mountAtPath:mountPath withOptions:options];
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender
{
	ENTRY;
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[fs_ unmount];
	[fs_ release];
	[fs_delegate_ release];
	
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
	
	[self loadConversionPresets];
	
#if __DEBUG__ 
	//- this is just because I'm lazy...
	NSArray *tivoArray = [EntityHelper
		arrayOfEntityWithName:TiVoPlayerEntityName
		usingPredicate:[NSPredicate predicateWithValue:TRUE]
	];
	if ( tivoArray.count ) {
		RETURN( @"already have players present" );
		return;
	}
	NSString *path = [[self applicationSupportFolder] stringByAppendingPathComponent:@"DefaultPlayers.plist"];
	tivoArray = [NSArray arrayWithContentsOfFile:path];
	
	TiVoPlayer *tempPlayer;
	NSDictionary *tempDict;
	for ( tempDict in tivoArray ) {
		tempPlayer = [NSEntityDescription
			insertNewObjectForEntityForName:TiVoPlayerEntityName
			inManagedObjectContext:managedObjectContext
		];
		tempPlayer.name = [tempDict valueForKey:@"name"];
		tempPlayer.host = [tempDict valueForKey:@"host"];
		tempPlayer.mediaAccessKey = [tempDict valueForKey:@"mediaAccessKey"];
	}

#endif
}

/**
    Returns the support folder for the application, used to store the Core Data
    store file.  This code uses a folder named "TiVo Butler" for
    the content, either in the NSApplicationSupportDirectory location or (if the
    former cannot be found), the system's temporary directory.
	The sub-folder is created if it isn't already there.
 */

- (NSString *)applicationSupportFolder {

    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    NSString *basePath = ([paths count] > 0) ? [paths objectAtIndex:0] : NSTemporaryDirectory();
	NSString *fullPath = [basePath stringByAppendingPathComponent:@"TiVo Butler"];
	
    NSFileManager *fileManager = [NSFileManager defaultManager];
	if ( ![fileManager fileExistsAtPath:fullPath isDirectory:NULL] ) {
		//- should probably put some more error checking here...
		[fileManager createDirectoryAtPath:fullPath attributes:nil];
	}
	
    return fullPath;
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

    NSURL *url;
    NSError *error;

    url = [NSURL fileURLWithPath: [[self applicationSupportFolder] stringByAppendingPathComponent:TiVoButlerDataFilename]];
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
	NSArray *presetsArray = [EntityHelper
		arrayOfEntityWithName:TiVoExternalActionEntityName
		usingPredicate:[NSPredicate predicateWithValue:TRUE]
	];
	if ( presetsArray.count ) {
		RETURN( @"already have conversion presets... exiting" );
		return;
	}
	ENTRY;

	NSString *defaultPresetsPath = [[NSBundle mainBundle] pathForResource:@"ConversionPresets" ofType:@"plist"];
	NSArray *conversionPresetsArray = [NSArray arrayWithContentsOfFile:defaultPresetsPath];
	
	id tempExternalAction;
	id tempExternalActionArgument;
	NSMutableArray *arguments;
	NSDictionary *presetDict;
	NSDictionary *argumentDict;
	for ( presetDict in conversionPresetsArray ) {
		tempExternalAction = [NSEntityDescription
			insertNewObjectForEntityForName:TiVoExternalActionEntityName
			inManagedObjectContext:managedObjectContext
		];
		[tempExternalAction setValue:[presetDict valueForKey:@"name"] forKey:@"name"];
		[tempExternalAction setValue:[presetDict valueForKey:@"path"] forKey:@"path"];
		[tempExternalAction setValue:[presetDict valueForKey:@"default"] forKey:@"default"];
		
		int orderNum = 0;
		arguments = [NSMutableArray array];
		for ( argumentDict in [presetDict valueForKey:@"arguments"] ) {
			orderNum++;
			tempExternalActionArgument = [NSEntityDescription
				insertNewObjectForEntityForName:TiVoExternalActionArgumentEntityName
				inManagedObjectContext:managedObjectContext
			];
			
			[tempExternalActionArgument setValue:[NSNumber numberWithInt:orderNum] forKey:@"orderNum"];
			[tempExternalActionArgument setValue:[argumentDict valueForKey:@"argument"] forKey:@"argument"];
			[tempExternalActionArgument setValue:[argumentDict valueForKey:@"argumentValue"] forKey:@"argumentValue"];
			[tempExternalActionArgument setValue:[argumentDict valueForKey:@"variable"] forKey:@"variable"];
			
			[arguments addObject:tempExternalActionArgument];
		}
		INFO( @"adding arguments for external action (%@):\n%@", [tempExternalAction description], [arguments description] );
		[tempExternalAction setValue:[NSSet setWithArray:arguments] forKey:@"arguments"];
	}
}

@end

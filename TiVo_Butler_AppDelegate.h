//
//  TiVo_Butler_AppDelegate.h
//  TiVo Butler
//
//  Created by Eric Baur on 1/15/08.
//  Copyright Eric Shore Baur 2008 . All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface TiVo_Butler_AppDelegate : NSObject 
{
    IBOutlet NSWindow *window;
	
    NSPersistentStoreCoordinator *persistentStoreCoordinator;
    NSManagedObjectModel *managedObjectModel;
    NSManagedObjectContext *managedObjectContext;
}

- (NSPersistentStoreCoordinator *)persistentStoreCoordinator;
- (NSManagedObjectModel *)managedObjectModel;
- (NSManagedObjectContext *)managedObjectContext;

- (IBAction)saveAction:sender;

@end

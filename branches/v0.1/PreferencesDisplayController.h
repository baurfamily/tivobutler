//
//  PreferencesDisplayController.h
//  TiVo Butler
//
//  Created by Eric Baur on 3/14/08.
//  Copyright 2008 Eric Shore Baur. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface PreferencesDisplayController : NSObject {
	IBOutlet NSWindow *preferencesWindow;
	IBOutlet NSArrayController *smartGroupArrayController;
	IBOutlet NSPredicateEditor *predicateEditor;
	
	NSManagedObjectContext *managedObjectContext;
}

- (IBAction)showWindow:(id)sender;
- (IBAction)addSmartGroup:(id)sender;
- (IBAction)predicateEditorChanged:(id)sender;
@end

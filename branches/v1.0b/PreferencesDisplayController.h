//
//  PreferencesDisplayController.h
//  TiVo Butler
//
//  Created by Eric Baur on 3/14/08.
//  Copyright 2008 Eric Shore Baur. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "EntityToken.h"

@interface PreferencesDisplayController : NSObject {
	IBOutlet NSWindow *preferencesWindow;
	IBOutlet NSWindow *preferencesSheetWindow;
	IBOutlet NSWindow *mainWindow;
	
	IBOutlet NSBox *preferencesSheetBox;
	
	IBOutlet NSArrayController *smartGroupArrayController;
	IBOutlet NSPredicateEditor *predicateEditor;

	IBOutlet NSView *devicesView;
	IBOutlet NSView *smartGroupsView;
	IBOutlet NSView *downloadingView;
	IBOutlet NSView *decodingView;
	IBOutlet NSView *convertingView;
	IBOutlet NSView *tokensView;
	
	IBOutlet NSTokenField *tokenField;
	
	NSManagedObjectContext *managedObjectContext;
}

- (IBAction)showWindow:(id)sender;
- (IBAction)addSmartGroup:(id)sender;
- (IBAction)predicateEditorChanged:(id)sender;

//- used by the preferences dialog
- (IBAction)showDevices:(id)sender;
- (IBAction)showSmartGroups:(id)sender;
- (IBAction)showDownloading:(id)sender;
- (IBAction)showDecoding:(id)sender;
- (IBAction)showConverting:(id)sender;
- (IBAction)showTokens:(id)sender;

//- used by the main window quick prefs.
- (IBAction)showDevicesSheet:(id)sender;
- (IBAction)showSmartGroupsSheet:(id)sender;
- (IBAction)showDownloadingSheet:(id)sender;
- (IBAction)showDecodingSheet:(id)sender;
- (IBAction)showConvertingSheet:(id)sender;

- (IBAction)showTokensSheet:(id)sender;

- (void)setPreferencesView:(NSView *)newView;
- (void)setPreferencesSheet:(NSView *)newView;

- (IBAction)endSheet:(id)sender;

//to support the token prefs.
- (IBAction)addToken:(id)sender;

@end

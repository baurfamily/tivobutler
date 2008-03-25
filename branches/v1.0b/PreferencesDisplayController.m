//
//  PreferencesDisplayController.m
//  TiVo Butler
//
//  Created by Eric Baur on 3/14/08.
//  Copyright 2008 Eric Shore Baur. All rights reserved.
//

#import "PreferencesDisplayController.h"


@implementation PreferencesDisplayController

- (void)awakeFromNib
{
	[self willChangeValueForKey:@"managedObjectContext"];	
	managedObjectContext = [[[[NSApplication sharedApplication] delegate] managedObjectContext] retain];
	[self didChangeValueForKey:@"managedObjectContext"];
	
	[predicateEditor addRow:self];
}

- (IBAction)showWindow:(id)sender
{
	ENTRY;
	if ( ! preferencesWindow ) {
		if ( ![NSBundle loadNibNamed:@"Preferences" owner:self] ) {
			ERROR( @"could not load Preferences.nib" );
			return;
		} else { INFO( @"loaded Preferences.nib" ); }
	}
	[preferencesWindow makeKeyAndOrderFront:self];
}

- (IBAction)addSmartGroup:(id)sender
{
	ENTRY;
	[smartGroupArrayController add:self];
	[predicateEditor addRow:self];
}

- (IBAction)predicateEditorChanged:(id)sender
{
	ENTRY;
	if ( ![predicateEditor numberOfRows] ) {
		DEBUG( @"adding a row to the predicate editor" );
		[predicateEditor addRow:self];
	}
}

@end

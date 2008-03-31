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
	
	[self showDevices:self];
	
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

- (IBAction)showDevices:(id)sender
{
	[self setPreferencesView:devicesView];
}

- (IBAction)showSmartGroups:(id)sender
{
	[self setPreferencesView:smartGroupsView];
}

- (IBAction)showDownloading:(id)sender
{
	[self setPreferencesView:downloadingView];
}

- (IBAction)showPostProcessing:(id)sender
{
	[self setPreferencesView:postProcessingView];
}

- (void)setPreferencesView:(NSView *)newView
{
	NSRect windowFrame = [preferencesWindow frame];
	NSRect viewFrame = [[preferencesWindow contentView] frame];
	NSRect newViewFrame = [newView frame];
	
	int heightDiff = newViewFrame.size.height - viewFrame.size.height;
	int widthDiff = newViewFrame.size.width - viewFrame.size.width;
	
	windowFrame.size.height += heightDiff;
	windowFrame.size.width += widthDiff;
	
	windowFrame.origin.y -= heightDiff;
	
	//it crashes if I take this out...
	[newView retain];	//TODO: figure out why the retain count goes up
	
	DEBUG( @"retain count: %d", [newView retainCount] );
	
	//- this places a blank view in place so we can animate more cleanly
	[preferencesWindow setContentView:[[[NSView alloc] initWithFrame:[[preferencesWindow contentView] frame]] autorelease] ];
	[preferencesWindow setFrame:windowFrame display:YES animate:YES];
	[preferencesWindow setContentView:newView];
	
}

@end

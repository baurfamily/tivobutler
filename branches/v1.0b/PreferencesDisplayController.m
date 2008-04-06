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
	ENTRY;
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
	
	[self endSheet:self];
	
	[self showDevices:self];
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


#pragma mark -
#pragma mark Window display methods

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

- (IBAction)showDecoding:(id)sender
{
	[self setPreferencesView:decodingView];
}

- (IBAction)showConverting:(id)sender
{
	[self setPreferencesView:convertingView];
}

#pragma mark -
#pragma mark Sheet display methods

- (IBAction)showDevicesSheet:(id)sender
{
	if ( ! devicesView ) {
		if ( ![NSBundle loadNibNamed:@"Preferences" owner:self] ) {
			ERROR( @"could not load Preferences.nib" );
			return;
		} else { INFO( @"loaded Preferences.nib" ); }
	}
	[self setPreferencesSheet:devicesView];
}

- (IBAction)showSmartGroupsSheet:(id)sender
{
	if ( ! smartGroupsView ) {
		if ( ![NSBundle loadNibNamed:@"Preferences" owner:self] ) {
			ERROR( @"could not load Preferences.nib" );
			return;
		} else { INFO( @"loaded Preferences.nib" ); }
	}
	[self setPreferencesSheet:smartGroupsView];
}

- (IBAction)showDownloadingSheet:(id)sender
{
	if ( ! downloadingView ) {
		if ( ![NSBundle loadNibNamed:@"Preferences" owner:self] ) {
			ERROR( @"could not load Preferences.nib" );
			return;
		} else { INFO( @"loaded Preferences.nib" ); }
	}
	[self setPreferencesSheet:downloadingView];
}

- (IBAction)showDecodingSheet:(id)sender
{
	if ( ! decodingView ) {
		if ( ![NSBundle loadNibNamed:@"Preferences" owner:self] ) {
			ERROR( @"could not load Preferences.nib" );
			return;
		} else { INFO( @"loaded Preferences.nib" ); }
	}
	[self setPreferencesSheet:decodingView];
}

- (IBAction)showConvertingSheet:(id)sender
{
	if ( ! convertingView ) {
		if ( ![NSBundle loadNibNamed:@"Preferences" owner:self] ) {
			ERROR( @"could not load Preferences.nib" );
			return;
		} else { INFO( @"loaded Preferences.nib" ); }
	}
	[self setPreferencesSheet:convertingView];
}

#pragma mark -
#pragma mark Generic display methods

- (void)setPreferencesView:(NSView *)newView
{
	ENTRY;
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

- (void)setPreferencesSheet:(NSView *)newView
{
	ENTRY;
	if ( ! ( preferencesSheetWindow && preferencesSheetBox &&  mainWindow ) ) {
		//TODO: figure out why this is being called at launch...
		return;
	}
	[preferencesWindow close];
	
	NSRect windowFrame = [preferencesSheetWindow frame];
	NSRect viewFrame = [[preferencesSheetBox contentView] frame];
	NSRect newViewFrame = [newView frame];
	
	int heightDiff = newViewFrame.size.height - viewFrame.size.height;
	int widthDiff = newViewFrame.size.width - viewFrame.size.width;
	
	windowFrame.size.height += heightDiff;
	windowFrame.size.width += widthDiff;
	
	//it crashes if I take this out...
	[newView retain];	//TODO: figure out why the retain count goes up
	
	DEBUG( @"retain count: %d", [newView retainCount] );
	
	[preferencesSheetBox setContentView:newView];
	[preferencesSheetWindow setFrame:windowFrame display:YES];
	
	[[NSApplication sharedApplication]
		beginSheet:preferencesSheetWindow
		modalForWindow:mainWindow
		modalDelegate:nil
		didEndSelector:nil
		contextInfo:NULL
	];
}

- (IBAction)endSheet:(id)sender
{
	[[NSApplication sharedApplication] endSheet:preferencesSheetWindow];
	[preferencesSheetWindow orderOut:self];
}

@end

//
//  PreferencesDisplayController.m
//  TiVo Butler
//
//  Created by Eric Baur on 3/14/08.
//  Copyright 2008 Eric Shore Baur. All rights reserved.
//

#import "PreferencesDisplayController.h"


@implementation PreferencesDisplayController

#pragma mark -
#pragma mark Setup methods

- (void)awakeFromNib
{
	ENTRY;
	[self willChangeValueForKey:@"managedObjectContext"];	
	managedObjectContext = [[[[NSApplication sharedApplication] delegate] managedObjectContext] retain];
	[self didChangeValueForKey:@"managedObjectContext"];
	
	[predicateEditor addRow:self];
	
	[tokenField setTokenizingCharacterSet:[NSCharacterSet characterSetWithCharactersInString:@""] ];
	[tokenField setTokenStyle: NSPlainTextTokenStyle];
	
	//- populate the add token popup button and the array controller
	NSMenu *menu = [addTokenPopup menu];
	NSMenuItem *tempMenuItem;
	for ( tempMenuItem in [tokenMenu itemArray] ) {
		DEBUG( @"adding: %@", [tempMenuItem description] );
		[menu addItem:[tempMenuItem copy]];
		/*
		[self addSampleTokenWithTag:[tempMenuItem tag]];
		[tokenArrayController addObject:[NSDictionary dictionaryWithObjectsAndKeys:
				[[[[EntityToken alloc] initWithTag:[tempMenuItem tag]] autorelease] label], @"entityToken",
				@"sample goes here",														@"sample",
				nil
			]
		];
		*/
	}
	
	//- populate the list of prebuit tokens
	NSArray *prebuiltTokens = [NSArray arrayWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"FilenameTokenSamples" ofType:@"plist"] ];
	NSDictionary *tempDict;
	NSMenuItem *menuItem;
	NSMenu *prebuiltTokensMenu = [prebuiltTokenPopup menu];
	int i;
	int count = [prebuiltTokens count];
	for ( i=0; i<count; i++ ) {
		menuItem = [[[NSMenuItem alloc] init] autorelease];
		tempDict = [prebuiltTokens objectAtIndex:i];
		[menuItem setTitle:[tempDict objectForKey:@"desc"]];
		[menuItem setTag:i];
		[prebuiltTokensMenu addItem:menuItem];
	}
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

- (IBAction)showTokens:(id)sender
{
	[self setPreferencesView:tokensView];
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

- (IBAction)showTokensSheet:(id)sender
{
	if ( ! tokensView ) {
		if ( ![NSBundle loadNibNamed:@"Preferences" owner:self] ) {
			ERROR( @"could not load Preferences.nib" );
			return;
		} else { INFO( @"loaded Preferences.nib" ); }
	}
	[self setPreferencesSheet:tokensView];
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

#pragma mark -
#pragma mark Token support methods

- (IBAction)addToken:(id)sender
{
	ENTRY;
	NSMutableArray* tempArray = [[tokenField objectValue] mutableCopy];
	DEBUG (@"Current: %@", tempArray);
	
	EntityToken* token = [[[EntityToken alloc] initWithTag:[[sender selectedItem] tag]] autorelease];
	[tempArray addObject:token];
	[tokenField setObjectValue:tempArray];
	[self saveFilenamePattern:self];
}

- (IBAction)addPrebuiltToken:(id)sender
{
	NSArray *prebuiltTokens = [NSArray arrayWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"FilenameTokenSamples" ofType:@"plist"] ];

	NSString *newTokenString = [[prebuiltTokens objectAtIndex:[sender selectedTag]] objectForKey:@"tokenString"];
	DEBUG( @"setting new filenameToken to: %@", newTokenString );
	EntityTokenFieldValueTransformer *transformer = [[[EntityTokenFieldValueTransformer alloc] init] autorelease];
	[tokenField setObjectValue:[transformer transformedValue:newTokenString] ];
	[self saveFilenamePattern:self];
}
/*
- (void)addSampleTokenWithTag:(TiVoProgramPropertyTag)sampleTag
{
	ENTRY;
	NSMutableArray* tempArray = [[sampleTokenField objectValue] mutableCopy];

	EntityToken* token = [[[EntityToken alloc] initWithTag:sampleTag] autorelease];
	[tempArray addObject:token];
	[sampleTokenField setObjectValue:tempArray];
}
*/

- (IBAction)saveFilenamePattern:(id)sender
{
	NSUserDefaults *defaults = [[NSUserDefaultsController sharedUserDefaultsController] defaults];	
	EntityTokenFieldValueTransformer *transformer = [[[EntityTokenFieldValueTransformer alloc] init] autorelease];
	[defaults setObject:[transformer reverseTransformedValue:[tokenField objectValue]] forKey:@"filenamePattern"];
}

#pragma mark -
#pragma mark NSTokenField delegate methods

- (NSString *)tokenField:(NSTokenField *)tokenField displayStringForRepresentedObject:(id)representedObject
{
	NSString* string;
	if ([representedObject isKindOfClass: [EntityToken class]]) {
		EntityToken* token = representedObject;
		string = [token label];
	}
	else
		string = representedObject;
	return string;
}

- (NSTokenStyle)tokenField:(NSTokenField *)tokenField styleForRepresentedObject:(id)representedObject
{
	return ([representedObject isKindOfClass: [EntityToken class]]) ? NSRoundedTokenStyle :NSPlainTextTokenStyle;
}

@end

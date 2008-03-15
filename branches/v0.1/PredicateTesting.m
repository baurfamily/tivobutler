//
//  PredicateTesting.m
//  TiVo Butler
//
//  Created by Eric Baur on 2/24/08.
//  Copyright 2008 Eric Shore Baur. All rights reserved.
//

#import "PredicateTesting.h"

@implementation PredicateTesting

- (void)awakeFromNib
{
	[self willChangeValueForKey:@"predicateString"];
	predicateString = [@"TRUEPREDICATE" retain];
	[self didChangeValueForKey:@"predicateString"];
	
	[self willChangeValueForKey:@"managedObjectContext"];	
	managedObjectContext = [[[[NSApplication sharedApplication] delegate] managedObjectContext] retain];
	[self didChangeValueForKey:@"managedObjectContext"];
}

- (IBAction)showPredicateTestingWindow:(id)sender
{
	if ( ![NSBundle loadNibNamed:@"PredicateTesting" owner:self] ) {
		ERROR( @"could not load PredicateTesting.nib" );
		return;
	} else { INFO( @"loaded PredicateTesting.nib" ); }
	[predicateTestingWindow makeKeyAndOrderFront:self];
}

- (IBAction)refreshPredicate:(id)sender
{
	DEBUG( predicateString );
	[self willChangeValueForKey:@"predicate"];
	[predicate release];
	predicate = [[NSPredicate predicateWithFormat:predicateString] retain];
	[self didChangeValueForKey:@"predicate"];
}

@end

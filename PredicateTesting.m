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
}

- (IBAction)refreshPredicate:(id)sender
{
	[self willChangeValueForKey:@"predicate"];
	[predicate release];
	predicate = [[NSPredicate predicateWithFormat:predicateString] retain];
	[self didChangeValueForKey:@"predicate"];
}

@end

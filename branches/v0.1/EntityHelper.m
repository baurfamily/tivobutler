//
//  EntityHelper.m
//  TiVo Butler
//
//  Created by Eric Baur on 2/3/08.
//  Copyright 2008 Eric Shore Baur. All rights reserved.
//

#import "EntityHelper.h"

static NSManagedObjectContext *managedObjectContext;

@implementation EntityHelper

+ (NSArray *)arrayOfEntityWithName:(NSString *)entityString usingPredicateString:(NSString *)predicateString
{
	return [EntityHelper arrayOfEntityWithName:entityString usingPredicate:[NSPredicate predicateWithFormat:predicateString] ];
}

+ (NSArray *)arrayOfEntityWithName:(NSString *)entityString usingPredicate:(NSPredicate *)predicate
{
	NSError *error = [[[NSError alloc] init] autorelease];

	//- check to see if we have a context to work with
	if (!managedObjectContext) {
		managedObjectContext = [[[NSApplication sharedApplication] delegate] managedObjectContext];
		DEBUG( @"setting managedObjectContext to %@", [managedObjectContext description] );
		if ( !managedObjectContext ) {
			ERROR( @"managedObjectContext is not valid!" );
			return nil;
		}
	}
	
	NSEntityDescription *entityDesc = [NSEntityDescription
		entityForName:entityString
		inManagedObjectContext:managedObjectContext
	];
	NSFetchRequest *request = [[[NSFetchRequest alloc] init] autorelease];
	
	[request setEntity:entityDesc];
	[request setPredicate:predicate];
	
	//DEBUG( @"Executing: %@", [request description] );
	NSArray *array = [managedObjectContext executeFetchRequest:request error:&error];

	if ( !array )
		WARNING( @"error executing fetch request: %@", [error description] );
	
	return array;
}

@end

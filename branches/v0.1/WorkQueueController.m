//
//  WorkQueueController.m
//  TiVo Butler
//
//  Created by Eric Baur on 2/7/08.
//  Copyright 2008 Eric Shore Baur. All rights reserved.
//

#import "WorkQueueController.h"


@implementation WorkQueueController

+ (void)initialize 
{
	NSUserDefaultsController *defaults = [NSUserDefaultsController sharedUserDefaultsController];
	//- does this clobber other defaults?
	[defaults setInitialValues:[NSDictionary dictionaryWithObjectsAndKeys:
			@"~/Downloads/", @"downloadFolder",
			nil
		]
	];
}

- (void)awakeFromNib
{
	managedObjectContext = [[[[NSApplication sharedApplication] delegate] managedObjectContext] retain];
}

- (IBAction)addSelection:(id)sender
{
	ENTRY;
	NSManagedObject *workQueueItem = [NSEntityDescription
		insertNewObjectForEntityForName:TiVoWorkQueueItemEntityName
		inManagedObjectContext:managedObjectContext
	];
	NSManagedObjectID *selectedProgramID = [[programArrayController selection] valueForKey:@"objectID"];
	NSManagedObject *selectedProgram = [managedObjectContext objectWithID:selectedProgramID];
	
	[workQueueItem setValue:selectedProgram forKey:@"program"];
	[workQueueItem setValue:[NSNumber numberWithBool:YES] forKey:@"active"];
	[workQueueItemArrayController addObject:workQueueItem];
	
	[workQueueItem performSelector:@selector(beginDownload)];
}

@end

//
//  WorkQueueItem_Workflows.m
//  TiVo Butler
//
//  Created by Eric Baur on 5/10/08.
//  Copyright 2008 Eric Shore Baur. All rights reserved.
//

#import "WorkQueueItem.h"

@implementation WorkQueueItem (Workflows)

- (void)beginProcessing
{
	ENTRY;
	NSArray *pendingSteps =
		[EntityHelper
			 arrayOfEntityWithName:TiVoWorkQueueStepEntityName
			 usingPredicate:[NSPredicate predicateWithFormat:@"item = %@", self]
			 withSortKeys:[NSArray arrayWithObject:@"actionType" ]
		];
	INFO( @"%d steps to perform.", [pendingSteps count] );
	[[pendingSteps objectAtIndex:0] beginProcessing];
}


- (void)completeWithMessage:(NSString *)message
{
	//TODO: need to cascade down to the current step
	if ( message )
		self.message = message;
	self.completedDate = [NSDate date];
}


- (WorkQueueStep *)addStepOfType:(WQAction)action afterStep:(WorkQueueStep *)prevStep
{
	INFO( @"actionType: %d prevStep: %@", action, [prevStep description] );
	WorkQueueStep *newStep = [NSEntityDescription
		insertNewObjectForEntityForName:TiVoWorkQueueStepEntityName
		inManagedObjectContext:[self managedObjectContext]
	];
	
	newStep.item = self;
	newStep.previousStep = prevStep;
	newStep.actionType = [NSNumber numberWithInt:action];
	
	return newStep;	
}

#pragma mark -
#pragma mark Callback methods

- (void)completedStep:(WorkQueueStep *)completedStep
{
	ENTRY;
	WorkQueueStep *nextStep = completedStep.nextStep;
	[nextStep beginProcessing];
}

@end

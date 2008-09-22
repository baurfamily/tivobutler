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
	if ( self.completedDate ) {
		return;
	}
	ENTRY;
	if ( message )
		self.message = message;
	self.completedDate = [NSDate date];
	
	NSArray *steps = [EntityHelper
		arrayOfEntityWithName:TiVoWorkQueueStepEntityName
		usingPredicate:[NSPredicate predicateWithFormat:@"item = %@", self]
		withSortKeys:[NSArray arrayWithObject:@"actionType"]
	];
	WorkQueueStep *step;
	//- we assume we're successful until we see a step that isn't
	self.successful = [NSNumber numberWithBool:YES];
	for ( step in steps ) {
		if ( ![step.successful boolValue] ) {
			self.successful = [NSNumber numberWithBool:NO];
		}
		if ( ![self.successful boolValue] ) {
			[step completeWithMessage:self.message successful:NO];
		}
	}
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

- (void)completedStep:(WorkQueueStep *)completedStep successful:(BOOL)successful
{
	ENTRY;
	WorkQueueStep *nextStep = completedStep.nextStep;
	if ( successful ) {
		if ( nextStep ) {
			[nextStep beginProcessing];
		} else {
			[self completeWithMessage:nil];
		}
	} else {
		[self completeWithMessage:[NSString stringWithFormat:@"Failed step: %@", completedStep.actionName] ];
	}
}

@end

//
//  WorkQueueStep.m
//  TiVo Butler
//
//  Created by Eric Baur on 5/13/08.
//  Copyright 2008 Eric Shore Baur. All rights reserved.
//

#import "WorkQueueStep.h"


@implementation WorkQueueStep

#pragma mark -
#pragma mark Setup methods

+ (void)initialize
{
	ENTRY;
	NSUserDefaultsController *defaults = [NSUserDefaultsController sharedUserDefaultsController];
	
	NSDictionary *tempDefaults;
	tempDefaults = [self workflowDefaults];
	
	[defaults setInitialValues:tempDefaults];
}

- (void)awakeFromInsert
{
	ENTRY;
	self.addedDate = [NSDate date];
	
	NSUserDefaultsController *defaults = [NSUserDefaultsController sharedUserDefaultsController];
	self.shouldKeepInput = [[defaults valueForKey:@"values"] valueForKey:@"keepIntermediateFiles"];
}

#pragma mark -
#pragma mark Accessor methods

@dynamic actionType;
@dynamic active;
@dynamic addedDate;
@dynamic completedDate;
@dynamic currentActionPercent;
@dynamic message;
@dynamic shouldKeepInput;
@dynamic startedDate;

@dynamic item;
@dynamic nextStep;
@dynamic previousStep;
@dynamic readFile;
@dynamic writeFile;

- (void)setActionType:(NSNumber *)value 
{
	ENTRY;
	if ( [self.actionType intValue] ) {
		WARNING( @"attempt to re-set actionType (blocking)" );
		return;
	}
	int action = [value intValue];
	if ( action > WQAction_MIN && action <= WQAction_MAX ) {
		[self willChangeValueForKey:@"actionType"];
		[self setPrimitiveActionType:value];
		[self didChangeValueForKey:@"actionType"];
		
		if ( self.item.program ) {
			[self setupWriteFile];
		}
	} else {
		WARNING( @"attempt to set actionType to invalid value: %@", [value description] );
	}
}

- (BOOL)validateActionType:(id *)valueRef error:(NSError **)outError 
{
	ENTRY;
	int type = [*valueRef intValue];
	if ( type < WQAction_MIN ) {
		NSDictionary *userInfoDict = [NSDictionary dictionaryWithObject:@"Action type too small." forKey:NSLocalizedDescriptionKey];
		*outError = [NSError errorWithDomain:NSCocoaErrorDomain code:-1 userInfo:userInfoDict];
		WARNING( [*outError localizedDescription] );
		return NO;
	}
	if ( type > WQAction_MAX ) {
		NSDictionary *userInfoDict = [NSDictionary dictionaryWithObject:@"Action type too large." forKey:NSLocalizedDescriptionKey];
		*outError = [NSError errorWithDomain:NSCocoaErrorDomain code:-1 userInfo:userInfoDict];
		WARNING( [*outError localizedDescription] );
		return NO;
	}
    return YES;
}

- (void)setItem:(WorkQueueItem *)value 
{
	if ( self.item ) {
		WARNING( @"attempt to re-set parent item value (blocking)" );
		return;
	}
    [self willChangeValueForKey:@"item"];
    [self setPrimitiveItem:value];
    [self didChangeValueForKey:@"item"];
	
	if ( [self.actionType intValue] ) {
		[self setupWriteFile];
	}
}

- (void)setPreviousStep:(WorkQueueStep *)value
{
	[self willChangeValueForKey:@"previousStep"];
	[self setPrimitivePreviousStep:value];
	[self didChangeValueForKey:@"previousStep"];
	
	self.readFile = self.previousStep.writeFile;
}

#pragma mark -
#pragma mark Action methods

- (void)setupWriteFile
{
	ENTRY;
	self.writeFile =
	[NSEntityDescription
	 insertNewObjectForEntityForName:TiVoWorkQueueFileEntityName
	 inManagedObjectContext:self.managedObjectContext
	 ];
	[self setValue:self forKeyPath:@"writeFile.writerStep"];
}

@end

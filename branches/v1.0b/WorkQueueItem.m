//
//  WorkQueueItem.m
//  TiVo Butler
//
//  Created by Eric Baur on 2/7/08.
//  Copyright 2008 Eric Shore Baur. All rights reserved.
//

#import "WorkQueueItem.h"

@implementation WorkQueueItem

#pragma mark -
#pragma mark Setup methods

- (void)awakeFromInsert
{
	ENTRY;
	self.addedDate = [NSDate date];
}

- (BOOL)canRemove
{
	if ( [self.active boolValue] ) {
		return NO;
	} else {
		return YES;
	}
}

#pragma mark -
#pragma mark Accessor methods

@dynamic active;
@dynamic addedDate;
@dynamic completedDate;
@dynamic message;
@dynamic sourceName;
@dynamic sourceType;
@dynamic startedDate;
@dynamic savedPath;
@dynamic successful;

@dynamic currentStep;
@dynamic program;
@dynamic smartGroup;
@dynamic steps;

- (NSNumber *)active
{
	if ( nil==self.completedDate && nil!=self.startedDate )
		return [NSNumber numberWithBool:YES];
	else
		return [NSNumber numberWithBool:NO];
}

- (NSString *)name
{
	if ( nil != self.program) {
		return self.program.title;
	} else {
		return @"";
	}
}

- (void)setProgram:(TiVoProgram *)value 
{
    [self willChangeValueForKey:@"program"];
    [self setPrimitiveProgram:value];
    [self didChangeValueForKey:@"program"];
	
	//- look at defaults to get what steps to add:
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	WQAction finalAction = [[defaults valueForKey:@"downloadAction"] intValue];
		
	WorkQueueStep *tempStep = nil;
	if ( finalAction==WQNoAction ) {
		WARNING( @"no work queue action set" );
	}
	if ( finalAction>=WQDownloadAction ) {
		tempStep = [self addStepOfType:WQDownloadAction afterStep:tempStep];
	}
	if ( finalAction>=WQDecodeAction ) {
		tempStep = [self addStepOfType:WQDecodeAction afterStep:tempStep];
	}
	if ( finalAction>=WQConvertAction ) {
		tempStep = [self addStepOfType:WQConvertAction afterStep:tempStep];
	}
	if ( finalAction==WQPostProcessAction ) {
		WARNING( @"post processing not working at this time" );
	}
}

- (void)setSourceType:(NSNumber *)value 
{
	if ( [self.sourceType intValue] ) {
		WARNING( @"attempt to re-set sourceType (blocking)" );
		return;
	}
    [self willChangeValueForKey:@"sourceType"];
    [self setPrimitiveSourceType:value];
    [self didChangeValueForKey:@"sourceType"];
}

#pragma mark -
#pragma mark Transient accessors

- (NSString *)sourceName
{
	int type = [self.sourceType intValue];
	switch (type) {
		case WQAutoGeneratedSourceType:	return WQAutoGeneratedSourceString;	break;
		case WQUserInitSourceType:		return WQUserInitSourceString;		break;
		case WQScheduledSourceType:		return WQScheduledSourceString;		break;
		default:						return nil;
	}
}

@end

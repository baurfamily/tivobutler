// 
//  TiVoProgram.m
//  TiVo Butler
//
//  Created by Eric Baur on 1/15/08.
//  Copyright 2008 Eric Shore Baur. All rights reserved.
//

#import "TiVoProgram.h"

#import "TiVoPlayer.h"

@implementation TiVoProgram 


+ (NSSet *)keyPathsForValuesAffectingValueForKey:(NSString *)key
{
	NSSet *returnSet;
	if ( [key isEqualToString:@"statusImage"] ) {
		returnSet = [NSSet setWithObject:@"status"];

	} else {
		returnSet = [NSSet set];
	}
	return returnSet;
}


#pragma mark -
#pragma mark Accessor methods

@dynamic sourceFormat;
@dynamic contentType;
@dynamic duration;
@dynamic captureDate;
@dynamic programDescription;
@dynamic highDefinition;
@dynamic byteOffset;
@dynamic sourceSize;
@dynamic programID;
@dynamic videoDetailsURL;
@dynamic title;
@dynamic episodeNumber;
@dynamic contentURL;
@dynamic inProgress;
@dynamic series;
@dynamic station;
@dynamic player;
@dynamic deletedFromPlayer;
@dynamic internalID;
@dynamic status;

@dynamic smartGroups;

@dynamic statusImage;

- (NSString *)description
{
	return self.title;
}

- (NSSet *)smartGroups
{
	//TODO: make sure this will work
	NSArray *entityArray = [EntityHelper
		arrayOfEntityWithName:TiVoSmartGroupEntityName
		usingPredicateString:[NSString stringWithFormat:@"%@ IN programs", self]
	];
	
	return [NSSet setWithArray:entityArray];
}

- (NSImage *)statusImage
{
	switch ( self.status.intValue ) {
		case TiVoProgramNoStatus:	return nil;		break;
		case TiVoProgramInProgressStatus:	return [NSImage imageNamed:@"in-progress-recording.png"];			break;
		case TiVoProgramSaveStatus:			return [NSImage imageNamed:@"save-until-i-delete-recording.png"];	break;
		case TiVoProgramExpiresSoonStatus:	return [NSImage imageNamed:@"expires-soon-recording.png"];			break;
		case TiVoProgramExpiredStatus:		return [NSImage imageNamed:@"expired-recording.png"];				break;
		default:
			WARNING( @"no valid status found for program" );
			return nil;
	}
}

@end

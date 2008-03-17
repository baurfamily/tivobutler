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
@dynamic player;
@dynamic deletedFromPlayer;
@dynamic smartGroups;

- (NSSet *)smartGroups
{
	//TODO: make sure this will work
	NSArray *entityArray = [EntityHelper
		arrayOfEntityWithName:TiVoSmartGroupEntityName
		usingPredicateString:[NSString stringWithFormat:@"%@ IN programs", self]
	];
	
	return [NSSet setWithArray:entityArray];
}

@end

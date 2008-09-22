//
//  TiVoProgram_AccessorAdditions.m
//  TiVo Butler
//
//  Created by Eric Baur on 5/3/08.
//  Copyright 2008 Eric Shore Baur. All rights reserved.
//

#import "TiVoProgram.h"
#import "TiVoPlayer.h"

//these methods are not directly defined...
//... this is on purpose, since I only plan to use them at runtime

@implementation TiVoProgram (AccessorAdditions)

- (NSString *)channel
{
	return [[self.station valueForKey:@"channel"] stringValue];
}

- (NSString *)def
{
	return ( [self.highDefinition boolValue] ) ? @"HD" : @"SD";
}

- (NSString *)durationString
{
	long temp = [self.duration doubleValue] / 1000 / 60;
	
	int minutes = temp % 60;
	int hours = temp / 60;
	
	return [NSString stringWithFormat:@"%.2dh%.2dm", hours, minutes];
}

- (NSString *)internalIDString
{
	return [self.internalID stringValue];
}

- (NSString *)playerName
{
	return self.player.name;
}

- (NSString *)seriesTitle
{
	return ( self.series ) ? [self.series valueForKey:@"title"] : self.title;
}

- (NSString *)sourceSizeString
{
	TiVoSizeValueTransformer *transformer = [[[TiVoSizeValueTransformer alloc] init] autorelease];
	return [transformer transformedValue:[self.sourceSize stringValue] ];
}

- (NSString *)stationName
{
	return [self.station valueForKey:@"name"];
}

@end

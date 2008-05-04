//
//  EntityToken.m
//  TiVo Butler
//
//  Created by Eric Baur on 5/1/08.
//  Copyright 2008 Eric Shore Baur. All rights reserved.
//

#import "EntityToken.h"


@implementation EntityToken

#pragma mark -
#pragma mark Setup methods

- (id)initWithTag:(TiVoProgramPropertyTag)initTag
{
	self = [super init];
	if (self) {
		DEBUG( @"set propertyTag: %d", initTag );
		propertyTag = initTag;
	}
	return self;
}

- (id)initWithTokenString:(NSString *)initString
{
	self = [super init];
	if (self) {
		if ( [initString isEqualToString:TiVoProgramTitleToken] ) {
			propertyTag = TiVoProgramTitleTag;
		} else if ( [initString isEqualToString:TiVoProgramSeriesTitleToken] ) {
			propertyTag = TiVoProgramSeriesTitleTag;
		} else if ( [initString isEqualToString:TiVoProgramCaptureDateToken] ) {
			propertyTag = TiVoProgramCaptureDateTag;
		} else if ( [initString isEqualToString:TiVoProgramChannelToken] ) {
			propertyTag = TiVoProgramChannelTag;
		} else if ( [initString isEqualToString:TiVoProgramStationToken] ) {
			propertyTag = TiVoProgramStationNameTag;
		} else if ( [initString isEqualToString:TiVoProgramDefToken] ) {
			propertyTag = TiVoProgramDefTag;
		} else if ( [initString isEqualToString:TiVoProgramEpisodeNumberToken] ) {
			propertyTag = TiVoProgramEpisodeNumberTag;
		} else if ( [initString isEqualToString:TiVoProgramProgramIDToken] ) {
			propertyTag = TiVoProgramProgramIDTag;
		} else if ( [initString isEqualToString:TiVoProgramPlayerToken] ) {
			propertyTag = TiVoProgramPlayerTag;
		} else if ( [initString isEqualToString:TiVoProgramInternalIDToken] ) {
			propertyTag = TiVoProgramInternalIDTag;
		} else if ( [initString isEqualToString:TiVoProgramDurationToken] ) {
			propertyTag = TiVoProgramDurationTag;
		} else if ( [initString isEqualToString:TiVoProgramSourceSizeToken] ) {
			propertyTag = TiVoProgramSourceSizeTag;
		} else {
			WARNING( @"no propertyTag found for initString: %@", initString );
			[self autorelease];
			return nil;
		}
	}
	RETURN( @"initString: %@ became propertyTag: %d", initString, propertyTag );
	return self;
}

#pragma mark -
#pragma mark Accessor methods

- (NSString *)description
{
	return [self tokenString];
}

- (NSString *)tokenString
{
	return [NSString stringWithFormat:@"%%{%@}@", [self stringValue] ];
}

- (NSString *)label
{
	switch ( propertyTag ) {
		case TiVoProgramTitleTag:			return TiVoProgramTitleString;			break;
		case TiVoProgramSeriesTitleTag:		return TiVoProgramSeriesTitleString;	break;
		case TiVoProgramCaptureDateTag:		return TiVoProgramCaptureDateString;	break;
		case TiVoProgramChannelTag:			return TiVoProgramChannelString;		break;
		case TiVoProgramStationNameTag:		return TiVoProgramStationString;		break;
		case TiVoProgramDefTag:				return TiVoProgramDefString;			break;
		case TiVoProgramEpisodeNumberTag:	return TiVoProgramEpisodeString;		break;
		case TiVoProgramProgramIDTag:		return TiVoProgramProgramIDString;		break;
		case TiVoProgramPlayerTag:			return TiVoProgramPlayerString;			break;
		case TiVoProgramInternalIDTag:		return TiVoProgramInternalIDString;		break;
		case TiVoProgramDurationTag:		return TiVoProgramDurationString;		break;
		case TiVoProgramSourceSizeTag:		return TiVoProgramSourceSizeString;		break;
		default:							return @"-";							break;
	}
}

- (NSString *)stringValue
{
	switch ( propertyTag ) {
		case TiVoProgramTitleTag:			return TiVoProgramTitleToken;			break;
		case TiVoProgramSeriesTitleTag:		return TiVoProgramSeriesTitleToken;		break;
		case TiVoProgramCaptureDateTag:		return TiVoProgramCaptureDateToken;		break;
		case TiVoProgramChannelTag:			return TiVoProgramChannelToken;			break;
		case TiVoProgramStationNameTag:		return TiVoProgramStationToken;			break;
		case TiVoProgramDefTag:				return TiVoProgramDefToken;				break;
		case TiVoProgramEpisodeNumberTag:	return TiVoProgramEpisodeNumberToken;	break;
		case TiVoProgramProgramIDTag:		return TiVoProgramProgramIDToken;		break;
		case TiVoProgramPlayerTag:			return TiVoProgramPlayerToken;			break;
		case TiVoProgramInternalIDTag:		return TiVoProgramInternalIDToken;		break;
		case TiVoProgramDurationTag:		return TiVoProgramDurationToken;		break;
		case TiVoProgramSourceSizeTag:		return TiVoProgramSourceSizeToken;		break;
		default:							return @"-";							break;
	}
}

- (NSString *)stringForProgram:(TiVoProgram *)program
{
	return [program valueForKey:[self stringValue] ];
}

@end

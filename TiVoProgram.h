//
//  TiVoProgram.h
//  TiVo Butler
//
//  Created by Eric Baur on 1/15/08.
//  Copyright 2008 Eric Shore Baur. All rights reserved.
//

#import <CoreData/CoreData.h>

#import "TiVoDurationValueTransformer.h"
#import "TiVoSizeValueTransformer.h"

@class TiVoPlayer;

typedef enum {
	TiVoProgramInProgressStatus = 0,
	TiVoProgramSaveStatus,
	TiVoProgramNoStatus,
	TiVoProgramExpiresSoonStatus,
	TiVoProgramExpiredStatus,
} TiVoProgramStatus;

typedef enum {
	TiVoProgramNoTag = -1,
	TiVoProgramTitleTag = 0,
	TiVoProgramSeriesTitleTag,
	TiVoProgramCaptureDateTag,
	TiVoProgramChannelTag,
	TiVoProgramStationNameTag,
	TiVoProgramDefTag,	// HD or SD
	TiVoProgramEpisodeNumberTag,
	TiVoProgramProgramIDTag,
	TiVoProgramPlayerTag,
	TiVoProgramInternalIDTag,
	TiVoProgramDurationTag,
	TiVoProgramSourceSizeTag
} TiVoProgramPropertyTag;

#define TiVoProgramNullToken			@"-"
//check the AccessorAdditions for implementations of indirect properties
#define TiVoProgramTitleToken			@"title"
#define TiVoProgramSeriesTitleToken		@"seriesTitle"
#define TiVoProgramCaptureDateToken		@"captureDate"
#define TiVoProgramChannelToken			@"channel"
#define TiVoProgramStationToken			@"stationName"
#define TiVoProgramDefToken				@"def"
#define TiVoProgramEpisodeNumberToken	@"episodeNumber"
#define TiVoProgramProgramIDToken		@"programID"
#define TiVoProgramPlayerToken			@"playerName"
#define TiVoProgramInternalIDToken		@"internalIDString"
#define TiVoProgramDurationToken		@"durationString"
#define TiVoProgramSourceSizeToken		@"sourceSizeString"

#define TiVoProgramNullString			@"-"

#define TiVoProgramTitleString			@"Title"
#define TiVoProgramSeriesTitleString	@"Series Title"
#define TiVoProgramCaptureDateString	@"Capture Date"
#define TiVoProgramChannelString		@"Channel"
#define TiVoProgramStationString		@"Station"
#define TiVoProgramDefString			@"Def."
#define TiVoProgramEpisodeString		@"Episode"
#define TiVoProgramProgramIDString		@"Program ID"
#define TiVoProgramPlayerString			@"Player Name"
#define TiVoProgramInternalIDString		@"Internal ID"
#define TiVoProgramDurationString		@"Duration"
#define TiVoProgramSourceSizeString		@"Source Size"

@interface TiVoProgram :  NSManagedObject  
{	

}

@property (retain) NSString * sourceFormat;
@property (retain) NSString * contentType;
@property (retain) NSNumber * duration;
@property (retain) NSDate * captureDate;
@property (retain) NSString * programDescription;
@property (retain) NSNumber * highDefinition;
@property (retain) NSNumber * byteOffset;
@property (retain) NSNumber * sourceSize;
@property (retain) NSString * programID;
@property (retain) NSString * videoDetailsURL;
@property (retain) NSString * title;
@property (retain) NSString * episodeNumber;
@property (retain) NSString * contentURL;
@property (retain) NSNumber * inProgress;
@property (retain) NSManagedObject * series;
@property (retain) NSManagedObject * station;
@property (retain) TiVoPlayer * player;
@property (retain) NSNumber * deletedFromPlayer;
@property (retain) NSNumber * internalID;
@property (retain) NSNumber * status;

@property (readonly) NSSet * smartGroups;

@property (readonly) NSImage * statusImage;

@end

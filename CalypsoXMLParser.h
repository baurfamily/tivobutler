//
//  CalypsoXMLParser.h
//  TiVo Butler
//
//  Created by Eric Baur on 1/31/08.
//  Copyright 2008 Eric Shore Baur. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "TiVoPlayer.h"
#import "TiVoProgram.h"

#import "EntityHelper.h"

#define CalypsoTiVoContainerTag		@"TiVoContainer"
#define CalypsoItemTag				@"Item"
#define CalypsoDetailsTag			@"Details"
#define CalypsoCopyProtectedTag		@"CopyProtected"
#define CalypsoLastChangeDateTag	@"LastChangeDate"
#define CalypsoSourceChannelTag		@"SourceChannel"
#define CalypsoSourceFormatTag		@"SourceFormat"
#define CalypsoContentTypeTag		@"ContentType"
#define CalypsoDurationTag			@"Duration"
#define CalypsoCaptureDateTag		@"CaptureDate"
#define CalypsoEpisodeTitleTag		@"EpisodeTitle"
#define CalypsoDescriptionTag		@"Description"
#define CalypsoSourceStationTag		@"SourceStation"
#define CalypsoSeriesIDTag			@"SeriesId"
#define CalypsoHighDefinitionTag	@"HighDefinition"
#define CalypsoByteOffsetTag		@"ByteOffset"
#define CalypsoSourceSizeTag		@"SourceSize"
#define CalypsoProgramIDTag			@"ProgramId"
#define CalypsoTitleTag				@"Title"
#define CalypsoEpisodeNumberTag		@"EpisodeNumber"
#define CalypsoLinksTag				@"Links"
#define CalypsoContentTag			@"Content"
#define CalypsoVideoDetailsTag		@"TiVoVideoDetails"
#define CalypsoUrlTag				@"Url"
#define CalypsoAvailableTag			@"Available"
#define CalypsoCustomIconTag		@"CustomIcon"
#define CalypsoAcceptsParamsTag		@"AcceptsParams"
#define CalypsoContentTypeTag		@"ContentType"
#define CalypsoInProgressTag		@"InProgress"

@interface CalypsoXMLParser : NSObject
{
	NSManagedObjectContext *managedObjectContext;
	NSXMLParser *xmlParser;

	int itemsParsed;

	TiVoPlayer *player;
	
	TiVoProgram *currentProgram;

	BOOL contentFlag;
	BOOL videoDetailsFlag;
	BOOL customIconFlag;

	NSMutableString *tempValueString;
	NSString *tempSeriesString;
	NSString *tempStationString;
	
	NSMutableDictionary *tempDict;
}

- (int)parseData:(NSData *)xmlData fromPlayer:(TiVoPlayer *)sourcePlayer resetPrograms:(BOOL)reset;
- (void)disableCurrentPrograms;
- (void)addNewProgram;

- (TiVoProgram *)programForInternalID:(int)internalID;
- (NSManagedObject *)stationWithName:(NSString *)name andChannel:(NSNumber *)channel;
- (NSManagedObject *)seriesWithIdentifier:(NSString *)ident title:(NSString *)title;
@end

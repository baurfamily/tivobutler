//
//  TiVoPlayer.h
//  TiVo Butler
//
//  Created by Eric Baur on 1/15/08.
//  Copyright 2008 Eric Shore Baur. All rights reserved.
//

#import <CoreData/CoreData.h>

#define TiVoPlayerItemTag			@"Item"
#define TiVoPlayerLastChangeDateTag	@"LastChangeDate"

#import "EntityHelper.h"
#import "CalypsoXMLParser.h"

@class TiVoProgram;

@interface TiVoPlayer :  NSManagedObject  
{
	NSURL *url;
	int anchor;
	
	BOOL isDownloading;
	
	NSURLConnection *urlConnection;
	NSMutableData *receivedData;
	
	id parser;
}

- (void)connect;

@property (retain) NSNumber * capacity;
@property (retain) NSString * mediaAccessKey;
@property (retain) NSString * host;
@property (retain) NSDate * dateLastChecked;
@property (retain) NSDate * dateLastUpdated;
@property (retain) NSSet* nowPlayingList;

@property (readonly) NSURL *url;

@end

@interface TiVoPlayer (CoreDataGeneratedPrimitiveAccessors)

- (NSString *)primitiveHost;
- (void)setPrimitiveHost:(NSString *)value;

- (NSString *)primitiveMediaAccessKey;
- (void)setPrimitiveMediaAccessKey:(NSString *)value;

@end

@interface TiVoPlayer (CoreDataGeneratedAccessors)
- (void)addNowPlayingListObject:(TiVoProgram *)value;
- (void)removeNowPlayingListObject:(TiVoProgram *)value;
- (void)addNowPlayingList:(NSSet *)value;
- (void)removeNowPlayingList:(NSSet *)value;

@end

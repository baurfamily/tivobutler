//
//  EntityHelper.h
//  TiVo Butler
//
//  Created by Eric Baur on 2/3/08.
//  Copyright 2008 Eric Shore Baur. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#define TiVoSeriesEntityName		@"Series"
#define TiVoStationEntityName		@"Station"
#define TiVoPlayerEntityName		@"TiVoPlayer"
#define TiVoProgramEntityName		@"TiVoProgram"
#define TiVoWorkQueueItemEntityName	@"WorkQueueItem"

@interface EntityHelper : NSObject {

}

+ (NSArray *)arrayOfEntityWithName:(NSString *)entityString usingPredicateString:(NSString *)predicateString;
+ (NSArray *)arrayOfEntityWithName:(NSString *)entityString usingPredicate:(NSPredicate *)predicate;

@end

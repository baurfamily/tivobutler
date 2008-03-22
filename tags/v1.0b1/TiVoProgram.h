//
//  TiVoProgram.h
//  TiVo Butler
//
//  Created by Eric Baur on 1/15/08.
//  Copyright 2008 Eric Shore Baur. All rights reserved.
//

#import <CoreData/CoreData.h>

@class TiVoPlayer;

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
@property (retain) TiVoPlayer * player;
@property (retain) NSNumber * deletedFromPlayer;

@property (readonly) NSSet * smartGroups;

@end



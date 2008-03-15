//
//  SmartGroup.h
//  TiVo Butler
//
//  Created by Eric Baur on 3/14/08.
//  Copyright 2008 Eric Shore Baur. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface SmartGroup : NSManagedObject {

}

@property (retain) NSNumber * autoDownload;
@property (retain) NSNumber * immediateDownload;
@property (retain) NSString * name;
@property (retain) NSPredicate * predicate;
@property (retain) NSString * predicateString;

@end

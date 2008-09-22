//
//  EntityTokenFieldValueTransformer.h
//  TiVo Butler
//
//  Created by Eric Baur on 5/3/08.
//  Copyright 2008 Eric Shore Baur. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "EntityToken.h"

@interface EntityTokenFieldValueTransformer : NSObject {

}

- (NSArray *)transformedValue:(NSString *)stringValue;
- (NSString *)reverseTransformedValue:(NSArray *)array;

@end

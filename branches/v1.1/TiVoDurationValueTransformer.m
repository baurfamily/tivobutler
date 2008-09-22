//
//  TiVoDurationValueTransformer.m
//  TiVo Butler
//
//  Created by Eric Baur on 3/25/08.
//  Copyright 2008 Eric Shore Baur. All rights reserved.
//

#import "TiVoDurationValueTransformer.h"


@implementation TiVoDurationValueTransformer

+ (Class)transformedValueClass
{
    return [NSString class];
}

+ (BOOL)allowsReverseTransformation
{
    return NO;
}

- (id)transformedValue:(NSNumber *)value
{	
	long temp = [value doubleValue] / 1000 / 60;
	
	int minutes = temp % 60;
	int hours = temp / 60;

	return [NSString stringWithFormat:@"%.2d:%.2d", hours, minutes];
}

@end

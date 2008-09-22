//
//  TiVoSizeValueTransformer.m
//  TiVo Butler
//
//  Created by Eric Baur on 3/25/08.
//  Copyright 2008 Eric Shore Baur. All rights reserved.
//

#import "TiVoSizeValueTransformer.h"

@implementation TiVoSizeValueTransformer

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
	double temp;
	
	temp = [value doubleValue] / 1024 / 1024;

	if ( temp < 1024 ) {
		return [NSString stringWithFormat:@"%1.0f MB", temp];
	}
	temp /= 1024;
	return [NSString stringWithFormat:@"%1.2f GB", temp];
}

@end

//
//  EntityTokenFieldValueTransformer.m
//  TiVo Butler
//
//  Created by Eric Baur on 5/3/08.
//  Copyright 2008 Eric Shore Baur. All rights reserved.
//

#import "EntityTokenFieldValueTransformer.h"


@implementation EntityTokenFieldValueTransformer

+ (Class)transformedValueClass
{
    return [NSArray class];
}

+ (BOOL)allowsReverseTransformation
{
    return YES;
}

- (NSArray *)transformedValue:(NSString *)stringValue
{
	DEBUG( @"stringValue: %@", stringValue );
	NSMutableArray *tempArray = [NSMutableArray array];
	NSScanner *scanner = [NSScanner scannerWithString:stringValue];
	
	NSString *tempString = nil;
	
	while ( [scanner scanUpToString:@"%{" intoString:&tempString] ) {
		[tempArray addObject:tempString];
		
		//eat the %{ so we don't try and parse it
		if ( [scanner scanString:@"%{" intoString:NULL] ) {
			if ( [scanner scanUpToString:@"}@" intoString:&tempString] ) {
				//make sure we have }@ at the end
				if ( [scanner scanString:@"}@" intoString:NULL] ) {
					EntityToken *token = [[[EntityToken alloc] initWithTokenString:tempString] autorelease];
					if ( token ) {
						[tempArray addObject:token];
					} else {
						[tempArray addObject:[NSString stringWithFormat:@"%%{%@}@", tempString] ];
					}
				} else {
					[tempArray addObject:@"}@"];
				}
			}
		} else {
			if ( ![scanner isAtEnd] ) {
				[tempArray addObject:@"%{"];
			}
		}
	}
	RETURN( [tempArray description] );
	return tempArray;
}

- (NSString *)reverseTransformedValue:(NSArray *)array
{	
	DEBUG( @"array:\n%@", [array description] );
	NSMutableString *tempString = [NSMutableString string];
	id tempObject;
	for ( tempObject in array ) {
		if ( [tempObject isKindOfClass:[EntityToken class]] ) {
			[tempString appendString:[tempObject tokenString] ];	//already has the %{ and }@ in it
		} else if ([tempObject isKindOfClass:[NSString class] ] ) {
			[tempString appendString:tempObject];
		} else {
			WARNING( @"failed to transform value of class: %@", [tempObject className] );
		}
	}
	RETURN( tempString );
	return [tempString copy];
}

@end

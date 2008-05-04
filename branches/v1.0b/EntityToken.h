//
//  EntityToken.h
//  TiVo Butler
//
//  Created by Eric Baur on 5/1/08.
//  Copyright 2008 Eric Shore Baur. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "EntityHelper.h"
#import "TiVoProgram.h"

@interface EntityToken : NSObject {
	TiVoProgramPropertyTag propertyTag;
}

- (id)initWithTag:(TiVoProgramPropertyTag)initTag;
- (id)initWithTokenString:(NSString *)initString;

- (NSString *)label;
- (NSString *)stringValue;
- (NSString *)tokenString;

- (NSString *)stringForProgram:(TiVoProgram *)program;

@end

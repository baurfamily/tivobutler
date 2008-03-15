//
//  SmartGroup.m
//  TiVo Butler
//
//  Created by Eric Baur on 3/14/08.
//  Copyright 2008 Eric Shore Baur. All rights reserved.
//

#import "SmartGroup.h"


@implementation SmartGroup

@dynamic autoDownload;
@dynamic immediateDownload;
@dynamic name;
@dynamic predicate;
@dynamic predicateString;

- (NSPredicate *)predicate
{
	ENTRY;
	return [NSPredicate predicateWithFormat:self.predicateString];
}

- (void)setPredicate:(NSPredicate *)newPredicate
{
	[self willChangeValueForKey:@"predicate"];
	[self willChangeValueForKey:@"predicateString"];
	self.predicateString = [newPredicate predicateFormat];
	[self didChangeValueForKey:@"predicate"];
	[self didChangeValueForKey:@"predicateString"];
}

@end

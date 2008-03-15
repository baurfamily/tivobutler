//
//  PredicateTesting.h
//  TiVo Butler
//
//  Created by Eric Baur on 2/24/08.
//  Copyright 2008 Eric Shore Baur. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface PredicateTesting : NSObject {
	NSString *predicateString;
	NSPredicate *predicate;
	
	IBOutlet NSWindow *predicateTestingWindow;

	NSManagedObjectContext *managedObjectContext;
}

- (IBAction)showPredicateTestingWindow:(id)sender;
- (IBAction)refreshPredicate:(id)sender;

@end

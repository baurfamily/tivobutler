//
//  LibraryController.h
//  Eavesdrop
//
//  Created by Eric Baur on 12/15/07.
//  Copyright 2007 Eric Shore Baur. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "EntityHelper.h"

typedef enum {
	LCLibraryPosition = 0,
	LCWorkQueuePosition,
	LCPlayersPosition,
	LCProgramGroupingsPosition,
	LCStationsPostion
} LCListingPostion;

@interface LibraryController : NSObject {
	NSMutableArray *libraryArray;
	
	IBOutlet NSArrayController *workQueueArrayController;
	IBOutlet NSArrayController *playerArrayController;
	IBOutlet NSArrayController *programArrayController;
	IBOutlet NSArrayController *seriesArrayController;
	IBOutlet NSArrayController *stationArrayController;
}

- (IBAction)update:(id)sender;

- (void)updateWorkQueue;
- (void)updatePlayerList;
- (void)updateProgramGroups;
- (void)updateStations;

@end

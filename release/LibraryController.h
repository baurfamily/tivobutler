//
//  LibraryController.h
//  Eavesdrop
//
//  Created by Eric Baur on 12/15/07.
//  Copyright 2007 Eric Shore Baur. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "EntityHelper.h"

#include "LNSSourceListView.h"

typedef enum {
	LCLibraryPosition = 0,
	LCHistoryPosition,
	LCWorkQueuePosition,
	LCWorkQueueHistoryPosition,
	LCPlayersPosition,
	LCProgramGroupingsPosition,
	LCStationsPostion,
	LCSmartGroupsPosition
} LCListingPostion;

@interface LibraryController : NSObject {
	NSMutableArray *libraryArray;
	
	IBOutlet NSArrayController *workQueueArrayController;
	IBOutlet NSArrayController *playerArrayController;
	IBOutlet NSArrayController *programArrayController;
	IBOutlet NSArrayController *seriesArrayController;
	IBOutlet NSArrayController *stationArrayController;
	IBOutlet NSArrayController *smartGroupArrayController;
	
	IBOutlet LNSSourceListView *sourceListView;
}

- (IBAction)update:(id)sender;

- (void)updateWorkQueue;
- (void)updateWorkHistoryQueue;
- (void)updatePlayerList;
- (void)updateProgramGroups;
- (void)updateStations;

- (void)updateSmartGroups;

@end

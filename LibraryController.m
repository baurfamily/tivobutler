//
//  LibraryController.m
//  Eavesdrop
//
//  Created by Eric Baur on 12/15/07.
//  Copyright 2007 Eric Shore Baur. All rights reserved.
//

#import "LibraryController.h"


@implementation LibraryController

- (void)awakeFromNib
{
	ENTRY;
	[self update:self];

	[workQueueArrayController
		addObserver:self
		forKeyPath:@"arrangedObjects"
		options:(NSKeyValueObservingOptionNew|NSKeyValueObservingOptionOld)
		context:NULL
	];
	[playerArrayController
		addObserver:self
		forKeyPath:@"arrangedObjects"
		options:(NSKeyValueObservingOptionNew|NSKeyValueObservingOptionOld)
		context:NULL
	];
	[seriesArrayController
		addObserver:self
		forKeyPath:@"arrangedObjects"
		options:(NSKeyValueObservingOptionNew|NSKeyValueObservingOptionOld)
		context:NULL
	];
	[stationArrayController
		addObserver:self
		forKeyPath:@"arrangedObjects"
		options:(NSKeyValueObservingOptionNew|NSKeyValueObservingOptionOld)
		context:NULL
	];
}

- (IBAction)update:(id)sender
{
	ENTRY;
	[self willChangeValueForKey:@"libraryArray"];

	//- create the library array if we don't already have one
	if ( !libraryArray ) {
		libraryArray = [[NSMutableArray arrayWithObjects:
			[NSDictionary dictionary],
			[NSDictionary dictionary],
			[NSDictionary dictionary],
			[NSDictionary dictionary],
			[NSDictionary dictionary],
			nil
		] retain];
	}
	
	NSDictionary *tempDict = [NSDictionary dictionaryWithObjectsAndKeys:
		[NSNumber numberWithBool:NO],	@"isSourceGroup",
		@"Library",						@"name",
		nil
	];
	[libraryArray replaceObjectAtIndex:LCLibraryPosition withObject:tempDict];
	
	//- update each of the component pieces of the library list
	[self updateWorkQueue];
	[self updatePlayerList];
	[self updateProgramGroups];
	[self updateStations];
	
	[self didChangeValueForKey:@"libraryArray"];
	EXIT;
}

- (void)updateWorkQueue
{
	ENTRY;

	[self willChangeValueForKey:@"libraryArray"];
	[libraryArray
		replaceObjectAtIndex:LCWorkQueuePosition
		withObject:[NSDictionary dictionaryWithObjectsAndKeys:
			[NSNumber numberWithBool:NO],	@"isSourceGroup",
			@"Work Queue",					@"name",
			[NSPredicate predicateWithFormat:@"ANY workQueueItems.active == YES"], @"predicate",
			nil ]
	];
	[self didChangeValueForKey:@"libraryArray"];
}

- (void)updatePlayerList
{
	ENTRY;
	NSArray *entityArray;
	@synchronized (TiVoPlayerEntityName) {
		entityArray = [EntityHelper arrayOfEntityWithName:TiVoPlayerEntityName usingPredicateString:@"active = YES"];
	}
	NSMutableArray *nameArray = [NSMutableArray array];
	NSManagedObject *tempObject;
	for ( tempObject in entityArray ) {
		[nameArray addObject:[NSDictionary dictionaryWithObjectsAndKeys:
			[NSNumber numberWithBool:NO],		@"isSourceGroup",
			[tempObject valueForKey:@"name"],	@"name",
			[NSPredicate predicateWithFormat:@"player = %@", tempObject ],
												@"predicate", 
			nil ]
		];
	}
	
	[self willChangeValueForKey:@"libraryArray"];
	[libraryArray
		replaceObjectAtIndex:LCPlayersPosition
		withObject:[NSDictionary dictionaryWithObjectsAndKeys:
			[NSNumber numberWithBool:YES],	@"isSourceGroup",
			@"Players",						@"name",
			nameArray,						@"children",
			nil ]
	];
	[self didChangeValueForKey:@"libraryArray"];
}

- (void)updateProgramGroups
{
	ENTRY;
	NSArray *entityArray;
	@synchronized (TiVoSeriesEntityName) {
		entityArray = [EntityHelper arrayOfEntityWithName:TiVoSeriesEntityName usingPredicate:[NSPredicate predicateWithValue:TRUE] ];
	}
	NSMutableArray *nameArray = [NSMutableArray array];
	NSManagedObject *tempObject;
	for ( tempObject in entityArray ) {
		[nameArray addObject:[NSDictionary dictionaryWithObjectsAndKeys:
			[NSNumber numberWithBool:NO],		@"isSourceGroup",
			[tempObject valueForKey:@"title"],	@"name",
			[NSPredicate predicateWithFormat:@"series = %@", tempObject ],
												@"predicate", 
			nil ]
		];
	}
	
	[self willChangeValueForKey:@"libraryArray"];
	[libraryArray
		replaceObjectAtIndex:LCProgramGroupingsPosition
		withObject:[NSDictionary dictionaryWithObjectsAndKeys:
			[NSNumber numberWithBool:YES],	@"isSourceGroup",
			@"Program Groups",				@"name",
			nameArray,						@"children",
			nil	]
	];
	[self didChangeValueForKey:@"libraryArray"];
}

- (void)updateStations
{
	ENTRY;
	NSArray *entityArray;
	@synchronized (TiVoStationEntityName) {
		entityArray = [EntityHelper arrayOfEntityWithName:TiVoStationEntityName usingPredicate:[NSPredicate predicateWithValue:TRUE] ];
	}
	NSMutableArray *nameArray = [NSMutableArray array];
	NSManagedObject *tempObject;
	for ( tempObject in entityArray ) {
		[nameArray addObject:[NSDictionary dictionaryWithObjectsAndKeys:
			[NSNumber numberWithBool:NO],		@"isSourceGroup",
			[NSString stringWithFormat:@"%@ (%@)", [tempObject valueForKey:@"name"], [tempObject valueForKey:@"channel"] ],
												@"name",
			[NSPredicate predicateWithFormat:@"station = %@", tempObject ],
												@"predicate", 
			nil ]
		];
	}
	
	[self willChangeValueForKey:@"libraryArray"];
	[libraryArray
		replaceObjectAtIndex:LCStationsPostion
		withObject:[NSDictionary dictionaryWithObjectsAndKeys:
			[NSNumber numberWithBool:YES],	@"isSourceGroup",
			@"Stations",					@"name",
			nameArray,						@"children",
			nil ]
	];
	[self didChangeValueForKey:@"libraryArray"];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	//TODO: Make the observation more granular
	DEBUG( @"keyPath:%@\nobject: %@\nchange: %@", keyPath, [object description], [change description] );
	if ( object == workQueueArrayController ) {
		[self updateWorkQueue];
	} else if ( object == playerArrayController ) {
		[self updatePlayerList];
	} else if ( object == programArrayController ) {
		//- nothing to do yet on this one...
	} else if ( object == seriesArrayController ) {
		[self updateProgramGroups];
	} else if ( object == stationArrayController ) {
		[self updateStations];
	} else {
		WARNING( @"no update done for observed object: %@", [object description] );
	}
}

@end

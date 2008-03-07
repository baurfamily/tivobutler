//
//  CalypsoXMLParser.m
//  TiVo Butler
//
//  Created by Eric Baur on 1/31/08.
//  Copyright 2008 Eric Shore Baur. All rights reserved.
//

#import "CalypsoXMLParser.h"


@implementation CalypsoXMLParser

- (void)beginParseThreadWithSettings:(NSDictionary *)settingsDict
{
	//- this isn't safe for now, because of multi-threading issues in Core Data, et. al.
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	[self
		parseData:[settingsDict objectForKey:@"data"]
		fromPlayer:[settingsDict objectForKey:@"player"]
	];
	[pool release];
}

- (void)parseData:(NSData *)xmlData fromPlayer:(TiVoPlayer *)sourcePlayer
{
	player = [sourcePlayer retain];
	managedObjectContext = [[player managedObjectContext] retain];
	
	if (xmlParser) {
		[xmlParser abortParsing];
		xmlParser = nil;
	}

	DEBUG( @"creating XML Parser" );
	xmlParser = [[NSXMLParser alloc] initWithData:xmlData];
	[xmlParser setDelegate:self];
	[xmlParser setShouldResolveExternalEntities:NO];

	[self disableCurrentPrograms];
	
	[xmlParser parse];
	
	DEBUG( @"releasing XML Parser" );
	[xmlParser release];
	xmlParser = nil;
}

- (void)disableCurrentPrograms
{
	NSArray *programsArray = [EntityHelper
		arrayOfEntityWithName:TiVoProgramEntityName
		usingPredicate:[NSPredicate predicateWithFormat:@"player = %@", player]
	];
	[programsArray makeObjectsPerformSelector:@selector(setDeletedFromPlayer:) withObject:[NSNumber numberWithBool:YES] ];
}

- (void)addNewProgram
{
	ENTRY;
	NSString *key;
	
	//- check to see if the dictionary has "basic" information
	if ( [tempDict objectForKey:@"programID"] == nil ) {
		DEBUG( @"won't add program with nil programID" );
		return;
	}
	
	//- create the program we'll be inserting
	TiVoProgram *tempProgram = [NSEntityDescription
		insertNewObjectForEntityForName:TiVoProgramEntityName
		inManagedObjectContext:managedObjectContext
	];
	[tempProgram setValue:player forKey:@"player"];
	
	//- add all the keys from the dictionary to the program
	for ( key in tempDict ) {
		//INFO( @"setting key: %@\nvalue: %@", key, [tempDict valueForKey:key] );
		[tempProgram setValue:[tempDict valueForKey:key] forKey:key];
	}
	//- now add the program to the player
	[player addNowPlayingListObject:tempProgram];
}

#pragma mark -
#pragma mark NSXMLParser delegate methods

- (void)parserDidStartDocument:(NSXMLParser *)parse
{
	ENTRY;
}

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName 
	namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName attributes:(NSDictionary *)attributeDict
{
	[tempValueString setString:@""];
 
	if ( [elementName isEqualToString:TiVoPlayerItemTag] ) {
		//- create a new dictionary and clear out the series info
		tempDict = [NSMutableDictionary dictionary];
		tempSeriesString = nil;
		tempStationString = nil;
		
	} else if ( [elementName isEqualToString:CalypsoLastChangeDateTag] ) {
		unsigned int timestamp;
		[[NSScanner scannerWithString:tempValueString] scanHexInt:&timestamp]; 
		player.dateLastUpdated = [NSDate dateWithTimeIntervalSince1970:timestamp];

	} else if ( [elementName isEqualToString:CalypsoContentTag] ) {
		contentFlag = YES;

	} else if ( [elementName isEqualToString:CalypsoVideoDetailsTag] ) {
		videoDetailsFlag = YES;

	} else if ( [elementName isEqualToString:CalypsoCustomIconTag] ) {
		customIconFlag = YES;
	
	}
}

- (void)parser:(NSXMLParser*)parser foundCharacters:(NSString*)string
{ 
	if ( !tempValueString )
		tempValueString = [[NSMutableString alloc] initWithCapacity:50];

	[tempValueString appendString:string];
} 

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName
	namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName
{
	//INFO( @"element %@ value: %@", elementName, [tempValueString copy] );
	
	//- see if we have a valid dictionary to work with
	if ( !tempDict ) return;
		
	//- check the element...
	if ( [elementName isEqualToString:CalypsoItemTag] ) {
		//- only add a new program if we have a dictionary with data in it
		//if ( tempDict ) [self addNewProgram];
		if ( tempDict ) {
			[self performSelectorOnMainThread:@selector(addNewProgram) withObject:nil waitUntilDone:YES]; 
		}
		
	} else if ( [elementName isEqualToString:CalypsoSourceChannelTag] ) {
		if ( tempStationString ) {
			[tempDict
				setObject:[self
					stationWithName:tempStationString
					andChannel:[NSNumber numberWithInt:[tempValueString intValue]] ]
				forKey:@"station"
			];
			tempStationString = nil;
		} else {
			tempStationString = [tempValueString copy];
		}

		
	} else if ( [elementName isEqualToString:CalypsoSourceFormatTag] ) {
		[tempDict setObject:[tempValueString copy] forKey:@"sourceFormat"];
				
	} else if ( [elementName isEqualToString:CalypsoContentTypeTag] ) {
		[tempDict setObject:[tempValueString copy] forKey:@"contentType"];
		
	} else if ( [elementName isEqualToString:CalypsoDurationTag] ) {
		[tempDict setObject:[NSNumber numberWithInt:[tempValueString integerValue] ] forKey:@"duration"];
		
	} else if ( [elementName isEqualToString:CalypsoCaptureDateTag] ) {
		unsigned int timestamp;
		[[NSScanner scannerWithString:tempValueString] scanHexInt:&timestamp]; 
		[tempDict setObject:[NSDate dateWithTimeIntervalSince1970:timestamp] forKey:@"captureDate"];
		
	} else if ( [elementName isEqualToString:CalypsoEpisodeTitleTag] ) {
		[tempDict setObject:[tempValueString copy] forKey:@"title"];
		
	} else if ( [elementName isEqualToString:CalypsoDescriptionTag] ) {
		[tempDict setObject:[tempValueString copy] forKey:@"programDescription"];
		
	} else if ( [elementName isEqualToString:CalypsoSourceStationTag] ) {
		if ( tempStationString ) {
			[tempDict
				setObject:[self
					stationWithName:tempValueString
					andChannel:[NSNumber numberWithInt:[tempStationString intValue]] ]
				forKey:@"station"
			];
			tempStationString = nil;
		} else {
			tempStationString = [tempValueString copy];
		}
		
	} else if ( [elementName isEqualToString:CalypsoSeriesIDTag] ) {
		if ( tempSeriesString ) {
			//- since we have a tempSeriesString, this is the second piece of info we need check for adding a new one
			[tempDict setObject:[self seriesWithIdentifier:tempValueString title:tempSeriesString] forKey:@"series"];
			tempSeriesString = nil;
		} else {
			//- since we don't have a tempSeriesString, then we'll save this info for later
			tempSeriesString = [tempValueString copy];
		}
		
	} else if ( [elementName isEqualToString:CalypsoHighDefinitionTag] ) {
		if ( [tempValueString isEqualToString:@"Yes"] ) {
			[tempDict setObject:[NSNumber numberWithBool:YES] forKey:@"highDefinition"];
		} else {
			[tempDict setObject:[NSNumber numberWithBool:NO] forKey:@"highDefinition"];
		}
			
	} else if ( [elementName isEqualToString:CalypsoByteOffsetTag] ) {
		[tempDict setObject:[NSNumber numberWithInt:[tempValueString intValue] ] forKey:@"byteOffset"];

	} else if ( [elementName isEqualToString:CalypsoSourceSizeTag] ) {
		[tempDict setObject:[NSNumber numberWithInt:[tempValueString integerValue]] forKey:@"sourceSize"];

	} else if ( [elementName isEqualToString:CalypsoProgramIDTag] ) {
		[tempDict setObject:[tempValueString copy] forKey:@"programID"];
		if ( [self isProgramIDUsed:tempValueString] ) {
			DEBUG( @"programID (%@) found", tempValueString );
			//- this programID was already in use, so we'll nil it out
			tempDict = nil;
		}

	} else if ( [elementName isEqualToString:CalypsoTitleTag] ) {
		if ( tempSeriesString ) {
			//- since we have a tempSeriesString, this is the second piece of info we need check for adding a new one
			[tempDict setObject:[self seriesWithIdentifier:tempSeriesString title:tempValueString] forKey:@"series"];
			tempSeriesString = nil;
		} else {
			//- since we don't have a tempSeriesString, then we'll save this info for later
			tempSeriesString = [tempValueString copy];
		}
		if ( [tempDict valueForKey:@"title"] == nil ) {
			//- since we don't already have a title, we'll use this title
			//- ...this may be wrong (some assumption about order here)
			[tempDict setObject:[tempValueString copy] forKey:@"title"];
		}

	} else if ( [elementName isEqualToString:CalypsoEpisodeNumberTag] ) {
		[tempDict setObject:[tempValueString copy] forKey:@"episodeNumber"];
		
	} else if ( [elementName isEqualToString:CalypsoCopyProtectedTag] ) {
		if ( [tempValueString isEqualToString:@"Yes"] ) {
			[tempDict setObject:[NSNumber numberWithBool:YES] forKey:@"copyProtected"];
		} else {
			[tempDict setObject:[NSNumber numberWithBool:NO] forKey:@"copyProtected"];
		}
		
	} else if ( [elementName isEqualToString:CalypsoUrlTag] ) {
		if ( contentFlag ) {
			[tempDict setObject:[tempValueString copy] forKey:@"contentURL"];
		} else if ( videoDetailsFlag ) {
			[tempDict setObject:[tempValueString copy] forKey:@"videoDetailsURL"];
		} else if ( customIconFlag ) {
			//- don't know if this could change...
			if ( [tempValueString isEqualTo:@"urn:tivo:image:in-progress-recording"] )
				[tempDict setObject:[NSNumber numberWithBool:YES] forKey:@"inProgress"];
			else
				[tempDict setObject:[NSNumber numberWithBool:NO] forKey:@"inProgress"];
		} else {
			WARNING( @"URL tag found outside of expected context." );
		}
	
	} else if ( [elementName isEqualToString:CalypsoAvailableTag] ) {
		if ( contentFlag ) {
			if ( [tempValueString isEqualToString:@"No"] ) {
				[tempDict setObject:[NSNumber numberWithBool:NO] forKey:@"available"];
			} else {
				[tempDict setObject:[NSNumber numberWithBool:YES] forKey:@"available"];
			}
		} else {
			WARNING( @"URL tag found outside of expected context." );
		}
	
	} else if ( [elementName isEqualToString:CalypsoContentTag] ) {
		contentFlag = NO;
	
	} else if ( [elementName isEqualToString:CalypsoVideoDetailsTag] ) {
		videoDetailsFlag = NO;
	
	} else if ( [elementName isEqualToString:CalypsoCustomIconTag] ) {
		customIconFlag = NO;
	
	} else if ( [elementName isEqualToString:CalypsoAcceptsParamsTag] ) {
		//- don't really care about AcceptsParams right now
	} else if ( [elementName isEqualToString:CalypsoContentTypeTag] ) {
		//- don't really care about ContentType right now
	} else if ( [elementName isEqualToString:CalypsoTiVoContainerTag] ) {
		//- don't really care about TiVoContainer right now
	} else if ( [elementName isEqualToString:CalypsoLinksTag] ) {
		//- don't really care about Links right now
	} else if ( [elementName isEqualToString:CalypsoDetailsTag] ) {
		//- don't really care about Details right now
	} else {
		WARNING( @"[parser:didEndElement:...] no match for elementName: %@", [elementName copy] );
	}
}

- (void)parserDidEndDocument:(NSXMLParser *)parser
{
	EXIT;
	[player release];
	player = nil;
	[managedObjectContext release];
	managedObjectContext = nil;
}

- (void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError
{
	ERROR( [parseError description] );
	[tempValueString release];
	tempValueString = nil;
}


#pragma mark -
#pragma mark Entity helper methods

- (BOOL)isProgramIDUsed:(NSString *)programID
{
	NSEntityDescription *entityDesc = [NSEntityDescription
		entityForName:TiVoProgramEntityName
		inManagedObjectContext:managedObjectContext
	];
	NSFetchRequest *request = [[[NSFetchRequest alloc] init] autorelease];
	
	[request setEntity:entityDesc];
	
	NSPredicate *predicate = [NSPredicate predicateWithFormat:
		@"programID = %@", programID
	];
	[request setPredicate:predicate];
	//DEBUG( @"Executing predicate: %@", [predicate description] );
	NSError *error;
	@synchronized (TiVoProgramEntityName) {
		if ( [managedObjectContext countForFetchRequest:request error:&error] > 0 ) {
			NSArray *tempArray = [managedObjectContext executeFetchRequest:request error:&error];
			if ( [tempArray count] > 1 ) {
				WARNING( @"Found %d matching program IDs, will enable the first one.", [tempArray count] );
			}
			[[tempArray objectAtIndex:0] setDeletedFromPlayer:[NSNumber numberWithBool:NO] ];
			return YES;
		} else {
			return NO;
		}
	}
	ERROR( @"shouldn't have gotten to this point!" );
	return NO;
}

- (NSManagedObject *)stationWithName:(NSString *)name andChannel:(NSNumber *)channel
{
	if ( nil==name || nil==channel ) NSLog ( @"bad!" );
	NSError *error = [[NSError alloc] init];
	
	NSEntityDescription *entityDesc = [NSEntityDescription
		entityForName:TiVoStationEntityName
		inManagedObjectContext:managedObjectContext
	];
	NSFetchRequest *request = [[[NSFetchRequest alloc] init] autorelease];
	
	[request setEntity:entityDesc];
	
	NSPredicate *predicate = [NSPredicate predicateWithFormat:
		@"name = %@ AND channel = %@", name, channel
	];
	[request setPredicate:predicate];
		
	@synchronized (TiVoStationEntityName) {
		//DEBUG( @"Executing predicate: %@", [predicate description] );
		NSArray *array;
		@try {
			array = [managedObjectContext executeFetchRequest:request error:&error];
		}
		@catch (NSException *e) {
			NSLog( @"caught exception in creating station when executing fetch request: %@", [e description] );
			array = nil;
		}
		if ( !array )
			WARNING( @"error executing fetch request: %@", [error description] );
		
		if ( [array count] == 1 ) {
			return [array objectAtIndex:0];
		} else if ( [array count] > 1 ) {
			//TODO: consolidate these when we find them
			ERROR( @"more than one match... something went wrong with the datastore!  Using first instance." );
			return [array objectAtIndex:0];
		} else {
			DEBUG( @"creating station with name: %@ and channel: %@", name, channel );
			id tempStation = [NSEntityDescription
				insertNewObjectForEntityForName:TiVoStationEntityName
				inManagedObjectContext:managedObjectContext
			];
			[tempStation setValue:[name copy] forKey:@"name"];
			[tempStation setValue:[channel copy] forKey:@"channel"];
			return tempStation;
		}
	}
	ERROR( @"shouldn't have gotten to this point!" );
	return nil;
}

- (NSManagedObject *)seriesWithIdentifier:(NSString *)ident title:(NSString *)title
{
	NSError *error = [[NSError alloc] init];
	
	NSEntityDescription *entityDesc = [NSEntityDescription
		entityForName:TiVoSeriesEntityName
		inManagedObjectContext:managedObjectContext
	];
	NSFetchRequest *request = [[[NSFetchRequest alloc] init] autorelease];
	
	[request setEntity:entityDesc];
	
	NSPredicate *predicate = [NSPredicate predicateWithFormat:
		@"ident = %@ AND title = %@", ident, title
	];
	[request setPredicate:predicate];

	@synchronized (TiVoSeriesEntityName) {
		//DEBUG( @"Executing predicate: %@", [predicate description] );
		NSArray *array = [managedObjectContext executeFetchRequest:request error:&error];
		
		if ( !array )
			WARNING( @"error executing fetch request: %@", [error description] );
		
		if ( [array count] == 1 ) {
			return [array objectAtIndex:0];
		} else if ( [array count] > 1 ) {
			//TODO: consolidate these when we find them
			ERROR( @"more than one match... something went wrong with the datastore!  Using first instance." );
			return [array objectAtIndex:0];
		} else {
			DEBUG( @"creating series with ident: %@ and title: %@", ident, title );
			id tempSeries = [NSEntityDescription
				insertNewObjectForEntityForName:TiVoSeriesEntityName
				inManagedObjectContext:managedObjectContext
			];
			[tempSeries setValue:[ident copy] forKey:@"ident"];
			[tempSeries setValue:[title copy] forKey:@"title"];
			DEBUG( @"created series with ident: %@ and title: %@", ident, title );
			return tempSeries;
		}
	}
	ERROR( @"shouldn't have gotten to this point!" );
	return nil;
}

@end

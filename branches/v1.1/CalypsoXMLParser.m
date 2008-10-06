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

- (int)parseData:(NSData *)xmlData fromPlayer:(TiVoPlayer *)sourcePlayer resetPrograms:(BOOL)reset
{
	player = [sourcePlayer retain];
	managedObjectContext = [[player managedObjectContext] retain];
	
	if (xmlParser) {
		[xmlParser abortParsing];
		[xmlParser release], xmlParser = nil;
	}

	DEBUG( @"creating XML Parser" );
	xmlParser = [[NSXMLParser alloc] initWithData:xmlData];
	[xmlParser setDelegate:self];
	[xmlParser setShouldResolveExternalEntities:NO];

	if (reset) {
		[self disableCurrentPrograms];
	}
	
	itemsParsed = 0;
	[xmlParser parse];

	return itemsParsed;
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
	//- check to see if the dictionary has "basic" information
	if ( [tempDict objectForKey:@"internalID"] == nil ) {
		DEBUG( @"won't add program with nil internalID" );
		return;
	}
	
	itemsParsed++;
	if ( !currentProgram ) {
		DEBUG( @"adding new program" );
		//- create a new program to insert
		currentProgram = [[NSEntityDescription
			insertNewObjectForEntityForName:TiVoProgramEntityName
			inManagedObjectContext:managedObjectContext
		] retain];
		[currentProgram setValue:player forKey:@"player"];
	}
	
	//- add all the keys from the dictionary to the program
	NSString *key;
	for ( key in tempDict ) {
		[currentProgram setValue:[tempDict valueForKey:key] forKey:key];
	}
	//- now add the program to the player
	[player addProgramsObject:currentProgram];
	
	[currentProgram release], currentProgram = nil;
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
	[tempValueString release], tempValueString = nil;
 
	if ( [elementName isEqualToString:TiVoPlayerItemTag] ) {
		//- create a new dictionary and clear out the series info
		[tempDict release];
		tempDict = [[NSMutableDictionary dictionary] retain];

		//- since we can't be sure we'll get a status
		[tempDict setObject:[NSNumber numberWithInt:TiVoProgramNoStatus] forKey:@"status"];
		
		[currentProgram release], currentProgram = nil;
		[tempSeriesString release], tempSeriesString = nil;
		[tempStationString release], tempStationString = nil;

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
	//- see if we have a valid dictionary to work with
	//- this prevents seeing errors when parsing the first part of the XML
	if ( !tempDict ) return;
		
	//- check the element...
	if ( [elementName isEqualToString:CalypsoItemTag] ) {
		//- only add a new program if we have a dictionary with data in it
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
			[tempStationString release], tempStationString = nil;
		} else {
			tempStationString = [tempValueString retain];
		}

		
	} else if ( [elementName isEqualToString:CalypsoSourceFormatTag] ) {
		[tempDict setObject:tempValueString forKey:@"sourceFormat"];
				
	} else if ( [elementName isEqualToString:CalypsoContentTypeTag] ) {
		[tempDict setObject:tempValueString forKey:@"contentType"];
		
	} else if ( [elementName isEqualToString:CalypsoDurationTag] ) {
		[tempDict setObject:[NSNumber numberWithInt:[tempValueString integerValue] ] forKey:@"duration"];
		
	} else if ( [elementName isEqualToString:CalypsoCaptureDateTag] ) {
		unsigned int timestamp;
		[[NSScanner scannerWithString:tempValueString] scanHexInt:&timestamp]; 
		[tempDict setObject:[NSDate dateWithTimeIntervalSince1970:timestamp] forKey:@"captureDate"];
		
	} else if ( [elementName isEqualToString:CalypsoEpisodeTitleTag] ) {
		[tempDict setObject:tempValueString forKey:@"title"];
		
	} else if ( [elementName isEqualToString:CalypsoDescriptionTag] ) {
		[tempDict setObject:tempValueString forKey:@"programDescription"];
		
	} else if ( [elementName isEqualToString:CalypsoSourceStationTag] ) {
		if ( tempStationString ) {
			[tempDict
				setObject:[self
					stationWithName:tempValueString
					andChannel:[NSNumber numberWithInt:[tempStationString intValue]] ]
				forKey:@"station"
			];
			[tempStationString release], tempStationString = nil;
		} else {
			tempStationString = [tempValueString retain];
		}
		
	} else if ( [elementName isEqualToString:CalypsoSeriesIDTag] ) {
		if ( tempSeriesString ) {
			//- since we have a tempSeriesString, this is the second piece of info we need check for adding a new one
			[tempDict setObject:[self seriesWithIdentifier:tempValueString title:tempSeriesString] forKey:@"series"];
			[tempSeriesString release], tempSeriesString = nil;
		} else {
			//- since we don't have a tempSeriesString, then we'll save this info for later
			tempSeriesString = [tempValueString retain];
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
		[tempDict setObject:[NSNumber numberWithLongLong:[tempValueString longLongValue]] forKey:@"sourceSize"];

	} else if ( [elementName isEqualToString:CalypsoProgramIDTag] ) {
		[tempDict setObject:tempValueString forKey:@"programID"];

	} else if ( [elementName isEqualToString:CalypsoTitleTag] ) {
		if ( tempSeriesString ) {
			//- since we have a tempSeriesString, this is the second piece of info we need check for adding a new one
			[tempDict setObject:[self seriesWithIdentifier:tempSeriesString title:tempValueString] forKey:@"series"];
			[tempSeriesString release], tempSeriesString = nil;
		} else {
			//- since we don't have a tempSeriesString, then we'll save this info for later
			tempSeriesString = [tempValueString retain];
		}
		if ( [tempDict valueForKey:@"title"] == nil ) {
			//- since we don't already have a title, we'll use this title
			//- ...this may be wrong (some assumption about order here)
			[tempDict setObject:tempValueString forKey:@"title"];
		}

	} else if ( [elementName isEqualToString:CalypsoEpisodeNumberTag] ) {
		[tempDict setObject:tempValueString forKey:@"episodeNumber"];
		
	} else if ( [elementName isEqualToString:CalypsoCopyProtectedTag] ) {
		if ( [tempValueString isEqualToString:@"Yes"] ) {
			[tempDict setObject:[NSNumber numberWithBool:YES] forKey:@"copyProtected"];
		} else {
			[tempDict setObject:[NSNumber numberWithBool:NO] forKey:@"copyProtected"];
		}
		
	} else if ( [elementName isEqualToString:CalypsoUrlTag] ) {
		//- first, strip off the ID used internally by TiVo to track the show
		if ( !currentProgram ) {
			NSScanner *scanner = [NSScanner scannerWithString:tempValueString];
			[scanner scanUpToString:@"id=" intoString:NULL];
			[scanner scanString:@"id=" intoString:NULL];
			int tempID = 0;
			//- make sure we scanned and we got a good result
			if ( [scanner scanInt:&tempID] && tempID ) {
				if ( currentProgram = [[self programForInternalID:tempID] retain] ) {
					DEBUG( @"internalID (%d) found", tempID );
				}
				[tempDict setObject:[NSNumber numberWithInt:tempID] forKey:@"internalID"];
			}
		}
		//- second, check which URL we have and save it off
		if ( contentFlag ) {
			[tempDict setObject:tempValueString forKey:@"contentURL"];
		} else if ( videoDetailsFlag ) {
			[tempDict setObject:tempValueString forKey:@"videoDetailsURL"];
		} else if ( customIconFlag ) {	//- this is the image used to represent it
			//- don't know if this could change...
			if ( [tempValueString isEqualTo:@"urn:tivo:image:in-progress-recording"] ) {
				[tempDict setObject:[NSNumber numberWithInt:TiVoProgramInProgressStatus] forKey:@"status"];
			} else if ( [tempValueString isEqualTo:@"urn:tivo:image:expired-recording"] ) {
				[tempDict setObject:[NSNumber numberWithInt:TiVoProgramExpiredStatus] forKey:@"status"];
			} else if ( [tempValueString isEqualTo:@"urn:tivo:image:expires-soon-recording"] ) {
				[tempDict setObject:[NSNumber numberWithInt:TiVoProgramExpiresSoonStatus] forKey:@"status"];
			} else if ( [tempValueString isEqualTo:@"urn:tivo:image:save-until-i-delete-recording"] ) {
				[tempDict setObject:[NSNumber numberWithInt:TiVoProgramSaveStatus] forKey:@"status"];
			} else {
				[tempDict setObject:[NSNumber numberWithInt:TiVoProgramNoStatus] forKey:@"status"];
			}
			
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
	} else if ( [elementName isEqualToString:CalypsoLastChangeDateTag] ) {
		unsigned int timestamp;
		[[NSScanner scannerWithString:tempValueString] scanHexInt:&timestamp]; 
		player.dateLastUpdated = [NSDate dateWithTimeIntervalSince1970:timestamp];
	} else if ( [elementName isEqualToString:CalypsoInProgressTag] ) {
		if ( [tempValueString isEqualToString:@"Yes"] )
			[tempDict setObject:[NSNumber numberWithBool:YES] forKey:@"inProgress"];
		else
			[tempDict setObject:[NSNumber numberWithBool:NO] forKey:@"inProgress"];
	} else {
		WARNING( @"[parser:didEndElement:...] no match for elementName: %@", elementName );
	}
}

- (void)parserDidEndDocument:(NSXMLParser *)parser
{
	EXIT;
	[player release], player = nil;
	[managedObjectContext release], managedObjectContext = nil;
	[tempValueString release], tempValueString = nil;
}

- (void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError
{
	ERROR( [parseError description] );
	[tempValueString release], tempValueString = nil;
}


#pragma mark -
#pragma mark Entity helper methods

- (TiVoProgram *)programForInternalID:(int)internalID
{
	NSEntityDescription *entityDesc = [NSEntityDescription
		entityForName:TiVoProgramEntityName
		inManagedObjectContext:managedObjectContext
	];
	NSFetchRequest *request = [[[NSFetchRequest alloc] init] autorelease];
	
	[request setEntity:entityDesc];
	
	NSPredicate *predicate = [NSPredicate predicateWithFormat:
		@"internalID = %d", internalID
	];
	[request setPredicate:predicate];
	
	NSError *error;
	@synchronized (TiVoProgramEntityName) {
		if ( [managedObjectContext countForFetchRequest:request error:&error] > 0 ) {
			NSArray *tempArray = [managedObjectContext executeFetchRequest:request error:&error];
			if ( [tempArray count] > 1 ) {
				WARNING( @"Found %d matching internal IDs, will use the first one.", [tempArray count] );
			}
			[[tempArray objectAtIndex:0] setDeletedFromPlayer:[NSNumber numberWithBool:NO] ];
			return [tempArray objectAtIndex:0];
		} else {
			return nil;
		}
	}
	ERROR( @"shouldn't have gotten to this point!" );
	return NO;
}

- (NSManagedObject *)stationWithName:(NSString *)name andChannel:(NSNumber *)channel
{
	if ( nil==name || nil==channel ) NSLog ( @"bad!" );
	NSError *error;
	
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
	NSError *error;
	
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

- (void)dealloc
{
	[managedObjectContext release], managedObjectContext = nil;
	[xmlParser release], xmlParser = nil;

	[player release], player = nil;
	
	[tempValueString release], tempValueString = nil;
	[tempSeriesString release], tempSeriesString = nil;
	[tempStationString release], tempStationString = nil;
	
	[tempDict release], tempDict = nil;
	[super dealloc];
}

@end

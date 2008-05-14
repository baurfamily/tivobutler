//
//  WorkQueueFile.m
//  TiVo Butler
//
//  Created by Eric Baur on 5/8/08.
//  Copyright 2008 Eric Shore Baur. All rights reserved.
//

#import "WorkQueueFile.h"


@implementation WorkQueueFile

@dynamic extension;
@dynamic filename;
@dynamic path;
@dynamic readerStep;
@dynamic writerStep;

- (NSString *)filename
{
    NSString * tmpValue;
    
    [self willAccessValueForKey:@"path"];
    tmpValue = [self primitivePath];
    [self didAccessValueForKey:@"path"];
	
	if (!tmpValue) {
		return [[tmpValue pathComponents] lastObject];
	} else {
		NSMutableString *tempString = [NSMutableString string];
		
		NSUserDefaultsController *defaults = [NSUserDefaultsController sharedUserDefaultsController];
		NSString *filenamePattern = [[defaults valueForKey:@"values"] valueForKey:@"filenamePattern"];
		EntityTokenFieldValueTransformer *transformer = [[[EntityTokenFieldValueTransformer alloc] init] autorelease];
		NSArray *tokenArray = [transformer transformedValue:filenamePattern];
		
		id token;
		for ( token in tokenArray ) {
			if ( [token isKindOfClass:[EntityToken class]] ) {
				[tempString appendString:[token stringForProgram:[self valueForKeyPath:@"writerItem.program"]] ];
			} else if ( [token isKindOfClass:[NSString class]] ) {
				[tempString appendString:token];
			} else {
				WARNING( @"unexpected class when parsing filenamePattern: %@", [token className] );
			}
		}
		[tempString appendString:self.extension];
		
		RETURN( tempString );
		return [tempString copy];
	}	
}

- (NSString *)extension
{
	int action = [self.writerStep.actionType intValue];
	switch (action) {
		case WQDownloadAction:		return WQDownloadActionExtension;	break;
		case WQDecodeAction:		return WQDecodeActionExtension;		break;
		case WQConvertAction:		return WQConvertActionExtension;	break;
		case WQPostProcessAction:	return nil;							break;
	}
	return @"";
}

- (NSString *)path 
{
    NSString * tmpValue;
    
    [self willAccessValueForKey:@"path"];
    tmpValue = [self primitivePath];
    [self didAccessValueForKey:@"path"];
	
	if (!tmpValue) {
		return tmpValue;
	} else {
		NSUserDefaultsController *defaults = [NSUserDefaultsController sharedUserDefaultsController];
		BOOL useIntermediateFolder = [[[defaults valueForKey:@"values"] valueForKey:@"useIntermediateFolder"] boolValue];
		
		NSString *tempDirectory;
		if ( self.writerStep ) {
			if ( useIntermediateFolder ) {
				tempDirectory = [[[defaults valueForKey:@"values"] valueForKey:@"intermediateFolder"] stringByExpandingTildeInPath];
			} else {
				tempDirectory = NSTemporaryDirectory();
			}
		} else {
			tempDirectory = [[defaults valueForKey:@"values"] valueForKey:@"downloadFolder"]; 
		}
		tmpValue = [NSString pathWithComponents:[NSArray arrayWithObjects:tempDirectory, self.filename, nil] ];
		
		[self willChangeValueForKey:@"path"];
		[self setPrimitivePath:tmpValue];
		[self didChangeValueForKey:@"path"];
	}
	
	if ( [self checkAndCreateDirectories] ) {
		RETURN( tmpValue );
		return tmpValue;	
	} else {
		ERROR( @"Could not create intermediate paths to: %@", tmpValue );
		return nil;
	}
}

- (BOOL)checkAndCreateDirectories
{
	NSUserDefaultsController *defaults = [NSUserDefaultsController sharedUserDefaultsController];
	NSString *fullPath = self.path;
	
	BOOL hitError = NO;
	BOOL isDirectory;
	
	BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:fullPath isDirectory:&isDirectory];
	if ( !exists ) {		
		NSError *error;
		BOOL succeeded = [[NSFileManager defaultManager]
						  createDirectoryAtPath:fullPath
						  withIntermediateDirectories:YES
						  attributes:nil
						  error:&error
						  ];
		if ( !succeeded ) {
			ERROR( @"could not create directory: %@ (%@)", fullPath, [error localizedDescription] );
			hitError = YES;
		}
	} else if ( !isDirectory ) {
		ERROR( @"can't save to '%@', not a directory (will try to use base path)", fullPath );
		hitError = YES;
	}

	NSFileManager *fileManager = [NSFileManager defaultManager];
	
	if ( [fileManager fileExistsAtPath:[fullPath stringByAppendingString:@".tivo"] ]
		|| [fileManager fileExistsAtPath:[fullPath stringByAppendingString:@".mpg"] ]
		|| [fileManager fileExistsAtPath:[fullPath stringByAppendingString:@".mp4"] ]
		) {
		WQFileExistsAction fileExistsAction = [[[defaults valueForKey:@"values"] valueForKey:@"fileExistsAction"] intValue];
		
		int i = 0;
		NSString *testPath = [fullPath copy];
		
		switch ( fileExistsAction ) {
			case WQFileExistsFailAction:
				fullPath = nil;
				break;
			case WQFileExistsOverwriteAction:
				//- existing path string is fine
				break;
			case WQFileExistsChangeNameAction:
				//default:
				while ( [fileManager fileExistsAtPath:[fullPath stringByAppendingString:@".tivo"] ]
					   || [fileManager fileExistsAtPath:[fullPath stringByAppendingString:@".mpg"] ]
					   || [fileManager fileExistsAtPath:[fullPath stringByAppendingString:@".mp4"] ]
					   ) {
					i++;
					fullPath = [testPath stringByAppendingFormat:@"-%d", i];
				}
				break;
		}
	}
	// this doesn't actually work, but we'll return YES anyway
	return YES;	
}

- (void)removeFile
{
	if ( self.path )
		[[NSFileManager defaultManager] removeItemAtPath:self.path error:NULL];
}

@end

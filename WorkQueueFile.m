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
	
	if (tmpValue) {
		return [[tmpValue pathComponents] lastObject];
	} else {
		NSMutableString *tempString = [NSMutableString string];
		
		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		NSString *filenamePattern = [defaults valueForKey:@"filenamePattern"];
		EntityTokenFieldValueTransformer *transformer = [[[EntityTokenFieldValueTransformer alloc] init] autorelease];
		NSArray *tokenArray = [transformer transformedValue:filenamePattern];
		
		id token;
		for ( token in tokenArray ) {
			if ( [token isKindOfClass:[EntityToken class]] ) {
				[tempString appendString:[token stringForProgram:[self valueForKeyPath:@"writerStep.item.program"]] ];
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
	
	if (tmpValue) {
		return tmpValue;
	} else {
		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		BOOL useIntermediateFolder = [[defaults valueForKey:@"useIntermediateFolder"] boolValue];
		
		NSString *tempDirectory;
		if ( self.writerStep ) {
			if ( useIntermediateFolder ) {
				tempDirectory = [[defaults valueForKey:@"intermediateFolder"] stringByExpandingTildeInPath];
			} else {
				tempDirectory = NSTemporaryDirectory();
			}
		} else {
			tempDirectory = [defaults valueForKey:@"downloadFolder"]; 
		}
		tmpValue = [NSString pathWithComponents:[NSArray arrayWithObjects:tempDirectory, self.filename, nil] ];
		
		[self willChangeValueForKey:@"path"];
		[self setPrimitivePath:tmpValue];
		[self didChangeValueForKey:@"path"];
	}
	
	if ( [self checkAndCreateDirectories] ) {
		//- check it again, just in case it changed
		[self willAccessValueForKey:@"path"];
		tmpValue = [self primitivePath];
		[self didAccessValueForKey:@"path"];
		
		RETURN( tmpValue );
		return tmpValue;
	} else {
		ERROR( @"Could not create intermediate paths to: %@", tmpValue );
		return nil;
	}
}

- (BOOL)checkAndCreateDirectories
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	WQFileExistsAction fileExistsAction = [[defaults valueForKey:@"fileExistsAction"] intValue];
	
    [self willAccessValueForKey:@"path"];
	NSString *fullPath = [self primitivePath];
    [self didAccessValueForKey:@"path"];

	NSString *directoryPath = [fullPath stringByDeletingLastPathComponent];
	
	BOOL hitError = NO;
	BOOL isDirectory;
	
	BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:directoryPath isDirectory:&isDirectory];
	if ( !exists ) {		
		NSError *error;
		BOOL succeeded =
			[[NSFileManager defaultManager]
				createDirectoryAtPath:directoryPath
				withIntermediateDirectories:YES
				attributes:nil
				error:&error
			 ];
		if ( !succeeded ) {
			ERROR( @"could not create directory: %@ (%@)", directoryPath, [error localizedDescription] );
			hitError = YES;
		}
	} else if ( !isDirectory ) {
		ERROR( @"can't save to '%@', not a directory (will try to use base path)", directoryPath );
		hitError = YES;
	}

	NSFileManager *fileManager = [NSFileManager defaultManager];
	
	if ( [fileManager fileExistsAtPath:fullPath] ) {
		int i = 0;
		NSString *testPath = [fullPath copy];
		
		switch ( fileExistsAction ) {
			case WQFileExistsFailAction:
				self.path = nil;	// this may cause problems...
				hitError = YES;
				break;
			case WQFileExistsOverwriteAction:
				//- existing path string is fine
				break;
			case WQFileExistsChangeNameAction:
				while ( [fileManager fileExistsAtPath:testPath]) {
					testPath =
						[NSString stringWithFormat:@"%@ %d.%@",
							[fullPath stringByDeletingPathExtension],
							++i,
							[fullPath pathExtension],
							nil
						 ];
				}
				self.path = testPath;
				break;
		}
	}
	return !hitError;	
}

- (void)removeFile
{
	if ( self.path )
		[[NSFileManager defaultManager] removeItemAtPath:self.path error:NULL];
}

@end

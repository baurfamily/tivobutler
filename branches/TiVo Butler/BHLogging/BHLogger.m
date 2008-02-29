//
//  BHLogger.m
//  BHLogger
//
//  Created by Eric Baur on 6/13/06.
//  Copyright 2006 Eric Shore Baur. All rights reserved.
//

#import "BHLogger.h"

@implementation BHLogger

static id logProxy;
static NSString *guid;

static int textLoggingMask = ( BHLoggerError | BHLoggerWarning );

static int threadNum = 1;

+ (void)initialize
{
	guid = [[[NSProcessInfo processInfo] globallyUniqueString] retain];
	NSLog( @"Initializing BHLogger with guid: %@", guid );

	NSConnection *connection;
	
	NSLog( @"checking for local proxy" );
	connection = [NSConnection connectionWithRegisteredName:@"BHLogger" host:nil];

	if (connection) {
		logProxy = [[connection rootProxy] retain];
		[logProxy setProtocolForProxy:@protocol(BHLogging)];
	} else {
		logProxy = nil;
	}
	
	[[NSUserDefaults standardUserDefaults] registerDefaults:
				[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:1] forKey:@"BHLoggerLevel"]
	];
	textLoggingMask = [[NSUserDefaults standardUserDefaults] integerForKey:@"BHLoggerMask"];
}


+ (void)log:(NSString *)text forObject:(id)sender  method:(SEL)selector filename:(const char *)file lineNumber:(int)line as:(int)logLevel
{
	NSThread *thread = [NSThread currentThread];
	if ( ![thread name] ) {
		if ( [thread isMainThread] ) {
			[thread setName:@"main"];
		} else {
			[thread setName:[NSString stringWithFormat:@"%d", threadNum] ];
			threadNum++;
		}
	}
	if ( !text )
		text = @"";
		
	if (logProxy) {
		@try {
			[logProxy logDetails:[NSDictionary dictionaryWithObjectsAndKeys:
					[NSDate date],												@"entrytime",
					text,														@"information",
					[NSNumber numberWithInt:logLevel],							@"level",
					[thread name],												@"thread",
					[sender className],											@"classname",
					guid,														@"guid",
					[NSNumber numberWithInt:
						[[NSProcessInfo processInfo] processIdentifier] ],		@"processid",
					[[NSProcessInfo processInfo] processName],					@"name",
					[[NSProcessInfo processInfo] hostName],						@"hostname",
					[[NSProcessInfo processInfo] operatingSystemVersionString],	@"osversion",
					[NSString stringWithCString:file],							@"filename",
					[NSNumber numberWithInt:line],								@"lineNumber",
					NSStringFromSelector(selector),								@"method",
					nil
				]
			];
		}
		@catch (NSException *e) {
			NSLog( @"caught exception in logging method: %@", [e description] );
			logProxy = nil;
		}
	} else if ( logLevel & textLoggingMask ) {
		NSLog( @"[%@] %@ -%@- %@",
			[thread name],
			stringForLevel(logLevel),
			[sender className],
			text
		);
	}
}

NSString* stringForLevel( int logLevel )
{
	switch (logLevel) {
		case BHLoggerError:		return BHLoggerErrorString;		break;
		case BHLoggerWarning:	return BHLoggerWarningString;	break;
		case BHLoggerDebug:		return BHLoggerDebugString;		break;
		case BHLoggerInfo:		return BHLoggerInfoString;		break;
		case BHLoggerEntry:		return BHLoggerEntryString;		break;
		case BHLoggerExit:		return BHLoggerExitString;		break;
		default:				return @"n/a";
	}
	return nil;
}

/*
+ (void)logObject:(id)sender atLevel:(int)logLevel withFormat:(id)format, ...
{
	va_list argList;
	va_start( argList, format );
	[BHLogger
		log:(NSString *)CFStringCreateWithFormatAndArguments( NULL, NULL, (CFStringRef)format, argList )
		forObject:sender
		at:logLevel
	];
	va_end( argList );
}
*/
@end

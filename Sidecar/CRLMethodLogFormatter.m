// Sidecar
// Copyright (c) 2014, Crush & Lovely <engineering@crushlovely.com>
// Under the MIT License; see LICENSE file for details.

#import "CRLMethodLogFormatter.h"
#if __has_include("CocoaLumberjack.h")
#import <CocoaLumberjack/CocoaLumberjack.h>
#else
#import <CocoaLumberjack/DDLog.h>
#endif
#import <libkern/OSAtomic.h>

static NSString * const CRLMethodLogFormatterCalendarKey = @"CRLMethodLogFormatterCalendarKey";
static const NSCalendarUnit CRLMethodLogFormatterCalendarUnitFlags = NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay | NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond;


@interface CRLMethodLogFormatter () {
    int32_t atomicLoggerCount;
    NSCalendar *threadUnsafeCalendar;
}

@end


@implementation CRLMethodLogFormatter

-(NSCalendar *)threadsafeCalendar
{
    int32_t loggerCount = OSAtomicAdd32(0, &atomicLoggerCount);

    if (loggerCount <= 1) {
        // Single-threaded
        if(!threadUnsafeCalendar) threadUnsafeCalendar = [NSCalendar autoupdatingCurrentCalendar];
        return threadUnsafeCalendar;
    }
    else {
        // Multi-threaded. Use the thread-local instance
        NSMutableDictionary *threadDictionary = [[NSThread currentThread] threadDictionary];
        NSCalendar *threadCalendar = [threadDictionary objectForKey:CRLMethodLogFormatterCalendarKey];

        if(!threadCalendar) {
            threadCalendar = [NSCalendar autoupdatingCurrentCalendar];
            [threadDictionary setObject:threadCalendar forKey:CRLMethodLogFormatterCalendarKey];
        }

        return threadCalendar;
    }
}

-(NSString *)formatLogMessage:(DDLogMessage *)logMessage
{
    // Time calculation is ripped from DDTTYLogger

    NSDateComponents *components = [[self threadsafeCalendar] components:CRLMethodLogFormatterCalendarUnitFlags
                                                                fromDate:logMessage.timestamp];

    NSTimeInterval epoch = [logMessage.timestamp timeIntervalSinceReferenceDate];
    int milliseconds = (int)((epoch - floor(epoch)) * 1000);

    NSString *formattedMsg = [NSString stringWithFormat:@"%04ld-%02ld-%02ld %02ld:%02ld:%02ld:%03d [%@] %@:%lu (%@): %@",
                              (long)components.year,
                              (long)components.month,
                              (long)components.day,
                              (long)components.hour,
                              (long)components.minute,
                              (long)components.second,
                              milliseconds,
                              [self CRLLogFlagToString:logMessage.flag],
                              [logMessage.file lastPathComponent],
                              (unsigned long)logMessage.line,
                              logMessage.function,
                              logMessage.message];

    return formattedMsg;
}

-(void)didAddToLogger:(id<DDLogger> __unused)logger
{
    OSAtomicIncrement32(&atomicLoggerCount);
}

-(void)willRemoveFromLogger:(id<DDLogger> __unused)logger
{
    OSAtomicDecrement32(&atomicLoggerCount);
}

-(NSString*)CRLLogFlagToString:(DDLogFlag)logFlag
{
    switch(logFlag) {
        case LOG_FLAG_ERROR: return @"ERR";
        case LOG_FLAG_WARN: return @"WRN";
        case LOG_FLAG_INFO: return @"INF";
        case LOG_FLAG_DEBUG: return @"DBG";
        case LOG_FLAG_VERBOSE: return @"VRB";
            
        default: return @"";
    }
}

@end

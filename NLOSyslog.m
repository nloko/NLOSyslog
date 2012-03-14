//
//  NLOSyslog.m
//
//  Created by Neil Loknath on 12-03-13.
//  Copyright (c) 2012 Neil Loknath. All rights reserved.
//
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

#import "NLOSyslog.h"

@interface NLOSyslog()

-(char*)seconds;
-(id)objectForFormattedLogEntry:(id)data;
-(id)objectForLogEntry:(id)data;
-(void)setStringFilter:(NSString*)filter 
                forKey:(char*)key
           withOptions:(uint32_t)options 
               onQuery:(aslmsg)query;

-(NSArray*)pullLogUsingEntrySelector:(SEL)selector;

@property (retain, nonatomic) NSString* senderFilter;
@property (retain, nonatomic) NSString* messageFilter;

@end

@implementation NLOSyslog

@synthesize senderFilter    = _senderFilter;
@synthesize messageFilter   = _messageFilter;

#pragma mark -
#pragma mark Public Interface

/**
 * Returns object without any filtering criteria
 */
+(id)syslog {
    return [[[self alloc] init] autorelease];
}

-(void)dealloc {
    self.senderFilter = nil;
    self.messageFilter = nil;
    
    [super dealloc];
}

/**
 * Add a filter to retrieve messages between now and the 
 * specified number of seconds from now
 *
 * @param seconds The number of seconds from the current time
 * @return self
 */
-(id)filterSecondsFromNow:(NSTimeInterval)seconds {        
    _seconds = MAX(0, seconds);
    return self;
}

/**
 * Set filter for the specified sender
 *
 * @param sender A substring of the message sender
 * @return self
 */
-(id)filterForSendersContainingString:(NSString *)sender {
    if ([sender length] == 0) {
        self.senderFilter = nil;
        return self;
    }
    
    self.senderFilter = sender;
    return self;
}

/**
 * Set filter for the specified message
 *
 * @param A substring of the message
 * @return self
 */
-(id)filterForMessagesContainingString:(NSString *)message {
    if ([message length] == 0) {
        self.messageFilter = nil;
        return self;
    }
    
    self.messageFilter = message;
    return self;
}

/**
 * Get raw log asynchronously and send it to the specified block
 * as an NSArray of NSDictionary objects
 * 
 * The block is execute on the main thread
 */
-(void)sendRawLogToBlock:(void(^)(NSArray*))result {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        id log = [self rawLog];
        dispatch_sync(dispatch_get_main_queue(), ^{ result(log); });
    });
}

/**
 * Returns an array of NSDictionary objects containing all available
 * filtered log message data
 *
 * @return NSArray of NSDictionary objects
 */
-(NSArray*)rawLog {
    return [self pullLogUsingEntrySelector:@selector(objectForLogEntry:)];
}

/**
 * Get formatted log asynchronously and send it to the specified block
 * as an NSArray of NSString objects
 * 
 * The block is execute on the main thread
 */
-(void)sendFormattedLogToBlock:(void(^)(NSArray*))result {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        id log = [self formattedLog];
        dispatch_sync(dispatch_get_main_queue(), ^{ result(log); });
    });
}

/**
 * Returns an array of NSString objects containing filtered log message 
 * data in the following format:
 * date time sender[pid]: msg
 *
 * @return NSArray of NSDictionary objects
 */
-(NSArray*)formattedLog {
    return [self pullLogUsingEntrySelector:@selector(objectForFormattedLogEntry:)];
}

#pragma mark -
#pragma mark Private Interface

-(char*)seconds {
    return (char*)[[NSString stringWithFormat:@"%.0f", 
                    [[NSDate dateWithTimeIntervalSinceNow:-_seconds] timeIntervalSince1970]] 
                   cStringUsingEncoding:NSUTF8StringEncoding];
}

-(id)objectForLogEntry:(id)data {
    return data;
}

-(id)objectForFormattedLogEntry:(id)data {
    NSString * const msg = @"%@ %@[%@]: %@";
    NSString * const timeKey = [NSString stringWithFormat:@"%s", ASL_KEY_TIME];
    NSString * const senderKey = [NSString stringWithFormat:@"%s", ASL_KEY_SENDER];
    NSString * const pidKey = [NSString stringWithFormat:@"%s", ASL_KEY_PID];
    NSString * const messageKey = [NSString stringWithFormat:@"%s", ASL_KEY_MSG];
    
    NSDate* entryTime = [NSDate dateWithTimeIntervalSince1970:[[data objectForKey:timeKey] doubleValue]];
    NSString* logEntry = [NSString stringWithFormat:msg, [NSDateFormatter localizedStringFromDate:entryTime 
                                              dateStyle:NSDateFormatterMediumStyle 
                                              timeStyle:NSDateFormatterLongStyle],
          [data objectForKey:senderKey],
          [data objectForKey:pidKey],
          [data objectForKey:messageKey]];
    
    return logEntry;
}

-(void)setStringFilter:(NSString*)filter 
                forKey:(char*)key
           withOptions:(uint32_t)options 
               onQuery:(aslmsg)query {
    
    if (!filter) return;
    
    asl_set_query(query, 
                  key, 
                  [filter UTF8String], 
                  options);
}

-(NSArray*)pullLogUsingEntrySelector:(SEL)selector {
    aslmsg msg;
    const char* key, *value;
    
    NSMutableArray* logEntries = [NSMutableArray array];
    
    aslmsg query = asl_new(ASL_TYPE_QUERY);

    if (_seconds >  0) {
        asl_set_query(query, 
                      ASL_KEY_TIME, 
                      [self seconds], 
                      ASL_QUERY_OP_GREATER);
    }
    
    [self setStringFilter:self.senderFilter 
                   forKey:ASL_KEY_SENDER 
              withOptions:ASL_QUERY_OP_EQUAL | ASL_QUERY_OP_SUBSTRING 
                  onQuery:query];
    
    [self setStringFilter:self.messageFilter 
                   forKey:ASL_KEY_MSG 
              withOptions:ASL_QUERY_OP_EQUAL | ASL_QUERY_OP_SUBSTRING 
                  onQuery:query];
    
    aslresponse response = asl_search(NULL, query);
    
    while (NULL != (msg = aslresponse_next(response))) {
        NSMutableDictionary *logEntry = [[NSMutableDictionary alloc] init];
        
        for (int i = 0; (NULL != (key = asl_key(msg, i))); i++) {            
            value = asl_get(msg, key);
            
            [logEntry setObject:[NSString stringWithUTF8String:value] 
                         forKey:[NSString stringWithUTF8String:(char *)key]];
        }
        
        [logEntries addObject:[self performSelector:selector withObject:logEntry]];  
        [logEntry release];
    }
    
    aslresponse_free(response);  
    asl_free(query);

    return logEntries;
}

@end

//
//  NLOSyslog.h
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

#import <Foundation/Foundation.h>
#include <asl.h>

@interface NLOSyslog : NSObject {
 @private
    NSTimeInterval _seconds;
    NSString* _senderFilter;
    NSString* _messageFilter;
    
    NSString* _timeKey;
    NSString* _senderKey;
    NSString* _messageKey;
    NSString* _pidKey;
}

+(id)syslog;

-(id)filterSecondsFromNow:(NSTimeInterval)seconds;
-(id)filterForSendersContainingString:(NSString*)sender;
-(id)filterForMessagesContainingString:(NSString*)message;

-(NSArray*)rawLog;
-(void)sendRawLogToBlock:(void(^)(NSArray*))result;
-(NSArray*)formattedLog;
-(void)sendFormattedLogToBlock:(void(^)(NSArray*))result;

@end

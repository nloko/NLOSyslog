NLOSyslog
=========

Summary
-------

NLOSyslog is an Objective-C wrapper around the asl (Apple System
Log) inteface.

It provides a simple means to search the system log. 

The NLOSyslog class is fairly straightforward and well-documented. Blocking
and non-blocking log retrieval methods are provided.

Filtering
---------

The following filter criteria is available:

| Filter  | Description                      |
| ------- | -------------------------------- |
| Time 	  | x number of seconds back in time |
| Sender  | a substring of a sender          |
| Message | a substring of a message         |

Criteria is combined using logical AND

Example Usage
-------------

    // Filter for messages logged in the past hour
    // containing 'SpringBoard' in the sender text
    // and 'wallpaper' in the message text
    //
    // Get the log asynchronously and provide a block
    // as a callback for the results

    [[[[[NLOSyslog syslog] 
                        filterSecondsFromNow:60 * 60] 
                       filterForSendersContainingString:@"SpringBoard"] 
                      filterForMessagesContainingString:@"wallpaper"] 
     sendRawLogToBlock:^(NSArray* log) {
         for (id entry in log) {
             NSLog(@"%@", entry);
         }
     }];

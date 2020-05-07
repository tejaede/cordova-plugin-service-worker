//
//  CDVSWURLSchemeHandler.h
//  DisasterAlert
//
//  Created by Thomas Jaede on 4/22/20.
//

#import <Webkit/WKURLSchemeHandler.h>
#import "CDVSWRequestQueueProtocol.h"

@interface CDVSWURLSchemeHandler : NSObject <WKURLSchemeHandler>

@property (strong, nonatomic) id <CDVSWRequestQueueProtocol> queueHandler;

- (void) sendRequestWithId: (NSString *) requestId;
- (void) completeTaskWithId: (NSNumber *) taskId response: (NSURLResponse *) response data: (NSData *) data error: (NSError *) error;

@end

#ifndef CDVSWURLSchemeHandler_h
#define CDVSWURLSchemeHandler_h


#endif /* CDVSWURLSchemeHandler_h */

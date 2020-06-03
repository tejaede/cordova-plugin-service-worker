//
//  CDVSWURLSchemeHandler.h
//  DisasterAlert
//
//  Created by Thomas Jaede on 4/22/20.
//

#import <Webkit/WKURLSchemeHandler.h>
#import "CDVSWRequestQueueProtocol.h"
#import "CDVSWURLSchemeHandlerDelegate.h"



@interface CDVSWURLSchemeHandler : NSObject <WKURLSchemeHandler>

@property (strong, nonatomic) id <CDVSWRequestQueueProtocol> queueHandler; // TODO Queue handler replaced by another delegate? Merged into queue delegate?
@property (strong, nonatomic) id <CDVSWURLSchemeHandlerDelegate> delegate;

@property (strong, nonatomic) NSMutableDictionary *tasks;
@property (strong, nonatomic) NSMutableDictionary *requests;

- (void) sendRequestWithId: (NSString *) requestId;
- (void) completeTaskWithId: (NSNumber *) taskId response: (NSHTTPURLResponse *) response data: (NSData *) data error: (NSError *) error;

@end

#ifndef CDVSWURLSchemeHandler_h
#define CDVSWURLSchemeHandler_h


#endif /* CDVSWURLSchemeHandler_h */

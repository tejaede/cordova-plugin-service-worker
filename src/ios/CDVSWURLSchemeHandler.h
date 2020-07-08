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

@property (nonatomic, retain) NSString * allowedOrigin;
@property (nonatomic, retain) NSString * scheme;
@property (readonly) NSURLSession* session;

- (void) sendRequestWithId: (NSNumber *) requestId;
- (void) completeTaskWithId: (NSNumber *) taskId response: (NSHTTPURLResponse *) response data: (NSData *) data error: (NSError *) error;

@end

#ifndef CDVSWURLSchemeHandler_h
#define CDVSWURLSchemeHandler_h


#endif /* CDVSWURLSchemeHandler_h */

//
//  CDVSWURLSchemeHandlerDelegate.h
//  DisasterAlert
//
//  Created by Thomas Jaede on 5/22/20.
//

#import <Foundation/Foundation.h>
#import "ServiceWorkerResponse.h"

NS_ASSUME_NONNULL_BEGIN

@protocol CDVSWURLSchemeHandlerDelegate <NSObject>

- (void)urlSchemeHandlerDidReceiveResponse: (NSHTTPURLResponse *) response withData: (NSData *) data forRequest: (NSURLRequest *) request;
- (ServiceWorkerResponse *)urlSchemeHandlerWillSendRequest: (NSURLRequest *) request;


@end

NS_ASSUME_NONNULL_END

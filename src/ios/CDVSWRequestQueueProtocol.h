//
//  CDVSWRequestQueueProtocol.h
//  DisasterAlert
//
//  Created by Thomas Jaede on 5/5/20.
//

#import <Foundation/Foundation.h>
#import "ServiceWorkerRequest.h"

NS_ASSUME_NONNULL_BEGIN

@protocol CDVSWRequestQueueProtocol <NSObject>

- (Boolean)addRequestToQueue:(ServiceWorkerRequest *)request;
- (Boolean)canAddToQueue;

@end

NS_ASSUME_NONNULL_END

/*
 Licensed to the Apache Software Foundation (ASF) under one
 or more contributor license agreements.  See the NOTICE file
 distributed with this work for additional information
 regarding copyright ownership.  The ASF licenses this file
 to you under the Apache License, Version 2.0 (the
 "License"); you may not use this file except in compliance
 with the License.  You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing,
 software distributed under the License is distributed on an
 "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 KIND, either express or implied.  See the License for the
 specific language governing permissions and limitations
 under the License.
 */

#import "FetchInterceptorProtocol.h"
#import "CDVServiceWorker.h"
#import "FetchConnectionDelegate.h"
#import "ServiceWorkerResponse.h"

#include <libkern/OSAtomic.h>

@implementation FetchInterceptorProtocol
@synthesize connection=_connection;

@synthesize serviceWorkerResponse = _serviceWorkerResponse;
@synthesize responseData = _responseData;

static int64_t requestCount = 0;

+ (BOOL)canInitWithRequest:(NSURLRequest *)request {
    // We don't want to intercept any requests for the worker page.
    
//    if ([[[request URL] absoluteString] hasSuffix:@"sw.html"]) {
//        return NO;
//    }
    
    

    // Check - is there a service worker for this request?
    // For now, assume YES -- all requests go through service worker. This may be incorrect if there are iframes present.
    if ([NSURLProtocol propertyForKey:@"PassThrough" inRequest:request]) {
        NSLog(@"PassThrough URL %@",   [[request URL] absoluteString]);
        // Already seen; not handling
        return NO;
    }
    NSLog(@"canInitWIthRequest - %@", [[request URL] absoluteString]);
//else if ([NSURLProtocol propertyForKey:@"PureFetch" inRequest:request]) {
//        // Fetching directly; bypass ServiceWorker.
//        return NO;
//    } else if ([request valueForHTTPHeaderField:@"x-import-scripts"] != nil){
//        NSLog(@"Import Script %@",   [[request URL] absoluteString]);
//        return NO;
//    } else if ([CDVServiceWorker instanceForRequest:request]) {
//        NSLog(@"FetchInterceptor.handleURL %@",   [[request URL] absoluteString]);
//        // Handling
//        return YES;
//    } else {
//        // No Service Worker installed; not handling
//        return NO;
//    }
    return YES;
}
//
+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request {
    return request;
}
//
+ (BOOL)requestIsCacheEquivalent:(NSURLRequest *)a toRequest:(NSURLRequest *)b {
    return [super requestIsCacheEquivalent:a toRequest:b];
}

- (void)startLoading {
    // Attach a reference to the Service Worker to a copy of the request
//    NSMutableURLRequest *workerRequest = [self.request mutableCopy];
//    CDVServiceWorker *instanceForRequest = [CDVServiceWorker instanceForRequest:workerRequest];
//    [NSURLProtocol setProperty:instanceForRequest forKey:@"ServiceWorkerPlugin" inRequest:workerRequest];
//    NSNumber *requestId = [NSNumber numberWithLongLong:OSAtomicIncrement64(&requestCount)];
//    [NSURLProtocol setProperty:requestId forKey:@"RequestId" inRequest:workerRequest];
    NSLog(@"startLoading %@", [[self.request URL] absoluteString]);
    CDVServiceWorker *sw = [CDVServiceWorker instanceForRequest:nil];
    _serviceWorkerResponse = [[sw cacheApi] matchRequest:[self.connection originalRequest] inCache:nil];
    if (_serviceWorkerResponse != nil) {
        NSLog(@"Found Response %@", [[self.request URL] absoluteString]);
    } else {
        NSLog(@"No Cached Response %@", [[self.request URL] absoluteString]);
    }
    
//    if ([[[workerRequest URL] absoluteString] hasSuffix:@"sw.js"] || [[[workerRequest URL] absoluteString] containsString:@"/sw_assets/"]) {
        NSMutableURLRequest *taggedRequest = [self.request mutableCopy];
        [NSURLProtocol setProperty:@YES forKey:@"PassThrough" inRequest:taggedRequest];
        self.connection = [NSURLConnection connectionWithRequest:taggedRequest delegate:self];
//    } else {
//        [instanceForRequest addRequestToQueue:workerRequest withId:requestId delegateTo:self];
//    }
}
//
- (void)stopLoading {
    [self.connection cancel];
    self.connection = nil;
}

//- (void)passThrough {
//    // Flag this request as a pass-through so that the URLProtocol doesn't try to grab it again
//    NSMutableURLRequest *taggedRequest = [self.request mutableCopy];
//    [NSURLProtocol setProperty:@YES forKey:@"PassThrough" inRequest:taggedRequest];
//
//    // Initiate a new request to actually retrieve the resource
//    self.connection = [NSURLConnection connectionWithRequest:taggedRequest delegate:self];
//}

- (void)sendResponseWithResponseCode:(NSInteger)statusCode data:(NSData*)data mimeType:(NSString*)mimeType {
    NSLog(@"sendResponseWithResponseCode - %ld %@", (long)statusCode, mimeType);
}

- (void)handleAResponse:(NSURLResponse *)response withSomeData:(NSData *)data {
    // TODO: Move cache storage policy into args
    [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageAllowed];
    [self.client URLProtocol:self didLoadData:data];
    [self.client URLProtocolDidFinishLoading:self];
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    NSLog(@"FetchInterceptorProtocol.didReceiveResponse %@",   [[response URL] absoluteString]);
    if (_serviceWorkerResponse == nil) {
        _serviceWorkerResponse = [ServiceWorkerResponse new];
        _serviceWorkerResponse.status = @200;
        _serviceWorkerResponse.headers = nil;
    }
     self.responseData = [[NSMutableData alloc] init];

    [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageAllowed];
    if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
        NSDictionary *allHeaders = [(NSHTTPURLResponse*)response allHeaderFields];
        [allHeaders enumerateKeysAndObjectsUsingBlock:^(NSString *key, id value, BOOL* stop) {
            if([value isKindOfClass:[NSArray class]]){
                value = [value objectAtIndex:0];
            }
//            NSLog(@"%@ : %@", key, value);
        }];
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    [self.responseData appendData: data];
    [self.client URLProtocol:self didLoadData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    CDVServiceWorker *sw = [CDVServiceWorker instanceForRequest:nil];
    _serviceWorkerResponse.body = self.responseData;
    [[sw cacheApi] putRequest:[connection currentRequest] andResponse:_serviceWorkerResponse inCache:nil];
    [self.client URLProtocolDidFinishLoading:self];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    NSLog(@"FetchInterceptorProtocol.didFailWithError %@",   [[[connection originalRequest] URL] absoluteString]);
    [self.client URLProtocol:self didFailWithError:error];
}

@end


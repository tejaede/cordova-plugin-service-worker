//
//  CDVSWURLSchemeHandler.m
//  DisasterAlert
//
//  Created by Thomas Jaede on 4/22/20.
//

#import <Foundation/Foundation.h>
#import <WebKit/WKURLSchemeTask.h>
#import "CDVSWURLSchemeHandler.h"
#import "CDVReachability.h"

#include <libkern/OSAtomic.h>
#include <stdatomic.h>


@implementation CDVSWURLSchemeHandler {}

@synthesize queueHandler = _queueHandler;
@synthesize delegate = _delegate;
@synthesize scheme = _scheme;
@synthesize session = _session;
@synthesize allowedOrigin = _allowedOrigin;


NSSet *_urlsToDebug;
- (NSSet *) _urlsToDebug {
    if (_urlsToDebug == nil) {
        _urlsToDebug = [[NSSet alloc] initWithArray:@[
        ]];
    }
    return _urlsToDebug;
}

- (BOOL) shouldDebugURL: (NSURL *) url {
    NSString *urlString = [url absoluteString];
    return [self shouldDebugURLString: urlString];
}

- (BOOL) shouldDebugURLString: (NSString *) urlString {
    BOOL found = [[self _urlsToDebug] count] == 0;
    NSString *testString;
    for (testString in [self _urlsToDebug]) {
        found = found || [urlString containsString:testString];
    }
    return found;
}


- (NSURLSession *) session {
    if (_session == nil) {
        _session = [NSURLSession sharedSession];
    }
    return _session;
}

- (void)webView:(WKWebView *)webView startURLSchemeTask:(id <WKURLSchemeTask>)urlSchemeTask
{
    #ifdef DEBUG_SCHEME_HANDLER
    if ([self shouldDebugURL:[[urlSchemeTask request] URL]]) {
        NSLog(@"Handle Schemed URL - %@ %@ %@", (_queueHandler != nil ? @"MAIN" : @"SW"), [[urlSchemeTask request] HTTPMethod],  [[[urlSchemeTask request] URL] absoluteString]);
    }
    #endif
    ServiceWorkerRequest *swRequest = [ServiceWorkerRequest requestWithURLSchemeTask: urlSchemeTask];
    if (_queueHandler != nil && [_queueHandler canAddToQueue]) {
        [_queueHandler addRequestToQueue: swRequest];
    } else {
        [self sendSWRequest: swRequest];
    }
}

- (BOOL) completeUrlTaskIfResponseIsCached: (NSURLRequest *) request forTask: (id <WKURLSchemeTask>) task {
    
    ServiceWorkerResponse* response = [_delegate urlSchemeHandlerWillSendRequest: request];
    if (response != nil) {
        
        #ifdef DEBUG_CACHE
        if ([self shouldDebugURL:[request URL]]) {
            NSLog(@"Return Cached Response:  %@ %@", (_queueHandler ? @"MAIN" : @"SW"), [[request URL] absoluteString]);
        }
        #endif
        NSData *data = [response body];
        NSHTTPURLResponse *httpUrlResponse = [[NSHTTPURLResponse alloc] initWithURL:[request URL] statusCode:[[response status] integerValue] HTTPVersion:@"2.0" headerFields:[response headers]];
        [self completeTask:task response:httpUrlResponse data: data error: nil];
        return YES;
    }
    return NO;
}

- (void) sendSWRequest:(ServiceWorkerRequest *) request {
    NSObject<WKURLSchemeTask> *task = [request schemeTask];
    if (![self completeUrlTaskIfResponseIsCached:[request schemedRequest] forTask:task]) {
        [self initiateDataTaskForRequest:[request outgoingRequest] urlSchemeTask:task];
    }
}

- (void) initiateDataTaskForRequest: (NSURLRequest *) request urlSchemeTask: (id <WKURLSchemeTask>) schemeTask  {
    CDVSWURLSchemeHandler * __weak weakSelf = self;
    NSMutableURLRequest *schemedRequest = (NSMutableURLRequest *)[schemeTask request];
    ServiceWorkerRequest *swRequest = [ServiceWorkerRequest requestForURLRequest:schemedRequest];
    NSURLSession *session = [self session];
   
    if (request != nil) {
        #ifdef DEBUG_SCHEME_HANDLER
            if ([self shouldDebugURL:[request URL]]) {
                NSLog(@"initiateDataTaskForRequest URL - %@ %@ %@", (_queueHandler ? @"MAIN" : @"SW"), [request HTTPMethod],  [[request URL] absoluteString]);
            }
        #endif
        NSURLSessionDataTask *dataTask = [session dataTaskWithRequest:request completionHandler: ^(NSData *data, NSURLResponse *response, NSError *error) {
            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
            NSMutableDictionary *allHeaders = [NSMutableDictionary dictionaryWithDictionary: [httpResponse allHeaderFields]];
            [allHeaders setValue:[NSString stringWithFormat: @"cordova-main://%@", self.allowedOrigin] forKey:@"Access-Control-Allow-Origin"];
//            [allHeaders setValue:[NSString stringWithFormat: @"contour-spec://%@", self.allowedOrigin] forKey:@"Access-Control-Allow-Origin"];
            [allHeaders setValue:@"true" forKey:@"Access-Control-Allow-Credentials"];
            
            #ifdef DEBUG_SCHEME_HANDLER
                if ([self shouldDebugURL:[request URL]]) {
                    NSInteger status = [httpResponse statusCode];
                    NSLog(@"initiateDataTaskForRequest DONE - %@ %ld %@ %@ %lu", (_queueHandler ? @"MAIN" : @"SW"), (long)status, [request HTTPMethod],  [[request URL] absoluteString], (unsigned long)[data length]);
                }
            #endif
            
            
            

            NSHTTPURLResponse *updatedResponse = [[NSHTTPURLResponse alloc] initWithURL:[[schemeTask request] URL] statusCode:httpResponse.statusCode HTTPVersion:@"2.0" headerFields:allHeaders];
            [_delegate urlSchemeHandlerDidReceiveResponse: updatedResponse withData: data forRequest: [swRequest schemedRequest]];
            [weakSelf completeTask:schemeTask response:updatedResponse data:data error:error];
        }];
        [dataTask resume];
        swRequest.dataTask = dataTask;
    }
    else {
        NSLog(@"Cannot send data task for nil request %@", [schemeTask request]);
    }
}

- (void) sendRequestWithId:(NSNumber *) requestId {
    ServiceWorkerRequest *swRequest = [ServiceWorkerRequest requestWithId: (NSNumber*)requestId];
    #ifdef DEBUG_SCHEME_HANDLER
        if ([self shouldDebugURL: [[swRequest outgoingRequest] URL]]) {
            NSLog(@"sendRequestWithId - %@ %@ %@ %@", requestId, (_queueHandler ? @"MAIN" : @"SW"), [[swRequest outgoingRequest] HTTPMethod], [[[swRequest outgoingRequest] URL] absoluteString]);
        }
    #endif
    
    [self sendSWRequest:swRequest];
}
 
- (void) completeTaskWithId: (NSNumber *) taskId response: (NSHTTPURLResponse *) response data: (NSData *) data error: (NSError *) error {
    ServiceWorkerRequest *swRequest = [ServiceWorkerRequest requestWithId:taskId];
    id <WKURLSchemeTask> task = [swRequest schemeTask];
    [self completeTask: task response:response data:data error:error];
}

- (void) completeTask: (id <WKURLSchemeTask>) task response: (NSHTTPURLResponse *) response data: (NSData *) data error: (NSError *) error {
    NSNumber *requestId = [NSURLProtocol propertyForKey:@"RequestId" inRequest:[task request]];
    ServiceWorkerRequest *request = [ServiceWorkerRequest requestWithId:requestId];
    if (request.isClosed) {
        NSLog(@"Cannot Complete task that is already closed: %@", [[response URL] absoluteString]);
    } else if (request == nil) {
        NSLog(@"Cannot Complete task that is NULL: %@", [[response URL] absoluteString]);
    } else {
        [ServiceWorkerRequest closeRequestWithId: requestId];
        if (error != nil) {
            NSLog(@"CDVSWURLSchemeHandler Request Failed for url (%@) with error: %@", [[response URL] absoluteString], [error localizedDescription]);
            [task didFailWithError:error];
        } else {
//            NSLog(@"CDVSWURLSchemeHandler stop task: %@", [[response URL] absoluteString]);
            [task didReceiveResponse: response];
            [task didReceiveData: data];
            [task didFinish];
        }
    }
}

- (void)webView:(WKWebView *)webView stopURLSchemeTask:(id <WKURLSchemeTask>)urlSchemeTask
{
    NSNumber *requestId = [NSURLProtocol propertyForKey:@"RequestId" inRequest:[urlSchemeTask request]];
    ServiceWorkerRequest *request = [ServiceWorkerRequest requestWithId:requestId];
    NSURLSessionTask *dataTask = [request dataTask];
    [ServiceWorkerRequest closeRequestWithId: requestId];
    if (dataTask) {
        NSLog(@"stopURLSchemeTask Cancel Data Task - %ld %@", (long)[dataTask state], [[[urlSchemeTask request] URL] absoluteString]);
        [dataTask cancel];
    } else {
        NSLog(@"Declare request complete: %@", [[[urlSchemeTask request] URL] absoluteString]);
    }
}




@end

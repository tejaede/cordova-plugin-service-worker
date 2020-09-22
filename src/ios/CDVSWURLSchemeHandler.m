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


- (NSURLSession *) session {
    if (_session == nil) {
        _session = [NSURLSession sharedSession];
    }
    return _session;
}

- (void)webView:(WKWebView *)webView startURLSchemeTask:(id <WKURLSchemeTask>)urlSchemeTask
{
    NSLog(@"Handle Schemed URL - %@ %@",[[urlSchemeTask request] HTTPMethod],  [[[urlSchemeTask request] URL] absoluteString]);
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
        NSLog(@"Return Cached Response: %@", [[request URL] absoluteString]);
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
//    NSLog(@"initiateDataTaskForRequest: %@", [[request URL] absoluteString]);
    if ([[[schemedRequest URL] absoluteString] containsString:@"languages"]) {
        NSLog(@"initiateDataTaskForRequest: %@", [[request URL] absoluteString]);
    }
//    [[[request URL] absoluteString] containsString:@"languages"];
    NSURLSession *session = [self session];
    if (request != nil) {
        NSURLSessionDataTask *dataTask = [session dataTaskWithRequest:request completionHandler: ^(NSData *data, NSURLResponse *response, NSError *error) {
//            NSLog(@"Complete Task: %@", [[request URL] absoluteString]);
            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
            NSMutableDictionary *allHeaders = [NSMutableDictionary dictionaryWithDictionary: [httpResponse allHeaderFields]];
            //TODO Pass CORS origin in from outside
            [allHeaders setValue:[NSString stringWithFormat: @"cordova-main://%@", self.allowedOrigin] forKey:@"Access-Control-Allow-Origin"];
            [allHeaders setValue:@"true" forKey:@"Access-Control-Allow-Credentials"];

            NSHTTPURLResponse *updatedResponse = [[NSHTTPURLResponse alloc] initWithURL:[[schemeTask request] URL] statusCode:httpResponse.statusCode HTTPVersion:@"2.0" headerFields:allHeaders];
            [_delegate urlSchemeHandlerDidReceiveResponse: updatedResponse withData: data forRequest: [swRequest schemedRequest]];
            [weakSelf completeTask:schemeTask response:updatedResponse data:data error:error];
        }];
        [dataTask resume];
        swRequest.dataTask = dataTask;
//        NSLog(@"Send Request: %@ %@", [request HTTPMethod], [[request URL] absoluteString]);
    }
    else {
        NSLog(@"Cannot send data task for nil request %@", [schemeTask request]);
    }
}

- (void) sendRequestWithId:(NSNumber *) requestId {
    ServiceWorkerRequest *swRequest = [ServiceWorkerRequest requestWithId: (NSNumber*)requestId];
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

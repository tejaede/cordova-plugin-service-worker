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

@synthesize tasks = _tasks;
@synthesize requests = _requests;

static atomic_int requestCount = 0;

//NSMutableDictionary *tasks;
//NSMutableDictionary *requests;

- (CDVSWURLSchemeHandler *) init {
    if (self = [super init]) {
        _requests = [[NSMutableDictionary alloc] init];
        _tasks = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (void)webView:(WKWebView *)webView startURLSchemeTask:(id <WKURLSchemeTask>)urlSchemeTask
{
    NSURL *url = [[urlSchemeTask request] URL];
    NSString *urlString = [url absoluteString];
    
    CDVReachability *reachability  = [CDVReachability reachabilityForInternetConnection];
    NetworkStatus networkStatus = [reachability currentReachabilityStatus];
    

    NSLog(@"Handle Schemed URL - %@", urlString);
    
    NSMutableURLRequest *schemedRequest = (NSMutableURLRequest *)[urlSchemeTask request];

    
    if (_queueHandler != nil && [_queueHandler canAddToQueue]) {
        //add unmapped request to queue
        [self cacheRequest:schemedRequest andTask:urlSchemeTask];
        ServiceWorkerRequest *swRequest = [ServiceWorkerRequest new];
        swRequest.request = schemedRequest;
        swRequest.requestId = [NSURLProtocol propertyForKey: @"RequestId" inRequest: schemedRequest];
        [_queueHandler addRequestToQueue: swRequest];
    } else {
        NSMutableURLRequest *httpRequest;
        //map request and send immediately
        if ([urlString containsString:@"cordova-main"]) {
            urlString = [urlString stringByReplacingOccurrencesOfString:@"cordova-main:"  withString:@"https:"];
        }
        httpRequest = [NSMutableURLRequest requestWithURL:[NSURL URLWithString: urlString] cachePolicy: NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:1000.0];
        NSDictionary *headers = [schemedRequest allHTTPHeaderFields];
        for (NSString* key in headers) {
            id value = headers[key];
            [httpRequest setValue: value forHTTPHeaderField:key];
        }
        [self cacheRequest:httpRequest andTask:urlSchemeTask];
        [self sendRequest:httpRequest forTask: urlSchemeTask];
    }
}

- (void) cacheRequest: (NSMutableURLRequest *) request andTask: (id <WKURLSchemeTask>)urlSchemeTask {
    NSNumber *requestId = [NSNumber numberWithLongLong:atomic_fetch_add_explicit(&requestCount, 1, memory_order_relaxed)];
    [NSURLProtocol setProperty:requestId forKey:@"RequestId" inRequest:request];
    [_tasks setObject:urlSchemeTask forKey: [requestId stringValue]];
    [_requests setObject:request forKey:[requestId stringValue]];
}

- (void) sendRequestWithId:(NSString *) requestId {
    NSMutableURLRequest *request = [_requests objectForKey:requestId];
    id <WKURLSchemeTask> task = [_tasks objectForKey:requestId];
    NSURL *url = [request URL];
    if ([[url scheme] isEqualToString:@"cordova-main"]) {
        NSString *urlString = [url absoluteString];
        urlString = [urlString stringByReplacingOccurrencesOfString:@"cordova-main:"  withString:@"https:"];
        [request setURL: [NSURL URLWithString:urlString]];
    }
    [self sendRequest:request forTask: task];
}

- (void) sendRequest:(NSMutableURLRequest *) request forTask: (id <WKURLSchemeTask>) task {
    [self sendRequest:request forTask:task protocol: @"cordova-main" webView:nil];
}

- (void) sendRequest:(NSMutableURLRequest *) request forTask: (id <WKURLSchemeTask>) task protocol: (NSString *) protocol webView: (WKWebView *) webView {
    NSURLSession *session = [NSURLSession sharedSession];
    CDVSWURLSchemeHandler * __weak weakSelf = self;
    NSMutableURLRequest *schemedRequest = (NSMutableURLRequest *)[task request];
    NSNumber *requestId = [NSURLProtocol propertyForKey:@"RequestId" inRequest:request];
    [NSURLProtocol setProperty:requestId forKey:@"RequestId" inRequest:schemedRequest];
    ServiceWorkerResponse* response = [_delegate urlSchemeHandlerWillSendRequest: schemedRequest];
    if (response != nil) {
        NSData *data = [response body];
        NSHTTPURLResponse *httpUrlResponse = [[NSHTTPURLResponse alloc] initWithURL:[request URL] statusCode:[[response status] integerValue] HTTPVersion:@"2.0" headerFields:[response headers]];
        [weakSelf completeTask:task response:httpUrlResponse data:data error:nil];
    } else {
        NSURLSessionDataTask *dataTask = [session dataTaskWithRequest:request completionHandler: ^(NSData *data, NSURLResponse *response, NSError *error) {
            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
            NSMutableDictionary *allHeaders = [NSMutableDictionary dictionaryWithDictionary: [httpResponse allHeaderFields]];

            NSHTTPURLResponse *updatedResponse = [[NSHTTPURLResponse alloc] initWithURL:[[task request] URL] statusCode:httpResponse.statusCode HTTPVersion:@"2.0" headerFields:allHeaders];
            [_delegate urlSchemeHandlerDidReceiveResponse: updatedResponse withData: data forRequest: schemedRequest];
            [weakSelf completeTask:task response:updatedResponse data:data error:error];
        }];
        [dataTask resume];
    }
}
 
- (void) completeTaskWithId: (NSNumber *) taskId response: (NSHTTPURLResponse *) response data: (NSData *) data error: (NSError *) error {
    id <WKURLSchemeTask> task = [_tasks objectForKey:[taskId stringValue]];
    [self completeTask: task response:response data:data error:error];
    [_tasks removeObjectForKey:[taskId stringValue]];
    [_requests removeObjectForKey:[taskId stringValue]];
}

- (void) completeTask: (id <WKURLSchemeTask>) task response: (NSHTTPURLResponse *) response data: (NSData *) data error: (NSError *) error {
    if (error != nil) {
        NSLog(@"CDVSWURlSchemeHandler Request Failed with error: %@", [error localizedDescription]);
        [task didFailWithError:error];
    } else {
        [task didReceiveResponse: response];
        [task didReceiveData: data];
        [task didFinish];
    }
}

- (void)webView:(WKWebView *)webView stopURLSchemeTask:(id <WKURLSchemeTask>)urlSchemeTask
{
    NSLog(@"StopURLSchemeTask");
//    NSString *urlString = [[[urlSchemeTask request] URL] absoluteString];
//    NSLog(@"Mapped URL: %@", urlString);
}




@end

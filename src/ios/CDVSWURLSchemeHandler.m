//
//  CDVSWURLSchemeHandler.m
//  DisasterAlert
//
//  Created by Thomas Jaede on 4/22/20.
//

#import <Foundation/Foundation.h>
#import <WebKit/WKURLSchemeTask.h>
#import "CDVSWURLSchemeHandler.h"
#import "FetchInterceptorProtocol.h"

#include <libkern/OSAtomic.h>
#include <stdatomic.h>


@implementation CDVSWURLSchemeHandler {}

@synthesize queueHandler = _queueHandler;

static atomic_int requestCount = 0;

NSMutableDictionary *tasks;
NSMutableDictionary *requests;

- (CDVSWURLSchemeHandler *) init {
    if (self = [super init]) {
        requests = [[NSMutableDictionary alloc] init];
        tasks = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (void)webView:(WKWebView *)webView startURLSchemeTask:(id <WKURLSchemeTask>)urlSchemeTask
{
    
    NSURL *url = [[urlSchemeTask request] URL];
    NSString *urlString = [url absoluteString];
    if ([urlString containsString:@"cordova-main"]) {
//        NSLog(@"startURLSchemeTask -- %@", [urlString stringByReplacingOccurrencesOfString:@"cordova-main:"  withString:@"https:"]);
         [urlString stringByReplacingOccurrencesOfString:@"cordova-main:"  withString:@"https:"];
    } else if ([urlString containsString:@"cordova-sw"]) {
//        NSLog(@"startURLSchemeTask -- %@", [urlString stringByReplacingOccurrencesOfString:@"cordova-sw:"  withString:@"https:"]);
        [urlString stringByReplacingOccurrencesOfString:@"cordova-sw:"  withString:@"https:"];
    }

    NSURLResponse *response;
    if ([urlString containsString:@"sw_assets"]) {
        NSString *responseString = [self readSchemedURLFromBundle:urlString];
        NSString *mimeType;
        if ([urlString hasSuffix: @"html"]) {
            mimeType = @"text/html";
        } else {
            mimeType = @"text/javascript";
        }
        response = [[NSURLResponse alloc] initWithURL: url MIMEType: mimeType expectedContentLength: -1 textEncodingName: @"UTF-8"];
        [urlSchemeTask didReceiveResponse:response];
        [urlSchemeTask didReceiveData: [responseString dataUsingEncoding: NSUTF8StringEncoding]];
        [urlSchemeTask didFinish];
    } else {
        NSURLRequest *taskRequest = [urlSchemeTask request];
        NSMutableURLRequest *request;
        if ([urlString containsString:@"cordova-sw"]) {
            urlString = [urlString stringByReplacingOccurrencesOfString:@"cordova-sw:"  withString:@"https:"];
            request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString: urlString]];
            [NSURLProtocol setProperty:@YES forKey:@"PassThrough" inRequest: request];
        } else if ([urlString containsString:@"cordova-main"]) {
            urlString = [urlString stringByReplacingOccurrencesOfString:@"cordova-main:"  withString:@"https:"];
            request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString: urlString]];
        }
        NSDictionary *headers = [taskRequest allHTTPHeaderFields];
        for (NSString* key in headers) {
            id value = headers[key];
            [request setValue: value forHTTPHeaderField:key];
        }
        
        NSNumber *requestId = [NSNumber numberWithLongLong:atomic_fetch_add_explicit(&requestCount, 1, memory_order_relaxed)];
        [NSURLProtocol setProperty:requestId forKey:@"RequestId" inRequest:request];
        [tasks setObject:urlSchemeTask forKey: [requestId stringValue]];
        [requests setObject:request forKey:[requestId stringValue]];


        if ([_queueHandler canAddToQueue]) {
            ServiceWorkerRequest *swRequest = [ServiceWorkerRequest new];
            swRequest.request = request;
            swRequest.requestId = requestId;
//            NSLog(@"Add Request to Queue:  %@", [urlString stringByReplacingOccurrencesOfString:@"cordova-main:"  withString:@"https:"]);
            [_queueHandler addRequestToQueue:swRequest];
        } else {
            
            [self sendRequest:request forTask:urlSchemeTask];
        }
    }
}

- (void) sendRequestWithId:(NSString *) requestId {
    NSMutableURLRequest *request = [requests objectForKey:requestId];
    id <WKURLSchemeTask> task = [tasks objectForKey:requestId];
    [self sendRequest:request forTask: task];
}

- (void) sendRequest:(NSMutableURLRequest *) request forTask: (id <WKURLSchemeTask>) task {
    NSURLSession *session = [NSURLSession sharedSession];
    CDVSWURLSchemeHandler * __weak weakSelf = self;
    #ifdef __DEBUG__
        NSString *urlString = [[request URL] absoluteString];
        NSLog(@"Send Request %@", urlString);
    #endif
    NSURLSessionDataTask *dataTask = [session dataTaskWithRequest:request completionHandler: ^(NSData *data, NSURLResponse *response, NSError *error) {
        #ifdef __DEBUG__
//            NSLog(@"Receive Response %@", urlString);
        #endif
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        NSMutableDictionary *allHeaders = [NSMutableDictionary dictionaryWithDictionary: [httpResponse allHeaderFields]];
        [allHeaders setValue:@"cordova-main://local.pdc.org" forKey:@"Access-Control-Allow-Origin"];
        [allHeaders setValue:@"true" forKey:@"Access-Control-Allow-Credentials"];
        NSHTTPURLResponse *updatedResponse = [[NSHTTPURLResponse alloc] initWithURL:[request URL] statusCode:httpResponse.statusCode HTTPVersion:@"1.1" headerFields:allHeaders];
        [weakSelf completeTask:task response:updatedResponse data:data error:error];
    }];
    [dataTask resume];
}
 
- (void) completeTaskWithId: (NSNumber *) taskId response: (NSURLResponse *) response data: (NSData *) data error: (NSError *) error {
    id <WKURLSchemeTask> task = [tasks objectForKey:taskId];
    [self completeTask: task response:response data:data error:error];
}

- (void) completeTask: (id <WKURLSchemeTask>) task response: (NSURLResponse *) response data: (NSData *) data error: (NSError *) error {
    [task didReceiveResponse: response];
    [task didReceiveData: data];
    [task didFinish];
}


- (NSString *) readSchemedURLFromBundle: (NSString *) urlString {
    NSString *localURLString = [urlString stringByReplacingOccurrencesOfString:@"cordova-sw:/" withString:@""];
    NSError *error;
    NSString *responseString = [NSString stringWithContentsOfFile:localURLString encoding:NSUTF8StringEncoding error:&error];
    if (error) {
        NSLog(@"CDVSWURLSchemeHandler could not read file: %@", [error description]);
        return nil;
    }
    return responseString;
}


- (void)webView:(WKWebView *)webView stopURLSchemeTask:(id <WKURLSchemeTask>)urlSchemeTask
{
    NSString *urlString = [[[urlSchemeTask request] URL] absoluteString];
    
    NSLog(@"Mapped URL: %@", urlString);
}




@end

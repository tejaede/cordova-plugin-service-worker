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
#import <Foundation/Foundation.h>
#import "ServiceWorkerRequest.h"
#import <JavaScriptCore/JavaScriptCore.h>

#include <libkern/OSAtomic.h>
#include <stdatomic.h>

@implementation ServiceWorkerRequest

static atomic_int requestCount = 0;
static NSMutableDictionary<NSNumber *,ServiceWorkerRequest *> * _requestsById;

+ (NSMutableDictionary<NSNumber *,ServiceWorkerRequest *> *) requestsById {
    if (_requestsById == nil) {
        _requestsById = [[NSMutableDictionary alloc] init];
    }
    return _requestsById;
}

+ (ServiceWorkerRequest *) requestWithURLSchemeTask: (id <WKURLSchemeTask>) schemeTask {
    NSNumber *requestId = [NSNumber numberWithLongLong:atomic_fetch_add_explicit(&requestCount, 1, memory_order_relaxed)];
    ServiceWorkerRequest *swRequest = [ServiceWorkerRequest new];
    swRequest.requestId = requestId;
    swRequest.schemedRequest = (NSMutableURLRequest *)[schemeTask request];
    [NSURLProtocol setProperty:requestId forKey:@"RequestId" inRequest:(NSMutableURLRequest *)swRequest.schemedRequest];
    swRequest.schemeTask = schemeTask;
    [[ServiceWorkerRequest requestsById] setObject:swRequest forKey: requestId];
    return swRequest;
}

+ (ServiceWorkerRequest *) requestWithDictionary: (NSDictionary *) requestDict {
//    NSNumber *requestId = [NSNumber numberWithLongLong:atomic_fetch_add_explicit(&requestCount, 1, memory_order_relaxed)];
    ServiceWorkerRequest *swRequest = [ServiceWorkerRequest new];
//    swRequest.requestId = requestId;
    swRequest.schemedRequestDict = requestDict;
//    [[ServiceWorkerRequest requestsById] setValue:swRequest forKey: [requestId stringValue]];
    return swRequest;
}

+ (ServiceWorkerRequest *) requestForURLRequest: (NSURLRequest *) urlRequest {
    NSNumber *requestId = [NSURLProtocol propertyForKey:@"RequestId" inRequest:urlRequest];
    return [ServiceWorkerRequest requestWithId: requestId];
}

+ (ServiceWorkerRequest *) requestWithId: (NSNumber *) requestId {
    return [[ServiceWorkerRequest requestsById] objectForKey: requestId];
}

+ (void) closeRequestWithId: (NSNumber *) requestId {
    ServiceWorkerRequest *swRequest = [ServiceWorkerRequest requestWithId:requestId];
    if (swRequest) {
        swRequest.isClosed = YES;
        [ServiceWorkerRequest removeRequestWithId:requestId];
    }
}

+ (void) removeRequestWithId: (NSNumber *) requestId {
    [[ServiceWorkerRequest requestsById] removeObjectForKey: requestId];
}


@synthesize outgoingRequest = _outgoingRequest;
@synthesize schemedRequest = _schemedRequest;
@synthesize schemedRequestDict = _schemedRequestDict;
@synthesize requestId = _requestId;
@synthesize schemeTask = _schemeTask;
@synthesize dataTask = _dataTask;

- (NSMutableURLRequest *) outgoingRequest {
    NSString *scheme;
    NSString *outgoingURLString;
    if (_outgoingRequest == nil && self.schemedRequest != nil) {
        
        scheme = [[[self schemedRequest] URL] scheme];
        if (![scheme isEqualToString:@"https"]) {
            outgoingURLString = [[[[self schemedRequest] URL] absoluteString] stringByReplacingOccurrencesOfString: scheme withString: @"https"];
        }
        NSURLRequest *request = [_schemedRequest mutableCopy];
        NSLog(@"url: %@", [request URL]);
        _outgoingRequest = [_schemedRequest mutableCopy];
        if ([[_outgoingRequest HTTPMethod] isEqualToString: @"POST"]) {
            NSString * contentType = [_outgoingRequest valueForHTTPHeaderField:@"content-type"];
            if (![contentType containsString:@"multipart/form-data"]) {
                NSData *body = [_schemedRequest HTTPBody];
                NSData *decodedBody = [[NSData alloc] initWithBase64EncodedData:body options:NSDataBase64DecodingIgnoreUnknownCharacters];
                [_outgoingRequest setHTTPBody:decodedBody];
            }
        }
        [_outgoingRequest setURL:[NSURL URLWithString:outgoingURLString]];
        [_outgoingRequest setCachePolicy:NSURLRequestReloadIgnoringLocalCacheData];
        if (self.requestId != nil) {
            [NSURLProtocol setProperty:[self requestId] forKey:@"RequestId" inRequest:_outgoingRequest];
        }
    } else if (_outgoingRequest == nil && self.schemedRequestDict != nil) {
        NSURL *url = [NSURL URLWithString:[_schemedRequestDict valueForKey:@"url"]];
        NSDictionary *headers = [self getHeadersForTrueFetchScriptMessage:_schemedRequestDict];
        scheme = [url scheme];
        if (![scheme isEqualToString:@"https"]) {
            outgoingURLString = [[url absoluteString] stringByReplacingOccurrencesOfString: scheme withString: @"https"];
        }
        JSValue *body = [_schemedRequestDict valueForKey:@"body"];
        NSString *method = [_schemedRequestDict valueForKey:@"method"];
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString: outgoingURLString]];
        [request setTimeoutInterval:60];
        NSString *contentType = [headers valueForKey:@"content-type"];
        NSString *boundary;
        NSData *httpBody;
        if ([body isKindOfClass:[NSDictionary class]]) {
            boundary = [self generateBoundaryString];
            if (contentType == nil) {
                contentType = [NSString stringWithFormat: @"multipart/form-data; boundary=%@", boundary];
            } else {
                contentType = [NSString stringWithFormat: @"%@; boundary=%@;", contentType, boundary];
            }
            httpBody = [self makeTrueFetchHTTPRequestMultipartBody: (NSDictionary *) body boundary: boundary];
            [headers setValue:contentType forKey:@"content-type"];
        }
        
        [request setHTTPMethod:method];
        if (headers != nil) {
            for (NSString* key in headers) {
                id value = headers[key];
                if([value isKindOfClass:[NSArray class]]){
                    value = [value objectAtIndex:0];
                }
                [request setValue: value forHTTPHeaderField:key];
            }
        };
        if (httpBody != nil) {
            [request setHTTPBody: httpBody];
        }
        _outgoingRequest = request;
    }
    return _outgoingRequest;
}

- (NSDictionary *) getHeadersForTrueFetchScriptMessage: (NSDictionary *) messageBody {
    NSDictionary *headers = [messageBody valueForKey:@"headers"];
    NSDictionary *innerDict = [headers valueForKey:@"headerDict"];
    if (innerDict != nil) {
        headers = innerDict;
    } else {
        innerDict = [headers valueForKey:@"_headerDict"];
        if (innerDict != nil) {
            headers = innerDict;
        }
    }
    return headers;
}

- (NSString *) generateBoundaryString {
    int r = arc4random_uniform(1000);
    return [NSString stringWithFormat: @"---CDVFormBoundary%d", r];
}

- (NSData *) makeTrueFetchHTTPRequestMultipartBody: (NSDictionary *) parameters boundary: (NSString *) boundary {
    NSMutableData *httpBody = [NSMutableData data];
    
    [parameters enumerateKeysAndObjectsUsingBlock:^(NSString *parameterKey, NSObject *parameterValue, BOOL *stop) {
        [httpBody appendData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding: NSUTF8StringEncoding]];
        if ([parameterValue isKindOfClass:[NSDictionary class]]) {
            NSString *fileName = [(NSDictionary*) parameterValue valueForKey:@"name"];
            NSString *mimeType = [(NSDictionary*) parameterValue valueForKey:@"type"];
            NSString *dataAsString = [(NSDictionary*) parameterValue valueForKey:@"data"];
            [httpBody appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"; filename=\"%@\"\r\n", parameterKey, fileName] dataUsingEncoding: NSUTF8StringEncoding]];
            [httpBody appendData:[[NSString stringWithFormat: @"Content-Type: %@\r\n\r\n", mimeType] dataUsingEncoding:NSUTF8StringEncoding]];
            NSData *fileData = [[NSData alloc] initWithBase64EncodedString:dataAsString options:NSDataBase64DecodingIgnoreUnknownCharacters];
            [httpBody appendData: fileData];
            [httpBody appendData:[[NSString stringWithFormat:@"--%@--\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
        } else {
            [httpBody appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"\r\n\r\n", parameterKey] dataUsingEncoding: NSUTF8StringEncoding]];
            [httpBody appendData:[[NSString stringWithFormat:@"%@", parameterValue] dataUsingEncoding: NSUTF8StringEncoding]];
        }
        [httpBody appendData:[[NSString stringWithFormat:@"\r\n"] dataUsingEncoding:NSUTF8StringEncoding]];
    }];
    [httpBody appendData:[[NSString stringWithFormat:@"--%@--\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    
    return httpBody;
}


@end

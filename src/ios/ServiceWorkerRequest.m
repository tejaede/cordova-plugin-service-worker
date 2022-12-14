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

NSString * const CONTENT_TYPE_HEADER_KEY = @"content-type";
NSString * const CONTENT_TYPE_JSON = @"application/json";
NSString * const CONTENT_TYPE_FORM_DATA = @"multipart/form-data";


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
    swRequest.originalRequest = (NSMutableURLRequest *)[schemeTask request];
    [NSURLProtocol setProperty:requestId forKey:@"RequestId" inRequest:(NSMutableURLRequest *)swRequest.originalRequest];
    swRequest.schemeTask = schemeTask;
    [[ServiceWorkerRequest requestsById] setObject:swRequest forKey: requestId];
    return swRequest;
}

+ (ServiceWorkerRequest *) requestWithDictionary: (NSDictionary *) requestDict {
    NSNumber *requestId = [NSNumber numberWithLongLong:atomic_fetch_add_explicit(&requestCount, 1, memory_order_relaxed)];
    ServiceWorkerRequest *swRequest = [ServiceWorkerRequest new];
    swRequest.requestId = requestId;
    swRequest.originalRequestDict = requestDict;
    [[ServiceWorkerRequest requestsById] setValue:swRequest forKey: [requestId stringValue]];
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

@synthesize originalRequest = _originalRequest;
@synthesize outgoingRequest = _outgoingRequest;
@synthesize schemedRequest = _schemedRequest;
@synthesize originalRequestDict = _originalRequestDict;
@synthesize requestId = _requestId;
@synthesize schemeTask = _schemeTask;
@synthesize dataTask = _dataTask;
@synthesize isBodyDecoded = _isBodyDecoded;

- (NSMutableURLRequest *) outgoingRequest {
    NSString *scheme;
    NSURL *schemedURL;
    
    NSString *outgoingURLString;
    if (_outgoingRequest == nil) {
        NSMutableURLRequest *schemedRequest = [self schemedRequest];
        if (schemedRequest != nil) {
            _outgoingRequest = [schemedRequest mutableCopy];
            schemedURL = [_outgoingRequest URL];
            scheme = [schemedURL scheme];
            NSURL *outgoingURL;
            if (![scheme isEqualToString:@"https"] && ![scheme isEqualToString:@"http"]) {
                outgoingURLString = [[schemedURL absoluteString] stringByReplacingOccurrencesOfString: scheme withString: @"https"];
                outgoingURL = [NSURL URLWithString:outgoingURLString];
            } else {
                outgoingURL= schemedURL;
            }
            [_outgoingRequest setURL:outgoingURL];
            NSString *httpBodyAsString;
            if ([[_outgoingRequest HTTPMethod] isEqualToString: @"POST"]) {
                NSString * contentType = [_outgoingRequest valueForHTTPHeaderField: CONTENT_TYPE_HEADER_KEY];
                if ([self isBodyBase64EncodedForContentType: contentType] && !_isBodyDecoded) {
                    NSData *decodedBody = [[NSData alloc] initWithBase64EncodedData:[_schemedRequest HTTPBody] options:NSDataBase64DecodingIgnoreUnknownCharacters];
                    _isBodyDecoded = true;
                    httpBodyAsString = [[NSString alloc] initWithData: decodedBody  encoding:NSUTF8StringEncoding];
                    if (decodedBody) {
                        [_outgoingRequest setHTTPBody:decodedBody];
                    }
                } else {
                    httpBodyAsString = [[NSString alloc] initWithData: [_schemedRequest HTTPBody] encoding:NSUTF8StringEncoding];
                    [_outgoingRequest setHTTPBody:[_schemedRequest HTTPBody]];
                }
            }
            [_outgoingRequest setCachePolicy:NSURLRequestReloadIgnoringLocalCacheData];
            if (self.requestId != nil) {
                [NSURLProtocol setProperty:[self requestId] forKey:@"RequestId" inRequest:_outgoingRequest];
            }
        } else {
            NSLog(@"ServiceWorkerRequest cannot create an outgoing request without a schemed request");
        }
    }
    return _outgoingRequest;
}


- (Boolean) isBodyBase64EncodedForContentType: (NSString *) contentType {
    return !([contentType isEqualToString: CONTENT_TYPE_JSON] || [contentType containsString: CONTENT_TYPE_FORM_DATA]);
}

- (NSMutableURLRequest *) schemedRequest {
    NSURL *schemedURL;
    if (_schemedRequest == nil && _originalRequest != nil) {
        _schemedRequest = [_originalRequest mutableCopy];
        schemedURL = [_originalRequest URL];
        schemedURL = [self normalizeURL: schemedURL];
        [_schemedRequest setURL: schemedURL];
    } else if (_schemedRequest == nil && _originalRequestDict != nil) {
        _schemedRequest = [self requestForRequestDict: _originalRequestDict];
    } else if (_schemedRequest == nil) {
        NSLog(@"ServiceWorkerRequest cannot create schemedRequest without original request or original request dict");
    }
    return _schemedRequest;
}

- (NSURL *) normalizeURL: (NSURL *) url {
    if ([[url lastPathComponent] isEqualToString:@"cross-origin"]) {
        url = [NSURL URLWithString:[url query]];
    }
    return url;
}

- (NSMutableURLRequest *) requestForRequestDict: (NSDictionary *) requestDict {
    NSURL *url = [NSURL URLWithString:[_originalRequestDict valueForKey:@"url"]];
    NSDictionary *headers = [self getHeadersForTrueFetchScriptMessage:_originalRequestDict];
    JSValue *body = [_originalRequestDict valueForKey:@"body"];
    NSString *method = [_originalRequestDict valueForKey:@"method"];
    
    url = [NSURL URLWithString:[_originalRequestDict valueForKey:@"url"]];
    url = [self normalizeURL:url];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setTimeoutInterval:60];
    NSString *contentType = [headers valueForKey:CONTENT_TYPE_HEADER_KEY];
    NSString *boundary;
    NSData *httpBody;
    NSString *httpBodyAsString;
    if ([body isKindOfClass:[NSDictionary class]]) {
        boundary = [self generateBoundaryString];
        if (contentType == nil) {
            contentType = [NSString stringWithFormat: @"multipart/form-data; boundary=%@", boundary];
        } else {
            contentType = [NSString stringWithFormat: @"%@; boundary=%@;", contentType, boundary];
        }
        httpBody = [self makeTrueFetchHTTPRequestMultipartBody: (NSDictionary *) body boundary: boundary];
        [headers setValue:contentType forKey:CONTENT_TYPE_HEADER_KEY];
    } else if ([body isKindOfClass:[NSString class]] && [(NSString*)body length] > 0 && [self isBodyBase64EncodedForContentType: contentType]) {
        httpBody = [[NSData alloc] initWithBase64EncodedString:(NSString*)body options:NSDataBase64DecodingIgnoreUnknownCharacters];
        httpBodyAsString = [[NSString alloc] initWithData: httpBody encoding:NSUTF8StringEncoding];
    } else if ([body isKindOfClass:[NSString class]] && [(NSString*)body length] > 0) {
        httpBody = [(NSString *)body dataUsingEncoding:NSUTF8StringEncoding];
    }
    _isBodyDecoded = true;
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
    return request;
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

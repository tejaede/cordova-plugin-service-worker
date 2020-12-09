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
#import <WebKit/WKURLSchemeTask.h>

@interface ServiceWorkerRequest : NSObject

+ (ServiceWorkerRequest *) requestWithURLSchemeTask: (id <WKURLSchemeTask>) schemeTask;
+ (ServiceWorkerRequest *) requestWithDictionary: (NSDictionary *) requestDict;
+ (ServiceWorkerRequest *) requestWithId: (NSNumber *) requestId;
+ (ServiceWorkerRequest *) requestForURLRequest: (NSURLRequest *) urlRequest;
+ (void) closeRequestWithId: (NSNumber *) requestId;

+ (void) removeRequestWithId: (NSNumber *) requestId;

@property (class, readonly) NSMutableDictionary<NSNumber *,ServiceWorkerRequest *> * requestsById;

@property (nonatomic, strong) NSURLRequest *originalRequest;
@property (nonatomic, retain) NSDictionary *originalRequestDict;
@property (nonatomic, strong) NSMutableURLRequest *outgoingRequest;
@property (nonatomic, strong) NSMutableURLRequest *schemedRequest;
@property (nonatomic, strong) NSNumber *requestId;
@property (nonatomic, retain) id <WKURLSchemeTask> schemeTask;
@property (nonatomic) Boolean isBodyBase64Encoded;

@property (nonatomic, retain) NSURLSessionDataTask *dataTask;

@property BOOL isClosed;
 
@end

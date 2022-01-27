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
#import <Cordova/CDV.h>
#import <CoreData/CoreData.h>
#import <JavaScriptCore/JSContext.h>
#import "ServiceWorkerResponse.h"
#import "ServiceWorkerCache.h"
#import <WebKit/WebKit.h>

extern NSString * const SERVICE_WORKER;

@interface ServiceWorkerCacheStorage : NSObject {}

-(ServiceWorkerCache*)cacheWithName:(NSString *)cacheName;
-(NSDictionary*)allCaches;
-(BOOL)deleteCacheWithName:(NSString *)cacheName;
-(BOOL)hasCacheWithName:(NSString *)cacheName;

-(ServiceWorkerResponse *)matchForRequest:(NSURLRequest *)request;
-(ServiceWorkerResponse *)matchForRequest:(NSURLRequest *)request withOptions:(/*ServiceWorkerCacheMatchOptions*/NSDictionary *)options;

@property (nonatomic, retain) NSMutableDictionary *caches;
@end

@interface ServiceWorkerCacheApi : CDVPlugin <WKScriptMessageHandler> {}

+ (id)sharedCacheApi;

-(id)initWithScope:(NSString *)scope internalCacheEnabled:(BOOL)internalCacheEnabled;
-(void)registerForJavascriptMessagesForWebView:(WKWebView *) webView;
-(ServiceWorkerCacheStorage *)cacheStorageForScope:(NSURL *)scope;
-(BOOL)initializeStorage;
-(void)putRequest:(NSURLRequest *) request andResponse:(ServiceWorkerResponse *)response inCache:(ServiceWorkerCache *)cache;
-(ServiceWorkerResponse *) matchRequest:(NSURLRequest *)request inCache:(ServiceWorkerCache *) cache;
-(NSArray *) matchAllForRequest:(NSURLRequest *)request inCache:(ServiceWorkerCache *) cache;
- (void)putInternal:(NSURLRequest *)request response: (NSHTTPURLResponse *) response data: (NSData *) data;
- (void)putInternal:(NSURLRequest *)request swResponse: (ServiceWorkerResponse *) response;
- (ServiceWorkerResponse *)matchInternal:(NSURLRequest *)request;
@property (nonatomic, retain) NSMutableDictionary *cacheStorageMap;
@property (nonatomic) BOOL internalCacheEnabled;
@property (nonatomic, retain) NSString *absoluteScope;
@end


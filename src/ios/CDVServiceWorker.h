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

#import <Cordova/CDVPlugin.h>
#import <JavaScriptCore/JSContext.h>
#import "ServiceWorkerCacheApi.h"
#import <WebKit/WebKit.h>
#import "CDVBackgroundSync.h"
#import "CDVSWRequestQueueProtocol.h"
#import "CDVSWURLSchemeHandler.h"
#import "ServiceWorkerRequest.h"
#import "CDVSWURLSchemeHandlerDelegate.h"


extern NSString * const SERVICE_WORKER;
extern NSString * const SERVICE_WORKER_CACHE_CORDOVA_ASSETS;
extern NSString * const SERVICE_WORKER_ACTIVATED;
extern NSString * const SERVICE_WORKER_INSTALLED;
extern NSString * const SERVICE_WORKER_SCRIPT_CHECKSUM;

extern NSString * const REGISTER_OPTIONS_KEY_SCOPE;

extern NSString * const REGISTRATION_KEY_ACTIVE;
extern NSString * const REGISTRATION_KEY_INSTALLING;
extern NSString * const REGISTRATION_KEY_REGISTERING_SCRIPT_URL;
extern NSString * const REGISTRATION_KEY_SCOPE;
extern NSString * const REGISTRATION_KEY_WAITING;

extern NSString * const SERVICE_WORKER_KEY_SCRIPT_URL;

@interface CDVServiceWorker : CDVPlugin <WKUIDelegate, CDVJavaScriptEvaluator, WKNavigationDelegate, WKScriptMessageHandler, CDVSWRequestQueueProtocol, CDVSWURLSchemeHandlerDelegate> {}

@property (nonatomic, retain) CDVBackgroundSync *backgroundSync;
@property (nonatomic, retain) ServiceWorkerCacheApi *cacheApi;
@property (nonatomic, copy) void (^initiateHandler)();
@property (nonatomic, retain) NSMutableArray *requestQueue;
@property (nonatomic, retain) NSDictionary *registration;
@property (nonatomic, retain) WKWebView *workerWebView;
@property (nonatomic, retain) NSString *swUrlScheme;

- (void) handleLogScriptMessage: (WKScriptMessage *) message;
- (NSString *) handlerNameForMessage: (WKScriptMessage *) message;
- (void) sendResultToWorker:(NSNumber*) messageId parameters:(NSDictionary *)parameters;

@end


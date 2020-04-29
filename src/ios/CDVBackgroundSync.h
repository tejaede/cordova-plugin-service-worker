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
#import "CDVConnection.h"
#import <WebKit/WebKit.h>
#import <JavaScriptCore/JavaScriptCore.h>
#import <objc/runtime.h>

@protocol CDVJavaScriptEvaluator

- (void)evaluateScript:(NSString *)script;

@end

@interface CDVBackgroundSync : CDVPlugin {}

typedef void(^Completion)(UIBackgroundFetchResult);

- (void) registerSync:(NSDictionary *) registration withType:(NSString *)type;
- (void) sendPeriodicSyncResponse:(NSNumber *) responseType forTag:(NSString *)tag;
- (void) sendSyncResponse:(NSNumber *) responseType forTag:(NSString *)tag;
- (BOOL) unregisterSyncByTag:(NSString *) tag withType:(NSString *)type;
- (NSMutableDictionary *) getRegistrationsOfType:(NSString *) type;
- (NSDictionary *)getRegistrationOfType:(NSString *)type andTag: (NSString *) tag;

@property (nonatomic, copy) NSString *syncCheckCallback;
@property (nonatomic, copy) Completion completionHandler;
@property (nonatomic, strong) NSMutableDictionary *registrationList;
@property (nonatomic, strong) NSMutableDictionary *periodicRegistrationList;
@property (strong) id <CDVJavaScriptEvaluator> scriptRunner;
@end

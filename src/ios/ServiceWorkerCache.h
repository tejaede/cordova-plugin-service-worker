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
#import <CoreData/CoreData.h>

#import "ServiceWorkerResponse.h"
#import "ServiceWorkerCacheEntry.h"

@interface ServiceWorkerCache : NSManagedObject

-(ServiceWorkerResponse *)matchForRequest:(NSURLRequest *)request inContext:(NSManagedObjectContext *)moc;
-(ServiceWorkerResponse *)matchForRequest:(NSURLRequest *)request withOptions:(/*ServiceWorkerCacheMatchOptions*/NSDictionary *)options inContext:(NSManagedObjectContext *)moc;
-(NSArray *)matchAllForRequest:(NSURLRequest *)request inContext:(NSManagedObjectContext *)moc;
-(NSArray *)matchAllForRequest:(NSURLRequest *)request withOptions:(/*ServiceWorkerCacheMatchOptions*/NSDictionary *)options inContext:(NSManagedObjectContext *)moc;
-(void) putRequest:(NSURLRequest *)request andResponse:(ServiceWorkerResponse *)response inContext:(NSManagedObjectContext *)moc;
-(bool) deleteRequest:(NSURLRequest *)request fromContext:(NSManagedObjectContext *)moc;
-(NSArray *)requestsFromContext:(NSManagedObjectContext *)moc;

@property (nonatomic, retain) NSString * name;
@property (nonatomic, retain) NSString * scope;
@property (nonatomic, retain) NSManagedObject *entries;

@end

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

#import "ServiceWorkerCache.h"

@implementation ServiceWorkerCache

@dynamic name;
@dynamic scope;
@dynamic entries;


-(NSString *)urlWithoutQueryForUrl:(NSURL *)url
{
    NSURL *absoluteURL = [url absoluteURL];
    NSURL *urlWithoutQuery;
    if ([absoluteURL scheme] == nil) {
        NSString *path = [absoluteURL path];
        NSRange queryRange = [path rangeOfString:@"?"];
        if (queryRange.location != NSNotFound) {
            path = [path substringToIndex:queryRange.location];
        }
        return path;
    }
    urlWithoutQuery = [[NSURL alloc] initWithScheme:[[absoluteURL scheme] lowercaseString]
                                               host:[[absoluteURL host] lowercaseString]
                                               path:[absoluteURL path]];
    return [urlWithoutQuery absoluteString];
}

-(NSArray *)entriesMatchingRequestByURL:(NSURL *)url includesQuery:(BOOL)includesQuery inContext:(NSManagedObjectContext *)moc
{
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];

    NSEntityDescription *entity = [NSEntityDescription
                                   entityForName:@"CacheEntry" inManagedObjectContext:moc];
    [fetchRequest setEntity:entity];

    NSPredicate *predicate;
    if ([[[url absoluteURL] absoluteString] hasSuffix: @"configuration"]) {
        predicate = [NSPredicate predicateWithFormat:@"url == %@", [self urlWithoutQueryForUrl:url]];
    } else if (includesQuery) {
        predicate = [NSPredicate predicateWithFormat:@"(cacheName == %@) AND (url == %@) AND (query == %@)", [self name], [self urlWithoutQueryForUrl:url], url.query];
    } else {
        predicate = [NSPredicate predicateWithFormat:@"(cacheName == %@) AND (url == %@)", [self name], [self urlWithoutQueryForUrl:url]];
    }
    
    
    [fetchRequest setPredicate:predicate];
    BOOL isMainThread = [NSThread isMainThread];
    NSError *error;
    NSArray *entries = [moc executeFetchRequest:fetchRequest error:&error];
    
    if (error != nil) {
        NSLog(@"Failed to fetch entries for url %@ (%@) %@ %@", isMainThread ? @"YES" : @"NO", [self name], url, [error localizedDescription]);
    }

    
    
    // TODO: check error on entries == nil
    return entries;
}

-(ServiceWorkerResponse *)matchForRequest:(NSURLRequest *)request inContext:(NSManagedObjectContext *)moc
{
    return [self matchForRequest:request withOptions:@{} inContext:moc];
}

-(ServiceWorkerResponse *)matchForRequest:(NSURLRequest *)request withOptions:(/*ServiceWorkerCacheMatchOptions*/NSDictionary *)options inContext:(NSManagedObjectContext *)moc
{
    NSArray *candidateEntries = [self matchAllForRequest:request withOptions:options inContext:moc];
    if (candidateEntries == nil || candidateEntries.count == 0) {
        return nil;
    }
    
    ServiceWorkerCacheEntry *bestEntry = (ServiceWorkerCacheEntry *)candidateEntries[0];
    ServiceWorkerResponse *bestResponse = (ServiceWorkerResponse *)[NSKeyedUnarchiver unarchiveObjectWithData:bestEntry.response];
//    [TJ] TODO The call above is deprecated and should be converted to the below. Determine why the snippet below triggers an exception.
//    NSError *unarchiveError;
//    ServiceWorkerResponse *bestResponse = (ServiceWorkerResponse *)[NSKeyedUnarchiver unarchivedObjectOfClass:[ServiceWorkerResponse class] fromData: bestEntry.response error: &unarchiveError];
//    if (unarchiveError != nil) {
//        NSLog(@"Failed to decode response: %@ - %@", [[request URL] absoluteString], [unarchiveError description]);
//    }
    return bestResponse;
}

-(NSArray *)matchAllForRequest:(NSURLRequest *)request inContext:(NSManagedObjectContext *)moc
{
    return [self matchAllForRequest:request withOptions:@{} inContext:moc];
}

-(NSArray *)matchAllForRequest:(NSURLRequest *)request withOptions:(/*ServiceWorkerCacheMatchOptions*/NSDictionary *)options inContext:(NSManagedObjectContext *)moc
{
    BOOL query = [options[@"includeQuery"] boolValue];
    NSArray *entries = [self entriesMatchingRequestByURL:request.URL includesQuery:query inContext:moc];
    
    if (entries == nil || entries.count == 0) {
        return nil;
    }

    NSMutableArray *candidateEntries = [[NSMutableArray alloc] init];
    for (ServiceWorkerCacheEntry *entry in entries) {
        ServiceWorkerResponse *cachedResponse = (ServiceWorkerResponse *)[NSKeyedUnarchiver unarchiveObjectWithData:entry.response];
//        NSString *varyHeader = cachedResponse.headers[@"Vary"];
        NSString *varyHeader;
        BOOL candidateIsViable = YES;
        if (varyHeader != nil) {
            NSURLRequest *originalRequest = (NSURLRequest *)[NSKeyedUnarchiver unarchiveObjectWithData:entry.request];
            for (NSString *rawVaryHeaderField in [varyHeader componentsSeparatedByString:@","]) {
                NSString *varyHeaderField = [rawVaryHeaderField stringByTrimmingCharactersInSet:
                                  [NSCharacterSet whitespaceCharacterSet]];
                if (![[originalRequest valueForHTTPHeaderField:varyHeaderField] isEqualToString:[request valueForHTTPHeaderField:varyHeaderField]])
                    candidateIsViable = NO;
                    // Break out of the Vary header checks; continue with the next candidate response.
                    break;
            }
        }
        if (candidateIsViable) {
            [candidateEntries insertObject:entry atIndex:[candidateEntries count]];
        }
    }

    return candidateEntries;
}

-(void)putRequest:(NSURLRequest *)request andResponse:(ServiceWorkerResponse *)response inContext:(NSManagedObjectContext *)moc
{
    
    NSError *err;
    [self putRequest:request andResponse:response inContext:moc error:&err];
    if (err != nil) {
        NSLog(@"Failed to put request in cache: %@", [err description]);
    }
}

-(void)putRequest:(NSURLRequest *)request andResponse:(ServiceWorkerResponse *)response inContext:(NSManagedObjectContext *)moc error: (NSError * _Nullable *)error
{
    [moc performBlockAndWait:^{
    NSArray *entries  = [self entriesMatchingRequestByURL: request.URL includesQuery:NO inContext:moc];
    ServiceWorkerCacheEntry *entry;
    BOOL foundEntry;
    if (entries != nil && [entries count] >= 1) {
        entry = [entries objectAtIndex:0];
        foundEntry = true;
        NSLog(@"Cache.putRequest: overwrite existing entry %@", [request.URL absoluteString]);
    } else {
        entry = (ServiceWorkerCacheEntry *)[NSEntityDescription insertNewObjectForEntityForName:@"CacheEntry" inManagedObjectContext:moc];
        foundEntry = false;
    }
    entry.url = [self urlWithoutQueryForUrl:request.URL];
    entry.query = request.URL.query;
    entry.request = [NSKeyedArchiver archivedDataWithRootObject:request];
    entry.response = [NSKeyedArchiver archivedDataWithRootObject:response];
        @try {
            entry.cache = self;
        //    if (!(@available(iOS 13, *))) {
            entry.cacheName = self.name;
        //    }
            NSError *error = nil;
            if (![moc save:&error]) {
                NSLog(@"Failed to put request in cache. Entry Cache Name/Self Name: %@/%@ \n URL: %@ \n Replace Current Entry: %@ \n Error Description: %@ \n %@ \n Reason: %@", entry.cacheName, self.name, [entry url], foundEntry ? @"YES" : @"NO", [error localizedDescription], [error description], [error localizedFailureReason]);
                abort();
            }
        } @catch (NSException *e) {
            NSLog(@"Exception thrown while puting request with URL %@ \n %@", [entry url], [e reason]);
        }
    }];
}

-(bool)deleteRequest:(NSURLRequest *)request fromContext:(NSManagedObjectContext *)moc
{
    NSArray *entries = [self entriesMatchingRequestByURL:request.URL includesQuery:NO inContext:moc];
    
    bool requestExistsInCache = ([entries count] > 0);
    if (requestExistsInCache) {
        [moc deleteObject:entries[0]];
    }
    return requestExistsInCache;
}

-(NSArray *)requestsFromContext:(NSManagedObjectContext *)moc
{
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [NSEntityDescription
                                   entityForName:@"CacheEntry" inManagedObjectContext:moc];
    [fetchRequest setEntity:entity];
    NSError *error;
    NSArray *entries = [moc executeFetchRequest:fetchRequest error:&error];
    
    return entries;
}


@end

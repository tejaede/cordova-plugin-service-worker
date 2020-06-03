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


#import <JavaScriptCore/JavaScriptCore.h>
#import <Cordova/CDV.h>
#import "ServiceWorkerCacheApi.h"
#import "ServiceWorkerResponse.h"
#import <WebKit/WebKit.h>

NSString * const CORDOVA_ASSETS_CACHE_NAME = @"CordovaAssets";
NSString * const CORDOVA_ASSETS_VERSION_KEY = @"CordovaAssetsVersion";

static NSManagedObjectContext *moc;
static NSString *rootPath_;

@implementation ServiceWorkerCacheStorage

@synthesize caches=caches_;


-(id) initWithContext:(NSManagedObjectContext *)moc
{
    if ((self = [super init]) != nil) {
        NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];

        NSEntityDescription *entity = [NSEntityDescription
                                   entityForName:@"Cache" inManagedObjectContext:moc];
        [fetchRequest setEntity:entity];

        NSError *error;
        NSArray *entries = [moc executeFetchRequest:fetchRequest error:&error];

        // TODO: check error on entries == nil
        if (!entries) {
            entries = @[];
        }

        caches_ = [[NSMutableDictionary alloc] initWithCapacity:entries.count+2];
        for (ServiceWorkerCache *cache in entries) {
            caches_[cache.name] = cache;
        }
    }
    return self;
}

-(NSArray *)getCacheNames
{
    return [self.caches allKeys];
}

-(ServiceWorkerCache *)cacheWithName:(NSString *)cacheName create:(BOOL)create
{
    ServiceWorkerCache *cache = [self.caches objectForKey:cacheName];
    if (cache == nil) {
        // First try to get it from storage:
        NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];

        NSEntityDescription *entity = [NSEntityDescription
                                       entityForName:@"Cache" inManagedObjectContext:moc];
        [fetchRequest setEntity:entity];

        NSPredicate *predicate;

        predicate = [NSPredicate predicateWithFormat:@"(name == %@)", cacheName];
        [fetchRequest setPredicate:predicate];

        NSError *error;
        NSArray *entries = [moc executeFetchRequest:fetchRequest error:&error];
        if (entries.count > 0) {
        // TODO: HAVE NOT SEEN THIS BRANCH EXECUTE YET.
            cache = entries[0];
        } else if (create) {
            // Not there; add it
            cache = (ServiceWorkerCache *)[NSEntityDescription insertNewObjectForEntityForName:@"Cache"
                                                                        inManagedObjectContext:moc];
            [self.caches setObject:cache forKey:cacheName];
            cache.name = cacheName;
            NSError *err;
            [moc save:&err];
        }
    }
    if (cache) {
        // Cache the cache
        [self.caches setObject:cache forKey:cacheName];
    }
    return cache;
}

-(ServiceWorkerCache *)cacheWithName:(NSString *)cacheName
{
    return [self cacheWithName:cacheName create:YES];
}

-(BOOL)deleteCacheWithName:(NSString *)cacheName
{
    ServiceWorkerCache *cache = [self cacheWithName:cacheName create:NO];
    if (cache != nil) {
        [moc deleteObject:cache];
        NSError *err;
        [moc save:&err];
        if (err == nil) {
            [self.caches removeObjectForKey:cacheName];
            return YES;
        } else {
            NSLog(@"Failed to delete cache with name: %@", [err localizedDescription]);
        }
    }
    return NO;
}

-(BOOL)hasCacheWithName:(NSString *)cacheName
{
    return ([self cacheWithName:cacheName create:NO] != nil);
}

-(ServiceWorkerResponse *)matchForRequest:(NSURLRequest *)request
{
    return [self matchForRequest:request withOptions:@{}];
}

-(ServiceWorkerResponse *)matchForRequest:(NSURLRequest *)request withOptions:(/*ServiceWorkerCacheMatchOptions*/NSDictionary *)options
{
    ServiceWorkerResponse *response = nil;
    for (NSString* cacheName in self.caches) {
        ServiceWorkerCache* cache = self.caches[cacheName];
        response = [cache matchForRequest:request withOptions:options inContext:moc];
        if (response != nil) {
            break;
        }
    }
    return response;
}



@end

@implementation ServiceWorkerCacheApi

@synthesize cacheStorageMap = _cacheStorageMap;
@synthesize cacheCordovaAssets = _cacheCordovaAssets;
@synthesize absoluteScope = _absoluteScope;
NSString *baseURL;

static ServiceWorkerCacheApi *sharedInstance;
+ (id)sharedCacheApi {
    return sharedInstance;
}

- (void)pluginInitialize
{
    NSLog(@"ServiceWorkerCacheApi.pluginInitialize");
    self.absoluteScope = @"/";
    self.cacheCordovaAssets = false;
    [self initializeStorage];
}

-(void)onReset {
    CDVViewController *vc = (CDVViewController *)[self viewController];
    NSMutableDictionary *settings = [vc settings];
    NSString *applicationURL = [settings objectForKey:@"remoteapplicationurl"];
    if ([applicationURL hasSuffix: @"/"]) {
        applicationURL = [applicationURL substringToIndex: [applicationURL length] - 1];
    }
    if (applicationURL != nil) {
        baseURL = applicationURL;
    } else {
        baseURL = _absoluteScope;
    }
}


- (id)init {
    self = [super init];
    if (self) {
        sharedInstance = self;
        self.absoluteScope = @"/";
        self.cacheCordovaAssets = false;
    }
    return self;
}

-(id)initWithScope:(NSString *)scope cacheCordovaAssets:(BOOL)cacheCordovaAssets
{
    if (self = [super init]) {
        if (scope == nil) {
            self.absoluteScope = @"/";
        } else {
            self.absoluteScope = scope;
        }
        self.cacheCordovaAssets = cacheCordovaAssets;
    }
    return self;
}

+(NSManagedObjectModel *)createManagedObjectModel
{
    NSManagedObjectModel *model = [[NSManagedObjectModel alloc] init];

    NSMutableArray *entities = [NSMutableArray array];

    // ServiceWorkerCache
    NSEntityDescription *cacheEntity = [[NSEntityDescription alloc] init];
    cacheEntity.name = @"Cache";
    cacheEntity.managedObjectClassName = @"ServiceWorkerCache";

    //ServiceWorkerCacheEntry
    NSEntityDescription *cacheEntryEntity = [[NSEntityDescription alloc] init];
    cacheEntryEntity.name = @"CacheEntry";
    cacheEntryEntity.managedObjectClassName = @"ServiceWorkerCacheEntry";

    NSMutableArray *cacheProperties = [NSMutableArray array];
    NSMutableArray *cacheEntryProperties = [NSMutableArray array];

    // ServiceWorkerCache::name
    NSAttributeDescription *nameAttribute = [[NSAttributeDescription alloc] init];
    nameAttribute.name = @"name";
    nameAttribute.attributeType = NSStringAttributeType;
    nameAttribute.optional = NO;
    nameAttribute.indexed = YES;
    [cacheProperties addObject:nameAttribute];

    // ServiceWorkerCache::scope
    NSAttributeDescription *scopeAttribute = [[NSAttributeDescription alloc] init];
    scopeAttribute.name = @"scope";
    scopeAttribute.attributeType = NSStringAttributeType;
    scopeAttribute.optional = YES;
    scopeAttribute.indexed = NO;
    [cacheProperties addObject:scopeAttribute];

    // ServiceWorkerCacheEntry::url
    NSAttributeDescription *urlAttribute = [[NSAttributeDescription alloc] init];
    urlAttribute.name = @"url";
    urlAttribute.attributeType = NSStringAttributeType;
    urlAttribute.optional = YES;
    urlAttribute.indexed = YES;
    [cacheEntryProperties addObject:urlAttribute];

    // ServiceWorkerCacheEntry::query
    NSAttributeDescription *queryAttribute = [[NSAttributeDescription alloc] init];
    queryAttribute.name = @"query";
    queryAttribute.attributeType = NSStringAttributeType;
    queryAttribute.optional = YES;
    queryAttribute.indexed = YES;
    [cacheEntryProperties addObject:queryAttribute];

    // ServiceWorkerCacheEntry::request
    NSAttributeDescription *requestAttribute = [[NSAttributeDescription alloc] init];
    requestAttribute.name = @"request";
    requestAttribute.attributeType = NSBinaryDataAttributeType;
    requestAttribute.optional = NO;
    requestAttribute.indexed = NO;
    [cacheEntryProperties addObject:requestAttribute];

    // ServiceWorkerCacheEntry::response
    NSAttributeDescription *responseAttribute = [[NSAttributeDescription alloc] init];
    responseAttribute.name = @"response";
    responseAttribute.attributeType = NSBinaryDataAttributeType;
    responseAttribute.optional = NO;
    responseAttribute.indexed = NO;
    [cacheEntryProperties addObject:responseAttribute];


    // ServiceWorkerCache::entries
    NSRelationshipDescription *entriesRelationship = [[NSRelationshipDescription alloc] init];
    entriesRelationship.name = @"entries";
    entriesRelationship.destinationEntity = cacheEntryEntity;
    entriesRelationship.minCount = 0;
    entriesRelationship.maxCount = 0;
    entriesRelationship.deleteRule = NSCascadeDeleteRule;

    // ServiceWorkerCacheEntry::cache
    NSRelationshipDescription *cacheRelationship = [[NSRelationshipDescription alloc] init];
    cacheRelationship.name = @"cache";
    cacheRelationship.destinationEntity = cacheEntity;
    cacheRelationship.minCount = 0;
    cacheRelationship.maxCount = 1;
    cacheRelationship.deleteRule = NSNullifyDeleteRule;
    cacheRelationship.inverseRelationship = entriesRelationship;
    [cacheEntryProperties addObject:cacheRelationship];


    entriesRelationship.inverseRelationship = cacheRelationship;
    [cacheProperties addObject:entriesRelationship];

    cacheEntity.properties = cacheProperties;
    cacheEntryEntity.properties = cacheEntryProperties;
    
//    cacheEntryEntity.uniquenessConstraints =  [NSArray arrayWithObject:[NSArray arrayWithObject: @"url"]];
    cacheEntryEntity.uniquenessConstraints =  [NSArray arrayWithObject:[NSArray arrayWithObjects: @"url", @"cache", nil]];

    [entities addObject:cacheEntity];
    [entities addObject:cacheEntryEntity];

    model.entities = entities;
    return model;
}

-(BOOL)initializeStorage
{
    NSBundle* mainBundle = [NSBundle mainBundle];
    rootPath_ = [[NSURL fileURLWithPath:[mainBundle pathForResource:@"www" ofType:@"" inDirectory:@""]] absoluteString];

    if (moc == nil) {
        NSManagedObjectModel *model = [ServiceWorkerCacheApi createManagedObjectModel];
        NSPersistentStoreCoordinator *psc = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:model];

        NSError *err;
        NSFileManager *fm = [NSFileManager defaultManager];
        NSURL *documentsDirectoryURL = [fm URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:NO error:&err];
        NSURL *cacheDirectoryURL = [documentsDirectoryURL URLByAppendingPathComponent:@"CacheData"];
        [fm createDirectoryAtURL:cacheDirectoryURL withIntermediateDirectories:YES attributes:nil error:&err];
        NSURL *storeURL = [cacheDirectoryURL URLByAppendingPathComponent:@"swcache.db"];

        if (![fm fileExistsAtPath:[storeURL path]]) {
            NSLog(@"Service Worker Cache doesn't exist.");
            NSString *initialDataPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"CacheData"];
            BOOL cacheDataIsDirectory;
            if ([fm fileExistsAtPath:initialDataPath isDirectory:&cacheDataIsDirectory]) {
                if (cacheDataIsDirectory) {
                    NSURL *initialDataURL = [NSURL fileURLWithPath:initialDataPath isDirectory:YES];
                    NSLog(@"Copying Initial Cache.");
                    NSArray *fileURLs = [fm contentsOfDirectoryAtURL:initialDataURL includingPropertiesForKeys:nil options:0 error:&err];
                    for (NSURL *fileURL in fileURLs) {
                        [fm copyItemAtURL:fileURL toURL:cacheDirectoryURL error:&err];
                    }
                }
            }
        }

        NSLog(@"Using file %@ for service worker cache", [cacheDirectoryURL path]);
        err = nil;
        [psc addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:[NSURL URLWithString:@"swcache.db" relativeToURL:storeURL] options:nil error:&err];
        if (err) {
            // Try to delete the old store and try again
            [fm removeItemAtURL:[NSURL URLWithString:@"swcache.db" relativeToURL:storeURL] error:&err];
            [fm removeItemAtURL:[NSURL URLWithString:@"swcache.db-shm" relativeToURL:storeURL] error:&err];
            [fm removeItemAtURL:[NSURL URLWithString:@"swcache.db-wal" relativeToURL:storeURL] error:&err];
            err = nil;
            [psc addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:[NSURL URLWithString:@"swcache.db" relativeToURL:storeURL] options:nil error:&err];
            if (err) {
                return NO;
            }
        }
        moc = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
        moc.persistentStoreCoordinator = psc;

        // If this is the first run ever, or the app has been updated, populate the Cordova assets cache with assets from www/.
        if (self.cacheCordovaAssets) {
            NSString *cordovaAssetsVersion = [[NSUserDefaults standardUserDefaults] stringForKey:CORDOVA_ASSETS_VERSION_KEY];
            NSString *currentAppVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
            if (cordovaAssetsVersion == nil || ![cordovaAssetsVersion isEqualToString:currentAppVersion]) {
                // Delete the existing cache (if it exists).
                NSURL *scope = [NSURL URLWithString:self.absoluteScope];
                ServiceWorkerCacheStorage *cacheStorage = [self cacheStorageForScope:scope];
                [cacheStorage deleteCacheWithName:CORDOVA_ASSETS_CACHE_NAME];

                // Populate the cache.
                [self populateCordovaAssetsCache];

                // Store the app version.
                [[NSUserDefaults standardUserDefaults] setObject:currentAppVersion forKey:CORDOVA_ASSETS_VERSION_KEY];
            }
        }
    }

    return YES;
}

-(void)populateCordovaAssetsCache
{
    NSFileManager *fileManager = [[NSFileManager alloc] init];
    NSString *wwwDirectoryPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingString:@"/www"];
    NSURL *wwwDirectoryUrl = [NSURL fileURLWithPath:wwwDirectoryPath isDirectory:YES];
    NSArray *keys = [NSArray arrayWithObject:NSURLIsDirectoryKey];

    NSDirectoryEnumerator *enumerator = [fileManager
        enumeratorAtURL:wwwDirectoryUrl
        includingPropertiesForKeys:keys
        options:0
        errorHandler:^(NSURL *url, NSError *error) {
            // Handle the error.
            // Return YES if the enumeration should continue after the error.
            return YES;
        }
    ];

    // TODO: Prevent caching of sw_assets?
    for (NSURL *url in enumerator) {
        NSError *error;
        NSNumber *isDirectory = nil;
        if (![url getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:&error]) {
            // Handle error.
        } else if (![isDirectory boolValue]) {
            [self addToCordovaAssetsCache:url];
        }
    }
}

//TODO implement with URLSessionDataTask
-(void)addToCordovaAssetsCache:(NSURL *)url
{
    
    // Create an NSURLRequest.
//    NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:url];
//
//    // Ensure we're fetching purely.
//    // Create a connection and send the request.
//    FetchConnectionDelegate *delegate = [FetchConnectionDelegate new];
//    delegate.resolve = ^(ServiceWorkerResponse *response) {
//        // Get or create the specified cache.
//        NSURL *scope = [NSURL URLWithString:self.absoluteScope];
//        ServiceWorkerCacheStorage *cacheStorage = [self cacheStorageForScope:scope];
//        ServiceWorkerCache *cache = [cacheStorage cacheWithName:CORDOVA_ASSETS_CACHE_NAME];
//
//        // Create a URL request using a relative path.
//        NSMutableURLRequest *shortUrlRequest = [self nativeRequestFromDictionary:@{@"url": [url absoluteString]}];
//NSLog(@"Using short url: %@", shortUrlRequest.URL);
//
//        // Put the request and response in the cache.
//        [cache putRequest:shortUrlRequest andResponse:response inContext:moc];
//    };
//    [NSURLConnection connectionWithRequest:urlRequest delegate:delegate];
}

-(ServiceWorkerCacheStorage *)cacheStorageForScope:(NSURL *)scope
{
    if (self.cacheStorageMap == nil) {
        self.cacheStorageMap = [[NSMutableDictionary alloc] initWithCapacity:1];
    }
    [self initializeStorage];
    ServiceWorkerCacheStorage *cachesForScope = (ServiceWorkerCacheStorage *)[self.cacheStorageMap objectForKey:scope];
    if (cachesForScope == nil) {
        // TODO: Init this properly, using `initWithEntity:insertIntoManagedObjectContext:`.
        cachesForScope = [[ServiceWorkerCacheStorage alloc] initWithContext:moc];
        [self.cacheStorageMap setObject:cachesForScope forKey:scope];
    }
    return cachesForScope;
}

- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message
{
    NSString *handlerName = [self handlerNameForMessage:message];
//    NSString *messageName = [message name];
  
    //TODO Figure out why choosing selector by name is not working
    //    SEL s = NSSelectorFromString(handlerName);
    //    [self performSelector:s withObject: message];
    
    if ([handlerName isEqualToString:@"handleCacheMatchScriptMessage"]) {
        [self handleCacheMatchScriptMessage:message];
    } else if ([handlerName isEqualToString:@"handleCacheMatchAllScriptMessage"]) {
         [self handleCacheMatchAllMessage:message];
    } else if ([handlerName isEqualToString:@"handleCachePutScriptMessage"]) {
         [self handleCachePutScriptMessage:message];
    } else if ([handlerName isEqualToString:@"handleCacheDeleteScriptMessage"]) {
         [self handleCacheDeleteScriptMessage:message];
    } else if ([handlerName isEqualToString:@"handleCacheKeysScriptMessage"]) {
         [self handleCacheKeysMessage:message];
    } else if ([handlerName isEqualToString:@"handleCachesHasScriptMessage"]) {
         [self handleCachesHasScriptMessage :message];
    } else if ([handlerName isEqualToString:@"handleCachesDeleteScriptMessage"]) {
         [self handleCachesDeleteMessage :message];
    } else if ([handlerName isEqualToString:@"handleCachesKeysScriptMessage"]) {
         [self handleCachesKeysMessage :message];
    } else {
        NSLog(@"Cache API DidReceiveScriptMessage %@", handlerName);
    }
}

- (NSString *) handlerNameForMessage: (WKScriptMessage *) message {
    NSString *upperName = [[[message name] substringToIndex: 1] uppercaseString];
    upperName = [upperName stringByAppendingString:[[message name] substringFromIndex: 1]];
    return [NSString stringWithFormat: @"handle%@ScriptMessage", upperName];
}

- (NSURLRequest *) nativeRequestForScriptMessageParameter: (JSValue *) requestParameter {
    NSURLRequest *nativeRequest;
    if ([requestParameter isKindOfClass: [NSString class]]) {
        nativeRequest = [self nativeRequestFromDictionary:@{@"url" : requestParameter}];
    } else if ([requestParameter isKindOfClass:[NSDictionary class]]) {
        nativeRequest = [self nativeRequestFromDictionary: (NSDictionary *) requestParameter];
    } else {
        nativeRequest = [self nativeRequestFromJsRequest: requestParameter];
    }
    return nativeRequest;
}

- (void)handleCacheMatchScriptMessage: (WKScriptMessage *) message
{
    NSDictionary *body = [message  body];
    NSNumber *messageId = [body valueForKey:@"messageId"];
    NSString *cacheName = [body valueForKey:@"cacheName"];
    JSValue *request = [body valueForKey: @"request"];
    
    // Retrieve the caches.
    NSURL *scope = [NSURL URLWithString:self.absoluteScope];
    ServiceWorkerCacheStorage *cacheStorage = [self cacheStorageForScope:scope];

    // Convert the given request into an NSURLRequest.
    NSURLRequest *urlRequest = [self nativeRequestForScriptMessageParameter: request];
    
    


    // Check for a match in the cache.
    // TODO: Deal with multiple matches.
    ServiceWorkerResponse *cachedResponse;
    if (cacheName == nil) {
        cachedResponse = [cacheStorage matchForRequest:urlRequest];
    } else {
        cachedResponse = [[cacheStorage cacheWithName:cacheName] matchForRequest:urlRequest inContext:moc];
    }

    if (cachedResponse == nil) {
        NSString *urlString = [[urlRequest URL] absoluteString];
        if ([[[urlRequest URL] pathExtension] length] == 0) {
            request[@"url"] = [NSString stringWithFormat: @"%@index.html", urlString];
            urlRequest = [self nativeRequestForScriptMessageParameter: request];
            if (cacheName == nil) {
                cachedResponse = [cacheStorage matchForRequest:urlRequest];
            } else {
                cachedResponse = [[cacheStorage cacheWithName:cacheName] matchForRequest:urlRequest inContext:moc];
            }
            if (cachedResponse == nil) {
                request[@"url"] = [NSString stringWithFormat: @"%@/index.native.html", urlString];
                urlRequest = [self nativeRequestForScriptMessageParameter: request];
                if (cacheName == nil) {
                    cachedResponse = [cacheStorage matchForRequest:urlRequest];
                } else {
                    cachedResponse = [[cacheStorage cacheWithName:cacheName] matchForRequest:urlRequest inContext:moc];
                }
            }
            if (cachedResponse != nil) {
                cachedResponse.url = urlString;
            }
        }
    }
    
    if (cachedResponse != nil) {
        // Convert the response to a dictionary and send it to the promise resolver.
        NSDictionary *responseDictionary = [cachedResponse toDictionary];
        [self sendResultToWorker: messageId parameters: responseDictionary];
    } else {
        [self sendResultToWorker: messageId parameters: nil];
    }
}

- (void)handleCacheMatchAllMessage: (WKScriptMessage *) message
{
    NSDictionary *body = [message  body];
    
}

- (void)handleCachePutScriptMessage: (WKScriptMessage *) message
{
    NSDictionary *body = [message  body];
    NSNumber *messageId = [body valueForKey:@"messageId"];
    NSString *cacheName = [body valueForKey:@"cacheName"];
    JSValue *request = [body valueForKey: @"request"];
    JSValue *response = [body valueForKey: @"response"];
    
    
    NSURL *scope = [NSURL URLWithString:self.absoluteScope];
    ServiceWorkerCacheStorage *cacheStorage = [self cacheStorageForScope:scope];
    


    // Get or create the specified cache.
    ServiceWorkerCache *cache = [cacheStorage cacheWithName:cacheName];

    // Convert the given request into an NSURLRequest.
    NSURLRequest *urlRequest = [self nativeRequestForScriptMessageParameter: request];
    

    // Convert the response into a ServiceWorkerResponse.
    ServiceWorkerResponse *serviceWorkerResponse = [ServiceWorkerResponse responseFromJSValue:response];
    NSError *error;
    [cache putRequest:urlRequest andResponse:serviceWorkerResponse inContext:moc error: &error];
    [self sendResultToWorker: messageId parameters:nil withError: error];
}

- (void)handleCacheDeleteScriptMessage: (WKScriptMessage *) message
{
    NSDictionary *body = [message  body];
    NSURL *scope = [NSURL URLWithString:self.absoluteScope];
    ServiceWorkerCacheStorage *cacheStorage = [self cacheStorageForScope:scope];
    NSNumber *messageId = [body valueForKey:@"messageId"];
    NSString *cacheName = [body valueForKey:@"cacheName"];
    
    BOOL cacheDeleted = [cacheStorage deleteCacheWithName:cacheName];
    [self sendResultToWorker: messageId parameters:@{@"success": [NSNumber numberWithBool: cacheDeleted]}];
}

- (void)handleCacheKeysMessage: (WKScriptMessage *) message
{
    NSDictionary *body = [message  body];
}

- (void)handleCachesHasScriptMessage: (WKScriptMessage *) message
{
    NSDictionary *body = [message  body];
    NSNumber *messageId = [body valueForKey:@"messageId"];
    NSString *cacheName = [body valueForKey:@"cacheName"];
    NSURL *scope = [NSURL URLWithString:self.absoluteScope];
    ServiceWorkerCacheStorage *cacheStorage = [self cacheStorageForScope:scope];
    ServiceWorkerCache *cache = [cacheStorage cacheWithName:cacheName create:NO];
    
     [self sendResultToWorker: messageId parameters:@{@"result": [NSNumber numberWithBool: cache != nil]}];
}

- (void)handleCachesDeleteMessage: (WKScriptMessage *) message
{
    NSDictionary *body = [message  body];
}

- (void)handleCachesKeysMessage: (WKScriptMessage *) message
{
    NSDictionary *body = [message  body];
}

- (void) sendResultToWorker:(NSNumber*) messageId parameters:(NSDictionary *)parameters
{
    NSError *error;
    NSData *jsonData = nil;
    NSString *parameterString = @"undefined";
    if (parameters != nil) {
        jsonData = [NSJSONSerialization dataWithJSONObject:parameters options:NSJSONWritingPrettyPrinted error:&error];
        parameterString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    }
    

    NSString* cordovaCallbackScript = [NSString stringWithFormat:@"cordovaCallback(%@, %@);", messageId, parameterString];
    [_webView evaluateJavaScript:cordovaCallbackScript completionHandler:^(id result, NSError *error) {
        if (error != nil) {
            NSLog(@"Failed to run cordovaCallback due to error %@", [error localizedDescription]);
            NSLog(@"Script: %@", cordovaCallbackScript);
        }
    }];
}

- (void) sendResultToWorker:(NSNumber*) messageId parameters:(NSDictionary *)parameters withError: (NSError*) error {
    NSData *jsonData = nil;
    NSString *parameterString = @"undefined";
    if (parameters != nil) {
        jsonData = [NSJSONSerialization dataWithJSONObject:parameters options:NSJSONWritingPrettyPrinted error:&error];
        parameterString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    }
    NSString* cordovaCallbackScript = [NSString stringWithFormat:@"cordovaCallback(%@, %@, %@);", messageId, parameterString, error];
    [_webView evaluateJavaScript:cordovaCallbackScript completionHandler:^(id result, NSError *error) {
        if (error != nil) {
            NSLog(@"Failed to run cordovaCallback due to error %@", [error localizedDescription]);
            NSLog(@"Script: %@", cordovaCallbackScript);
        }
    }];
}

WKWebView *_webView = nil;
- (void)registerForJavascriptMessagesForWebView:(WKWebView *) webView
{
    _webView = webView;
    WKUserContentController *controller = webView.configuration.userContentController;
    [controller addScriptMessageHandler:self name:@"cacheMatch"];
    [controller addScriptMessageHandler:self name:@"cacheMatchAll"];
    [controller addScriptMessageHandler:self name:@"cachePut"];
    [controller addScriptMessageHandler:self name:@"cacheDelete"];
    [controller addScriptMessageHandler:self name:@"cacheKeys"];
    [controller addScriptMessageHandler:self name:@"cachesHas"];
    [controller addScriptMessageHandler:self name:@"cachesDelete"];
    [controller addScriptMessageHandler:self name:@"cachesKeys"];
}

- (void)put:(CDVInvokedUrlCommand*)command
{
    NSString *cacheName = [command argumentAtIndex:0];
    JSValue *request = [command argumentAtIndex: 1];
    JSValue *response = [command argumentAtIndex: 2];
    
    
    NSURL *scope = [NSURL URLWithString:self.absoluteScope];
    ServiceWorkerCacheStorage *cacheStorage = [self cacheStorageForScope:scope];

    // Get or create the specified cache.
    ServiceWorkerCache *cache = [cacheStorage cacheWithName:cacheName];

    // Convert the given request into an NSURLRequest.
    NSURLRequest *urlRequest = [self nativeRequestForScriptMessageParameter: request];
    NSLog(@"ServiceWorkerCacheApi.put (%@) - %@", cacheName, [[urlRequest URL] absoluteString]);
    ;
    
    // Convert the response into a ServiceWorkerResponse.
    ServiceWorkerResponse *serviceWorkerResponse = [ServiceWorkerResponse responseFromJSValue:response];
    NSError *error;
    [cache putRequest:urlRequest andResponse:serviceWorkerResponse inContext:moc error: &error];
    CDVPluginResult *result;
    if (error != nil) {
        NSLog(@"ServiceWorkerCacheApi.put failed: %@", [error description]);
        result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:[error localizedDescription]];
    } else {
        result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"OK"];
    }
    [result setKeepCallback:@(YES)];
    [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
}

NSString *internalCacheName = @"__cordova_sw_internal__";
- (void)putInternal:(NSURLRequest *)request response: (NSHTTPURLResponse *) response data: (NSData *) data {
    // Convert the response into a ServiceWorkerResponse.
    ServiceWorkerResponse *serviceWorkerResponse = [ServiceWorkerResponse responseWithHTTPResponse:response andBody: data];
    [self putInternal:request swResponse:serviceWorkerResponse];
}

- (ServiceWorkerResponse *)matchInternal:(NSURLRequest *)request {
    NSURL *scope = [NSURL URLWithString:self.absoluteScope];
    ServiceWorkerCacheStorage *cacheStorage = [self cacheStorageForScope:scope];
    ServiceWorkerCache *cache = [cacheStorage cacheWithName: internalCacheName];
    return [self matchRequest:request inCache: cache];
}

- (ServiceWorkerResponse *)matchRequest:(NSURLRequest *)request inCacheWithName: (NSString *) cacheName {
    NSURL *scope = [NSURL URLWithString:self.absoluteScope];
    ServiceWorkerCacheStorage *cacheStorage = [self cacheStorageForScope:scope];
    ServiceWorkerResponse *response;
    if (cacheName) {
        ServiceWorkerCache *cache = [cacheStorage cacheWithName: cacheName];
        response = [cache matchForRequest:request inContext:moc];
    } else {
       response = [cacheStorage matchForRequest:request];
    }
   
    return response;
}

- (void)putInternal:(NSURLRequest *)request swResponse: (ServiceWorkerResponse *) response {
    NSURL *scope = [NSURL URLWithString:self.absoluteScope];
    ServiceWorkerCacheStorage *cacheStorage = [self cacheStorageForScope:scope];
    ServiceWorkerCache *cache = [cacheStorage cacheWithName: internalCacheName];
    
    // Convert the response into a ServiceWorkerResponse.
    NSError *error;
    [cache putRequest:request andResponse:response inContext:moc];
    if (error != nil) {
        NSLog(@"Failed to put internal asset in cache - %@ %@", [[request URL] absoluteString], [error localizedDescription]);
    }
}


- (void)match:(CDVInvokedUrlCommand*)command
{
    NSString *cacheName = [command argumentAtIndex:0];
    JSValue *request = [command argumentAtIndex: 1];
    NSDictionary *options = [command argumentAtIndex: 2];

    // Retrieve the caches.
    NSURL *scope = [NSURL URLWithString:self.absoluteScope];
    ServiceWorkerCacheStorage *cacheStorage = [self cacheStorageForScope:scope];

    // Convert the given request into an NSURLRequest.
    NSURLRequest *urlRequest = [self nativeRequestForScriptMessageParameter: request];

    // Check for a match in the cache.
    // TODO: Deal with multiple matches.
    ServiceWorkerResponse *cachedResponse;
    if (cacheName == nil) {
        cachedResponse = [cacheStorage matchForRequest:urlRequest];
        
    } else {
        cachedResponse = [[cacheStorage cacheWithName:cacheName] matchForRequest:urlRequest inContext:moc];
    }

    NSLog(@"Main - Match: %@ %d", [[urlRequest URL] path], cachedResponse != nil);
    
    CDVPluginResult *result;
    if (cachedResponse != nil) {
        // Convert the response to a dictionary and send it to the promise resolver.
        NSDictionary *responseDictionary = [cachedResponse toDictionary];
        result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:responseDictionary];
    } else {
        result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:nil];
    }

    [result setKeepCallback:@(YES)];
    [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
}



- (void)matchAll:(CDVInvokedUrlCommand*)command
{
    NSString *cacheName = [command argumentAtIndex:0];
    NSDictionary *request = [command argumentAtIndex: 1];
    NSDictionary *options = [command argumentAtIndex: 2];
    NSLog(@"ServiceWorkerCacheAPI.matchAll: %@", cacheName);

    CDVPluginResult *result;
    result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:nil];
    [result setKeepCallback:@(YES)];
    [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
}

- (void)delete:(CDVInvokedUrlCommand*)command
{
    NSString *cacheName = [command argumentAtIndex:0];
    NSDictionary *request = [command argumentAtIndex: 1];
    NSDictionary *options = [command argumentAtIndex: 2];
    NSLog(@"ServiceWorkerCacheAPI.delete: %@", cacheName);

    CDVPluginResult *result;
    result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"OK"];
    [result setKeepCallback:@(YES)];
    [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
}


-(NSMutableURLRequest *)nativeRequestFromJsRequest:(JSValue *)jsRequest
{
    NSDictionary *requestDictionary = [jsRequest toDictionary];
    return [self nativeRequestFromDictionary:requestDictionary];
    
}

-(NSMutableURLRequest *)nativeRequestFromDictionary:(NSDictionary *)requestDictionary
{
    NSString *urlString = requestDictionary[@"url"];
    if ([urlString hasPrefix:rootPath_]) {
        urlString = [NSString stringWithFormat:@"%@%@", self.absoluteScope, [urlString substringFromIndex:[rootPath_ length]]];
    }
    return [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
}

#pragma Unit Testing

-(void) putRequest:(NSURLRequest *)request andResponse:(ServiceWorkerResponse *) response inCache:(ServiceWorkerCache *) cache
{
    [cache putRequest:request andResponse:response inContext:moc];
}

-(ServiceWorkerResponse *) matchRequest:(NSURLRequest *)request inCache:(ServiceWorkerCache *) cache
{
    if (cache != nil) {
        return [cache matchForRequest:request inContext:moc];
    } else {
        NSURL *scope = [NSURL URLWithString:self.absoluteScope];
        ServiceWorkerCacheStorage *cacheStorage = [self cacheStorageForScope:scope];
        return [cacheStorage matchForRequest:request];
    }
}

-(NSArray *) matchAllForRequest:(NSURLRequest *)request inCache:(ServiceWorkerCache *) cache
{
    return [cache matchAllForRequest:request inContext:moc];
}





@end


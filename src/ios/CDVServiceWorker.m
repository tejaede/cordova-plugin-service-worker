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

/* Foundation included so this module can be unit tested in swift*/
#import <Cordova/CDV.h>
#import <JavaScriptCore/JavaScriptCore.h>
#import <CommonCrypto/CommonDigest.h>
#import "CDVServiceWorker.h"
#import "ServiceWorkerCacheApi.h"
#import "ServiceWorkerRequest.h"
#import "CDVBackgroundSync.h"
#import "SWScriptTemplate.h"
#import "CDVWKWebViewEngine.h"
#import "CDVSWURLSchemeHandler.h"


NSString * const SERVICE_WORKER = @"serviceworker";
NSString * const SERVICE_WORKER_SCOPE = @"serviceworkerscope";
NSString * const SERVICE_WORKER_KEY_SHELL = @"serviceworkershell";
NSString * const SERVICE_WORKER_KEY_INTERNAL_CACHE_ENABLED = @"internalcacheenabled";
NSString * const SERVICE_WORKER_KEY_APPLICATION_URL = @"remoteapplicationurl";
NSString * const SERVICE_WORKER_KEY_URL_SCHEME = @"serviceworkerurlscheme";

NSString * const SERVICE_WORKER_ACTIVATED = @"ServiceWorkerActivated";
NSString * const SERVICE_WORKER_INSTALLED = @"ServiceWorkerInstalled";
NSString * const SERVICE_WORKER_SCRIPT_CHECKSUM = @"ServiceWorkerScriptChecksum";

NSString * const REGISTER_OPTIONS_KEY_SCOPE = @"scope";

NSString * const REGISTRATION_KEY_ACTIVE = @"active";
NSString * const REGISTRATION_KEY_INSTALLING = @"installing";
NSString * const REGISTRATION_KEY_REGISTERING_SCRIPT_URL = @"registeringScriptURL";
NSString * const REGISTRATION_KEY_SCOPE = @"scope";
NSString * const REGISTRATION_KEY_WAITING = @"waiting";

NSString * const SERVICE_WORKER_KEY_CLIENT_URL = @"clientURL";
NSString * const SERVICE_WORKER_KEY_SCRIPT_URL = @"scriptURL";

NSString * const DEFAULT_SERVICE_WORKER_SHELL = @"sw.html";

NSString * const SERVICE_WORKER_ASSETS_RELATIVE_PATH = @"www/sw_assets";

NSString * const SERVICE_WORKER_DEFAULT_URL_SCHEME = @"cordova-sw";

static bool isServiceWorkerActive = YES;




@implementation CDVServiceWorker

@synthesize backgroundSync = _backgroundSync;
@synthesize workerWebView = _workerWebView;
@synthesize registration = _registration;

@synthesize requestQueue = _requestQueue;
@synthesize cacheApi = _cacheApi;
@synthesize initiateHandler = _initiateHandler;

@synthesize swUrlScheme = _swUrlScheme;

CDVSWURLSchemeHandler *swUrlSchemeHandler;
CDVSWURLSchemeHandler *mainUrlSchemeHandler;
NSURL *_clientUrl = nil;
NSString *swShellFileName = nil;
NSString *swClientApplicationUrl = nil;
NSString *swClientApplicationVersion = nil;

bool internalCacheEnabled = YES;

NSSet *_urlsToDebug;
- (NSSet *) _urlsToDebug {
    if (_urlsToDebug == nil) {
        _urlsToDebug = [[NSSet alloc] initWithArray:@[
        ]];
    }
    return _urlsToDebug;
}

- (BOOL) shouldDebugURL: (NSURL *) url {
    NSString *urlString = [url absoluteString];
    return [self shouldDebugURLString: urlString];
}

- (BOOL) shouldDebugURLString: (NSString *) urlString {
    BOOL found = [[self _urlsToDebug] count] == 0;
    NSString *testString;
    for (testString in [self _urlsToDebug]) {
        found = found || [urlString containsString:testString];
    }
    return found;
}


- (void)onReset {
    NSLog(@"CDVServiceWorker.onReset");
}

SWScriptTemplate *cordovaCallbackTemplate;
SWScriptTemplate *createRegistrationTemplate;
SWScriptTemplate *definePolyfillIsReadyTemplate;
SWScriptTemplate *dispatchActivateEventTemplate;
SWScriptTemplate *dispatchFetchEventTemplate;
SWScriptTemplate *dispatchInstallEventTemplate;
SWScriptTemplate *postMessageTemplate;
SWScriptTemplate *resolvePolyfillIsReadyTemplate;

- (void) initializeScriptTemplates {
    cordovaCallbackTemplate = [[SWScriptTemplate alloc] initWithFilename:@"cordova-callback.js"];
    createRegistrationTemplate = [[SWScriptTemplate alloc] initWithFilename:@"create-registration.js"];
    definePolyfillIsReadyTemplate = [[SWScriptTemplate alloc] initWithFilename:@"define-polyfill-is-ready.js"];
    dispatchActivateEventTemplate = [[SWScriptTemplate alloc] initWithFilename:@"dispatch-activate-event.js"];
    dispatchFetchEventTemplate = [[SWScriptTemplate alloc] initWithFilename:@"dispatch-fetch-event.js"];
    dispatchInstallEventTemplate = [[SWScriptTemplate alloc] initWithFilename:@"dispatch-install-event.js"];
    postMessageTemplate = [[SWScriptTemplate alloc] initWithFilename:@"post-message.js"];
    resolvePolyfillIsReadyTemplate = [[SWScriptTemplate alloc] initWithFilename:@"resolve-polyfill-is-ready.js"];
}

- (void) parseServiceWorkerConfigurations
{
    CDVViewController *vc = (CDVViewController *)[self viewController];
    NSMutableDictionary *settings = [vc settings];
    
    NSString *configuredURLScheme =  [settings objectForKey:SERVICE_WORKER_KEY_URL_SCHEME];
    _swUrlScheme = configuredURLScheme != nil ? configuredURLScheme : SERVICE_WORKER_DEFAULT_URL_SCHEME;
    
    NSString *applicationURL =  [settings objectForKey:SERVICE_WORKER_KEY_APPLICATION_URL];
    applicationURL = [applicationURL stringByReplacingOccurrencesOfString:@"https" withString: _swUrlScheme];
    if ([applicationURL hasSuffix: @"/"]) {
        applicationURL = [applicationURL substringToIndex: [applicationURL length] - 1];
    }
    swClientApplicationUrl = applicationURL;
    swClientApplicationVersion = [applicationURL stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
    
    NSString *serviceWorkerShell =  [settings objectForKey:SERVICE_WORKER_KEY_SHELL];
    swShellFileName = serviceWorkerShell != nil ? serviceWorkerShell : DEFAULT_SERVICE_WORKER_SHELL;
    
    internalCacheEnabled = ![[[settings objectForKey: SERVICE_WORKER_KEY_INTERNAL_CACHE_ENABLED] lowercaseString] isEqualToString: @"false"];
}

- (void)pluginInitialize
{
    [self parseServiceWorkerConfigurations];

    [self initializeScriptTemplates];
    self.requestQueue = [NSMutableArray new];

    WKWebView *mainWebView = (WKWebView *)[[self webViewEngine] engineWebView];
    mainUrlSchemeHandler = [[mainWebView configuration] urlSchemeHandlerForURLScheme: _swUrlScheme];
    mainUrlSchemeHandler.queueHandler = self;
    mainUrlSchemeHandler.delegate = self;
    mainUrlSchemeHandler.scheme = _swUrlScheme;
    

    [self clearBrowserCache];
    [self createNewWorkerWebView];
}

-(void) createNewWorkerWebView {

    // Initialize CoreData for the Cache API.
    self.cacheApi = [[ServiceWorkerCacheApi alloc] initWithScope:@"/" internalCacheEnabled: internalCacheEnabled];
    [self.cacheApi initializeStorage];
    

    //Clean up existing webView
    if (self.workerWebView != nil) {
        [self.workerWebView removeFromSuperview];
        self.workerWebView = nil;
    }
    
    WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
    swUrlSchemeHandler =  [[CDVSWURLSchemeHandler alloc] init];
    swUrlSchemeHandler.delegate = self;
    swUrlSchemeHandler.scheme = _swUrlScheme;
    if (@available(iOS 11.0, *)) {
        [config setURLSchemeHandler:swUrlSchemeHandler forURLScheme:_swUrlScheme];
    } else {
        // Fallback on earlier versions
    }
    [config.preferences setValue:@YES forKey:@"allowFileAccessFromFileURLs"];
    self.workerWebView = [[WKWebView alloc] initWithFrame: CGRectMake(0, 0, 0, 0) configuration: config]; // Headless
    
    [self registerForJavascriptMessages];
    [self.cacheApi registerForJavascriptMessagesForWebView:[self workerWebView]];
    
    self.backgroundSync = [self.commandDelegate getCommandInstance:@"BackgroundSync"];
    self.backgroundSync.scriptRunner = self;
    

    [self.viewController.view addSubview:self.workerWebView];
    
    [self.workerWebView setUIDelegate:self];
    [self.workerWebView setNavigationDelegate:self];
    
    if (swClientApplicationUrl != nil) {
        NSURL *url = [NSURL URLWithString:swClientApplicationUrl];
        NSString *extension = [url pathExtension];
        if ([extension length] != 0) {
            url = [url URLByDeletingLastPathComponent];
        }
        url = [url URLByAppendingPathComponent:swShellFileName];
//        NSURLRequest *request = [NSURLRequest requestWithURL: url cachePolicy:NSURLRequestReturnCacheDataElseLoad timeoutInterval:60];
        NSURLRequest *request = [NSURLRequest requestWithURL: url cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:60];
        [self.workerWebView loadRequest:request];
    } else {
        NSURL* bundleURL = [NSURL fileURLWithPath:[[NSBundle mainBundle] bundlePath]];
        NSURL* swShellURL = [bundleURL URLByAppendingPathComponent: [NSString stringWithFormat:@"%@/%@", SERVICE_WORKER_ASSETS_RELATIVE_PATH, swShellFileName]];
        [self.workerWebView loadFileURL:swShellURL allowingReadAccessToURL:bundleURL];
    }
}


//Needs testing
-(void) clearBrowserCache {
    if (@available(iOS 11.3, *)) {
        NSSet *websiteDataTypes = [NSSet setWithArray:@[
            WKWebsiteDataTypeDiskCache,
            WKWebsiteDataTypeMemoryCache,
            WKWebsiteDataTypeFetchCache, //(iOS 11.3, *)
            //WKWebsiteDataTypeServiceWorkerRegistrations, //(iOS 11.3, *)
        ]];
        // All kinds of data
        // NSSet *websiteDataTypes = [WKWebsiteDataStore allWebsiteDataTypes];
        // Date from
        NSDate *dateFrom = [NSDate dateWithTimeIntervalSince1970:0];
        // Execute
        [[WKWebsiteDataStore defaultDataStore] removeDataOfTypes:websiteDataTypes modifiedSince:dateFrom completionHandler:^{
            NSLog(@"ClearedBrowserCache");
        }];
    } else {
        // Fallback on earlier versions
        NSSet *websiteDataTypes = [NSSet setWithArray:@[
            WKWebsiteDataTypeDiskCache,
            WKWebsiteDataTypeOfflineWebApplicationCache,
            WKWebsiteDataTypeMemoryCache,
            //WKWebsiteDataTypeLocalStorage,
            //WKWebsiteDataTypeCookies,
            //WKWebsiteDataTypeSessionStorage,
            //WKWebsiteDataTypeIndexedDBDatabases,
            //WKWebsiteDataTypeWebSQLDatabases,
            //WKWebsiteDataTypeServiceWorkerRegistrations, //(iOS 11.3, *)
        ]];
        // All kinds of data
        // NSSet *websiteDataTypes = [WKWebsiteDataStore allWebsiteDataTypes];
        // Date from
        NSDate *dateFrom = [NSDate dateWithTimeIntervalSince1970:0];
        // Execute
        [[WKWebsiteDataStore defaultDataStore] removeDataOfTypes:websiteDataTypes modifiedSince:dateFrom completionHandler:^{
            NSLog(@"ClearedBrowserCache");
        }];
    }
}

-(void) registerForJavascriptMessages
{
    WKUserContentController *controller = self.workerWebView.configuration.userContentController;
    [controller addScriptMessageHandler:self name:@"log"];
    [controller addScriptMessageHandler:self name:@"installServiceWorkerCallback"];
    [controller addScriptMessageHandler:self name:@"activateServiceWorkerCallback"];
    [controller addScriptMessageHandler:self name:@"fetchResponse"];
    [controller addScriptMessageHandler:self name:@"fetchDefault"];
    [controller addScriptMessageHandler:self name:@"trueFetch"];
    [controller addScriptMessageHandler:self name:@"polyfillIsReady"];
    [controller addScriptMessageHandler:self name:@"postMessage"];
    [controller addScriptMessageHandler:self name:@"registerSync"];
    [controller addScriptMessageHandler:self name:@"getSyncRegistrations"];
    [controller addScriptMessageHandler:self name:@"getSyncRegistration"];
    [controller addScriptMessageHandler:self name:@"serviceWorkerLoaded"];
    [controller addScriptMessageHandler:self name:@"syncResponse"];
    [controller addScriptMessageHandler:self name:@"unregisterSync"];
}

- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message
{
    NSString *handlerName = [self handlerNameForMessage:message];
    //TODO Figure out why choosing selector by name is not working
    //    SEL s = NSSelectorFromString(handlerName);
    //    [self performSelector:s withObject: message];
    if ([handlerName isEqualToString:@"handleLogScriptMessage"]) {
        [self handleLogScriptMessage:message];
    } else if ([handlerName isEqualToString:@"handleInstallServiceWorkerCallbackScriptMessage"]) {
         [self handleInstallServiceWorkerCallbackScriptMessage:message];
    } else if ([handlerName isEqualToString:@"handleActivateServiceWorkerCallbackScriptMessage"]) {
         [self handleActivateServiceWorkerCallbackScriptMessage:message];
    } else if ([handlerName isEqualToString:@"handleFetchResponseScriptMessage"]) {
         [self handleFetchResponseScriptMessage:message];
    } else if ([handlerName isEqualToString:@"handleTrueFetchScriptMessage"]) {
         [self handleTrueFetchScriptMessage:message];
    } else if ([handlerName isEqualToString:@"handleFetchDefaultScriptMessage"]) {
         [self handleFetchDefaultScriptMessage:message];
    } else if ([handlerName isEqualToString:@"handlePostMessageScriptMessage"]) {
         [self handlePostMessageScriptMessage:message];
    } else if ([handlerName isEqualToString:@"handleRegisterSyncScriptMessage"]) {
         [self handleRegisterSyncScriptMessage:message];
    } else if ([handlerName isEqualToString:@"handleGetSyncRegistrationsScriptMessage"]) {
         [self handleGetSyncRegistrationsScriptMessage:message];
    } else if ([handlerName isEqualToString:@"handleGetSyncRegistrationScriptMessage"]) {
         [self handleGetSyncRegistrationScriptMessage:message];
    }  else if ([handlerName isEqualToString:@"handleServiceWorkerLoadedScriptMessage"]) {
        [self handleServiceWorkerLoadedScriptMessage:message];
   } else if ([handlerName isEqualToString:@"handleSyncResponseScriptMessage"]) {
         [self handleSyncResponseScriptMessage:message];
    } else if ([handlerName isEqualToString:@"handleUnregisterSyncScriptMessage"]) {
         [self handleUnregisterSyncScriptMessage:message];
    } else if ([handlerName isEqualToString:@"handlePolyfillIsReadyScriptMessage"]) {
         [self handlePolyfillIsReadyScriptMessage:message];
    } else {
        NSLog(@"DidReceiveScriptMessage %@", handlerName);
    }
}


- (void) sendResultToWorker:(NSNumber*) messageId parameters:(NSDictionary *)parameters
{
    NSString* cordovaCallbackScript = [self makeCordovaCallbackScriptWith: messageId parameters: parameters andError: nil];
    [self evaluateScript:cordovaCallbackScript inWebView: self.workerWebView callback:nil];
}

- (void) sendResultToWorker:(NSNumber*) messageId parameters:(NSDictionary *)parameters withError: (NSError*) error {
    NSString* cordovaCallbackScript = [self makeCordovaCallbackScriptWith: messageId parameters: parameters andError: error];
    [self evaluateScript:cordovaCallbackScript inWebView: self.workerWebView callback:nil];
}

- (NSString *) convertResultParametersToString: (NSDictionary *) parameters {
    NSString *string;
    NSError *jsonError;
    NSData *jsonData;
    if (parameters == nil) {
        string = @"undefined";
    } else {
        jsonData = [NSJSONSerialization dataWithJSONObject:parameters options:NSJSONWritingPrettyPrinted error:&jsonError];
        string = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    }
    return string;
}

-(NSString *)makeCordovaCallbackScriptWith:(NSNumber *)messageId parameters:(NSDictionary *) parameters andError: (NSError *) error {
    NSString *parameterString = [self convertResultParametersToString: parameters];
    
    NSString *errorString;
    if (error == nil) {
        errorString = @"undefined";
    } else {
        errorString = [NSString stringWithFormat:@"'%@'", [error localizedDescription]];
    }

//    return [NSString stringWithFormat:@"try { cordovaCallback(%@, %@, %@); } catch (e) { console.error('Failed to call cordova callback');}", messageId, parameterString, errorString];
    return [NSString stringWithFormat:[cordovaCallbackTemplate content], messageId, parameterString, errorString];
}

- (NSString *) handlerNameForMessage: (WKScriptMessage *) message {
    NSString *upperName = [[[message name] substringToIndex: 1] uppercaseString];
    upperName = [upperName stringByAppendingString:[[message name] substringFromIndex: 1]];
    return [NSString stringWithFormat: @"handle%@ScriptMessage", upperName];
}

- (void)handleLogScriptMessage: (WKScriptMessage *) message
{
    NSLog(@"JS:SW %@", message.body);
}

- (void)handleInstallServiceWorkerCallbackScriptMessage: (WKScriptMessage *) message
{
    NSLog(@"Service Worker was installed. Trying to activate...");
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:SERVICE_WORKER_INSTALLED];
    [self activateServiceWorker];
}

- (void)handleActivateServiceWorkerCallbackScriptMessage: (WKScriptMessage *) message
{
    NSLog(@"Service Worker was activated. Trying to initiate...");
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:SERVICE_WORKER_ACTIVATED];
    [self initiateServiceWorker];
}

- (void)handleFetchResponseScriptMessage: (WKScriptMessage *) message
{
    NSDictionary *body = [message body];
    NSDictionary *response = [body valueForKey: @"response"];
    NSString *jsRequestId = [body valueForKey: @"requestId"];
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    [formatter setNumberStyle:NSNumberFormatterDecimalStyle];
    NSNumber *requestId = [formatter numberFromString:jsRequestId];
    
    NSString *responseBody = response[@"body"];
    NSData *data = [[NSData alloc] initWithBase64EncodedString:responseBody options:NSDataBase64DecodingIgnoreUnknownCharacters];
    if (data == nil) {
        data = [responseBody dataUsingEncoding:NSUTF8StringEncoding];
    }
    NSDictionary *headers = (NSDictionary *)response[@"headers"];
    NSNumber *status = response[@"status"];
//    NSString *url = [response[@"url"] toString]; // TODO: Can this ever be different than the request url? if not, don't allow it to be overridden
    NSString *url = response[@"url"];
    
    #ifdef DEBUG_SCHEME_HANDLER
        if ([self shouldDebugURLString: url]) {
            NSLog(@"handleFetchResponseScriptMessage - %@", url);
        }
    #endif
        
    NSHTTPURLResponse *urlResponse = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:url] statusCode:[status integerValue] HTTPVersion:@"2.0" headerFields:headers];
    
    [mainUrlSchemeHandler completeTaskWithId: requestId response: urlResponse data: data error:nil];
}

-(BOOL) isURLAPrecachedJavascriptFile: (NSURL *) url {
    NSArray *components = [url pathComponents];
    BOOL isDependency = [components containsObject: @"packages"];
    return isDependency && [self urlHasJavascriptExtension: url];
}

-(BOOL) isURLJavascriptDependency: (NSURL *) url {
    NSArray *components = [url pathComponents];
    BOOL isDependency = [components containsObject: @"node_modules"];
    return isDependency && [self urlHasJavascriptExtension: url];
}

-(BOOL) urlHasJavascriptExtension: (NSURL *) url {
    return [[url pathExtension] isEqualToString:@"js"];
}

- (void)handleTrueFetchScriptMessage: (WKScriptMessage *) message
{
    NSDictionary *body = [message body];
    NSNumber *messageId = [body valueForKey:@"messageId"];
    ServiceWorkerRequest *swRequest = [ServiceWorkerRequest requestWithDictionary: body];
    NSURLRequest *request = [swRequest outgoingRequest];
    NSURL *url = [request URL];
    // fetch() sent directly from the service worker thread does not
    // trigger a fetch event. This means the cache logic in the worker
    // does not have a chance to handle the request. The below
    // accounts for that by checking the cache.
    ServiceWorkerResponse *response;
    if (internalCacheEnabled) {
        response = [[self cacheApi] matchRequest:request inCache:nil];
    }
    if (response != nil) {
        NSDictionary *responseDict = [response toDictionary];
        [self sendResultToWorker:messageId parameters: responseDict];
        return;
    }
    BOOL isImportScriptRequest = [request valueForHTTPHeaderField:@"x-import-scripts"] != nil;
    BOOL isScriptOnFileSystem = [self isURLAPrecachedJavascriptFile:url];
    BOOL isJavascriptDependency = [self isURLJavascriptDependency:url];
    
    if ([[url path] containsString:@"cache-worker.js"]) {
        response = [self loadURLFromFileSystem: url];
    }// Specific to Contour Use Case
    else
        if (isScriptOnFileSystem && internalCacheEnabled) {
        response = [self loadURLFromFileSystem: url];
    } else if (isImportScriptRequest && internalCacheEnabled) {
        response = [[self cacheApi] matchInternal:request];
    } else if (isJavascriptDependency && internalCacheEnabled) {
        response = [[self cacheApi] matchInternal:request];
    }

    if (response != nil) {
        #ifdef DEBUG_SCHEME_HANDLER
            if ([self shouldDebugURL: url]) {
                NSLog(@"Return Cached True Fetch: %@", url);
            }
        #endif
        NSDictionary *responseDict = [response toDictionary];
        [self sendResultToWorker:messageId parameters: responseDict];
    } else {
        #ifdef DEBUG_SCHEME_HANDLER
            if ([self shouldDebugURL: url]) {
                NSLog(@"handleTrueFetchScriptMessage SEND - %@", [url absoluteString]);
            }
        #endif
        NSURLSession *session = [NSURLSession sharedSession];
        NSURLSessionDataTask *dataTask = [session dataTaskWithRequest:request completionHandler: ^(NSData *data, NSURLResponse *response, NSError *error) {
            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
            ServiceWorkerResponse *swResponse = [ServiceWorkerResponse responseWithHTTPResponse:httpResponse andBody:data];
            if (error != nil) {
                NSLog(@"True Fetch Failed: %@", [error localizedDescription]);
                [self sendResultToWorker:messageId parameters: nil withError: error];
            } else {
                if (isImportScriptRequest || isJavascriptDependency) {
                    #ifdef DEBUG_CACHE
                    if ([self shouldDebugURL: url]) {
                        NSLog(@"Cache Import Scripts: %@", url);
                    }
                    #endif
                    if (internalCacheEnabled) {
                        [[self cacheApi] putInternal:request swResponse:swResponse];
                    }
                }
                #ifdef DEBUG_SCHEME_HANDLER
                    if ([self shouldDebugURL: url]) {
                        NSLog(@"handleTrueFetchScriptMessage DONE %@", [url absoluteString]);
                    }
                #endif
                NSDictionary *responseDict = [swResponse toDictionary];
                [self sendResultToWorker:messageId parameters: responseDict];
            }
        }];
        [dataTask resume];
    }
}


- (ServiceWorkerResponse *) loadURLFromFileSystem: (NSURL *) url {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString* fsString = [[url path] stringByReplacingOccurrencesOfString:[_clientUrl path] withString:@""];
    NSData *content;
    ServiceWorkerResponse *response;
    fsString = [NSString stringWithFormat:@"/%@/www/app/%@", [[NSBundle mainBundle] resourcePath], fsString];
    if ([fileManager fileExistsAtPath:fsString]) {
        content = [NSData dataWithContentsOfFile:fsString];
        if (content != nil) {
            response = [[ServiceWorkerResponse alloc] initWithUrl:[url absoluteString] body:content status:@200 headers:[[NSDictionary alloc] init]];
        }
    }
    return response;
}

- (void)handleFetchDefaultScriptMessage: (WKScriptMessage *) message {
    NSDictionary *body = [message body];
    NSString *jsRequestId = [body valueForKey:@"requestId"];
    [mainUrlSchemeHandler sendRequestWithId: [NSNumber numberWithInteger: [jsRequestId integerValue]]];
}


- (BOOL)stringIsJavascriptStringLiteral: (NSString *) content {
    return ([content hasPrefix:@"\""] && [content hasSuffix:@"\""]);
}

- (void)handlePostMessageScriptMessage: (WKScriptMessage *) message {
    NSString *body = [message body];
    NSString *postMessageCode;
    WKWebView *mainWebView = (WKWebView *)[[self webViewEngine] engineWebView];

    if ([self stringIsJavascriptStringLiteral: body]) {
        postMessageCode = [NSString stringWithFormat:@"window.postMessage(%@, '*');'';", body];
    } else {
        postMessageCode = [NSString stringWithFormat:@"window.postMessage(Kamino.parse('%@'), '*');'';", body];
    }
    [self evaluateScript:postMessageCode inWebView:mainWebView callback: nil];
}


- (void)handleRegisterSyncScriptMessage: (WKScriptMessage *) message {
    NSDictionary *body = [message body];
    NSNumber *messageId = [body valueForKey:@"messageId"];
    NSString *syncType = [body valueForKey:@"type"];
    NSDictionary *options = [body valueForKey:@"registration"];
    [_backgroundSync registerSync: options withType: syncType];
    [self sendResultToWorker:messageId parameters: nil];
}

- (void)handleUnregisterSyncScriptMessage: (WKScriptMessage *) message {
    NSDictionary *body = [message body];
    NSNumber *messageId = [body valueForKey:@"messageId"];
    NSString *syncType = [body valueForKey:@"type"];
    NSString *tag = [body valueForKey:@"tag"];
    BOOL unregistered = [_backgroundSync unregisterSyncByTag: tag withType: syncType];
//    NSDictionary *result = [NSDictionary dictionaryWithValuesForKeys:[@"success", [NSNumber numberWithBool:unregistered]]];
    NSDictionary *result = [NSDictionary dictionaryWithObjectsAndKeys:@"success", [NSNumber numberWithBool:unregistered], nil];
    [self sendResultToWorker:messageId parameters: result];
}

- (void)handlePolyfillIsReadyScriptMessage: (WKScriptMessage *) message {
    #ifdef DEBUG_JAVASCRIPT
    [self createRegistrationWithExistingScript];
    #endif
}

- (void)handleGetSyncRegistrationScriptMessage: (WKScriptMessage *) message {
    NSDictionary *body = [message body];
    NSNumber *messageId = [body valueForKey:@"messageId"];
    NSString *syncType = [body valueForKey:@"type"];
    NSString *tag = [body valueForKey:@"tag"];
    NSDictionary *registrations = [_backgroundSync getRegistrationOfType:syncType andTag: tag];
    [self sendResultToWorker:messageId parameters:registrations];
}

- (void)handleGetSyncRegistrationsScriptMessage: (WKScriptMessage *) message {
    NSDictionary *body = [message body];
    NSNumber *messageId = [body valueForKey:@"messageId"];
    NSString *syncType = [body valueForKey:@"type"];
    NSDictionary *registrations = [_backgroundSync getRegistrationsOfType:syncType];
    [self sendResultToWorker:messageId parameters:registrations];
}

- (void)handleSyncResponseScriptMessage: (WKScriptMessage *) message {
    NSDictionary *body = [message body];
    NSNumber *responseType = [body valueForKey:@"type"];
    NSString *tag = [body valueForKey:@"tag"];
    
    [self.backgroundSync sendSyncResponse:responseType forTag:tag];
}

- (void)handlePeriodicSyncResponseScriptMessage: (WKScriptMessage *) message {
    NSDictionary *body = [message body];
    NSNumber *responseType = [body valueForKey:@"type"];
    NSString *tag = [body valueForKey:@"tag"];
    
    [self.backgroundSync sendPeriodicSyncResponse:responseType forTag:tag];
}


- (void)handleServiceWorkerLoadedScriptMessage: (WKScriptMessage *) message {
//    NSDictionary *body = [message body];
    NSLog(@"handleServiceWorkerLoadedScriptMessage");
    [self installServiceWorker: nil];
}

# pragma mark Cordova ServiceWorker Functions

- (void)restartWorker:(CDVInvokedUrlCommand*)command {
    [self createNewWorkerWebView];
}

- (void) registerWithURL:(NSString *) scriptUrl absoluteURL: (NSString *) absoluteScriptUrl andClientURL: (NSString *) clientURL handler: (void(^)(CDVPluginResult *))handler
{
    
        if (clientURL != nil) {
            NSString *setBaseURLCode = [NSString stringWithFormat: @"window.mainClientURL = '%@';", clientURL];
            [self evaluateScript: setBaseURLCode];
        }

        // The script url must be at the root.
        // TODO: Look into supporting non-root ServiceWorker scripts.
        // The provided scope is ignored; we always set it to the root.
        // TODO: Support provided scopes.
        NSString *scopeUrl = @"/";
        NSString *currentScriptURL = [self.registration valueForKey:REGISTRATION_KEY_REGISTERING_SCRIPT_URL];
        // If we have a registration on record, make sure it matches the attempted registration.
        // If it matches, return it.  If it doesn't, we have a problem!
        // If we don't have a registration on record, create one, store it, and return it.
        if (self.registration != nil && [currentScriptURL isEqualToString: absoluteScriptUrl]) {
            CDVPluginResult *pluginResult;
            if (![[self.registration valueForKey:REGISTRATION_KEY_SCOPE] isEqualToString:scopeUrl]) {
                pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                                                  messageAsString:@"The scope URL doesn't match the existing registration."];
            } else {
                NSLog(@"Return existing registration");
                pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:self.registration];
            }
            if (handler != nil) {
                handler(pluginResult);
            }
        } else {
            if (self.registration) {
                [self unregisterWorker];
            }
            
            NSLog(@"Create ServiceWorkerClient: %@", clientURL);
            [self createServiceWorkerClientWithUrl:clientURL];
            NSLog(@"Create ServiceWorkerRegistration: %@", absoluteScriptUrl);
            [self createServiceWorkerRegistrationWithScriptUrl:absoluteScriptUrl scopeUrl:scopeUrl];
            
            CDVServiceWorker * __weak weakSelf = self;
            _initiateHandler = ^() {
                CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:weakSelf.registration];
                if (handler != nil) {
                    handler(pluginResult);
                }
            };
            NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
            [defaults setValue:absoluteScriptUrl forKey:REGISTRATION_KEY_REGISTERING_SCRIPT_URL];
            NSLog(@"Load ServiceWorkerScript: %@ %@", absoluteScriptUrl, clientURL);
            [self createServiceWorkerFromScript:absoluteScriptUrl clientUrl:clientURL];
        }
            
}

- (void)register:(CDVInvokedUrlCommand*)command
{
    NSString *scriptUrl = [command argumentAtIndex:0];
//    NSDictionary *options = [command argumentAtIndex:1];
    NSString *absoluteScriptUrl = [command argumentAtIndex:2];
    NSString *clientURL = [absoluteScriptUrl stringByReplacingOccurrencesOfString:scriptUrl   withString:@""];
    NSLog(@"Register service worker: %@ (for client: %@)", scriptUrl, clientURL);
    
    [self registerWithURL: scriptUrl absoluteURL: absoluteScriptUrl andClientURL: clientURL handler: ^(CDVPluginResult * result) {
        [[self commandDelegate] sendPluginResult: result callbackId:[command callbackId]];
    }];
}

- (void)unregister:(CDVInvokedUrlCommand*)command
{
    
    NSString *scriptUrl = [command argumentAtIndex:0];
    NSString *scope = [command argumentAtIndex:1];
    NSLog(@"Unregister SW at script URL: %@", scriptUrl);
    [self unregisterWorker];
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:self.registration];
    [[self commandDelegate] sendPluginResult:pluginResult callbackId:[command callbackId]];
}

- (void)unregisterWorker {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults removeObjectForKey:REGISTRATION_KEY_REGISTERING_SCRIPT_URL];
    self.registration = nil;
    [self createNewWorkerWebView];
}

- (void)createServiceWorkerRegistrationWithScriptUrl:(NSString*)scriptUrl scopeUrl:(NSString*)scopeUrl
{
    NSDictionary *serviceWorker = [NSDictionary dictionaryWithObject:scriptUrl forKey:SERVICE_WORKER_KEY_SCRIPT_URL];
    // TODO: Add a state to the ServiceWorker object.

    NSArray *registrationKeys = @[REGISTRATION_KEY_INSTALLING,
                                  REGISTRATION_KEY_WAITING,
                                  REGISTRATION_KEY_ACTIVE,
                                  REGISTRATION_KEY_REGISTERING_SCRIPT_URL,
                                  REGISTRATION_KEY_SCOPE];
    NSArray *registrationObjects = @[[NSNull null], [NSNull null], serviceWorker, scriptUrl, scopeUrl];
    self.registration = [NSDictionary dictionaryWithObjects:registrationObjects forKeys:registrationKeys];
    NSString *createRegistrationScript = [NSString stringWithFormat:[createRegistrationTemplate content], scriptUrl];
    NSLog(@"%@", createRegistrationScript);
    [self evaluateScript:createRegistrationScript];
}

- (void)serviceWorkerReady:(CDVInvokedUrlCommand*)command
{
    // The provided scope is ignored; we always set it to the root.
    // TODO: Support provided scopes.
    NSString *scopeUrl = @"/";
    NSString *scriptUrl =  [self.registration valueForKey:REGISTRATION_KEY_REGISTERING_SCRIPT_URL];

    if (isServiceWorkerActive) {
        NSLog(@"Service Worker is active. Completing registration");
        if (self.registration == nil) {
            [self createServiceWorkerRegistrationWithScriptUrl:scriptUrl scopeUrl:scopeUrl];
        }
        // Return the registration.
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:self.registration];
        [[self commandDelegate] sendPluginResult:pluginResult callbackId:[command callbackId]];
    } else {
        NSLog(@"Service Worker is NOT active. Unable to complete registration");
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                                          messageAsString:@"No Service Worker is currently active."];
        [[self commandDelegate] sendPluginResult:pluginResult callbackId:[command callbackId]];
    }
}


- (void)postMessage:(CDVInvokedUrlCommand*)command
{
    NSString *message = [command argumentAtIndex:0];
    NSData *data = [message dataUsingEncoding:NSUTF8StringEncoding];
    message = [data base64EncodedStringWithOptions:NSUTF8StringEncoding];
    NSString *dispatchCode = [NSString stringWithFormat:[postMessageTemplate content], message];
    [self evaluateScript:dispatchCode];
}

- (void)installServiceWorker:(void(^)())handler
{
    if (handler != nil) {
        _initiateHandler = handler;
    }
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:SERVICE_WORKER_INSTALLED];
    [self evaluateScript:[dispatchInstallEventTemplate content]];
}

- (void)activateServiceWorker
{
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:SERVICE_WORKER_ACTIVATED];
    [self evaluateScript:[dispatchActivateEventTemplate content]];
}

- (void)initiateServiceWorker
{
    isServiceWorkerActive = YES;
    NSLog(@"Initiating Service Worker. Processing request queue.");
    if (_initiateHandler != nil) {
        _initiateHandler();
        _initiateHandler = nil;
    }
    [self processRequestQueue];
}


# pragma mark Helper Functions

- (void)evaluateScript:(NSString *)script
{
    [self evaluateScript:script inWebView: self.workerWebView callback: nil];
}

- (void)evaluateScript:(NSString *)script inWebView: (WKWebView *) webView callback:(void(^)(NSString *result, NSError *error)) callback
{
    if ([NSThread isMainThread]) {
        [self evaluateScriptInMainThread:script inWebView: webView callback:callback];
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self evaluateScriptInMainThread:script inWebView: webView callback:callback];
        });
    }
}

- (void)evaluateScriptInMainThread:(NSString *)script inWebView: (WKWebView *) webView callback:(void(^)(NSString *result, NSError *error)) callback {
    NSString *viewName = webView == [self workerWebView] ? @"ServiceWorker" : @"Main";
    [webView evaluateJavaScript:script completionHandler:^(NSString *result, NSError *error) {
        if (error != nil) {
            if (![[error description] containsString:@"JavaScript execution returned a result of an unsupported type"]) {
                if (error.localizedDescription != nil) {
                    NSLog(@"CDVServiceWorker failed to evaluate script in (%@) webView with error: %@", viewName, error.localizedDescription);
                } else {
                    NSLog(@"CDVServiceWorker failed to evaluate script in (%@) webView with error: %@", viewName, error.description);
                }
                
                NSLog(@"Failed Script: %@", script);
            }
        }
        if (callback != nil) {
            callback(result, error);
        }
    }];
}

- (void)createServiceWorkerFromScript:(NSString *)script clientUrl:(NSString*)clientUrl
{
    _clientUrl = [NSURL URLWithString: clientUrl];
   mainUrlSchemeHandler.allowedOrigin = [_clientUrl host];
   NSString *originalLoader = [self readScriptAtRelativePath:@"www/load_sw.js"];
   NSString *processedLoader = [originalLoader stringByReplacingOccurrencesOfString:@"{{SERVICE_WORKER_PATH}}" withString:script];
   [self loadScript:processedLoader];
}

- (void)createServiceWorkerClientWithUrl:(NSString *)url
{
    // Create a ServiceWorker client.
    NSString *createClientCode = [NSString stringWithFormat:@"var client = new Client('%@');", url];
    [self evaluateScript:createClientCode];
}

- (NSString *)readScriptAtRelativePath:(NSString *)relativePath
{
    // NOTE: Relative path means relative to the app bundle.

    // Compose the absolute path.
    NSString *absolutePath = [[[NSBundle mainBundle] resourcePath] stringByAppendingString:[NSString stringWithFormat:@"/%@", relativePath]];
    NSString *script;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath: absolutePath]) {
        NSError *error;
        script = [NSString stringWithContentsOfFile:absolutePath encoding:NSUTF8StringEncoding error:&error];
        if (error) {
            NSLog(@"Could not read script: %@", [error description]);
        }
    }

    // Return our script!
    return script;
}

- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    decisionHandler(WKNavigationActionPolicyAllow);
}

- (void)webView:(WKWebView *)webView decidePolicyForNavigationResponse:(WKNavigationResponse *)navigationResponse decisionHandler:(void (^)(WKNavigationResponsePolicy))decisionHandler {
    decisionHandler(WKNavigationResponsePolicyAllow);
}

- (void) webView: (WKWebView *) webView didReceiveAuthenticationChallenge: (NSURLAuthenticationChallenge *) challenge completionHandler:(nonnull void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential * _Nullable))completionHandler {
    NSURLCredential * credential = [[NSURLCredential alloc] initWithTrust:[challenge protectionSpace].serverTrust];
    completionHandler(NSURLSessionAuthChallengeUseCredential, credential);
}


- (void)loadServiceWorkerAssetsIntoContext
{
    NSArray *baseSWAssetFileNames = [[NSArray alloc] initWithObjects:
        @"client.js",
        @"cordova-bridge.js",
        @"event.js",
        @"fetch.js",
        @"import-scripts.js",
        @"kamino.js",
        @"message.js",
        @"cache.js",
        @"service_worker_container.js",
        @"service_worker_registration.js",
    nil];
    // Specify the assets directory.e
    // TODO: Move assets up one directory, so they're not in www.
    NSString *assetDirectoryPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingString:@"/www/sw_assets"];
    
    // Get the list of assets.
    NSArray *assetFilenames = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:assetDirectoryPath error:NULL];
    NSPredicate *notInBasePredicate = [NSPredicate predicateWithFormat:@"NOT(SELF IN %@)", baseSWAssetFileNames];
    NSArray *supplementarySWAssetFileNames = [assetFilenames filteredArrayUsingPredicate: notInBasePredicate];
    

    BOOL useScriptTags = NO;
    #ifdef DEBUG_JAVASCRIPT
        useScriptTags = YES;
    #endif
    if (useScriptTags) {
        [self loadServiceWorkerAssetsInContextWithScriptTags:baseSWAssetFileNames supplementary:supplementarySWAssetFileNames];
    } else {
        [self evaluateServiceWorkerAssetsInContextDirectly:baseSWAssetFileNames supplementary:supplementarySWAssetFileNames];
    }
}

- (void)evaluateServiceWorkerAssetsInContextDirectly: (NSArray *) baseScripts supplementary: (NSArray *) supplementaryScripts {
    NSString *fileName;
    NSString *relativePath;
    NSString *script;
    [self evaluateScript:[definePolyfillIsReadyTemplate content] inWebView: self.workerWebView callback: nil];
    
    for (fileName in baseScripts) {
        NSLog(@"load base sw asset: %@", fileName);
        relativePath = [NSString stringWithFormat:@"www/sw_assets/%@", fileName];
        script = [self readScriptAtRelativePath: relativePath];
        [self evaluateScript:script];
    }
    for (fileName in supplementaryScripts) {
        if (![fileName isEqualToString:@"log.js"]) {
            NSLog(@"load supplemental sw asset: %@", fileName);
            relativePath = [NSString stringWithFormat:@"www/sw_assets/%@", fileName];
            script = [self readScriptAtRelativePath:relativePath];
            [self evaluateScript:script];
        }
    }
    [self evaluateScript: [resolvePolyfillIsReadyTemplate content]];
}

- (void)loadServiceWorkerAssetsInContextWithScriptTags: (NSArray *) baseScripts supplementary: (NSArray *) supplementaryScripts {
    NSString *loadSWScript = [self readScriptAtRelativePath:@"www/load_sw_assets.js"];
    NSArray *allScripts = [NSArray arrayWithObject:@"define-polyfill-is-ready.js"];
    allScripts = [allScripts arrayByAddingObjectsFromArray: [baseScripts arrayByAddingObjectsFromArray:supplementaryScripts]];
    NSString *scriptList = [allScripts componentsJoinedByString:@"',\n'"];
    scriptList = [NSString stringWithFormat:@"'%@'", scriptList];
    
    loadSWScript = [loadSWScript stringByReplacingOccurrencesOfString:@"{{SW_ASSETS}}" withString: scriptList];
    [self evaluateScript: loadSWScript];
}

- (void)loadScript:(NSString *)script
{
    // Evaluate the script.
    [self evaluateScript:script];
}

- (void)webViewWebContentProcessDidTerminate:(WKWebView *)webView {
    [webView reload];
}



- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation
{
    NSLog(@"Worker WebView didFinishNavigation - %@", [[webView URL] absoluteString]);
    // Load the Service Worker polyfillse
    [self loadServiceWorkerAssetsIntoContext];
    mainUrlSchemeHandler.allowedOrigin = [[webView URL] host];

    #ifndef DEBUG_JAVASCRIPT
    [self createRegistrationWithExistingScript];
    #endif
}

- (void) createRegistrationWithExistingScript {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *serviceWorkerScriptURL = [defaults stringForKey:REGISTRATION_KEY_REGISTERING_SCRIPT_URL];
    if (serviceWorkerScriptURL != nil) {
        NSURL *url = [NSURL URLWithString: serviceWorkerScriptURL];
        NSString *relativeURL = [[url pathComponents] lastObject];
        NSString *savedClientURL = [serviceWorkerScriptURL stringByReplacingOccurrencesOfString:relativeURL withString:@""];
        NSString *currentClientURL = [[[_workerWebView URL] URLByDeletingLastPathComponent] absoluteString];
        if ([savedClientURL isEqualToString: currentClientURL]) {
//            NSLog(@"Existing Service Worker Registration URL %@ %@ %@", serviceWorkerScriptURL, relativeURL, currentClientURL);
            NSLog(@"Initialize Cached Registration - \n   script: %@\n   client: %@", serviceWorkerScriptURL, currentClientURL);
            [self registerWithURL:relativeURL absoluteURL:serviceWorkerScriptURL andClientURL:currentClientURL handler:nil];
        } else {
            NSLog(@"Initialize Cached Registration - Cached SW client URL does not match current client URL.\n   cached: %@\n   current: %@", savedClientURL, currentClientURL);
        }
    }
}

- (void) webView: (WKWebView *) webView didFailLoadWithError:(nonnull NSError *)error {
    NSLog(@"WorkerWebView didFailLoadWithError - %@", [[webView URL] absoluteString]);
}

NSSet *autoCacheFileNames;
- (BOOL) shouldAutoCacheRequest: (NSURLRequest *) request {
    NSString *fileName = [[request URL] lastPathComponent];
    if (autoCacheFileNames == nil) {
        autoCacheFileNames = [NSSet setWithArray: @[@"sw.html", @"worker-bootstrap.js", @"index.native.html", @"alt-host.json"]];
    }
    return [autoCacheFileNames containsObject: fileName];
}

- (void)urlSchemeHandlerDidReceiveResponse: (NSHTTPURLResponse *) response withData: (NSData *) data forRequest: (NSURLRequest *) request {
//    NSLog(@"ServiceWorker.urlSchemeHandlerDidReceiveResponse: %@ %@", [[request URL] absoluteString], [[response URL] absoluteString]);
    
    // worker bootstrap.js, index.native.html, and alt-host.json are specific to contour
    if (([response statusCode] == 200) && [self shouldAutoCacheRequest:request]) {
        NSLog(@"[CDVServiceWorker] Auto-cache Response %@", [[request URL] absoluteString]);
        [[self cacheApi] putInternal:request response:response data:data];
    }
}

- (ServiceWorkerResponse *)urlSchemeHandlerWillSendRequest: (NSURLRequest *) request {
    #ifdef DEBUG_SCHEME_HANDLER
    if ([self shouldDebugURL:[request URL]]) {
        NSLog(@"urlSchemeHandlerWillSendRequest: %@", [[request URL] absoluteString]);
    }
    #endif
    ServiceWorkerResponse *response;
    #ifdef DEBUG_JAVASCRIPT
     NSURL *baseURL = [[_workerWebView URL] URLByDeletingLastPathComponent];
    if (baseURL != nil) {
        NSString *baseURLPath = [baseURL path];
        NSString *relativePath = [[[request URL] path] stringByReplacingOccurrencesOfString:baseURLPath withString:@""];
       if ([relativePath characterAtIndex: 0] == '/') {
           relativePath = [relativePath substringFromIndex: 1];
       }
        NSString *localPath = [NSString stringWithFormat:@"www/sw_assets/%@", relativePath];
        NSString *script = [self readScriptAtRelativePath: localPath];
       if (script == nil) {
           localPath = [NSString stringWithFormat:@"www/sw_templates/%@", relativePath];
           script = [self readScriptAtRelativePath: localPath];
       }
       if (script != nil) {
           NSData *data = [script dataUsingEncoding:NSUTF8StringEncoding];
           response = [[ServiceWorkerResponse alloc] initWithUrl: [[request URL] absoluteString] body:data status:@200 headers:[[NSDictionary alloc] init]];
           return response;
       }
    }
    
    #endif
    if (internalCacheEnabled) {
        response = [[self cacheApi] matchInternal:request];
        #ifdef DEBUG_CACHE
        if ([self shouldDebugURL:[request URL]]) {
            NSLog(@"Response Found For Request: %@ %@", response == nil ? @"NO" : @"YES", [[request URL] absoluteString]);
        }
        #endif
    }
    return response;
}


- (Boolean)addRequestToQueue:(ServiceWorkerRequest *) swRequest {
    if (_registration != nil) {
        // Add the request object to the queue.
        [self.requestQueue addObject:swRequest];

        // Process the request queue.
        [self processRequestQueue];
        return YES;
    } else {
        return NO;
    }
}

-(Boolean)canAddToQueue {
    return _registration != nil;
}

- (void)processRequestQueue {
    // If the ServiceWorker isn't active, there's nothing we can do yet.

    if (!isServiceWorkerActive) {
        NSLog(@"CDVServiceWorker cannot process the request queue until the worker is active");
        return;
    }

    for (ServiceWorkerRequest *swRequest in self.requestQueue) {
        // Log!
        #ifdef DEBUG_SCHEME_HANDLER
        if ([self shouldDebugURL: [swRequest.schemedRequest URL]]) {
            NSLog(@"Processing from queue: %@", [[swRequest.schemedRequest URL] absoluteString]);
        }
        #endif

        // Fire a fetch event in the JSContext.
        NSURLRequest *request = swRequest.schemedRequest;
        NSString *method = [request HTTPMethod];
        NSString *url = [[request URL] absoluteString];

        url = [url stringByReplacingOccurrencesOfString:@"'" withString:@"\'"];
        NSData *headerData = [NSJSONSerialization dataWithJSONObject:[request allHTTPHeaderFields]
                                                             options:NSJSONWritingPrettyPrinted
                                                               error:nil];
        NSString *headers = [[[NSString alloc] initWithData:headerData encoding:NSUTF8StringEncoding] stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
        NSString *dispatchCode = [NSString stringWithFormat:[dispatchFetchEventTemplate content], method, url, headers, [swRequest.requestId longLongValue]];
        [self evaluateScript:dispatchCode];
    }

    // Clear the queue.
    // TODO: Deal with the possibility that requests could be added during the loop that we might not necessarily want to remove.
    [self.requestQueue removeAllObjects];
}

- (NSString *)hashForString:(NSString *)string
{
    const char *cstring = [string UTF8String];
    size_t length = strlen(cstring);

    // We're assuming below that CC_LONG is an unsigned int; fail here if that's not true.
    assert(sizeof(CC_LONG) == sizeof(unsigned int));

    unsigned char hash[33];

    CC_MD5_CTX hashContext;

    // We'll almost certainly never see >4GB files, but loop with UINT32_MAX sized-chunks just to be correct
    CC_MD5_Init(&hashContext);
    CC_LONG dataToHash;
    while (length != 0) {
        if (length > UINT32_MAX) {
            dataToHash = UINT32_MAX;
            length -= UINT32_MAX;
        } else {
            dataToHash = (CC_LONG)length;
            length = 0;
        }
        CC_MD5_Update(&hashContext, cstring, dataToHash);
        cstring += dataToHash;
    }
    CC_MD5_Final(hash, &hashContext);

    // Construct a simple base-16 representation of the hash for comparison
    for (int i=15; i >= 0; --i) {
        hash[i*2+1] = 'a' + (hash[i] & 0x0f);
        hash[i*2] = 'a' + ((hash[i] >> 4) & 0x0f);
    }
    // Null-terminate
    hash[32] = 0;

    return [NSString stringWithCString:(char *)hash
                                          encoding:NSUTF8StringEncoding];
}

@end


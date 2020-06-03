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
#import "FetchConnectionDelegate.h"
#import "FetchInterceptorProtocol.h"
#import "ServiceWorkerCacheApi.h"
#import "ServiceWorkerRequest.h"
#import "CDVBackgroundSync.h"
#import "SWScriptTemplate.h"
#import "CDVWKWebViewEngine.h"
#import "CDVSWURLSchemeHandler.h"

static bool isServiceWorkerActive = NO;


NSString * const SERVICE_WORKER = @"serviceworker";
NSString * const SERVICE_WORKER_SCOPE = @"serviceworkerscope";
NSString * const SERVICE_WORKER_CACHE_CORDOVA_ASSETS = @"cachecordovaassets";
NSString * const SERVICE_WORKER_ACTIVATED = @"ServiceWorkerActivated";
NSString * const SERVICE_WORKER_INSTALLED = @"ServiceWorkerInstalled";
NSString * const SERVICE_WORKER_SCRIPT_CHECKSUM = @"ServiceWorkerScriptChecksum";

NSString * const REGISTER_OPTIONS_KEY_SCOPE = @"scope";

NSString * const REGISTRATION_KEY_ACTIVE = @"active";
NSString * const REGISTRATION_KEY_INSTALLING = @"installing";
NSString * const REGISTRATION_KEY_REGISTERING_SCRIPT_URL = @"registeringScriptURL";
NSString * const REGISTRATION_KEY_SCOPE = @"scope";
NSString * const REGISTRATION_KEY_WAITING = @"waiting";

NSString * const SERVICE_WORKER_KEY_SCRIPT_URL = @"scriptURL";

NSString * const DEFAULT_SERVICE_WORKER_SHELL = @"sw.html";

NSString * const SERVICE_WORKER_ASSETS_RELATIVE_PATH = @"www/sw_assets";



@implementation CDVServiceWorker

@synthesize backgroundSync = _backgroundSync;
@synthesize workerWebView = _workerWebView;
@synthesize registration = _registration;
@synthesize requestDelegates = _requestDelegates;

@synthesize requestQueue = _requestQueue;
@synthesize serviceWorkerScriptFilename = _serviceWorkerScriptFilename;
@synthesize cacheApi = _cacheApi;
@synthesize initiateHandler = _initiateHandler;
@synthesize isServiceWorkerActive = _isServiceWorkerActive;

CDVSWURLSchemeHandler *swUrlSchemeHandler;
CDVSWURLSchemeHandler *mainUrlSchemeHandler;
NSMutableDictionary *requestsById;

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

CDVServiceWorker * singletonInstance = nil;
+ (CDVServiceWorker *)instanceForRequest:(NSURLRequest *)request
{
    return singletonInstance;
}

+ (CDVServiceWorker *)getSingletonInstance
{
    if (singletonInstance == nil) {
        singletonInstance = [[CDVServiceWorker alloc] init];
    }
    return singletonInstance;
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

- (void)pluginInitialize
{
    // TODO: Make this better; probably a registry
    singletonInstance = self;

    [self initializeScriptTemplates];
    self.requestDelegates = [[NSMutableDictionary alloc] initWithCapacity:10];
    requestsById = [[NSMutableDictionary alloc] initWithCapacity:10];
    self.requestQueue = [NSMutableArray new];
    
    NSLog(@"Add Cordova Main Protocol");
    WKWebView *mainWebView = (WKWebView *)[[self webViewEngine] engineWebView];
    mainUrlSchemeHandler = [[mainWebView configuration] urlSchemeHandlerForURLScheme: @"cordova-main"];
    mainUrlSchemeHandler.queueHandler = self;

    [self clearBrowserCache];
    [self createNewWorkerWebView];
}

-(void) createNewWorkerWebView {
    
    CDVViewController *vc = (CDVViewController *)[self viewController];
    NSMutableDictionary *settings = [vc settings];
    NSString *applicationURL =  [settings objectForKey:@"remoteapplicationurl"];
    if ([applicationURL hasSuffix: @"/"]) {
        applicationURL = [applicationURL substringToIndex: [applicationURL length] - 1];
    }
//    applicationURL = [applicationURL stringByReplacingOccurrencesOfString:@"https" withString:@"cordova-sw"];
//    applicationURL = [applicationURL stringByReplacingOccurrencesOfString:@"cordova-main" withString:@"https"];
    NSString *serviceWorkerShell =  [settings objectForKey:@"serviceworkershell"];
    if (serviceWorkerShell == nil) {
        serviceWorkerShell = DEFAULT_SERVICE_WORKER_SHELL;
    }

    // Initialize CoreData for the Cache API.
    self.cacheApi = [[ServiceWorkerCacheApi alloc] initWithScope:@"/" cacheCordovaAssets:false];
    [self.cacheApi initializeStorage];
    

    //Clean up existing webView
    if (self.workerWebView != nil) {
        [self.workerWebView removeFromSuperview];
        self.workerWebView = nil;
    }
    
    WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
   swUrlSchemeHandler =  [[CDVSWURLSchemeHandler alloc] init];
    [config setURLSchemeHandler:swUrlSchemeHandler forURLScheme:@"cordova-main"];
    [config.preferences setValue:@YES forKey:@"allowFileAccessFromFileURLs"];
    self.workerWebView = [[WKWebView alloc] initWithFrame: CGRectMake(0, 0, 0, 0) configuration: config]; // Headless
    
    [self registerForJavascriptMessages];
    [self.cacheApi registerForJavascriptMessagesForWebView:[self workerWebView]];
    
    self.backgroundSync = [self.commandDelegate getCommandInstance:@"BackgroundSync"];
    self.backgroundSync.scriptRunner = self;
    
    
//    NSLog(@"createNewWorkerWebView");

    [self.viewController.view addSubview:self.workerWebView];
    
    [self.workerWebView setUIDelegate:self];
    [self.workerWebView setNavigationDelegate:self];
    
    NSString *absoluteShellURLString;
    if (applicationURL != nil) {
        absoluteShellURLString = [NSString stringWithFormat:@"%@/%@", applicationURL, serviceWorkerShell];
        NSLog(@"LoadShell - %@", absoluteShellURLString);
        NSURL *url = [NSURL URLWithString: absoluteShellURLString];
        NSURLRequest *request = [NSURLRequest requestWithURL: url cachePolicy:NSURLRequestReturnCacheDataElseLoad timeoutInterval:60];
        [self.workerWebView loadRequest:request];
    } else {
        NSURL* bundleURL = [NSURL fileURLWithPath:[[NSBundle mainBundle] bundlePath]];
        NSURL* swShellURL = [bundleURL URLByAppendingPathComponent: [NSString stringWithFormat:@"%@/%@", SERVICE_WORKER_ASSETS_RELATIVE_PATH, serviceWorkerShell]];
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
    } else {
        NSLog(@"DidReceiveScriptMessage %@", handlerName);
    }
}


- (void) sendResultToWorker:(NSNumber*) messageId parameters:(NSDictionary *)parameters
{
    NSString* cordovaCallbackScript = [self makeCordovaCallbackScriptWith: messageId parameters: parameters andError: nil];
    [self.workerWebView evaluateJavaScript:cordovaCallbackScript completionHandler:^(id result, NSError *error) {
        if (error != nil) {
            NSLog(@"Failed to run cordovaCallback due to error %@", [error localizedDescription]);
            NSLog(@"Script: %@", cordovaCallbackScript);
        }
    }];
}

- (void) sendResultToWorker:(NSNumber*) messageId parameters:(NSDictionary *)parameters withError: (NSError*) error {
    NSString* cordovaCallbackScript = [self makeCordovaCallbackScriptWith: messageId parameters: parameters andError: error];
    [self.workerWebView evaluateJavaScript:cordovaCallbackScript completionHandler:^(id result, NSError *error) {
        if (error != nil) {
            NSLog(@"Failed to run cordovaCallback due to error %@", [error localizedDescription]);
            NSLog(@"Script: %@", cordovaCallbackScript);
        }
    }];
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
        errorString = [NSString stringWithFormat:@"'%@'", [error description]];
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
    [self.requestDelegates removeObjectForKey:requestId];
    
    NSString *responseBody = response[@"body"];
    NSData *data = [[NSData alloc] initWithBase64EncodedString:responseBody options:0];
    JSValue *headers = response[@"headers"];
    NSString *mimeType = [headers[@"mimeType"] toString];
    NSString *encoding = @"utf-8";
//    NSString *url = [response[@"url"] toString]; // TODO: Can this ever be different than the request url? if not, don't allow it to be overridden
    NSString *url = response[@"url"];
    
    NSURLResponse *urlResponse = [[NSURLResponse alloc] initWithURL:[NSURL URLWithString:url]
                                                        MIMEType:mimeType
                                           expectedContentLength:data.length
                                                textEncodingName:encoding];
    
    [mainUrlSchemeHandler completeTaskWithId: requestId response: urlResponse data: data error:nil];
    
//    [handler completeTask: requestId response: urlResponse data: data error: nil];

//    [interceptor handleAResponse:urlResponse withSomeData:data];
}

- (void)handleTrueFetchScriptMessage: (WKScriptMessage *) message
{
    NSDictionary *body = [message body];
    NSNumber *messageId = [body valueForKey:@"messageId"];
    NSString *url = [body valueForKey:@"url"];
    NSString *method = [body valueForKey:@"method"];
    NSDictionary *headers = [body valueForKey:@"headers"];
    NSDictionary *headersDict = [headers valueForKey:@"headerDict"];
    
    NSLog(@"SW Fetch: %@", url);
    
    if ([url hasPrefix:@"cordova-main"]) {
        url = [url stringByReplacingOccurrencesOfString:@"cordova-main:"  withString:@"https:"];
    }

    if (headersDict != nil) {
        headers = headersDict;
    } else {
        headersDict = [headers valueForKey:@"_headerDict"];
        if (headersDict != nil) {
            headers = headersDict;
        }
    }
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *internalUrlString = url;
    
    if (![url containsString:@"://"]) {
        internalUrlString = [NSString stringWithFormat:@"/%@/www/%@", [[NSBundle mainBundle] resourcePath], url];
        if (![fileManager fileExistsAtPath:internalUrlString]) {
            url = [NSString stringWithFormat:@"%@%@", _clientUrl, url];
            NSLog(@"File does not exist in local fs. Requesting remotely from: %@", url);
        } else {
            url = [NSString stringWithFormat:@"file://%@/www/%@", [[NSBundle mainBundle] resourcePath], url];
        }
    }


    // Create the request.
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString: url]];
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


    NSURLSession *session = [NSURLSession sharedSession];
    NSURLSessionDataTask *dataTask = [session dataTaskWithRequest:request completionHandler: ^(NSData *data, NSURLResponse *response, NSError *error) {
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        ServiceWorkerResponse *swResponse = [ServiceWorkerResponse responseWithHTTPResponse:httpResponse andBody:data];
        if (error != nil) {
            NSLog(@"True Fetch Failed: %@", [error localizedDescription]);
            [self sendResultToWorker:messageId parameters: nil withError: error];
        } else {
            if (isImportScriptRequest) {
                NSLog(@"Cache Import Scripts: %@", origUrl);
                [[self cacheApi] putInternal:request swResponse:swResponse];
            }
            NSDictionary *responseDict = [swResponse toDictionary];
            [self sendResultToWorker:messageId parameters: responseDict];
        }
    }];
    [dataTask resume];
}


- (void)handleFetchDefaultScriptMessage: (WKScriptMessage *) message {
    NSDictionary *body = [message body];
    NSString *jsRequestId = [body valueForKey:@"requestId"];

    [mainUrlSchemeHandler sendRequestWithId: jsRequestId];
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

    [self evaluateScript:postMessageCode inWebView:mainWebView];
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
    [self installServiceWorker];
}

# pragma mark Cordova ServiceWorker Functions

- (void)restartWorker:(CDVInvokedUrlCommand*)command {
    [self createNewWorkerWebView];
}

- (void)register:(CDVInvokedUrlCommand*)command
{
    NSString *scriptUrl = [command argumentAtIndex:0];
//    NSDictionary *options = [command argumentAtIndex:1];
    NSString *absoluteScriptUrl = [command argumentAtIndex:2];
//    absoluteScriptUrl = [absoluteScriptUrl stringByReplacingOccurrencesOfString:@"cordova-main" withString:@"https"];
    NSString *clientURL = [absoluteScriptUrl stringByReplacingOccurrencesOfString:scriptUrl   withString:@""];
    NSLog(@"Register service worker: %@ (for client: %@)", scriptUrl, clientURL);
    
    
    if (clientURL != nil) {
        NSString *setBaseURLCode = [NSString stringWithFormat: @"window.mainClientURL = '%@';", clientURL];
        [self evaluateScript: setBaseURLCode];
    }

    // The script url must be at the root.
    // TODO: Look into supporting non-root ServiceWorker scripts.
    if ([scriptUrl containsString:@"/"]) {
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                                          messageAsString:@"The script URL must be at the root."];
        [[self commandDelegate] sendPluginResult:pluginResult callbackId:[command callbackId]];
    }

    // The provided scope is ignored; we always set it to the root.
    // TODO: Support provided scopes.
    NSString *scopeUrl = @"/";

    // If we have a registration on record, make sure it matches the attempted registration.
    // If it matches, return it.  If it doesn't, we have a problem!
    // If we don't have a registration on record, create one, store it, and return it.
    if (self.registration != nil) {
        
        if (![[self.registration valueForKey:REGISTRATION_KEY_REGISTERING_SCRIPT_URL] isEqualToString: absoluteScriptUrl]) {
            CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                                              messageAsString:[NSString stringWithFormat:@"The script URL doesn't match the existing registration. existing: %@  new: %@", self.serviceWorkerScriptFilename, scriptUrl]];
            [[self commandDelegate] sendPluginResult:pluginResult callbackId:[command callbackId]];
        } else if (![[self.registration valueForKey:REGISTRATION_KEY_SCOPE] isEqualToString:scopeUrl]) {
            CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                                              messageAsString:@"The scope URL doesn't match the existing registration."];
            [[self commandDelegate] sendPluginResult:pluginResult callbackId:[command callbackId]];
        } else {
            NSLog(@"Return existing registration");
            CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:self.registration];
            [[self commandDelegate] sendPluginResult:pluginResult callbackId:[command callbackId]];
        }
    } else {
//        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
//        bool serviceWorkerInstalled = [defaults boolForKey:SERVICE_WORKER_INSTALLED];
//        bool serviceWorkerActivated = [defaults boolForKey:SERVICE_WORKER_ACTIVATED];
//        NSString *serviceWorkerScriptRelativePath = [NSString stringWithFormat:@"www/%@", scriptUrl];
//        NSString *serviceWorkerScriptChecksum = [defaults stringForKey:SERVICE_WORKER_SCRIPT_CHECKSUM];
//        NSString *serviceWorkerScript = [self readScriptAtRelativePath:serviceWorkerScriptRelativePath];
//        if (serviceWorkerScript != nil) {
//            if (![[self hashForString:serviceWorkerScript] isEqualToString:serviceWorkerScriptChecksum]) {
        
        NSLog(@"Create ServiceWorkerClient: %@", clientURL);
        [self createServiceWorkerClientWithUrl:clientURL];
        NSLog(@"Create ServiceWorkerRegistration: %@", absoluteScriptUrl);
        [self createServiceWorkerRegistrationWithScriptUrl:absoluteScriptUrl scopeUrl:scopeUrl];
        
        
        CDVServiceWorker * __weak weakSelf = self;
        _initiateHandler = ^() {
            CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:weakSelf.registration];
            [[weakSelf commandDelegate] sendPluginResult:pluginResult callbackId:[command callbackId]];
        };
        NSLog(@"Load ServiceWorkerScript: %@ %@", absoluteScriptUrl, clientURL);
        [self createServiceWorkerFromScript:absoluteScriptUrl clientUrl:clientURL];

//            } else {
//                NSLog(@"ServiceWorker is already registered and contains no changes: %@", serviceWorkerScriptRelativePath);
//            }
//        } else {
//            NSLog(@"ServiceWorker script is empty: %@", serviceWorkerScriptRelativePath);
//        }
    }

    // Return the registration.
//    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:self.registration];
//    [[self commandDelegate] sendPluginResult:pluginResult callbackId:[command callbackId]];
}

- (void)unregister:(CDVInvokedUrlCommand*)command
{
    
    NSString *scriptUrl = [command argumentAtIndex:0];
    NSString *scope = [command argumentAtIndex:1];
    NSLog(@"Unregister SW at script URL: %@", scriptUrl);
    self.registration = nil;
    [self createNewWorkerWebView];
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:self.registration];
    [[self commandDelegate] sendPluginResult:pluginResult callbackId:[command callbackId]];
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
    [self evaluateScript:createRegistrationScript];
}

- (void)serviceWorkerReady:(CDVInvokedUrlCommand*)command
{
    // The provided scope is ignored; we always set it to the root.
    // TODO: Support provided scopes.
    NSString *scopeUrl = @"/";
    NSString *scriptUrl = self.serviceWorkerScriptFilename;

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
    [self evaluateScript:[dispatchInstallEventTemplate content]];
}

- (void)installServiceWorker
{
    [self installServiceWorker: nil];
}

- (void)activateServiceWorker
{
    [self evaluateScript:[dispatchActivateEventTemplate content]];
}

- (void)initiateServiceWorker
{
    isServiceWorkerActive = YES;
    _isServiceWorkerActive = YES;
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
    [self evaluateScript:script inWebView: self.workerWebView];
}

- (void)evaluateScript:(NSString *)script callback:(void(^)(NSString *result, NSError *error)) callback
{
    [self evaluateScript:script inWebView: self.workerWebView callback:callback];
}

- (void)evaluateScript:(NSString *)script inWebView: (WKWebView *) webView
{
    [self evaluateScript:script inWebView: webView callback: nil];
}

- (void)evaluateScript:(NSString *)script inWebView: (WKWebView *) webView callback:(void(^)(NSString *result, NSError *error)) callback
{
    
    NSString *viewName = webView == [self workerWebView] ? @"ServiceWorker" : @"Main";
    if ([NSThread isMainThread]) {
        [webView evaluateJavaScript:script completionHandler:^(NSString *result, NSError *error) {
            if (error != nil) {
                if (![[error description] containsString:@"JavaScript execution returned a result of an unsupported type"]) {
                    NSLog(@"CDVServiceWorker failed to evaluate script in (%@) webView with error: %@", viewName, error.localizedDescription);
                    NSLog(@"Failed Script: %@", script);
                }
            }
            if (callback != nil) {
                callback(result, error);
            }
        }];
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            [webView evaluateJavaScript:script completionHandler:^(NSString *result, NSError *error) {
                if (![[error description] containsString:@"JavaScript execution returned a result of an unsupported type"]) {
                    NSLog(@"CDVServiceWorker failed to evaluate script in (%@) webView with error: %@", viewName, error.localizedDescription);
                    NSLog(@"Failed Script: %@", script);
                }
                if (callback != nil) {
                    callback(result, error);
                }
            }];
        });
    }
}

NSString *_clientUrl = nil;

- (void)createServiceWorkerFromScript:(NSString *)script clientUrl:(NSString*)clientUrl
{
    _clientUrl = clientUrl;
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

    // Read the script from the file.
    NSError *error;
    NSString *script = [NSString stringWithContentsOfFile:absolutePath encoding:NSUTF8StringEncoding error:&error];

    // If there was an error, log it and return.
    if (error) {
        NSLog(@"Could not read script: %@", [error description]);
        return nil;
    }

    // Return our script!
    return script;
}

- (void) webView: (WKWebView *) webView didReceiveAuthenticationChallenge: (NSURLAuthenticationChallenge *) challenge completionHandler:(nonnull void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential * _Nullable))completionHandler {
    NSURLCredential * credential = [[NSURLCredential alloc] initWithTrust:[challenge protectionSpace].serverTrust];
    NSLog(@"didReceiveAuthenticationChallenge");
    completionHandler(NSURLSessionAuthChallengeUseCredential, credential);
}


- (void)loadServiceWorkerAssetsIntoContext
{
    NSArray *rootSWAssetFileNames = [[NSArray alloc] initWithObjects:
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
    
    [self evaluateScript: [definePolyfillIsReadyTemplate content]];
    
    // Get the list of assets.
    NSArray *assetFilenames = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:assetDirectoryPath error:NULL];
    
    NSString *fileName;
    NSString *relativePath;
    NSString *script;
    for (fileName in rootSWAssetFileNames) {
        NSLog(@"load root sw asset: %@", fileName);
        relativePath = [NSString stringWithFormat:@"www/sw_assets/%@", fileName];
        script = [self readScriptAtRelativePath:relativePath];
        [self evaluateScript:script];
    }
        for (fileName in assetFilenames) {
        if (![rootSWAssetFileNames containsObject:fileName]) {
            NSLog(@"load supplemental swe asset: %@", fileName);
            relativePath = [NSString stringWithFormat:@"www/sw_assets/%@", fileName];
            script = [self readScriptAtRelativePath:relativePath];
            [self evaluateScript:script];
        }

    }
    
     [self evaluateScript: [resolvePolyfillIsReadyTemplate content]];
}

- (void)loadScript:(NSString *)script
{
    // Evaluate the script.
    [self evaluateScript:script];
}

- (void)webViewWebContentProcessDidTerminate:(WKWebView *)webView {
    NSLog(@"Worker webViewWebContentProcessDidTerminate - %@", [[webView URL] absoluteString]);
    [webView reload];
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation
{
    NSLog(@"Worker WebView didFinishNavigation - %@", [[webView URL] absoluteString]);
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    bool serviceWorkerInstalled = [defaults boolForKey:SERVICE_WORKER_INSTALLED];
    bool serviceWorkerActivated = [defaults boolForKey:SERVICE_WORKER_ACTIVATED];
    NSString *serviceWorkerScriptChecksum = [defaults stringForKey:SERVICE_WORKER_SCRIPT_CHECKSUM];
    // Load the Service Worker polyfills
    [self loadServiceWorkerAssetsIntoContext];
    
      
    if (self.serviceWorkerScriptFilename == nil) {
        NSLog(@"No service worker script defined. Please add the following line to config.xml: <preference name=\"ServiceWorker\" value=\"[your-service-worker].js\" />");
    }
}

- (void) webView: (WKWebView *) webView didFailLoadWithError:(nonnull NSError *)error {
    NSLog(@"Worker WebView didFailLoadWithError - %@", [[webView URL] absoluteString]);
}


- (void)webView:(WKWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request {
    NSLog(@"Worker WebView shouldStartLoadWithRequest - %@", [[webView URL] absoluteString]);
}
- (void)webViewDidStartLoad:(WKWebView *)webView {
    NSLog(@"Worker WebView didStartLoad - %@", [[webView URL] absoluteString]);
}

- (Boolean)canAddToQueue {
    return _isServiceWorkerActive;
}


- (void)addRequestToQueue:(ServiceWorkerRequest *) swRequest {
    // Add the request object to the queue.
    [self.requestQueue addObject:swRequest];

    // Process the request queue.
    [self processRequestQueue];
}

- (void)addRequestToQueue:(NSURLRequest *)request withId:(NSNumber *)requestId delegateTo:(CDVSWURLSchemeHandler *)handler
{
    // Log!
    NSLog(@"Adding to queue: %@", [[request URL] absoluteString]);

    // Create a request object.
    ServiceWorkerRequest *swRequest = [ServiceWorkerRequest new];
    swRequest.request = request;
    swRequest.requestId = requestId;
    [requestsById setValue:request forKey: [requestId stringValue]];
//    swRequest.protocol = protocol;

    // Add the request object to the queue.
    [self.requestQueue addObject:swRequest];

    // Process the request queue.
    [self processRequestQueue];
}

- (void)processRequestQueue {
    // If the ServiceWorker isn't active, there's nothing we can do yet.
    NSLog(@"processRequestQueue");
    if (!isServiceWorkerActive) {
        return;
    }

    for (ServiceWorkerRequest *swRequest in self.requestQueue) {
        // Log!
        NSLog(@"Processing from queue: %@", [[swRequest.request URL] absoluteString]);

        // Register the request and delegate.
//        [self.requestDelegates setObject:swRequest.handler forKey:swRequest.requestId];

        // Fire a fetch event in the JSContext.
        NSURLRequest *request = swRequest.request;
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

@end


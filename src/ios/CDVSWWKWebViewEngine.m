//
//  CDVSWURLSchemeHandler.m
//  DisasterAlert
//
//  Created by Thomas Jaede on 4/22/20.
//

#import "CDVWKProcessPoolFactory.h"
#import "CDVSWWKWebViewEngine.h"
#import <Cordova/NSDictionary+CordovaPreferences.h>
#import "CDVSWURLSchemeHandler.h"
#import "CDVServiceWorker.h"

@implementation CDVSWWKWebViewEngine : CDVWKWebViewEngine

- (void)pluginInitialize
{
    NSLog(@"Using SW WKWebView");
    
    WKWebView* wkWebView = (WKWebView*)self.engineWebView;
    [wkWebView setNavigationDelegate: self];
    [super pluginInitialize];
}

- (WKWebViewConfiguration*) createConfigurationFromSettings:(NSDictionary*)settings
{
    WKWebViewConfiguration* configuration = [[WKWebViewConfiguration alloc] init];
    configuration.processPool = [[CDVWKProcessPoolFactory sharedFactory] sharedProcessPool];
    CDVSWURLSchemeHandler *swUrlHandler = [[CDVSWURLSchemeHandler alloc] init];    
    [configuration setURLSchemeHandler:swUrlHandler forURLScheme:@"cordova-main"];
    
    if (settings == nil) {
        return configuration;
    }

    configuration.allowsInlineMediaPlayback = [settings cordovaBoolSettingForKey:@"AllowInlineMediaPlayback" defaultValue:NO];
    configuration.mediaPlaybackRequiresUserAction = [settings cordovaBoolSettingForKey:@"MediaPlaybackRequiresUserAction" defaultValue:YES];
    configuration.suppressesIncrementalRendering = [settings cordovaBoolSettingForKey:@"SuppressesIncrementalRendering" defaultValue:NO];
    configuration.mediaPlaybackAllowsAirPlay = [settings cordovaBoolSettingForKey:@"MediaPlaybackAllowsAirPlay" defaultValue:YES];
    return configuration;
}

- (void) webView: (WKWebView *) webView didReceiveAuthenticationChallenge: (NSURLAuthenticationChallenge *) challenge completionHandler:(nonnull void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential * _Nullable))completionHandler {
    NSURLCredential * credential = [[NSURLCredential alloc] initWithTrust:[challenge protectionSpace].serverTrust];
    NSLog(@"SWWKWebViewEngine.didReceiveAuthenticationChallenge");
    completionHandler(NSURLSessionAuthChallengeUseCredential, credential);
}

@end

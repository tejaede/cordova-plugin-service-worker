//
//  CDVSWURLSchemeHandler.m
//  DisasterAlert
//
//  Created by Thomas Jaede on 4/22/20.
//

#import "CDVWebViewProcessPoolFactory.h"
#import "CDVSWWKWebViewEngine.h"
#import <Cordova/NSDictionary+CordovaPreferences.h>
#import "CDVSWURLSchemeHandler.h"
#import "CDVServiceWorker.h"


//TODO Merge with same two properties in CDVServiceWorker.m
NSString * const SW_DEFAULT_URL_SCHEME = @"cordova-sw";


@implementation CDVSWWKWebViewEngine : CDVWebViewEngine

@synthesize swUrlScheme = _swUrlScheme;

- (void)pluginInitialize
{
    CDVViewController *vc = (CDVViewController *)[self viewController];
    NSMutableDictionary *settings = [vc settings];
    NSString *configuredURLScheme =  [settings objectForKey:@"serviceworkerurlscheme"];
    _swUrlScheme = configuredURLScheme != nil ? configuredURLScheme : SW_DEFAULT_URL_SCHEME;
    WKWebView* wkWebView = (WKWebView*)self.engineWebView;
    [wkWebView setNavigationDelegate: self];
    [super pluginInitialize];
}

- (WKWebViewConfiguration*) createConfigurationFromSettings:(NSDictionary*)settings
{
    WKWebViewConfiguration* configuration = [super createConfigurationFromSettings: settings];
    configuration.processPool = [[CDVWebViewProcessPoolFactory sharedFactory] sharedProcessPool];
    CDVSWURLSchemeHandler *swUrlHandler = [[CDVSWURLSchemeHandler alloc] init];    
    if (@available(iOS 11.0, *)) {
        [configuration setURLSchemeHandler:swUrlHandler forURLScheme: _swUrlScheme];
    } else {
        // Fallback on earlier versions
    }
    
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
//    NSLog(@"SWWKWebViewEngine.didReceiveAuthenticationChallenge");
    completionHandler(NSURLSessionAuthChallengeUseCredential, credential);
}

- (void) webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    [super webView:webView didFinishNavigation:navigation];
    NSLog(@"Finished navigation");
}

@end

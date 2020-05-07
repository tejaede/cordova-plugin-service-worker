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

@end

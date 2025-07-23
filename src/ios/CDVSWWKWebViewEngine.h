//
//  CDVSWWKWebViewEngine.h
//  DisasterAlert
//
//  Created by Thomas Jaede on 5/5/20.
//

#import "Cordova/CDVWebViewEngine.h"

#ifndef CDVSWWKWebViewEngine_h
#define CDVSWWKWebViewEngine_h

@interface CDVSWWKWebViewEngine : CDVWebViewEngine <WKNavigationDelegate>

@property (nonatomic, retain) NSString *swUrlScheme;

@end

#endif /* CDVSWWKWebViewEngine_h */

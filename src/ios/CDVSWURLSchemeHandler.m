//
//  CDVSWURLSchemeHandler.m
//  DisasterAlert
//
//  Created by Thomas Jaede on 4/22/20.
//

#import <Foundation/Foundation.h>
#import <WebKit/WKURLSchemeTask.h>
#import "CDVSWURLSchemeHandler.h"

@implementation CDVSWURLSchemeHandler {}

- (void)webView:(WKWebView *)webView startURLSchemeTask:(id <WKURLSchemeTask>)urlSchemeTask
{
    
//    - (instancetype)initWithURL:(NSURL *)URL MIMEType:(NSString *)MIMEType expectedContentLength:(NSInteger)length textEncodingName:(NSString *)name
    
    NSURL *url = [[urlSchemeTask request] URL];
    NSString *urlString = [url absoluteString];
    NSLog(@"Mapped URL: %@", urlString);
    NSURLResponse *response;
    if ([urlString containsString:@"sw_assets"]) {
        NSString *responseString = [self readSchemedURLFromBundle:urlString];
        NSString *mimeType;
        if ([urlString hasSuffix: @"html"]) {
            mimeType = @"text/html";
        } else {
            mimeType = @"text/javascript";
        }
        response = [[NSURLResponse alloc] initWithURL: url MIMEType: mimeType expectedContentLength: -1 textEncodingName: @"UTF-8"];
        [urlSchemeTask didReceiveResponse:response];
        [urlSchemeTask didReceiveData: [responseString dataUsingEncoding: NSUTF8StringEncoding]];
        [urlSchemeTask didFinish];
    } else {
        urlString = [urlString stringByReplacingOccurrencesOfString:@"cordova-sw:"  withString:@"https:"];
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString: urlString]];
        [NSURLProtocol setProperty:@YES forKey:@"PassThrough" inRequest: request];
        NSURLSession *session = [NSURLSession sharedSession];
        NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler: ^(NSData *data, NSURLResponse *response, NSError *error) {
            [urlSchemeTask didReceiveResponse: response];
            [urlSchemeTask didReceiveData: data];
            [urlSchemeTask didFinish];
        }];
        [task resume];
    }
}

- (NSString *) readSchemedURLFromBundle: (NSString *) urlString {
    NSString *localURLString = [urlString stringByReplacingOccurrencesOfString:@"cordova-sw:/" withString:@""];
    NSError *error;
    NSString *responseString = [NSString stringWithContentsOfFile:localURLString encoding:NSUTF8StringEncoding error:&error];
    if (error) {
        NSLog(@"CDVSWURLSchemeHandler could not read file: %@", [error description]);
        return nil;
    }
    return responseString;
}


- (void)webView:(WKWebView *)webView stopURLSchemeTask:(id <WKURLSchemeTask>)urlSchemeTask
{
    NSString *urlString = [[[urlSchemeTask request] URL] absoluteString];
    
    NSLog(@"Mapped URL: %@", urlString);
}




@end

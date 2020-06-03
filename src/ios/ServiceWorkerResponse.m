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
#import "ServiceWorkerResponse.h"

@implementation ServiceWorkerResponse

@synthesize url = _url;
@synthesize body = _body;
@synthesize status = _status;

- (id) initWithUrl:(NSString *)url body:(NSData *)body status:(NSNumber *)status headers:(NSDictionary *)headers {
    if (self = [super init]) {
        _url = url;
        _body = body;
        _status = status;
        _headers = headers;
    }
    return self;
}

+ (ServiceWorkerResponse *)responseWithHTTPResponse:(NSHTTPURLResponse *)response andBody: (NSData *) body
{
    NSString *url = [[response URL] absoluteString];
    NSNumber *status = [NSNumber numberWithInteger:[response statusCode]];
    NSDictionary *headers = [response allHeaderFields];
    return [[ServiceWorkerResponse alloc] initWithUrl:url body:body status:status headers:headers];
}

+ (ServiceWorkerResponse *)responseFromJSValue:(JSValue *)jvalue
{
    NSString *url = (NSString *)jvalue[@"url"];
    NSString *body = (NSString *)jvalue[@"body"];
    NSData *decodedBody = [[NSData alloc] initWithBase64EncodedString:body options:NSDataBase64DecodingIgnoreUnknownCharacters];
    if (body != nil && decodedBody == nil) {
        decodedBody = [body dataUsingEncoding:NSDataBase64Encoding64CharacterLineLength];
    }
    
//    NSNumber *status = [jvalue[@"status"] toNumber];
    NSNumber *status = (NSNumber *)jvalue[@"status"];
    NSDictionary *headers = (NSDictionary *)jvalue[@"headers"];
//    NSDictionary *headers = [jvalue[@"headers"] toDictionary];
    return [[ServiceWorkerResponse alloc] initWithUrl:url body:decodedBody status:status headers:headers];
}

+ (ServiceWorkerResponse *)responseFromDictionary:(NSDictionary *)dictionary
{
    NSString *url = dictionary[@"url"];
    NSData *body = dictionary[@"body"];
    NSNumber *status = dictionary[@"status"];
    NSDictionary *headers = dictionary[@"headers"];
    return [[ServiceWorkerResponse alloc] initWithUrl:url body:body status:status headers:headers];
}

- (NSDictionary *)toDictionary {
    // Convert the body to base64.
    if (self.url == nil) {
        NSLog(@"Failed to convert ServiceWorkerResponseToDictionary because response.url is nil");
        return nil;
    } else {
        NSString *encodedBody;
        NSNumber *isEncoded = [NSNumber numberWithInt:![self.url hasSuffix:@".js"]];
        if ([isEncoded isEqualToNumber:@0]) {
            encodedBody = [[NSString alloc] initWithData:self.body encoding:NSUTF8StringEncoding];
        }
        if (encodedBody == nil) {
            encodedBody = [self.body base64EncodedStringWithOptions: 0];
        }
        if (encodedBody == nil) {
            encodedBody = @"No response";
        }
        return [NSDictionary dictionaryWithObjects:@[self.url, encodedBody, self.status, self.headers ? self.headers : [NSDictionary new], [isEncoded stringValue]] forKeys:@[@"url", @"body", @"status", @"headers", @"isEncoded"]];
    }
}


- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:self.url forKey:@"url"];
    [aCoder encodeObject:self.body forKey:@"body"];
    [aCoder encodeInt:[self.status intValue] forKey:@"status"];
    [aCoder encodeObject:self.headers forKey:@"headers"];
}

- (id)initWithCoder:(NSCoder *)decoder
{
    if (self = [super init]) {
        self.url = [decoder decodeObjectForKey:@"url"];
        self.body = [decoder decodeObjectForKey:@"body"];
        self.status = [NSNumber numberWithInt:[decoder decodeIntForKey:@"status"]];
        self.headers = [decoder decodeObjectForKey:@"headers"];
    }
    return self;
}

@end


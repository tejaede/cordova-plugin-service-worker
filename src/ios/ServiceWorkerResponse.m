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

@interface MimeType : NSObject

@property NSSet *fileExtensions;
@property NSString *name;
@property BOOL isPlainText;

+ (MimeType *) forName: (NSString *) name;
+ (MimeType *) forFileExtension: (NSString *) extension;

@end
 
@implementation MimeType

@synthesize name = _name;
@synthesize fileExtensions = _fileExtensions;
@synthesize isPlainText = _isPlainText;

static NSDictionary *_mimeTypesByFileExtension;
static NSDictionary *_mimeTypesByName;

static NSArray *_known;
+ (NSArray *) known {
    if (!_known) {
        _known = @[
            [MimeType mimeTypeWithName: @"text/css" fileExtensions: @[@"css"] andIsPlainText: true],
            [MimeType mimeTypeWithName: @"text/csv" fileExtensions: @[@"csv"] andIsPlainText: true],
            [MimeType mimeTypeWithName: @"text/html" fileExtensions: @[@"htm", @"html"] andIsPlainText: true],
            [MimeType mimeTypeWithName: @"text/javascript" fileExtensions: @[@"js"] andIsPlainText: true],
            [MimeType mimeTypeWithName: @"application/javascript" fileExtensions: @[@"js"] andIsPlainText: true],
            [MimeType mimeTypeWithName: @"application/json" fileExtensions: @[@"json"] andIsPlainText: true],
            [MimeType mimeTypeWithName: @"text/plain" fileExtensions: @[@"txt", @"manifest"] andIsPlainText: true],
            [MimeType mimeTypeWithName: @"application/svg+xml" fileExtensions: @[@"svg"] andIsPlainText: true],
            [MimeType mimeTypeWithName: @"application/xml" fileExtensions: @[@"xml"] andIsPlainText: true]
        ];
    }
    return _known;
}

+ (NSDictionary *) mimeTypesByName {
    if (_mimeTypesByName == nil) {
        NSMutableDictionary *dictInitializer = [NSMutableDictionary new];
        for (MimeType *type in [self known]) {
            [dictInitializer setValue:type forKey:[type name]];
        }
        _mimeTypesByName = [NSDictionary dictionaryWithDictionary:dictInitializer];
    }
    return _mimeTypesByName;
}

+ (NSDictionary *) mimeTypesByFileExtension {
    if (_mimeTypesByFileExtension == nil) {
        NSMutableDictionary *dictInitializer = [NSMutableDictionary new];
        for (MimeType *type in [self known]) {
            for (NSString *ext in [type fileExtensions]) {
                [dictInitializer setValue:type forKey: ext];
            }
        }
        _mimeTypesByFileExtension = [NSDictionary dictionaryWithDictionary:dictInitializer];
    }
    return _mimeTypesByFileExtension;
}


+ (MimeType *) mimeTypeWithName: (NSString *)name fileExtensions:(NSArray *)fileExtensions andIsPlainText: (BOOL) isPlainText {
    return [[MimeType alloc] initWithName:name fileExtensions:fileExtensions andIsPlainText:isPlainText];
}

+ (MimeType *) forName: (NSString *) name {
    return [[MimeType mimeTypesByName] valueForKey:name];
}

+ (MimeType *) forFileExtension: (NSString *) extension {
    return [[MimeType mimeTypesByFileExtension] valueForKey:extension];
}
 
- (id) initWithName:(NSString *)name fileExtensions:(NSArray *)fileExtensions andIsPlainText: (BOOL) isPlainText {
    if (self = [super init]) {
        _name = name;
        _fileExtensions = [NSSet setWithArray: fileExtensions];
        _isPlainText = isPlainText;
    }
    return self;
}
 
@end

@implementation ServiceWorkerResponse


@synthesize contentType = _contentType;
@synthesize isBodyPlainText = _isBodyPlainText;
//TODO Convert URL to NSURL
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
    NSString *url = (NSString *)dictionary[@"url"];
    NSData *body = dictionary[@"body"];
    NSNumber *status = dictionary[@"status"];
    NSDictionary *headers = dictionary[@"headers"];
    return [[ServiceWorkerResponse alloc] initWithUrl:url body:body status:status headers:headers];
}


- (BOOL) isBodyPlainText {
    MimeType* mimeType = [self mimeType];
    return mimeType != nil ? [mimeType isPlainText] : NO;
}

MimeType *_mimeType;
- (MimeType *) mimeType {
    if (_mimeType == nil) {
        NSString *contentType = [self contentType];
        NSString *extension = _url != nil ? [_url pathExtension] : nil;
        _mimeType = [MimeType forName: contentType];
        _mimeType = _mimeType    ? _mimeType : [MimeType forFileExtension: extension];
    }
    return _mimeType;
}

- (NSString *) contentType {
    if (_contentType == nil && _headers != nil) {
        _contentType = [_headers objectForKey:@"Content-Type"] != nil ? [_headers objectForKey:@"Content-Type"] : [_headers objectForKey:@"content-type"];
    }
    return _contentType;
}

- (NSDictionary *)toDictionary {
    // Convert the body to base64.
    if (self.url == nil) {
        NSLog(@"Failed to convert ServiceWorkerResponseToDictionary because response.url is nil");
        return nil;
    } else {
        NSString *encodedBody;
        BOOL isPlainText = [self isBodyPlainText];
        if (isPlainText) {
            encodedBody = [[NSString alloc] initWithData:self.body encoding:NSUTF8StringEncoding];
        }
        if (encodedBody == nil) {
            encodedBody = [self.body base64EncodedStringWithOptions: 0];
            isPlainText = false;
        }
        if (encodedBody == nil) {
            encodedBody = @"No response";
        }
        NSString *isEncoded = isPlainText ? @"0" : @"1";
        return [NSDictionary dictionaryWithObjects:@[self.url, encodedBody, self.status, self.headers ? self.headers : [NSDictionary new], isEncoded] forKeys:@[@"url", @"body", @"status", @"headers", @"isEncoded"]];
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




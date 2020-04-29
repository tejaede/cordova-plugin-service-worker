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

#import "FetchConnectionDelegate.h"
#import "ServiceWorkerResponse.h"

@implementation FetchConnectionDelegate

@synthesize responseData = _responseData;
@synthesize resolve = _resolve;
@synthesize reject = _reject;

#pragma mark NSURLConnection Delegate Methods

- (BOOL) getIsClosed {
    if (_isClosed == nil) {
        _isClosed = false;
    }
    return _isClosed;
}

- (void) setIsClosed: (BOOL)value {
    _isClosed = value;
}


- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    _swResponse = [ServiceWorkerResponse new];
    _swResponse.url =  [[[connection currentRequest] URL] absoluteString];
    if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
       NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse*)response;
       _swResponse.status = [NSNumber numberWithInteger:[httpResponse statusCode]];
       _swResponse.headers = [httpResponse allHeaderFields];
    } else {
        _swResponse.status = @200;
        _swResponse.headers = nil;
    }
    self.responseData = [[NSMutableData alloc] init];
    self.isClosed = YES;
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    [self.responseData appendData:data];
}

- (NSCachedURLResponse *)connection:(NSURLConnection *)connection
                  willCacheResponse:(NSCachedURLResponse*)cachedResponse {
    return nil;
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    if (_swResponse == nil) {
        _swResponse = [ServiceWorkerResponse new];
        _swResponse.status = @200;
        _swResponse.headers = nil;
    }
    _swResponse.body = self.responseData;
    self.resolve(_swResponse);
    self.isClosed = YES;
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    NSLog(@"Failed to load %@", [[[connection currentRequest] URL] absoluteString]);
    self.reject(error);
    self.isClosed = YES;
}

@end



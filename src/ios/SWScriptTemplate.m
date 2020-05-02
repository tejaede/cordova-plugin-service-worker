//
//  SWScriptTemplate.m
//  
//
//  Created by Thomas Jaede on 5/1/20.
//

#import <Foundation/Foundation.h>
#import "SWScriptTemplate.h"


@implementation SWScriptTemplate

@synthesize filename = _filename;

- (SWScriptTemplate *)initWithFilename:(NSString *) filename {
    if (self = [super init]) {
        _filename = filename;
    }
    return self;
}

- (NSString *) readScript {
    NSString * directory = @"www/sw_templates";
    NSString *relativePath = [NSString stringWithFormat: @"%@/%@", directory, _filename];
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

-(NSString *) content
{
    if (content == nil) {
        content = [self readScript];
    }
    
    return content;
}

@end

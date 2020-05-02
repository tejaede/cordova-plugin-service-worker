//
//  SWScriptTemplate.h
//  
//
//  Created by Thomas Jaede on 5/1/20.
//

#ifndef SWScriptTemplate_h
#define SWScriptTemplate_h


@interface SWScriptTemplate : NSObject

@property (nonatomic, strong) NSString *filename;
@property (nonatomic, strong) NSString *content;

- (SWScriptTemplate *)initWithFilename:(NSString *) filename;
@end

#endif /* SWScriptTemplate_h */

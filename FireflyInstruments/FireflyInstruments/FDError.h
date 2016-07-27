//
//  FDError.h
//  FireflyInstruments
//
//  Created by Denis Bohm on 7/20/16.
//  Copyright © 2016 Firefly Design LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

BOOL FDErrorCreate(NSError **error, const char *file, int line, NSString *className, NSString *methodName, NSDictionary *userInfo);

#define FDErrorReturn(error, userInfo) FDErrorCreate(error, __FILE__, __LINE__, [self className], NSStringFromSelector(_cmd), userInfo)

@interface FDError : NSObject

+ (BOOL)checkThreadIsCancelled:(NSError **)error;

@end

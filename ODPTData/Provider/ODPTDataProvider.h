//
//  ODPTDataProvider.h
//
//  Copyright (c) 2015 Takehito Ikema
//
//  This software is released under the MIT License.
//  https://opensource.org/licenses/mit-license.php
//

#import <Foundation/Foundation.h>
#import "ODPTDataProviderSession.h"

@interface ODPTDataProvider : NSObject<ODPTDataProviderSessionDelegate>;

- (void)setEndPointURL:(NSString *)endPointURL;
- (void)setToken:(NSString *)token;
- (void)clear;

// interface for API access.
- (void)requestAccessWithOwner:(id)owner withPredicate:(NSDictionary *)pred block:(void (^)(id))block;
- (void)requestSequentialAccessWithOwner:(id)owner withPredicates:(NSArray<NSDictionary *> *)preds block:(void (^)(NSArray <id> *))block;
- (void)cancelAccess;
- (void)cancelAccessForOwner:(id)owner;

// ONLY for Test
- (void)printQueue;
- (void)printCache;

@end

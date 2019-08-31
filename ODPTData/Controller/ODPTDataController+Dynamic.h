//
//  ODPTDataController+Dyamic.h
//
//  Copyright (c) 2019 Takehito Ikema
//
//  This software is released under the MIT License.
//  https://opensource.org/licenses/mit-license.php
//

#import "ODPTDataController.h"

NS_ASSUME_NONNULL_BEGIN

@interface ODPTDataController (Dynamic)

- (void)requestWithOwner:(id _Nullable)owner LineInformationForLineIdentifier:(NSString *)LineIdentifier Block:(void (^)(NSDictionary * _Nullable, NSDate * _Nullable))block;

- (void)requestWithOwner:(id _Nullable)owner NowRunningTrainsForLine:(NSString *)lineIdentifier Block:(void (^)(NSArray * _Nullable, NSDate * _Nullable))block;


@end

NS_ASSUME_NONNULL_END

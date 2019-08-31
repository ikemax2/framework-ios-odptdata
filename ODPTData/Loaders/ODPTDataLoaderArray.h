//
//  ODPTDataLoaderArray.h
//
//  Copyright (c) 2018 Takehito Ikema
//
//  This software is released under the MIT License.
//  https://opensource.org/licenses/mit-license.php
//
// 複数の loader を実行後にコールバックを呼ぶ.


#import "ODPTDataLoader.h"

extern NSString *const ODPTDataLoaderArrayOptionsInCompleteFinish;

@interface ODPTDataLoaderArray : ODPTDataLoader
@property(nonatomic, strong) NSArray<ODPTDataLoader *> *loaderArray;

- (id) initWithLoaders:(NSArray<ODPTDataLoader *> *)loaders Block:(void (^)(NSArray<NSManagedObjectID *> *))block;
- (id) initWithLoaders:(NSArray<ODPTDataLoader *> *)loaders withOptions:(NSDictionary *)options Block:(void (^)(NSArray<NSManagedObjectID *> *))block;

@end

//
//  ODPTDataLoaderTrainType.h
//
//  Copyright (c) 2018 Takehito Ikema
//
//  This software is released under the MIT License.
//  https://opensource.org/licenses/mit-license.php
//
#import "ODPTDataLoader.h"

@interface ODPTDataLoaderTrainType : ODPTDataLoader

@property(nonatomic, strong) NSString *trainTypeIdentifier;

- (id) initWithTrainType:(NSString *)trainTypeIdentifier Block:(void (^)(NSManagedObjectID *))block;
@end

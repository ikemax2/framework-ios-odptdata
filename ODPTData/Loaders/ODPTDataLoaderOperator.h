//
//  ODPTDataLoaderOperator.h
//
//  Copyright (c) 2019 Takehito Ikema
//
//  This software is released under the MIT License.
//  https://opensource.org/licenses/mit-license.php
//
#import "ODPTDataLoader.h"

@interface ODPTDataLoaderOperator : ODPTDataLoader

@property(nonatomic, strong) NSString *operatorIdentifier;

- (id) initWithOperator:(NSString *)operatorIdentifier Block:(void (^)(NSManagedObjectID *))block;
@end

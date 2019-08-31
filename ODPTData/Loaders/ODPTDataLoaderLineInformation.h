//
//  ODPTDataLoaderLineInformation.h
//
//  Copyright (c) 2018 Takehito Ikema
//
//  This software is released under the MIT License.
//  https://opensource.org/licenses/mit-license.php
//
#import "ODPTDataLoader.h"

@interface ODPTDataLoaderLineInformation : ODPTDataLoader

@property(nonatomic, strong) NSString *lineIdentifier;

- (id) initWithLine:(NSString *)llineIdentifier Block:(void (^)(NSManagedObjectID *))block;

@end

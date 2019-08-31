//
//  ODPTDataLoaderStation.h
//
//  Copyright (c) 2018 Takehito Ikema
//
//  This software is released under the MIT License.
//  https://opensource.org/licenses/mit-license.php
//
#import "ODPTDataLoader.h"

@interface ODPTDataLoaderStation : ODPTDataLoader

@property(nonatomic, strong) NSString *stationIdentifier;

- (id) initWithStation:(NSString *)stationIdentifier Block:(void (^)(NSManagedObjectID *))block;
@end

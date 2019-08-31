//
//  ODPTDataLoaderConnectingLines.h
//
//  Copyright (c) 2018 Takehito Ikema
//
//  This software is released under the MIT License.
//  https://opensource.org/licenses/mit-license.php
//
#import "ODPTDataLoader.h"

extern NSString *const ODPTDataLoaderConnectingLinesOptionsNeedToLoadRailway;
extern NSString *const ODPTDataLoaderConnectingLinesOptionsNeedToLoadBusRoutePattern;
extern NSString *const ODPTDataLoaderConnectingLinesOptionsSearchRadius;

enum {
    ODPTDataLoaderConnectingLinesInValid = -1,
    ODPTDataLoaderConnectingLinesValidForRailway = 0,
    ODPTDataLoaderConnectingLinesValidForBus = 1,
    ODPTDataLoaderConnectingLinesValidComplete = 2
};

@interface ODPTDataLoaderConnectingLines : ODPTDataLoader

@property(nonatomic, strong) NSString *stationIdentifier;

- (id) initWithStaion:(NSString *)stationIdentifier withOptions:(NSDictionary *)option Block:(void (^)(NSManagedObjectID *))block;

@end

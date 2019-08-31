//
//  ODPTDataLoaderPoint.h
//
//  Copyright (c) 2018 Takehito Ikema
//
//  This software is released under the MIT License.
//  https://opensource.org/licenses/mit-license.php
//

#import "ODPTDataLoader.h"

extern NSString *const ODPTDataLoaderPointOptionsNeedToLoadRailway;
extern NSString *const ODPTDataLoaderPointOptionsNeedToLoadBusRoutePattern;
extern NSString *const ODPTDataLoaderPointOptionsSearchRadius;

@interface ODPTDataLoaderPoint : ODPTDataLoader

- (id) initWithLocation:(CLLocationCoordinate2D)p withOptions:(NSDictionary *)option Block:(void (^)(NSManagedObjectID *))block;

@end

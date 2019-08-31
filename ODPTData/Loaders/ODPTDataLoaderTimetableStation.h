//
//  ODPTDataLoaderTimetableStation.h
//
//  Copyright (c) 2018 Takehito Ikema
//
//  This software is released under the MIT License.
//  https://opensource.org/licenses/mit-license.php
//

#import "ODPTDataLoader.h"

@interface ODPTDataLoaderTimetableStation : ODPTDataLoader

@property(nonatomic, strong) NSString *stationIdentifier;
@property(nonatomic, strong) NSString *lineIdentifier;
// @property(nonatomic) NSInteger dayType;

// @property(nonatomic, strong) void (^callback)(id);

//- (id) initWithLine:(NSString *)lineIdentifier andStation:(NSString *)stationIdentifier andDayType:(NSInteger)dayType Block:(void (^)(NSManagedObjectID *))block;
- (id) initWithLine:(NSString *)lineIdentifier andStation:(NSString *)stationIdentifier Block:(void (^)(NSManagedObjectID *))block;
@end

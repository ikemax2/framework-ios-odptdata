//
//  ODPTDataLoaderTimetableVehicle.h
//
//  Copyright (c) 2019 Takehito Ikema
//
//  This software is released under the MIT License.
//  https://opensource.org/licenses/mit-license.php
//

#import "ODPTDataLoader.h"

NS_ASSUME_NONNULL_BEGIN

@interface ODPTDataLoaderTimetableVehicle : ODPTDataLoader

@property(nonatomic, strong) NSString *timetableVehicleIdentifier;

- (id) initWithTimetableVehicle:(NSString *)timetableVehicleIdentifier Block:( void (^ _Nullable)(NSManagedObjectID *) ) block;

- (NSManagedObjectID *) makeObjectOfTimetableIdentifier:(NSString *)TimetableIdentifier ForDictionary:(NSDictionary *)dict;

@end

NS_ASSUME_NONNULL_END

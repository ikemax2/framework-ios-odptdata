//
//  ODPTDataController+Timetable.h
//
//  Copyright (c) 2019 Takehito Ikema
//
//  This software is released under the MIT License.
//  https://opensource.org/licenses/mit-license.php
//
#import "ODPTDataController.h"

NS_ASSUME_NONNULL_BEGIN

@interface ODPTDataController (Timetable)

- (void)requestWithOwner:(id _Nullable)owner StationTimetableOfLineArray:(NSArray<NSString *> *)lineIdentifiers atStationArray:(NSArray<NSString *> *)stationIdentifiers atDepartureTime:(NSDate *)departureTime Block:(void (^)(NSArray<NSDictionary *> *))block ;

- (void)requestWithOwner:(id _Nullable)owner TrainTimetableOfLine:(NSString *)lineIdentifier atStation:(NSString *)stationIdentifier atDepartureTime:(NSDate *)departureTime Block:(void (^)(NSArray<NSDictionary *> * _Nullable))block ;

- (void)requestWithOwner:(id _Nullable)owner StationTimetableAllRecordsOfLineArray:(NSArray<NSString *> *)lineIdentifiers atStationArray:(NSArray<NSString *> *)stationIdentifiers atDepartureTime:(NSDate *)departureTime Block:(void (^)(NSArray<NSDictionary *> * _Nullable, NSDictionary * _Nullable))block;

- (void) requestWithOwner:(id _Nullable)owner ApplicableCalendarForDate:(NSDate *)date fromCalendars:(NSArray<NSString *> *)calendars Block:(void (^)(NSString * _Nullable))block;

- (void)requestWithOwner:(id _Nullable)owner TrainTypeTitleForTrainTypeIdentifier:(NSString *)trainTypeIdentifier Block:(void (^)(NSString * _Nullable))block ;

@end

NS_ASSUME_NONNULL_END

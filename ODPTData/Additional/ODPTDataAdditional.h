//
//  ODPTDataAdditional.h
//
//  Copyright (c) 2018 Takehito Ikema
//
//  This software is released under the MIT License.
//  https://opensource.org/licenses/mit-license.php
//
#import <Foundation/Foundation.h>



@interface ODPTDataAdditional : NSObject
+ (ODPTDataAdditional *)sharedData;

- (void)clear;
- (NSString *)colorStringForLine:(NSString *)lineIdentifier;
- (NSArray *)directConnectionLinesForLine:(NSString *)lineIdentifier AtStation:(NSString *)stationIdentifier;

- (BOOL) isConnectStation:(NSString *)stationA andStation:(NSString *)stationB;

- (NSArray *)stationOrderForOtherLine:(NSString *)LineIdentifier;

- (NSDictionary *)lineTitleForOtherLine:(NSString *)LineIdentifier;

- (BOOL)isHolidayForDate:(NSDate *)date;

- (NSInteger)lineStatusLevel:(NSString *)statusString;

// - (NSString *)lineInformationStatus:(NSString *)statusString;

- (BOOL)isAbleToAccessAPIOfRailway:(NSString *)lineIdentifier;

- (NSString *)operatorHeaderForIdentifier:(NSString *)operatorIdentifier;

// - (NSString *)directionIdentifierForLine:(NSString *)lineIdentifier andDirectionNum:(NSInteger)directionNum;
@end

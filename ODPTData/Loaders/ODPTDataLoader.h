//
//  ODPTDataLoader.h
//
//  Copyright (c) 2018 Takehito Ikema
//
//  This software is released under the MIT License.
//  https://opensource.org/licenses/mit-license.php
//
#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import "CoreDataManager.h"
#import "EfficientLoader.h"
#import "ODPTDataConstant.h"
#import "ODPTDataProvider.h"

enum {
    ODPTDataLoaderDirectionNumberNotDefined = -2
};

@interface ODPTDataLoader : EfficientLoader

@property(nonatomic, weak) CoreDataManager *dataManager;
@property(nonatomic, weak) ODPTDataProvider *dataProvider;


@property(nonatomic, strong) void (^callback)(id);

- (NSInteger)identifierTypeForIdentifier:(NSString *)identifier;
- (NSInteger)stationTypeForStationIdentifier:(NSString *)StationIdentifier;
- (NSInteger)lineTypeForLineIdentifier:(NSString *)LineIdentifier;
- (NSString *)operatorIdentifierForLineIdentifier:(NSString *)LineIdentifier;
- (double)convertLocationDataString:(id)text;
- (NSArray <NSString *> *)directionIdentifierForLineObject:(NSManagedObject *)lineObject;
- (NSInteger)directionNumberForLineIdentifier:(NSString *)lineIdent;
- (CLLocationDistance)distanceFromPoint:(CLLocationCoordinate2D)pointA toPoint:(CLLocationCoordinate2D)pointB;

// NSManagedObject ハンドリング  performBlock 内でのみ使用のこと。
- (NSArray<NSManagedObject *> *)stationArrayForLineObject:(NSManagedObject *)object;
- (NSArray<NSNumber *> *)stationDuplicationArrayForLineObject:(NSManagedObject *)object;
- (NSManagedObject *)startStationForLineObject:(NSManagedObject *)object;
- (NSManagedObject *)endStationForLineObject:(NSManagedObject *)object;
- (NSArray<NSDictionary *> *) directConnectingLinesForLineObject:(NSManagedObject *)obj;
- (NSString *) connectStationOfLine:(NSManagedObject *)lineObject forStation:(NSManagedObject *)stationObject;
- (NSString *) connectStationOfLine:(NSManagedObject *)lineObject forStationIdentifier:(NSString *)stationIdent;
- (NSTimeInterval) timeIntervalOfTimetableRecord:(NSManagedObject *)recordObject SinceDate:(NSDate *)date;
- (NSDictionary *)dictionaryForStationTimetableRecord:(NSManagedObject *)recordObject;
- (NSDictionary *)dictionaryForTrainTimetable:(NSManagedObject *)trainObject;
- (BOOL)isValidDateOfObject:(NSManagedObject *)object;
- (NSDictionary *)dictionaryForTrainLocation:(NSManagedObject *)trainLocationObject;
- (NSString *)stationTitleForStationObject:(NSManagedObject *)stationObject;
- (NSString *)lineTitleForLineObject:(NSManagedObject *)lineObject;
- (NSString *) applicableCalendarIdentifierForDate:(NSDate *)date fromCalendars:(NSArray<NSManagedObject *> *)calendarObjects;
- (NSDictionary *)dictionaryForStation:(NSManagedObject *)stationObject;


// API独自拡張関係
- (NSString *) removeFooterFromLineIdentifier:(NSString *)LineIdentifier;
- (BOOL)isExtensionLineIdentifier:(NSString *)ident;
- (void) setLineInformationExtentionFor:(NSManagedObject *)object OfIdentifier:(NSString *)lineIdentifier;
- (BOOL)isLineIdentifierDownwardExtention:(NSString *)ident;
- (NSArray *)addAllSuffixLineIdentifierExtension:(NSString *)ident;
- (NSString *)reverseDirectingLineForLineIdentifier:(NSString *)l;
- (NSString *)busRouteIdentifierFromBusRoutePatternIdentifier:(NSString *)brpIdentifier;

- (NSArray *)adjustStationOrder:(NSArray *)stations ExtentionOfIdentifier:(NSString *)LineIdentifier;
- (BOOL) isAbleToAccessAPIOfLine:(NSString *)LineIdentifier;


@end

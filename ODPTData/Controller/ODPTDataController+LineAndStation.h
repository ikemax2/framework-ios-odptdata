//
//  ODPTDataController+LineAndStation.h
//
//  Copyright (c) 2019 Takehito Ikema
//
//  This software is released under the MIT License.
//  https://opensource.org/licenses/mit-license.php
//

#import "ODPTDataController.h"
#import <CoreLocation/CoreLocation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ODPTDataController (LineAndStation)

- (void)requestWithOwner:(id _Nullable)owner StationLocationsForStations:(NSArray<NSString *> *)identArray Block:(void (^)(NSArray * _Nullable))block;

- (void)requestWithOwner:(id _Nullable)owner StationLocationsForLine:(NSString *)LineIdentifier Block:(void (^)(NSArray * _Nullable))block;

- (void)requestWithOwner:(id _Nullable)owner StationIdentifiersForLine:(NSString *)LineIdentifier Block:(void (^)(NSArray<NSString *>* _Nullable))block;

- (void)requestWithOwner:(id _Nullable)owner StationLocationsForLineArray:(NSArray<NSString *> *)LineIdentifiers Block:(void (^)(NSArray * _Nullable))block;

- (void)requestWithOwner:(id _Nullable)owner ColorForLine:(NSString *)LineIdentifier Block:(void (^)(UIColor * _Nullable))block;

- (void)requestWithOwner:(id _Nullable)owner IsCirculationForLine:(NSString *)LineIdentifier Block:(void (^)(BOOL))block;

// 未使用
- (void)requestWithOwner:(id _Nullable)owner NearStationsAtPoint:(CLLocationCoordinate2D)point Block:(void (^)(NSArray * nullable))block ;

- (void)requestWithOwner:(id _Nullable)owner NearLinesAtPoint:(CLLocationCoordinate2D)point ofRailway:(BOOL)loadRailway ofBus:(BOOL)loadBus withSearchRadius:(int)radius Block:(void (^)(NSArray * _Nullable, NSArray * _Nullable))block;

- (void)requestWithOwner:(id _Nullable)owner LineTitleForIdentifier:(NSString * _Nullable)identifierOriginal Block:(void (^)(NSString *))block ;

- (void)requestWithOwner:(id _Nullable)owner StationTitleForIdentifier:(NSString *)identifier Block:(void (^)(NSString * _Nullable))block;

- (void)requestWithOwner:(id _Nullable)owner LineAndStationInformationsForIdentifier:(NSArray <NSString *> *)identifiers  Block:(void (^)(NSArray<NSDictionary *> *))block;


- (void)requestWithOwner:(id _Nullable)owner IntegratedStationsForLine:(NSString *)LineIdentifier atStation:(NSDictionary *)startStationDict withBranchData:(NSArray * _Nullable)branchData Block:(void (^)(NSArray * _Nullable, NSArray * _Nullable, NSArray * _Nullable))block ;

// 未使用
- (void)requestWithOwner:(id _Nullable)owner SelectedDirectConnectedLineForLine:(NSString *)lineIdentifier atStation:(NSString *)branchStationIdentifier withBranchData:(NSArray * _Nullable)branchData Block:(void (^)(NSString * _Nullable))block ;


- (void)selectToDirectConnectedLine:(NSString *)selectedLine forLine:(NSString *)lineIdentifier atStation:(NSString *)branchStationIdentifier;

- (void)requestWithOwner:(id _Nullable)owner ConnectingLinesForStation:(NSString *)StationIdentifier ofRailway:(BOOL)loadRailway ofBus:(BOOL)loadBus withSearchRadius:(int)radius Block:(void (^)(NSArray * _Nullable, NSArray * _Nullable))block ;

- (void)requestWithOwner:(id _Nullable)owner LineEndPointForIdentifier:(NSString *)identifierOriginal Block:(void (^)(NSString * _Nullable))block;


// ある路線・駅における直通・分岐路線とそのうち、現在Activeな路線のインデックスを返す
- (void)requestWithOwner:(id _Nullable)owner BranchLinesForStation:(NSString *)StationIdentifier forLine:(NSString *)LineIdentifier withBranchData:(NSArray * _Nullable)branchData Block:(void (^)(NSArray * _Nullable, NSInteger))block;

// 未使用
- (void)requestWithOwner:(id _Nullable)owner DirectConnectingLinesForStation:(NSString *)StationIdentifier OfLine:(NSString *)LineIdentifier Block:(void (^)(NSArray * _Nullable))block ;

- (void)requestWithOwner:(id _Nullable)owner ReverseDirectionLineForLine:(NSString *)LineIdentifier Block:(void (^)(NSString * _Nullable))block;

- (void)requestWithOwner:(id _Nullable)owner StationInformationForIdentifier:(NSString *)StationIdentifier Block:(void (^)(NSDictionary * _Nullable))block;

- (BOOL)isConnectStation:(NSString *)stationA andStation:(NSString *)stationB;


- (void)requestWithOwner:(id _Nullable)owner DirectConnectingLinesForLine:(NSString *)LineIdent Block:(void (^)(NSDictionary *))block;

- (BOOL)isAccessibleLine:(NSString *)lineIdentifier;

- (BOOL)isSameStation:(NSDictionary * _Nullable)dictA withStation:(NSDictionary * _Nullable)dictB;

@end

NS_ASSUME_NONNULL_END

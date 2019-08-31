//
//  ODPTDataController+Common.h
//
//  Copyright (c) 2019 Takehito Ikema
//
//  This software is released under the MIT License.
//  https://opensource.org/licenses/mit-license.php
//
#import <UIKit/UIKit.h>
#import "ODPTDataController.h"
#import <CoreData/CoreData.h>

NS_ASSUME_NONNULL_BEGIN

@interface ODPTDataController (Common)

- (NSManagedObject *)newPlaceEntityObjectOfMOC:(NSManagedObjectContext *)moc;
- (void)setOriginToPlaceObject:(NSManagedObject *)object ofMOC:(NSManagedObjectContext *)moc;
- (NSManagedObject *)originPlaceObjectOfMOC:(NSManagedObjectContext *)moc;
- (NSDictionary *)placeDictionaryForPlaceObject:(NSManagedObject *)obj;

- (void)setBranchObject:(NSManagedObject *)object toBranchDictionary:(NSDictionary *)dict;
- (NSDictionary *)branchDictionaryForBranchObject:(NSManagedObject *)object;
- (NSDictionary *)branchOfLine:(NSString *)lineIdentifier atStation:(NSString *)branchStationIdentifier withBranchArray:(NSArray * _Nullable)branchArray;
- (NSDictionary * _Nullable)readBranchForLine:(NSString *)lineIdentifier atStation:(NSString *)branchStationIdentifier;
- (void)writeBranchForSelectedLine:(NSString *)selectedLine ofLine:(NSString *)lineIdentifier atStation:(NSString *)branchStationIdentifier;
- (void)writeBranch:(NSDictionary *)branchDict;



- (void)setTransferObject:(NSManagedObject *)transferObject toTransferDictionary:(NSDictionary *)transferDict inManagedObjectContext:(NSManagedObjectContext *)moc;
- (NSDictionary *)transferDictionaryForTransferObject:(NSManagedObject *)transferObject;

- (NSDictionary *)userSetting;
- (void)setUserSetting:(NSDictionary *)dict;

- (UIColor *)colorFromString:(NSString *)colorStr;
- (NSString *)reformStationTitle:(NSString *)orig;
- (NSInteger)typeForIdentifier:(NSString *)identifier;

@end

NS_ASSUME_NONNULL_END

//
//  ODPTDataController.h
//
//  Copyright (c) 2018 Takehito Ikema
//
//  This software is released under the MIT License.
//  https://opensource.org/licenses/mit-license.php
//


#import <Foundation/Foundation.h>

@class ODPTDataProvider;
@class CoreDataManager;
@class EfficientLoaderQueue;

@class NSManagedObject;

NS_ASSUME_NONNULL_BEGIN

@protocol ODPTDataControllerMigrationDelegate
- (void)migrationDidProgress:(float)progress withStep:(NSInteger)currentStep fullStep:(NSInteger)fullStep;
@end

@interface ODPTDataController : NSObject {
    @private    
    CoreDataManager *APIDataManager;
    CoreDataManager *userDataManager;
    
    ODPTDataProvider *dataProvider;
    EfficientLoaderQueue *queue;
}

@property (nonatomic, weak) id<ODPTDataControllerMigrationDelegate> migrationDelegate;

@property (nonatomic) NSInteger searchCountOfTimetable;


- (id _Nullable)initWithAPICacheDirectory:(NSString *)apiCacheDirectory withUserDataDirectory:(NSString *)userDataDirectory withEndPointURL:(NSString *)endPointURL withToken:(NSString *)token;

- (void)beforeEnterBackground;
- (void)beforeEnterForeground;
- (void)prepare;
- (NSInteger)APICacheVersion;

// Cache Control
- (void)requestIsAPIAlive:(void (^)(BOOL isAlive))block;
- (void)clearUserData;
- (BOOL)clearCache;
- (void)cancelAllLoading;
- (void)cancelLoadingForOwner:(id)owner;
- (NSDate * _Nullable)updatedDateStringStatic;
- (NSDate * _Nullable)updatedDateStringDynamic;
- (NSInteger)countOfActiveLoader;

 // Utility
- (id _Nullable)convertedValueOfObject:(NSManagedObject *)obj ForKey:(NSString *)key;

// ONLY FOR TEST
//- (void)fetchAllAPIDataWithType:(NSInteger) type;
- (CoreDataManager *)dataManager;

- (void)printModelInformation;
- (void)printUserDataPlace;
- (void)printAPICacheLinesAndStations;
- (void)printAPICachePoint;
- (void)printUserDataSystemBranch;

@end

NS_ASSUME_NONNULL_END

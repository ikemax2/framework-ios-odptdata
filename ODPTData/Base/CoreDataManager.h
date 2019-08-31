//
//  CoreDataManager.h
//
//  Copyright (c) 2014 Takehito Ikema
//
//  This software is released under the MIT License.
//  https://opensource.org/licenses/mit-license.php
//

#import <CoreData/CoreData.h>

@protocol CoreDataManagerMigrationDelegate
- (void)migrationDidProgress:(float)progress withStep:(NSInteger)currentStep fullStep:(NSInteger)fullStep;
@end


@interface CoreDataManager : NSObject

@property (nonatomic, strong) id<CoreDataManagerMigrationDelegate> migrationDelegate;

- (NSManagedObjectContext *)managedObjectContextForConcurrent;

- (id)initWithStoreDirectory:(NSString *)storeDir andStoreIdent:(NSString *)storeIdent andModelIdent:(NSString *)modelIdent;

- (void)persist;  // 永続化を行う。ディスクに保存する。
- (void)clear;

- (BOOL)resetData;

// for migration
- (BOOL)isRequiredMigration;
- (BOOL)doMigration;
- (BOOL)doMigrationProgressive;

// for debug.
- (BOOL)removeStoreURL;
@end

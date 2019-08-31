//
//  MigrationManager.h
//
//  Copyright (c) 2019 Takehito Ikema
//
//  This software is released under the MIT License.
//  https://opensource.org/licenses/mit-license.php
//

#import <CoreData/CoreData.h>

@interface MigrationManager : NSMigrationManager

- (id)initWithSourceModel:(NSManagedObjectModel *)sourceModel destinationModel:(NSManagedObjectModel *)destinationModel
            sourceVersion:(NSInteger)sourceVersion destinationVersion:(NSInteger)destinationVersion modelIdentifier:(NSString *)modelIdent storeURL:(NSURL *)storeURL;

- (BOOL)performMigration;


@end


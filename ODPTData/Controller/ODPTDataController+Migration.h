//
//  ODPTDataController+Migration.h
//
//  Copyright (c) 2019 Takehito Ikema
//
//  This software is released under the MIT License.
//  https://opensource.org/licenses/mit-license.php
//
#import "ODPTDataController.h"

NS_ASSUME_NONNULL_BEGIN

@interface ODPTDataController (Migration) 

- (BOOL)isRequredUserDataMigration;
- (void)doMigrationWithCompletion:(void (^)(BOOL success))block;
@end

NS_ASSUME_NONNULL_END

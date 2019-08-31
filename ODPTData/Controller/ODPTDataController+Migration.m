//
//  ODPTDataController+Migration.m
//
//  Copyright (c) 2019 Takehito Ikema
//
//  This software is released under the MIT License.
//  https://opensource.org/licenses/mit-license.php
//
#import "ODPTDataController+Migration.h"
#import "CoreDataManager.h"

@implementation ODPTDataController (Migration)

- (BOOL)isRequredUserDataMigration{
    if( [userDataManager isRequiredMigration] == YES){
        return YES;
    }
    
    if([self->APIDataManager isRequiredMigration] == YES){
        [self clearCache];
    }
    return NO;
}

- (void)doMigrationWithCompletion:(void (^)(BOOL success))block{
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        BOOL successFlag = NO;
        
        if([self->userDataManager isRequiredMigration] == YES){
            successFlag = [self->userDataManager doMigrationProgressive];
        }
        
        // メインスレッドで実行。
        dispatch_async(dispatch_get_main_queue(), ^{
            block(successFlag);
        });
    });
    
    return;
}

@end

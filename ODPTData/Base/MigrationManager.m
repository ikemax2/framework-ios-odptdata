//
//  MigrationManager.m
//
//  Copyright (c) 2019 Takehito Ikema
//
//  This software is released under the MIT License.
//  https://opensource.org/licenses/mit-license.php
//

#import "MigrationManager.h"

@implementation MigrationManager{

    NSURL *storeURL;
    NSInteger sourceVersion;
    NSInteger destinationVersion;
    NSString *modelIdentifier;
}

- (id)initWithSourceModel:(NSManagedObjectModel *)sourceModel destinationModel:(NSManagedObjectModel *)destinationModel
            sourceVersion:(NSInteger)sourceVersion destinationVersion:(NSInteger)destinationVersion  modelIdentifier:(NSString *)modelIdent storeURL:(NSURL *)storeURL{
    
    if(self = [super initWithSourceModel:sourceModel destinationModel:destinationModel]){
        self->storeURL = storeURL;
        self->sourceVersion = sourceVersion;
        self->destinationVersion = destinationVersion;
        self->modelIdentifier = modelIdent;
    }
    
    return self;
    
}


- (BOOL)performMigration{

    NSError *error = nil;
    
    
    NSMappingModel *mappingModel = [NSMappingModel
                                    mappingModelFromBundles:nil
                                    forSourceModel:self.sourceModel
                                    destinationModel:self.destinationModel];
    
    /*
    NSMappingModel *mappingModel = [self searchMappingModelForModelIdentifier:modelIdentifier
                                                           sourceModelVersion:sourceVersion
                                                      destinationModelVersion:destinationVersion];
    */
    
    if (mappingModel == nil) {
        // deal with the error
        NSLog(@"MigrationManager cannot found mappingFile for %d -> %d", (int)sourceVersion, (int)destinationVersion);
        return NO;
    }
    
    NSURL *backupedURL = [self backupStoreURL];
    if(backupedURL == nil){
        // deal with the error
        NSLog(@"MigrationManager storeFile backup failure.");
        return NO;
    }
    
    NSURL *sourceStoreURL = backupedURL; // URL for the source store  ;
    NSString *sourceStoreType = NSSQLiteStoreType; // type for the source store, or nil if not known  ;
    NSDictionary *sourceStoreOptions = nil; // options for the source store ;
    
    NSURL *destinationStoreURL = storeURL; // URL for the destination store  ;
    NSString *destinationStoreType = NSSQLiteStoreType; // type for the destination store  ;
    NSDictionary *destinationStoreOptions = nil;  // options for the destination store  ;
    
    BOOL ok = [self migrateStoreFromURL:sourceStoreURL
                                   type:sourceStoreType
                                options:sourceStoreOptions
                       withMappingModel:mappingModel
                       toDestinationURL:destinationStoreURL
                        destinationType:destinationStoreType
                     destinationOptions:destinationStoreOptions
                                  error:&error];
    
    return ok;
    
}

- (NSMappingModel *)searchMappingModelForModelIdentifier:(NSString *)modelIdent sourceModelVersion:(NSInteger)sourceVersion destinationModelVersion:(NSInteger)destinationVersion{
    // 正しいmappingファイルを見つけられない場合に使う

    NSString *mappingModelIdent = [NSString stringWithFormat:@"%@_%d_%d", modelIdentifier, (int)sourceVersion, (int)destinationVersion];
    
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSURL *mappingModelURL = [bundle URLForResource:mappingModelIdent withExtension:@"cdm"];
    
    return [[NSMappingModel alloc] initWithContentsOfURL:mappingModelURL];
}

- (NSURL *)backupStoreURL{
    // storeURL ファイルを名前を変えて保存する。
    
    // storeType NSSQLiteStoreType の場合はファイルが3つ。
    
    // バックアップ先ディレクトリ
    NSString *backupDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
    
    NSString *sql_file = storeURL.path;
    NSString *shm_file = [sql_file stringByReplacingOccurrencesOfString:@".sqlite" withString:@".sqlite-shm"];
    NSString *wal_file = [sql_file stringByReplacingOccurrencesOfString:@".sqlite" withString:@".sqlite-wal"];
    NSArray *srcFiles = @[sql_file, shm_file, wal_file];
    
    NSURL *dstURL = nil;
    NSFileManager *fm = [NSFileManager defaultManager];
    for(int i=0; i<[srcFiles count]; i++){
        NSString *srcFile = srcFiles[i];
        NSError *error;

        NSString *fname = [srcFile lastPathComponent];
        NSString *ext = [srcFile pathExtension];
        NSString *fn = [fname stringByDeletingPathExtension];
        
        NSString *newFname = [NSString stringWithFormat:@"%@_v%d.%@", fn, (int)sourceVersion, ext];
        NSString *dstFile = [backupDirectory stringByAppendingPathComponent:newFname];
        
        if(i==0){
            dstURL = [[NSURL alloc] initFileURLWithPath:dstFile];
        }
        
        if ([fm fileExistsAtPath:srcFile]){
            // 上書きコピーする。
            /*
            if ( [fm fileExistsAtPath:dstFile]){
                [fm removeItemAtPath:dstFile error:&error];
            }
            if(! [fm copyItemAtPath:srcFile toPath:dstFile error:&error]){
                NSLog(@"MigrationManager can't copy file %@", srcFile);
                return NO;
            }
             */
            if ( [fm fileExistsAtPath:dstFile]){
                [fm removeItemAtPath:dstFile error:&error];
            }
            if(! [fm moveItemAtPath:srcFile toPath:dstFile error:&error]){
                NSLog(@"MigrationManager can't move file %@", srcFile);
                return nil;
            }
            
        }else{
            NSLog(@"MigrationManager fileCopy failed. not found %@", srcFile);
        }
    }
    
    NSLog(@"MigrationManager backup version %d success.", (int)sourceVersion);
    return dstURL;
}

@end

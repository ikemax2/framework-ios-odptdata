//
//  CoreDataManager.m
//
//  Copyright (c) 2014 Takehito Ikema
//
//  This software is released under the MIT License.
//  https://opensource.org/licenses/mit-license.php
//

#import "CoreDataManager.h"
#import "MigrationManager.h"

// reference https://www.cocoanetics.com/2012/07/multi-context-coredata/

@interface CoreDataManager (){
    NSPersistentStoreCoordinator *kPersistentStoreCoordinator;
    
    NSManagedObjectModel *kManagedObjectModel;
    
    // NSManagedObjectContext *kManagedObjectContext;
    NSManagedObjectContext *kManagedObjectContextConcurrent;
    NSManagedObjectContext *kManagedObjectContextWriter;
    
    
    NSURL *storeURL;
    NSURL *modelURL;
    
    BOOL needToMigration;
    
    NSString *storeDirectory;
    NSString *modelIdentifier;
    
    NSInteger currentMigrationStep;
    NSInteger fullMigrationStep;
    
    dispatch_group_t migrationDispatchGroup;  // Migration 時の dispatch_group. 完了を待機するため。
    //dispatch_group_t loadDispatchGroup;  // load 完了を待機する。 -> スレッドセーフに。
    
    //BOOL isLoading;  // load 実行中
}
@end

@implementation CoreDataManager

- (id)initWithStoreDirectory:(NSString *)storeDir andStoreIdent:(NSString *)storeIdent andModelIdent:(NSString *)modelIdent{
    
    self = [super init];
    if (self) {
        
        self->storeDirectory = storeDir;
        self->modelIdentifier = modelIdent;
        currentMigrationStep = 0;
        fullMigrationStep = 0;
        
        migrationDispatchGroup = nil;
        //loadDispatchGroup = nil;
        //isLoading = NO;
        
        //Initialization
        NSString *fname = [NSString stringWithFormat:@"%@.sqlite", storeIdent];
        storeURL = [NSURL fileURLWithPath: [storeDirectory stringByAppendingPathComponent:fname]];
        
        NSBundle *bundle = [NSBundle bundleForClass:[self class]];
        modelURL = [bundle URLForResource:modelIdent withExtension:@"momd"];
        
        NSLog(@"CoreDataManager store: %@", storeURL);
        NSLog(@"CoreDataManager model: %@", modelURL);
        NSAssert(storeURL != nil && modelURL != nil, @"CoreDataManager initialize error.");
    
        [self clear];
        
        needToMigration = NO;
        [self checkNeedToMigration];
        
        if(needToMigration == YES){
            // migrationが必要。 => このオブジェクトに対するアクセス load/persist/managedObjectContextForConcurrent  は、すべて一旦止める。
            // resetData, resetStoreURL は実行可能。
            migrationDispatchGroup = dispatch_group_create();
            
            dispatch_group_async(migrationDispatchGroup, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
                BOOL checkFlag = YES;
                do{
                    sleep(0.5);
                    @synchronized(self){
                        checkFlag = self->needToMigration;
                    }
                }while(checkFlag == YES);
    
            });
        }

    }
    
    return self;
}

- (void)clear{
    kManagedObjectContextConcurrent = nil;
    kManagedObjectContextWriter = nil;
}

- (void)load{
    if(needToMigration == YES){
        dispatch_group_wait(migrationDispatchGroup, DISPATCH_TIME_FOREVER);  // migration処理完了を待つ。
    }
    // storeURLを読み込む.
        
        // 並列処理用に、 moc内部に専用のキューを持つ。
        self->kManagedObjectContextConcurrent = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
        
        NSError *error = nil;
        
        self->kPersistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[self managedObjectModel]];
        
        if (![self->kPersistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:self->storeURL options:nil error:&error]) {
            
            if (self->kPersistentStoreCoordinator == nil) {
                self->kPersistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[self managedObjectModel]];
            }
            
            NSPersistentStore  *store = [self->kPersistentStoreCoordinator persistentStoreForURL:self->storeURL];
            if(! [self->kPersistentStoreCoordinator removePersistentStore:store error:&error] ){
                NSLog(@"resetCoreData persistentStore remove failure.");
                NSLog(@"  %@, %@", error, [error userInfo]);
                abort();
            }
            
            [self removeStoreURL];
        }
        
        NSAssert(self->kPersistentStoreCoordinator != nil, @"persistentStoreCoordinator is nil!!");

        self->kManagedObjectContextWriter = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
        [self->kManagedObjectContextWriter setPersistentStoreCoordinator:self->kPersistentStoreCoordinator];

        NSAssert(self->kManagedObjectContextWriter != nil, @"mocWriter is nil!!");
        [self->kManagedObjectContextConcurrent setParentContext:self->kManagedObjectContextWriter];
    

}

- (BOOL)isReadyToAccess{
    // データへのアクセス準備完了か。
    @synchronized (self){
        if(kManagedObjectModel != nil && kPersistentStoreCoordinator != nil &&
           kManagedObjectContextWriter != nil && kManagedObjectContextConcurrent != nil){
            return YES;
        }
    }
    return NO;
}

- (NSManagedObjectContext *)managedObjectContextForConcurrent{
    if(needToMigration == YES){
        dispatch_group_wait(migrationDispatchGroup, DISPATCH_TIME_FOREVER);  // migration処理完了を待つ。
    }
    @synchronized (self) {
        /*
    if(isLoading == YES){
        dispatch_group_wait(loadDispatchGroup, DISPATCH_TIME_FOREVER);  // migration処理完了を待つ。
    }else{
        if([self isReadyToAccess] == NO){
            self->isLoading = YES;
            loadDispatchGroup = dispatch_group_create();
            
            dispatch_group_async(loadDispatchGroup, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
                [self load];
                self->isLoading = NO;
            });
        }
    }
         */
        if(kManagedObjectContextConcurrent == nil){
            [self load];
        }
    }
    return kManagedObjectContextConcurrent;
}
    
/*
- (NSManagedObjectContext *)managedObjectContextForConcurrent{
    if(needToMigration == YES){
        dispatch_group_wait(migrationDispatchGroup, DISPATCH_TIME_FOREVER);  // migration処理完了を待つ。
    }
 
    
    // バックグラウンドで動作する読み書き用moc
    if ( kManagedObjectContextConcurrent != nil) {
        return kManagedObjectContextConcurrent;
    }
    
    // 並列処理用に、 moc内部に専用のキューを持つ。
    kManagedObjectContextConcurrent = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    
    NSManagedObjectContext *parentMoc = [self managedObjectContextWriter];
    if(parentMoc != nil){
        [kManagedObjectContextConcurrent setParentContext:parentMoc];
    }else{
        NSLog(@"WARNING!! managedObjectContextForConcurrent parentMOC is nil.");
    }
    
    // 子 Mocに対して　saveすると、　親Mocに変更内容がマージされるだけで、永続的保管はされない。
    
    return kManagedObjectContextConcurrent;
}

- (NSManagedObjectContext *)managedObjectContextWriter{
    // バックグラウンドで動作する永続化用moc
    if ( kManagedObjectContextWriter != nil) {
        return kManagedObjectContextWriter;
    }
    
    NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
    if (coordinator != nil) {
        kManagedObjectContextWriter = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
        [kManagedObjectContextWriter setPersistentStoreCoordinator:coordinator];
    }
    return kManagedObjectContextWriter;
}

- (NSPersistentStoreCoordinator *)persistentStoreCoordinator{
    
    NSAssert(needToMigration == NO, @"CoreDataManager This StoreURL is need to Migration. can not load.");
    
    if (kPersistentStoreCoordinator != nil) {
        return kPersistentStoreCoordinator;
    }
    
    
    NSError *error = nil;
    
    kPersistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[self managedObjectModel]];
    
    if (![kPersistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeURL options:nil error:&error]) {
        
        if (kPersistentStoreCoordinator == nil) {
            kPersistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[self managedObjectModel]];
        }
        
        NSPersistentStore  *store = [kPersistentStoreCoordinator persistentStoreForURL:storeURL];
        if(! [kPersistentStoreCoordinator removePersistentStore:store error:&error] ){
            NSLog(@"resetCoreData persistentStore remove failure.");
            NSLog(@"  %@, %@", error, [error userInfo]);
            abort();
        }
        
        [self removeStoreURL];
    }
    
    return kPersistentStoreCoordinator;
}

 */

- (NSManagedObjectModel *)managedObjectModel{     
     if (kManagedObjectModel != nil) {
         return kManagedObjectModel;
     }
    
     NSLog(@"CoreDataManager ModelURL:%@", modelURL);
     
     NSAssert(modelURL != nil, @"Error modelURL is nil.");
     kManagedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
      NSAssert(kManagedObjectModel != nil, @"Error initializing Managed Object Model");
     return kManagedObjectModel;
 }


/*
 - (NSManagedObjectContext *)managedObjectContext{
 // メインスレッドで動作するmoc
 if ( kManagedObjectContext != nil) {
 return kManagedObjectContext;
 }
 
 kManagedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
 
 NSManagedObjectContext *parentMoc = [self managedObjectContextWriter];
 if(parentMoc != nil){
 [kManagedObjectContext setParentContext:parentMoc];
 }else{
 NSLog(@"WARNING!! managedObjectContext parentMOC is nil.");
 }
 
 return kManagedObjectContext;
 }
 */

/*
 + (void)removeStoreFile:(NSURL *)url{
 
 NSError *error;
 if ([[NSFileManager defaultManager] fileExistsAtPath:url.path]){
 if(! [[NSFileManager defaultManager] removeItemAtURL:url error:&error] ){
 
 NSLog(@"resetStoreFile file remove failure.");
 NSLog(@"  %@, %@", error, [error userInfo]);
 abort();
 }
 }
 
 }
 */

- (BOOL)removeStoreURL{
    
    NSString *sql_file = storeURL.path;
    
    
    NSError *error;
    if ([[NSFileManager defaultManager] fileExistsAtPath:storeURL.path]){
        NSString *shm_file = [sql_file stringByReplacingOccurrencesOfString:@".sqlite" withString:@".sqlite-shm"];
        NSString *wal_file = [sql_file stringByReplacingOccurrencesOfString:@".sqlite" withString:@".sqlite-wal"];
        NSArray *files = @[sql_file, shm_file, wal_file];
        
        for(int i=0; i<[files count]; i++){
            NSString *deleteFile = files[i];
            NSURL *deleteURL = [[NSURL alloc] initFileURLWithPath:deleteFile];
            if(! [[NSFileManager defaultManager] removeItemAtURL:deleteURL error:&error] ){
            
                NSLog(@"removeStoreURL file remove failure. file:%@", deleteURL);
                NSLog(@"  %@, %@", error, [error userInfo]);
                // abort();
                return NO;
            }
        }
    }
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:sql_file]){
        NSLog(@"file is exist after remove.");
    }
    
    
    NSLog(@"removeStoreURL successful!");
    NSLog(@"   URL:%@", storeURL.path);
    return YES;
}


- (BOOL)resetData{

    NSError *error;
   
    if (kPersistentStoreCoordinator != nil) {
        // _persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[self managedObjectModel]];

        NSPersistentStore  *store = [kPersistentStoreCoordinator persistentStoreForURL:storeURL];
        if(! [kPersistentStoreCoordinator removePersistentStore:store error:&error] ){
            NSLog(@"resetCoreData persistentStore remove failure.");
            NSLog(@"  %@, %@", error, [error userInfo]);
            return NO;
        }
    }
    
    BOOL ret = [self removeStoreURL];
    /*
    kPersistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[self managedObjectModel]];
    if (![kPersistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeURL options:nil error:&error]) {
        NSLog(@"resetCoreData make new storeCoordinator failure.");
        NSLog(@"  %@, %@", error, [error userInfo]);
        return NO;
    }
    */
    @synchronized (self) {
        kManagedObjectContextWriter = nil;
        kPersistentStoreCoordinator = nil;
        kManagedObjectModel = nil;
        kManagedObjectContextConcurrent = nil;
    }
    
    sleep(1.0);
    needToMigration = NO;


    NSLog(@"resetCoreData successful!");
    
    return ret;
}


// 永続的に保存する。 非同期で。
/*
 - (void)saveContext{

     // メインスレッドで実行。
     dispatch_async(dispatch_get_main_queue(),^{
                        // 親 managedObjectContextを呼び、そこでsave -> 永続的に保存。
                        NSManagedObjectContext *managedObjectContext = [self managedObjectContext];
                        
                        if (managedObjectContext != nil) {
                            [managedObjectContext performBlockAndWait:^{
                                
                                NSError *error = nil;
                                if ([managedObjectContext hasChanges] && ![managedObjectContext save:&error]) {
                                    // Replace this implementation with code to handle the error appropriately.
                                    // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                                    NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
                                    abort();
                                }
                            }];
                        }
    });
     
 }
 */

- (void)persist{
    if(needToMigration == YES){
        dispatch_group_wait(migrationDispatchGroup, DISPATCH_TIME_FOREVER);  // migration処理完了を待つ。
    }

    @synchronized (self) {
        if(kManagedObjectContextWriter == nil){
            [self load];
        }
    }

    NSManagedObjectContext *writerMOC = kManagedObjectContextWriter;
    
    if (writerMOC != nil) {
        [writerMOC performBlockAndWait:^{
            
            NSError *error = nil;
            if ([writerMOC hasChanges] && ![writerMOC save:&error]) {
                // Replace this implementation with code to handle the error appropriately.
                // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
                abort();
            }
        }];
    }else{
        NSLog(@"WARNING!! persist writerMOC is nil.");
    }
    
}


- (void)checkNeedToMigration{
//- (BOOL)isRequiredMigration{
    
    // 参照しないが、以下の一行は必要。
    // [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:manager.managedObjectModel];
    
    // NSURL* fileURL = [CoreDataManager fileURL_];
    NSError* error = nil;
    
    NSDictionary* sourceMetaData =
    [NSPersistentStoreCoordinator metadataForPersistentStoreOfType:NSSQLiteStoreType
                                                               URL:storeURL
                                                           options:nil
                                                             error:&error];
    
    if (! [[NSFileManager defaultManager] fileExistsAtPath:storeURL.path]){
        NSLog(@"checkNeedToMigration file is NOT exist.");
    }
    
    if (sourceMetaData == nil) {
        // 一度も書き込んでいない場合、storeURLは存在しない。
        needToMigration = NO;
        return;
        
    } else if (error) {
        NSLog(@"Checking migration was failed (%@, %@)", error, [error userInfo]);
        abort();
    }
    
    NSManagedObjectModel *model = [self managedObjectModel];
    BOOL isCompatible = [model isConfiguration:nil compatibleWithStoreMetadata:sourceMetaData];
    

    if(isCompatible == NO){
        NSLog(@"CoreDataManager detect need to migrate. %@", modelURL);
    }

    // NSLog(@"checkNeedToMigration store:%@ -> %d", storeURL, !isCompatible);
    // return !isCompatible;
    needToMigration = !isCompatible;
}

- (BOOL)isRequiredMigration{
    return needToMigration;
}

- (BOOL)doMigration{
    NSLog(@"CoreDataManager %@ migration(auto) start..", modelIdentifier);
    // NSLog(@"doMigration start. singleton cordinator: %@", _persistentStoreCoordinator);
    
    NSManagedObjectModel *model = [self managedObjectModel];
    NSPersistentStoreCoordinator *coordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:model];
    
    // NSURL* fileURL = [CoreDataManager fileURL_];
    NSError* error = nil;
    
    NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
                             [NSNumber numberWithBool:YES], NSMigratePersistentStoresAutomaticallyOption,
                             [NSNumber numberWithBool:YES], NSInferMappingModelAutomaticallyOption,
                             nil];
    
    // 以下の一行で自動マイグレーション(mappingファイルを使わない）が走る。
    if (![coordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeURL options:options error:&error]) {
        
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
        abort();
    }
    
    
    // 親 managedObjectContextを呼び、そこでsave -> 永続的に保存。
    NSManagedObjectContext *moc = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
    [moc setPersistentStoreCoordinator:coordinator];
    
    if (moc != nil) {
        [moc performBlock:^{
            
            NSError *error = nil;
            if (![moc save:&error]) {
                // Replace this implementation with code to handle the error appropriately.
                // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
                abort();
            }
        }];
    }
    
    needToMigration = NO;
    NSLog(@"CoreDataManager %@ migration success", modelIdentifier);
    return YES;
}

/*}
- (BOOL)doMigrationProgressive{
    NSLog(@"CoreDataManager %@ migration(progressive) start..", modelIdentifier);
    
    NSDictionary *versionInfo = [self searchModelVersions];
    if(versionInfo == nil){
        abort();
    }
    
    NSArray *models = [versionInfo objectForKey:@"versionedModels"];
    NSArray *mappings = [versionInfo objectForKey:@"versionedMappings"];
    
    NSNumber *currentVersion = [versionInfo objectForKey:@"currentVersion"];
    
    
}
*/

- (BOOL)doMigrationProgressive{
    // ***.xcdatamodel, ***_v2.xcdatamodel , ***_v3.xcdatamodel などの名前で保存してあること。
    
    NSURL *mURL = nil;
    
    NSMutableArray *versionedModels = [[NSMutableArray alloc] init];
    // NSMutableArray *versionedMappings = [[NSMutableArray alloc] init];
    
    NSInteger version = 1;

    NSError *error = nil;
    NSDictionary* sourceMetaData =
    [NSPersistentStoreCoordinator metadataForPersistentStoreOfType:NSSQLiteStoreType
                                                               URL:storeURL
                                                           options:nil
                                                             error:&error];
    
    NSInteger currentVersion = -1;
    do{
        NSString *mfile = nil;
        if(version == 1){
            mfile = [NSString stringWithFormat:@"%@.momd/%@",modelIdentifier, modelIdentifier];
        }else{
            mfile = [NSString stringWithFormat:@"%@.momd/%@_v%d",modelIdentifier, modelIdentifier, (int)version];
        }

        mURL = [[NSBundle mainBundle] URLForResource:mfile withExtension:@"mom"];
        
        if(mURL == nil){
            break;
        }
        
        NSManagedObjectModel *tModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:mURL];
        [versionedModels addObject:tModel];
        
        if (sourceMetaData != nil) {
            BOOL isCompatible = [tModel isConfiguration:nil
                            compatibleWithStoreMetadata:sourceMetaData];
            
            if(isCompatible == YES){
                currentVersion = version;
            }
        }
        
        version++;
        
    }while(mURL != nil);
    
    
    NSLog(@"%@ migration current Model is version %d", modelIdentifier, (int)currentVersion);
    NSLog(@"%@ migration destination Model is version %d", modelIdentifier, (int)(version - 1) );
    
    self->fullMigrationStep = [versionedModels count] - (currentVersion - 1) - 1;
    self->currentMigrationStep = 0;
    
    NSInteger startIndex  = currentVersion - 1 ;
    
    for(NSInteger i = startIndex; i<[versionedModels count]-1; i++){
        self->currentMigrationStep++;
        
        NSManagedObjectModel *sourceModel = versionedModels[i];
        NSManagedObjectModel *destinationModel = versionedModels[i+1];
        
        MigrationManager *migrationManager = [[MigrationManager alloc] initWithSourceModel:sourceModel
                                                                          destinationModel:destinationModel
                                                                             sourceVersion:i+1
                                                                        destinationVersion:i+2
                                                                           modelIdentifier:modelIdentifier
                                                                                  storeURL:storeURL];

        // migrationManager.migrationProgressに変化があった場合、 selfに通知されるように設定。
        [migrationManager addObserver:self forKeyPath:@"migrationProgress" options:NSKeyValueObservingOptionNew context:NULL];
        
        if([migrationManager performMigration] == NO){
            NSLog(@"CoreDataManager migration failure version %d -> %d", (int)i+1, (int)i+2);
            return NO;
        }
        
        NSLog(@"CoreDataManager migration success version %d -> %d ", (int)i+1, (int)i+2);
        
        [migrationManager removeObserver:self forKeyPath:@"migrationProgress"];
    }
    
    
    needToMigration = NO;
    NSLog(@"CoreDataManager %@ migration success", modelIdentifier);
    return YES;
    
}



// キー値監視による通知
 - (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context{
 
     // addObserverで、option: NSKeyValueObservingOptionNew  変更後の値を通知  -> didChangeValueForKeyで呼ばれる。
     // addObserverで、option: NSKeyValueObservingOptionOld  変更前の値を通知  -> willChangeValueForKeyで呼ばれる。
     
     if([keyPath isEqualToString:@"migrationProgress"]){
         [self.migrationDelegate migrationDidProgress:[object migrationProgress]
                                             withStep:self->currentMigrationStep
                                             fullStep:self->fullMigrationStep];
     }
 
 }

/*
- (id)initWithCompletionBlock:(CallbackBlock)callback{
    self = [super init];
    if (!self) return nil;
    
    //This resource is the same name as your xcdatamodeld contained in your project
    NSURL *modelURL = [[NSBundle mainBundle] URLForResource:@"Workspace" withExtension:@"momd"];
    NSAssert(modelURL, @"Failed to locate momd bundle in application");
    // The managed object model for the application. It is a fatal error for the application not to be able to find and load its model.
    NSManagedObjectModel *mom = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
    NSAssert(mom, @"Failed to initialize mom from URL: %@", modelURL);
    
    NSPersistentStoreCoordinator *coordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:mom];
    
    NSManagedObjectContext *moc = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
    [moc setPersistentStoreCoordinator:coordinator];
    [self setManagedObjectContext:moc];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        NSPersistentStoreCoordinator *psc = [[self managedObjectContext] persistentStoreCoordinator];
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSURL *documentsURL = [[fileManager URLsForDirectory:NSDocumentationDirectory inDomains:NSUserDomainMask] lastObject];
        // The directory the application uses to store the Core Data store file. This code uses a file named "DataModel.sqlite" in the application's documents directory.
        NSURL *storeURL = [documentsURL URLByAppendingPathComponent:@"DataModel.sqlite"];
        
        NSError *error = nil;
        NSPersistentStore *store = [psc addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeURL options:nil error:&error];
        if (!store) {
            NSLog(@"Failed to initalize persistent store: %@\n%@", [error localizedDescription], [error userInfo]);
            abort();
            //A more user facing error message may be appropriate here rather than just a console log and an abort
        }
        if (!callback) {
            //If there is no callback block we can safely return
            return;
        }
        //The callback block is expected to complete the User Interface and therefore should be presented back on the main queue so that the user interface does not need to be concerned with which queue this call is coming from.
        dispatch_sync(dispatch_get_main_queue(), ^{
            callback();
        });
    });
    return self;
}
 */
@end

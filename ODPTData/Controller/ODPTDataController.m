//
//  ODPTDataController.m
//
//  Copyright (c) 2018 Takehito Ikema
//
//  This software is released under the MIT License.
//  https://opensource.org/licenses/mit-license.php
//

#import "ODPTDataController.h"

#import "ODPTDataAdditional.h"
#import "ODPTDataController+Common.h"
#import "CoreDataManager.h"
#import "ODPTDataProvider.h"
#import "EfficientLoaderQueue.h"


@interface ODPTDataController ()  <CoreDataManagerMigrationDelegate> {
    
    // NSMutableDictionary *colorForLine;
    NSDictionary *railwayForAreaIndex;
    NSDictionary *busrouteForAreaIndex;
    
    NSTimer *timerPersistAPICache; // キャッシュデータ永続化タイマー
    NSInteger timerIntervalPersistAPICache;   // 永続化間隔
}


@end

@implementation ODPTDataController


- (id _Nullable)init{
    NSAssert(NO, @"You should initiate the ODPTDataModel with API Token using initWithToken: message.");
    
    return nil;
}


- (id _Nullable)initWithAPICacheDirectory:(NSString *)apiCacheDirectory withUserDataDirectory:(NSString *)userDataDirectory withEndPointURL:(NSString *)endPointURL withToken:(NSString *)token{
    
    if(self = [super init]){
        
        [self removeCacheData_V1];
        [self copyUserData_V2_0_0];
        
        APIDataManager = [[CoreDataManager alloc] initWithStoreDirectory:apiCacheDirectory andStoreIdent:@"ODPTAPICache" andModelIdent:@"APIModel"];
        
        userDataManager = [[CoreDataManager alloc] initWithStoreDirectory:userDataDirectory andStoreIdent:@"user" andModelIdent:@"UserDataModel"];
        [userDataManager setMigrationDelegate:self];
        
        dataProvider = [[ODPTDataProvider alloc] init];
        [dataProvider setEndPointURL:endPointURL];
        [dataProvider setToken:token];
        
        timerIntervalPersistAPICache = 60;
        timerPersistAPICache = nil;
        [self setTimerPersistAPICache:timerIntervalPersistAPICache];
        
        self.searchCountOfTimetable = 3;
        
        queue = [[EfficientLoaderQueue alloc] init];

        [queue setSuspended:YES]; // model 作成時は　queueをサスペンド状態とし、addLoaderされても実行しない。
        
        NSLog(@"endPointURL:%@",endPointURL);
        NSLog(@"token:%@",token);
        
        //  この段階ではloadしない。　migration確認前。
    }
    
    return self;
}

- (NSInteger)APICacheVersion{
    // APICacheは Migrationを提供しない。
    // 起動時, UserDefault に記載のversion と一致しない場合に強制的にreflesh する。
    return 5;
}

- (void)prepare{
    // APIとの通信ができるか確認
    
    [self checkAPIAliveForCompletionBlock:^(BOOL isAlive) {
        NSLog(@"API isAlive: %d", isAlive);
        if(isAlive == YES){
            // 古いオブジェクトは削除し、リフレッシュする。
            [self sweepOldLineObject];
        }
        // APIが利用できない場合は、キャッシュのデータだけを使う。
        
        [self->queue setSuspended:NO]; // サスペンド解除
        // 以降、アクセス可能。
    }];
}

- (void)beforeEnterBackground{
    
    [self cancelAllLoading];
    
    [timerPersistAPICache invalidate];
    
    [self->APIDataManager persist];
    [self->APIDataManager clear];
    
    [self->userDataManager persist];
    [self->userDataManager clear];
    
    [[ODPTDataAdditional sharedData] clear];
    [dataProvider clear];
    
    [queue clear];
    
}

- (void)beforeEnterForeground{
    
    [self setTimerPersistAPICache:timerIntervalPersistAPICache];
    
}



- (void)checkAPIAliveForCompletionBlock:(void (^)(BOOL isAlive))block{
    // APIに通信が可能かを確認する
    // 試しに列車運行情報を取得
    
    // APIアクセス開始。
    
    NSString *operator = @"odpt.Operator:Odakyu";
    
    NSString *ltype = @"odpt:TrainInformation";
    
    NSDictionary *pred = [NSDictionary dictionaryWithObjectsAndKeys:
                          ltype, @"type",
                          operator, @"odpt:operator",
                          nil];
    
    [dataProvider requestAccessWithOwner:self withPredicate:pred block:^(id ary) {
        
        BOOL flag = NO;
        if(ary == nil || [ary count] == 0){
            block(flag);
            return;
        }
        
        NSDictionary *rec = nil;
        
        for(int i=0; i<[ary count]; i++){
            rec = [ary objectAtIndex:i];
            if([operator isEqualToString:[rec objectForKey:@"odpt:operator"]]){
                flag = YES;
                break;
            }
        }
        
        block(flag);
    }];
}

#pragma mark - Legacy

- (void) removeCacheData_V1{
    
    // Ver. 1.0.0 で使っていたSQLデータベースファイルを削除。
    NSString *applicationDocumentDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
    NSURL *oldstoreURL2 = [NSURL fileURLWithPath:
                           [applicationDocumentDirectory stringByAppendingPathComponent:@"metroView.sqlite"]];
    NSLog(@"oldstoreURL2: %@", oldstoreURL2);
    
    // 古い SQLデータベースファイルを削除。
    NSFileManager *fm = [NSFileManager defaultManager];
    NSError *error;
    NSString *filename = oldstoreURL2.absoluteString;
    if ([fm fileExistsAtPath:filename]){
        // ファイルの削除（ディレクトリも同じ）
        if(! [fm removeItemAtPath:filename error:&error] ){
            NSLog(@"can't delete file %@", filename);
        }
    }
}

- (void)copyUserData_V2_0_0{
    // Ver.2.0.0 で使っていた SQLデータベースは誤って キャッシュフォルダに保存されていた。
    // それをマイグレーションの前に正しい場所に移す
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *applicationCacheDirectory = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject];
    NSString *sql_file = [applicationCacheDirectory stringByAppendingPathComponent:@"user.sqlite"];
    
    
    if ([fm fileExistsAtPath:sql_file]){
        NSString *shm_file = [sql_file stringByReplacingOccurrencesOfString:@".sqlite" withString:@".sqlite-shm"];
        NSString *wal_file = [sql_file stringByReplacingOccurrencesOfString:@".sqlite" withString:@".sqlite-wal"];
        NSArray *srcFiles = @[sql_file, shm_file, wal_file];
        
        NSString *dstDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
        
        for(int i=0; i<[srcFiles count]; i++){
            NSString *srcFile = srcFiles[i];
            NSError *error;
            
            NSString *fname = [srcFile lastPathComponent];
            NSString *dstFile = [dstDirectory stringByAppendingPathComponent:fname];
            
            // 上書きコピーする。
            if ( [fm fileExistsAtPath:dstFile]){
                [fm removeItemAtPath:dstFile error:&error];
            }
            if(! [fm moveItemAtPath:srcFile toPath:dstFile error:&error]){
                NSLog(@"can't move file %@", srcFile);
            }
        }
        
    }
    
}

#pragma mark - Cache Reflesh

- (void) sweepOldLineObject{
    // 一定期間後のLine オブジェクトを削除。
    // 関連する Station オブジェクトを削除。
    
    NSDictionary *dict = [self userSetting];
    NSTimeInterval refleshStartTimeInterval = [[dict objectForKey:@"cacheRefleshStart"] integerValue];
    
    if(refleshStartTimeInterval < 0){
        return;
    }
    
    // refleshStartTimeInterval = 259200.0f;
    NSTimeInterval refleshEndTimeInterval = refleshStartTimeInterval + 3600*24*3;
    
    NSDate *referenceDate = [NSDate dateWithTimeIntervalSinceNow:-refleshStartTimeInterval];
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Line"];
    [request setPredicate:[NSPredicate predicateWithFormat:@"fetchDate <= %@", referenceDate] ];
    
    NSManagedObjectContext *moc = [APIDataManager managedObjectContextForConcurrent];
    [moc performBlockAndWait:^{
        NSArray *results = nil;
        NSError *error = nil;
        results = [moc executeFetchRequest:request error:&error];
        if (results == nil) {
            NSLog(@"Error fetching objects: %@\n%@", [error localizedDescription], [error userInfo]);
            abort();
        }
        
        for(int i=0; i<[results count]; i++){
            
            NSManagedObject *object = [results objectAtIndex:i];
            
            if([self shouldRefleshLineObject:object withStartTimeInterval:refleshStartTimeInterval withEndTimeInterval:refleshEndTimeInterval]){
                NSLog(@"removeLineObject: %@", [object valueForKey:@"identifier"] );
                
                // CoreDataの DeletedRule:cascadeによって、
                // 逆方向のLine,このLineに直通する・直通されるLineも再帰的に削除される。
                // Lineに属するstationも再帰的に削除される。
                
                
                [moc deleteObject:object];
                
                NSError *error;
                // Save the context.
                if (![moc save:&error]) {
                    // Replace this implementation with code to handle the error appropriately.
                    // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                    NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
                    abort();
                }
            }
        }
        
        [self->APIDataManager persist]; // 永続保管 非同期で。
        
    }];
    
    
}


// 取得したデータは定期的にリフレッシュする。
// Lineオブジェクト　とそれに関連するStationオブジェクトを削除。
//  PerformBlock内から呼び出すこと。
- (BOOL)shouldRefleshLineObject:(NSManagedObject *)object
          withStartTimeInterval:(NSTimeInterval)rStartTimeInterval withEndTimeInterval:(NSTimeInterval)rEndTimeInterval{
    
    if(object == nil){
        return NO;
    }
    
    NSDate *fdate = [object valueForKey:@"fetchDate"];
    if(fdate == nil){
        return NO;
    }
    
    
    NSTimeInterval delta = [fdate timeIntervalSinceNow];
    // delta は負
    
    float kakuritu = ( (-delta) - rStartTimeInterval ) / (rEndTimeInterval - rStartTimeInterval);
    
    if(kakuritu < 0.0f) kakuritu = 0.0f;
    if(kakuritu > 1.0f) kakuritu = 1.0f;
    
    int rnum = arc4random_uniform(1000);
    
    if( (float)rnum / 1000.0f < kakuritu ){
        return YES;
    }
    
    return NO;
    
}

#pragma mark - Access to NSManagedObject

- (id _Nullable)convertedValueOfObject:(NSManagedObject *)obj ForKey:(NSString *)key{
    
    NSManagedObjectContext *moc = [self->userDataManager managedObjectContextForConcurrent];
    
    __block id cval = nil;
    [moc performBlockAndWait:^{
        cval = [obj valueForKey:key];
    }];
    
    return cval;
}

#pragma mark - Timer

// APIキャッシュ永続化タイマー 開始

- (void)setTimerPersistAPICache:(NSInteger)secondsFromNow{
    
    if(timerPersistAPICache != nil){
        [timerPersistAPICache invalidate];
    }
    
    timerPersistAPICache = [NSTimer scheduledTimerWithTimeInterval:secondsFromNow
                                                            target:self
                                                          selector:@selector(eventForTimerPersistAPICache:) userInfo:nil repeats:NO];
    
    // 複数タイマーを動作させるには以下を付ける。
    [[NSRunLoop currentRunLoop] addTimer:timerPersistAPICache forMode:NSRunLoopCommonModes];
    
}


- (void) eventForTimerPersistAPICache:(NSTimer *)timer {
    NSLog(@"eventForTimerPersistAPICache");
    [self->APIDataManager persist];
    
    // 次回起動をセット
    [self setTimerPersistAPICache:timerIntervalPersistAPICache];
}



#pragma mark - Cache Control

- (void)requestIsAPIAlive:(void (^)(BOOL isAlive))block{
    [self checkAPIAliveForCompletionBlock:^(BOOL isAlive) {
        // メインスレッドで実行。
        dispatch_async(
                       dispatch_get_main_queue(),
                       ^{
                           block(isAlive);
                       });
    }];
}

- (NSDate * _Nullable)updatedDateStringStatic{
    
    NSManagedObjectContext *moc = [self->APIDataManager managedObjectContextForConcurrent];
    
    __block NSDate *retDate = nil;
    [moc performBlockAndWait:^{
        
        /// fetch requestの生成
        NSFetchRequest *fetchRequest = [NSFetchRequest new];
        
        /// entity descriptionの生成
        NSEntityDescription *entityDescription = [NSEntityDescription entityForName:@"Line" inManagedObjectContext:moc];
        fetchRequest.entity = entityDescription;
        
        /// NSExpressionの生成
        NSExpression *keyPathExpression = [NSExpression expressionForKeyPath:@"fetchDate"];
        NSExpression *expression = [NSExpression expressionForFunction:@"min:" arguments:@[keyPathExpression]];
        NSExpressionDescription *expressionDescription = [NSExpressionDescription new];
        expressionDescription.name = @"minDate";
        expressionDescription.expression = expression;
        expressionDescription.expressionResultType = NSDateAttributeType;
        
        /// 結果のタイプを指定(NSFetchRequestResultType)
        fetchRequest.resultType = NSDictionaryResultType;
        fetchRequest.propertiesToFetch = @[expressionDescription];
        
        NSError *error = nil;
        NSArray *results = [moc executeFetchRequest:fetchRequest error:&error];
        
        if (results == nil) {
            NSLog(@"Error fetching objects: %@\n%@", [error localizedDescription], [error userInfo]);
            abort();
        }
        
        if([results count] > 0){
            retDate = [results.firstObject valueForKey:@"minDate"];   // エンティティ Place プロパティ index の最大値
        }
        
    }];
    
    return retDate;
}

- (NSDate * _Nullable)updatedDateStringDynamic{
    NSManagedObjectContext *moc = [self->APIDataManager managedObjectContextForConcurrent];
    
    __block NSDate *retDate = nil;
    [moc performBlockAndWait:^{
        /// fetch requestの生成
        NSFetchRequest *fetchRequest = [NSFetchRequest new];
        
        NSArray *entities = @[@"LineInformation", @"TrainLocationArray"];
        
        for(int i=0; i<[entities count]; i++){
            /// entity descriptionの生成
            NSString *entityName = entities[i];
            NSEntityDescription *entityDescription = [NSEntityDescription entityForName:entityName inManagedObjectContext:moc];
            fetchRequest.entity = entityDescription;
            
            /// NSExpressionの生成
            NSExpression *keyPathExpression = [NSExpression expressionForKeyPath:@"fetchDate"];
            NSExpression *expression = [NSExpression expressionForFunction:@"min:" arguments:@[keyPathExpression]];
            NSExpressionDescription *expressionDescription = [NSExpressionDescription new];
            expressionDescription.name = @"minDate";
            expressionDescription.expression = expression;
            expressionDescription.expressionResultType = NSDateAttributeType;
            
            /// 結果のタイプを指定(NSFetchRequestResultType)
            fetchRequest.resultType = NSDictionaryResultType;
            fetchRequest.propertiesToFetch = @[expressionDescription];
            
            NSError *error = nil;
            NSArray *results = [moc executeFetchRequest:fetchRequest error:&error];
            
            if (results == nil) {
                NSLog(@"Error fetching objects: %@\n%@", [error localizedDescription], [error userInfo]);
                abort();
            }
            
            if([results count] > 0){
                NSDate *d = [results.firstObject valueForKey:@"minDate"];   // エンティティ Place プロパティ index の最大値
                if(retDate == nil){
                    retDate = [NSDate date];
                }
                
                retDate = [retDate earlierDate:d];
            }
        }
        
    }];
    
    return retDate;
}

- (BOOL)clearCache{
    if(APIDataManager != nil){
        return [APIDataManager resetData];
    }
    return NO;
}

- (void)clearUserData{
    if(userDataManager != nil){
        [userDataManager resetData];
    }
}



- (NSInteger)countOfActiveLoader{
    // loader キュー中の項目数をかえす
    NSInteger count = 0;
    @synchronized(self) {
        //count =[[LoaderManager sharedManager] countLoading];
        count = [self->queue countLoading];
    }
    
    return count;
}

- (void)cancelAllLoading{
    [self->queue cancelAllLoading];
}

- (void)cancelLoadingForOwner:(id)owner{
    [self->queue cancelLoadingForOwner:owner];
}


#pragma mark - CoreDataManagerMigrationDelegate

- (void)migrationDidProgress:(float)progress withStep:(NSInteger)currentStep fullStep:(NSInteger)fullStep{
    // メインスレッドで実行。
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.migrationDelegate migrationDidProgress:progress withStep:currentStep fullStep:fullStep];
        // NSLog(@"xx %@", self.migrationDelegate);
    });
}

#pragma mark - for Debug
- (CoreDataManager *)dataManager{
    return self->APIDataManager;
}

- (void)printAPICacheLinesAndStations{
    
    CoreDataManager *manager = APIDataManager;
    
    NSManagedObjectContext *moc = [manager managedObjectContextForConcurrent];
    [moc performBlockAndWait:^{
        NSArray *results = nil;
        NSError *error = nil;
        
        // 残っている Lineオブジェクトを表示
        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Line"];
        results = [moc executeFetchRequest:request error:&error];
        if (results == nil) {
            NSLog(@"Error fetching objects: %@\n%@", [error localizedDescription], [error userInfo]);
            abort();
        }
        
        NSLog(@"Line Entity object count:%d", (int)[results count]);
        for(int i=0; i<[results count]; i++){
            NSManagedObject *object = [results objectAtIndex:i];
            NSLog(@"  %@", [object valueForKey:@"identifier"] );
        }
        
        // 残っている Stationオブジェクトを表示
        request = [NSFetchRequest fetchRequestWithEntityName:@"Station"];
        results = [moc executeFetchRequest:request error:&error];
        if (results == nil) {
            NSLog(@"Error fetching objects: %@\n%@", [error localizedDescription], [error userInfo]);
            abort();
        }
        
        NSLog(@"Station Entity object count:%d", (int)[results count]);
        for(int i=0; i<[results count]; i++){
            NSManagedObject *object = [results objectAtIndex:i];
            NSLog(@"  %@", [object valueForKey:@"identifier"] );
        }
    }];
    
}

- (void)printAPICachePoint{
    
    CoreDataManager *manager = APIDataManager;
    
    NSManagedObjectContext *moc = [manager managedObjectContextForConcurrent];
    [moc performBlockAndWait:^{
        NSArray *results = nil;
        NSError *error = nil;
        
        // 残っている Place エンティティのオブジェクトを表示
        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Point"];
        results = [moc executeFetchRequest:request error:&error];
        if (results == nil) {
            NSLog(@"Error fetching objects: %@\n%@", [error localizedDescription], [error userInfo]);
            abort();
        }
        
        NSLog(@"Point Entity object count:%d", (int)[results count]);
        for(int i=0; i<[results count]; i++){
            NSManagedObject *object = [results objectAtIndex:i];
            
            NSSet *nearStations = [object valueForKey:@"nearStations"];
            NSLog(@"  (%@,%@) date:%@ points:%d", [object valueForKey:@"latitude"], [object valueForKey:@"longitude"],
                  [object valueForKey:@"fetchDate"], (int)[nearStations count]);
        }
        
    }];
}

- (void)printUserDataSystemBranch{
    
    CoreDataManager *manager = userDataManager;
    
    NSManagedObjectContext *moc = [manager managedObjectContextForConcurrent];
    [moc performBlockAndWait:^{
        NSArray *results = nil;
        NSError *error = nil;
        
        // 残っている Place エンティティのオブジェクトを表示
        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Branch"];
        [request setPredicate:[NSPredicate predicateWithFormat:@"systemDefault == %@", [NSNumber numberWithBool:YES]]];
        results = [moc executeFetchRequest:request error:&error];
        if (results == nil) {
            NSLog(@"Error fetching objects: %@\n%@", [error localizedDescription], [error userInfo]);
            abort();
        }
        
        for(int i=0; i<[results count]; i++){
            NSManagedObject *object = [results objectAtIndex:i];
            
            NSLog(@"Branch Entity object: at:%@ ofLine:%@ selLine:%@", [object valueForKey:@"atStation"], [object valueForKey:@"ofLine"],
                  [object valueForKey:@"selectedLine"]);
        }
        
    }];
}


- (void)printModelInformation{
    NSLog(@"LoaderQueue information:");
    [self->queue printQueueInformation];
    
    NSLog(@"");
    NSLog(@"AccessorQueue information:");
    [dataProvider printQueue];
    
}

- (void)printUserDataPlace{
    
    CoreDataManager *manager = userDataManager;
    
    NSManagedObjectContext *moc = [manager managedObjectContextForConcurrent];
    [moc performBlockAndWait:^{
        NSArray *results = nil;
        NSError *error = nil;
        
        // 残っている Place エンティティのオブジェクトを表示
        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Place"];
        results = [moc executeFetchRequest:request error:&error];
        if (results == nil) {
            NSLog(@"Error fetching objects: %@\n%@", [error localizedDescription], [error userInfo]);
            abort();
        }
        
        
        
        for(int i=0; i<[results count]; i++){
            NSManagedObject *object = [results objectAtIndex:i];
            
            NSLog(@"Place Entity object: %@,%@ t:%@ No.%@ origin:%@", [object valueForKey:@"latitude"], [object valueForKey:@"longitude"],
                  [object valueForKey:@"title"], [object valueForKey:@"index"], [object valueForKey:@"isOrigin"] );
        }
        
    }];
}

@end

//
//  ODPTDataProvider.m
//
//  Copyright (c) 2015 Takehito Ikema
//
//  This software is released under the MIT License.
//  https://opensource.org/licenses/mit-license.php
//

#import "ODPTDataProvider.h"

NSInteger const ODPTDataProviderMaxConcurrentOperationCountDefault = 2; // ほぼ逐次実行。
NSInteger const ODPTDataProviderSlowDownPeriodDefault = 60;  // retry となった時のslowDown 継続時間[秒]

@implementation ODPTDataProvider{
    
    NSOperationQueue *queue;
    
    NSMutableDictionary *cache;
    
    NSDate *_lastAccessTime;
    
    BOOL isSlowDown;
    NSDate *slowDownStartDate;
    
    long serialNumber;
    
    NSString *token;
    NSString *endPointURL;
    
    NSInteger maxConcurrentOperationCount;
    NSInteger slowDownPeriod;
    
    id ownerForCancel;

}

- (void)setToken:(NSString *)t{
    token = t;    
}

- (void)setEndPointURL:(NSString *)e{
    endPointURL = e;
}

- (id)init{
    if(self = [super init]){

        maxConcurrentOperationCount = ODPTDataProviderMaxConcurrentOperationCountDefault;
        slowDownPeriod = ODPTDataProviderMaxConcurrentOperationCountDefault;

        queue = [[NSOperationQueue alloc] init];
        queue.maxConcurrentOperationCount = maxConcurrentOperationCount;
        

        cache = [[NSMutableDictionary alloc] init];

        _lastAccessTime = [NSDate date];
        
        isSlowDown = NO;
        
        serialNumber = 0;
        
        token = nil;
        endPointURL = nil;
        ownerForCancel = nil;
        
        // キャッシュをクリア
        [[NSURLCache sharedURLCache] removeAllCachedResponses];

    }
    
    return self;
}

- (void)clear{
    
    [self removeAllCacheRecord];
    [self refleshQueue];
    
}

// キューだけを作り直す
- (void)refleshQueue{
    @synchronized(self){
        queue = nil;
        queue = [[NSOperationQueue alloc] init];
        queue.maxConcurrentOperationCount = maxConcurrentOperationCount;
    }
}


- (void)addSession:(ODPTDataProviderSession *)op{
    @synchronized(self){
        [queue addOperation:op];
    }
}

- (void)printQueue{
    NSLog(@"Queue count %d", (int)queue.operationCount);
    NSLog(@"Queue suspended %d", [queue isSuspended]);
    
    NSArray *ops = [NSArray arrayWithArray:[queue operations]];
    for(int i=0; i<[ops count]; i++){
        ODPTDataProviderSession *a = [ops objectAtIndex:i];
#ifdef TESTING
        NSLog(@"Queue: n:%d e:%d f:%d c:%d ", a.num, [a isExecuting], [a isFinished], [a isCancelled]);
#else
        NSLog(@"Queue: e:%d f:%d c:%d o:%@", [a isExecuting], [a isFinished], [a isCancelled], a.query);
#endif
        
    }
    
}


- (void)printCache{
    NSLog(@"Cache count %d", (int)[cache count]);
    
    NSArray *keys = [cache allKeys];
    for(NSString *key in keys){
        ODPTDataProviderSession *obj = [cache objectForKey:key];
        NSLog(@"cached: %@", obj.query);
    }
    
}

- (NSDate *)lastAccessTime{
    @synchronized(self) {
        return _lastAccessTime;
    }
    
}

- (void)setLastAccessTime:(NSDate *)date{
    @synchronized(self) {
        _lastAccessTime = date;
    }
}


// キューの中にいくつジョブがあるかを返す
- (NSInteger)queueOperationCount{
    return queue.operationCount;
}


- (void)addCacheRecord:(ODPTDataProviderSession *)record{

    @synchronized(self) {

        // キャッシュ追加時に、validTime以上前のcacheは削除する。余分にキャッシュを増やさない。
        NSArray *keys = [cache allKeys];
        for(NSString *key in keys){
            ODPTDataProviderSession *obj = [cache objectForKey:key];
            
            if(obj != nil){
                [self removeOldCache:obj];
            }
        }
        
        [cache setObject:record forKey:record.query];
    }
}

- (BOOL)removeOldCache:(ODPTDataProviderSession *)obj{
    //一定時間以上前のcacheは削除 削除した時に YESを返す。
    // @synchronized(self) ブロック内で呼び出すこと。
    NSDate *accessDate = obj.accessDate;
    
    NSDate *now = [NSDate date];
    NSTimeInterval delta = [now timeIntervalSinceDate:accessDate];
    if(delta > obj.cacheValidPeriod){
        [cache removeObjectForKey:obj.query];
        return YES;
    }
    
    return NO;
}

- (void)removeCacheRecord:(ODPTDataProviderSession *)record{
    @synchronized(self) {
        [cache removeObjectForKey:record.query];
    }

}

- (void)removeAllCacheRecord{
    @synchronized(self) {
        [cache removeAllObjects];
    }
}

- (BOOL)slowDown{
    return isSlowDown;
}


- (void)setSlowDown:(BOOL)sd{
    isSlowDown = sd;
    
    if(isSlowDown == YES){
        slowDownStartDate = [NSDate date];
    }
}

//- (float)cacheValidPeriodForAPI:(NSString *)api ForType:(NSString *)type{
- (float)cacheValidPeriodForURL:(NSString *)url{
    
    NSArray *f = [url componentsSeparatedByString:@"?"];
    NSString *typeString = [f firstObject];
    
    NSString *api = @"datapoints";
    NSString *type = nil;
    
    if([typeString hasPrefix:@"/places/"] == YES){
        api = @"places";
        type = [typeString stringByReplacingOccurrencesOfString:@"/places/" withString:@""];
    }else{
        type = [typeString stringByReplacingOccurrencesOfString:@"/" withString:@""];
    }
    
    float ret = 0;
    if([api isEqualToString:@"datapoints"]){
        
        if([type isEqualToString:@"odpt:Train"]){
            ret = 5;
        }else if([type isEqualToString:@"odpt:TrainInformation"]){
            ret = 5;
        }else{
            ret = 300;
        }
        
    }else if([api isEqualToString:@"places"]){
        ret = 3600;
    }else{
        ret = 60;
    }
    
    return ret;
}

#pragma mark - ODPTDataProviderSessionDelegate

- (ODPTDataProviderSession *) searchCacheForURL:(NSString *)url{
    
    NSString *key = url;
    @synchronized(self) {
        
        ODPTDataProviderSession *obj = [cache objectForKey:key];
        
        if(obj != nil){
            if(obj.accessDate != nil){
                
                if([self removeOldCache:obj] == YES){
                    obj = nil;
                }
                
            }else{
                // まだアクセスしていないSession.
            }
        }
        
        return obj;
    }
}


- (void)readyForURLAccessOfSession:(ODPTDataProviderSession *)a{
    
    // 外部アクセスを始める
    
    // 条件が合えば、slowDown 状態を解除
    
    if(slowDownStartDate != nil){
        NSInteger delta = [slowDownStartDate timeIntervalSinceNow];
        if(delta < - slowDownPeriod ){
            isSlowDown = NO;
            slowDownStartDate = nil;
        }
    }
    
    
    // キャッシュ有効期間を設定
    a.cacheValidPeriod = [self cacheValidPeriodForURL:a.query];
    
    // cacheに追加 resultはまだ空
    [self addCacheRecord:a];
    
    // アクセスキューに追加。　以降、適切なタイミングで startメソッドが呼ばれ、アクセスが始まる。
    [self addSession:a];
    
    // queue によって、順次外部アクセスを始める。
    // 次はstart メソッドから。

}

- (void)didReceivedResponseOfSession:(ODPTDataProviderSession *)a{
    
    // 最終アクセス完了時刻を記録。
    [self setLastAccessTime:[NSDate date]];
}

- (void)didParseResponseOfSession:(ODPTDataProviderSession *)a withSuccess:(BOOL)isSuccess{
    
    if(isSuccess == NO){
        // アクセス失敗時
        [self setSlowDown:YES];  // ジョブ間の間隔を長く。
        
        // このSessionは キャッシュから削除 次のアクセッサの requestForQueryを出す前に。
        [self removeCacheRecord:a];
    }
}

- (void)didAbortAccessOfSession:(ODPTDataProviderSession *)a{
    
    //  キャンセル or 通信失敗 の場合
    // このアクセッサは cacheには保存しない。
    [self removeCacheRecord:a];
}

- (float)waitTimeForNextSessionFromNow{
    
    NSTimeInterval delta = [[self lastAccessTime] timeIntervalSinceNow];
    // deltaは負値をとる。
    
    float waitTime = 0.12f + delta;
    // slowDown となっている場合は待ち時間を長く。
    if( [self slowDown] == YES){
        waitTime += 1.0f;
    }
    
    return waitTime;
}

- (id) ownerForCancel{
    return ownerForCancel;
    
}

- (NSString *)token{
    return token;
}

- (NSString *)endPointURL{
    return endPointURL;
}

#pragma mark - Interface for API Access

// APIへのアクセス開始。
//   pred のキーとして "type" は必須。
- (void)requestAccessWithOwner:(id)owner withPredicate:(NSDictionary *)pred block:(void (^)(id))block{
    NSAssert(endPointURL != nil, @"requestAccessWithOwner:withPredicate:block: cannot start because endPointURL is not set.");
    NSAssert(token != nil, @"requestAccessWithOwner:withPredicate:block: cannot start because token is not set.");

    BOOL highPriority = NO;
    if([pred objectForKey:@"highPriority"] != nil){
        highPriority = [[pred objectForKey:@"highPriority"] boolValue];
    }
    
    NSAssert([pred objectForKey:@"type"] != nil, @"requestAccessWithOwner:withPredicate:block: cannot start!!");
    
    NSString *type = [pred objectForKey:@"type"];
    
    
    NSMutableDictionary *s_pred = [pred mutableCopy];
    [s_pred removeObjectForKey:@"type"];
    [s_pred removeObjectForKey:@"highPriority"];
    
    ODPTDataProviderSession *atmod = [[ODPTDataProviderSession alloc] initWithOwner:owner withHighPriority:highPriority];
    [atmod setDelegate:self];
    
    // atmod.uuid = [NSString stringWithFormat:@"%ld", ++serialNumber ];
    
    [atmod requestDataSearchForType:type forPredicate:[s_pred copy] block:^(id obj){
        // NSLog(@"callback start No. %@", atmod.uuid);
        block(obj);
    }];
}


//  複数のAPIアクセスを実行。全て終了後に blockが呼ばれる。
- (void)requestSequentialAccessWithOwner:(id)owner withPredicates:(NSArray<NSDictionary *> *)preds block:(void (^)(NSArray <id> *))block{
    NSAssert(endPointURL != nil, @"requestSequentialAccessWithOwner:withPredicates:block: cannot start because endPointURL is not set.");
    NSAssert(token != nil, @"requestSequentialAccessWithOwner:withPredicates:block: cannot start because token is not set.");
 
    __block NSMutableDictionary *retDict =[[NSMutableDictionary alloc] init];
    
    if([preds count] == 0){
        NSLog(@"WARNING. AccessorManager sequentialAccess preds count is zero.");
        block(@[]) ;
        return;
    }
    
    for(int i=0; i<[preds count]; i++){
        NSDictionary *pred = [preds objectAtIndex:i];
    
        [self requestAccessWithOwner:owner withPredicate:pred block:^(id obj) {
            
            if(obj != nil){
                [retDict setObject:obj forKey:[NSString stringWithFormat:@"%d", i]];
            }else{
                // アクセスに失敗した場合は NSNull を返す
                [retDict setObject:[NSNull null] forKey:[NSString stringWithFormat:@"%d", i]];
            }
            
            BOOL waitFlag = NO;
            for(int j=0; j<[preds count]; j++){
                NSNumber *b = [retDict objectForKey:[NSString stringWithFormat:@"%d", j]];
                if(b == nil){
                    waitFlag = YES;
                }
            }
            
            if(waitFlag == NO){
                NSMutableArray *retArray = [[NSMutableArray alloc] init];
                for(int j=0; j<[preds count]; j++){
                    id s = [retDict objectForKey:[NSString stringWithFormat:@"%d", j]];
                    NSAssert(s != nil, @"requestSequentialAccess is error!!");
                    [retArray addObject:s];
                }
                block([retArray copy]) ;
                return;
            };
                                             
        }];
    }
        
}

- (void)cancelAccess{
    @synchronized(self) {
        ownerForCancel = nil;
        [queue cancelAllOperations];  // キューの中にあるNSOperationクラスのcancelメソッドを呼び出す。
    }
}

- (void)cancelAccessForOwner:(id)owner{
    @synchronized(self) {
        ownerForCancel = owner;
        [queue cancelAllOperations];  // キューの中にあるNSOperationクラスのcancelメソッドを呼び出す。
        ownerForCancel = nil;
    }
}


@end

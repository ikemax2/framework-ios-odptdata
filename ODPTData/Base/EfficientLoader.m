//
//  EfficientLoader.m
//
//  Copyright (c) 2018 Takehito Ikema
//
//  This software is released under the MIT License.
//  https://opensource.org/licenses/mit-license.php
//

#import "EfficientLoader.h"


@implementation EfficientLoader{
    
    BOOL _isFinished; // 結果を受けたか アクセスキューからのみアクセス
    BOOL _isExecuting; // 実行中か　アクセスキューからのみアクセス
    
    NSMutableArray *relatedLoaders;
    EfficientLoader *parent;   // 親ローダ。 循環アクセスを防ぐために使う。
    NSMutableArray <EfficientLoader *> *children;   // 子ローダ。このローダが完了しないと本ローダは完了しない。循環アクセスを防ぐために使う。
    
    
    NSNumber *fetchComplete;  // 取得完了のフラグ。このフラグが立った以降は addRelatedLoader を受け付けない。
    
    NSInteger l_serialNumber;
    
    __weak id l_owner;   // ローダのアクセス元を表す　キャンセル処理に使用
    
    BOOL failureFlag;  // loadに失敗した時、キャンセルされた時に YESとする。 -> このLoaderが完了した後のrelatedLoaderの挙動を変化させる
    
    __weak id<EfficientLoaderQueue> queue;  // このLoaderが属するqueueを表す。
    
    BOOL waitingRelatedLoader;
}

static NSInteger gSerialNumber = 0;

+ (NSInteger)nextSerialNumber{
    return gSerialNumber++;
}

- (id)init{
    
    if(self = [super init]){
        _isFinished = NO;
        _isExecuting = NO;
        
        fetchComplete = [NSNumber numberWithBool:NO];
        waitingRelatedLoader = NO;
        
        parent = nil;
        children = [[NSMutableArray alloc] init];
        l_serialNumber = [EfficientLoader nextSerialNumber];
        
        l_owner = nil;
        relatedLoaders = [[NSMutableArray alloc] init];
        
        failureFlag = NO;
        
        queue = nil;

    }
    
    return self;
}

// Loader 終了時。　これを呼ぶと Loaderは終了する。
- (void)completeOperation{
    @synchronized(self){
        fetchComplete = [NSNumber numberWithBool:YES];
    }
    
    if(self->queue == nil){
        NSLog(@"!!WARNING!! EfficientLoader queue is not set. query:%@", self.query);
    }
    [self->queue startRelatedCallBackForLoader:self];
    
    
    [self setValue:[NSNumber numberWithBool:NO] forKey:@"isExecuting"];
    [self setValue:[NSNumber numberWithBool:YES] forKey:@"isFinished"];
}

- (void)setParent:(EfficientLoader *)p{
    __weak typeof(p) weakParent = p; // __weak修飾子をつける事で弱い参照とする。
    parent = weakParent;
    
    //__weak typeof(self) weakSelf = self; // __weak修飾子をつける事で弱い参照とする。
    // [p.children addObject:weakSelf];
    
    [p addChild:self];
    
    // p の ownerを この ownerにセット
    [self setOwner:[p owner]];
    
}

- (void) cancelAction{
    
}


- (void) main{
    // 継承したクラスで実装する
    [NSException raise:NSInternalInconsistencyException
                format:@"You must override %@ in a subclass", NSStringFromSelector(_cmd)];
    
}

- (NSString *)query{
    // 継承したクラスで実装する
    [NSException raise:NSInternalInconsistencyException
                format:@"You must override %@ in a subclass", NSStringFromSelector(_cmd)];
    
    return nil;
}


- (BOOL)addRelatedLoader:(EfficientLoader *)loader{
    
    if(relatedLoaders == nil){
        // 追加に失敗 おそらく終了間際
        return NO;
    }
    
    @synchronized (relatedLoaders) {
        [relatedLoaders addObject:loader];
    }
    
    return YES;
}

- (EfficientLoader *) parent{
    return parent;
}

- (NSArray<EfficientLoader *> *) children{
    return children;
}

- (BOOL)isFinishedLoading{
    
    BOOL retFlag = NO;
    @synchronized(fetchComplete){
        retFlag = [fetchComplete boolValue];
    }
    
    return retFlag;
}

- (NSInteger)serialNumber{
    return l_serialNumber;
}

- (void)addChild:(EfficientLoader *)c{
    __weak typeof(c) weakChild = c; // __weak修飾子をつける事で弱い参照とする。
    
    [children addObject:weakChild];
}

- (void)printInformation{
    NSLog(@"No.%ld", (long)self.serialNumber);
    NSLog(@"  query:%@", self.query);
    NSLog(@"  waitingRelatedLoader:%d", waitingRelatedLoader);
    NSLog(@"  relatedLoaders:");
    for(int i=0; i<[relatedLoaders count]; i++){
        EfficientLoader *l = [relatedLoaders objectAtIndex:i];
        NSLog(@"  <- No.%ld", [l serialNumber]);
    }
    
}

- (id)owner{
    return l_owner;
}

- (void)setOwner:(id)owner{
    l_owner = owner;
}

- (void)setFailure{
    failureFlag = YES;
}

- (BOOL)isSuccess{
    if(failureFlag == YES){
        return NO;
    }
    
    return YES;
}

- (void)setQueue:(__weak id<EfficientLoaderQueue>)queue{
    self->queue = queue;
}

- (id<EfficientLoaderQueue>)queue{
    return self->queue;
}

- (NSArray *)relatedLoaders{
    NSArray *rl = nil;
    @synchronized (relatedLoaders) {
        rl = [self->relatedLoaders copy];
    }
    
    return rl;
}

- (void)clearRelatedLoaders{
    @synchronized (relatedLoaders) {
        //self->relatedLoaders = nil;
        [self->relatedLoaders removeAllObjects];
    }
}

- (void)setWaitingRelatedLoader:(BOOL)flag{
    waitingRelatedLoader = flag;
}

- (BOOL)waitingRelatedLoader{
    return waitingRelatedLoader;
}


#pragma mark - NSOperation override

- (void) start{
    
    // isExecutingを　YESに。
    [self setValue:[NSNumber numberWithBool:YES] forKey:@"isExecuting"];   // -> オブザーバに通知
    
    [self main];
    
}

- (void)cancel{
    
    id cancelOwner = [[self queue] cancelOwner];
    
    BOOL cancelFlag = NO;
    
    if(cancelOwner != nil){
        // cancelOwnerだけキャンセル
        if([cancelOwner isEqual:l_owner] == YES){
            cancelFlag = YES;
        }
        
    }else{
        cancelFlag = YES;
    }
    
    if(cancelFlag == YES){
        
        [self cancelAction];
        // 本来のNSOperation のcancelを呼ぶ。　-> [self isCancelled] が YESを返すようになる。
        [super cancel];
    }
    
    if(cancelFlag == YES){
        failureFlag = YES;
    }
    //TODO: 下記コードを有効にするとキューが詰まる　cancel時のrelatedLoaderの処理
    
    /*
     if(relatedLoaders != nil){
     // relatedLoader内のLoaderはjobqueueに入っていないので、cancelが呼ばれない。ここで呼ぶ。
     for(ManagedLoader *obj in relatedLoaders){
     [obj cancel];
     }
     }*/
}

- (BOOL) isFinished{
    return _isFinished;
}

- (BOOL) isExecuting{
    return _isExecuting;
}

- (BOOL) isConcurrent{
    return YES;  // YESを返さないとメインキュー以外で動かなくなる。
}

// 監視するキー値の設定  これを設定しないとKVOが動作しない。
+ (BOOL)automaticallyNotifiesObserversForKey:(NSString*)key {
    
    if ([key isEqualToString:@"isExecuting"] ||
        [key isEqualToString:@"isFinished"]) {
        return YES;
        // 自動(setValue ForKeyを使用) の場合は YES
        // 手動(willChange/didChange valuForKeyを使用する）の場合は NO
        
    }else{
        
    }
    return [super automaticallyNotifiesObserversForKey:key];
}

@end

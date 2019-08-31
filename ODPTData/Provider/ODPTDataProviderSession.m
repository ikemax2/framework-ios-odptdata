//
//  ODPTDataProviderSession.m
//
//  Copyright (c) 2015 Takehito Ikema
//
//  This software is released under the MIT License.
//  https://opensource.org/licenses/mit-license.php
//

#import "ODPTDataProviderSession.h"


@implementation ODPTDataProviderSession{
    NSMutableData *receivedData;
    
    void (^callback)(id);
    
     NSURLSession *urlSession;
    
}

- (id)initWithOwner:(id)owner withHighPriority:(BOOL)highPriority{

    if(self = [super init]){
        
        self.owner = owner;
        // Session における優先度は2段階のみ。
        if(highPriority == YES){
            self.queuePriority = NSOperationQueuePriorityVeryHigh;
        }else{
            self.queuePriority = NSOperationQueuePriorityNormal;
        }
        
        _isFinished = NO;
        _isExecuting = NO;
        
        self.cacheValidPeriod = -1;
        
        receivedData = nil;
        self.parsedData = nil;
        
        _retryCount = 0;
        
        _relatedSessions = nil;
        
        self.uuid = [[NSUUID UUID] UUIDString];
        
        urlSession = nil;
    }
    
    
    return self;
}


- (void)requestDataSearchForType:(NSString *)typeString forPredicate:(NSDictionary *)pred block:(void (^)(id))block{
    
    NSMutableString *url = [[NSMutableString alloc] init];
    [url appendString:@"/"];
    
    [url appendString:typeString];
    [url appendString:@"?"];
    
    if(pred != nil){
        BOOL first = YES;
        for (id key in pred) {
            if(first == NO){
                [url appendString:@"&"];
            }
            [url appendString:key];
            [url appendString:@"="];
            [url appendString:[pred objectForKey:key]];
            first = NO;
        }
    }
    
    
    callback = [block copy]; // IMPORTANT
    
    [self requestURL:url];
}


// 再アクセスの際に利用される。
- (void)requestForQuery:(NSString *)url block:(void (^)(id))block{
    
    callback = [block copy]; // IMPORTANT
    
    [self requestURL:url];
}

- (void)requestURL:(NSString *)url{
    
    _query = url;
    
    receivedData = [NSMutableData dataWithCapacity:0];
    
    if([self checkCache] == YES){
        return;
    }
    // キャッシュにデータはない。外部アクセスを始める
    
    [self.delegate readyForURLAccessOfSession:self];
    
    return;
}

// 読み込みキャッシュを確認し、
//  1. キャッシュがすでに存在すれば、その内容でコールバックを実行し、 YESを返す。
//  2. キャッシュがすでに存在するが、読み込み中の場合、キャッシュ対象のSession をモニタし、YESを返す。
//  3. キャッシュが存在しない場合、NOを返す。
// 追加時と、読込開始時の2回確認する。

- (BOOL)checkCache{

    // cacheの確認
    ODPTDataProviderSession *c = [self.delegate searchCacheForURL:_query];
    if( [c isEqualToSession:self] == YES ){
        // キャッシュヒットしたものが自身と同じかを確認
        c = nil;
    }
    
    if(c != nil){
        // キャッシュがすでにある。以前に同じクエリで 読み込んだことがある。
        
        if(c.isFinished == NO){
            // 前のSession の読み取り完了時に、このSessionのコールバックを走らせるようにセット。
            [c addRelatedSession:self];
            
        }else{
            // 既に読み込み済み。
            
            // キャッシュからすぐに読み込み、コールバック実行
            self.parsedData = c.parsedData;
            
            if(c.parsedData == nil){
                NSLog(@"cache data is nil!!");
            }
            
            [self startCallBack];
        }
        
        return YES;
    }
    
    return NO;
}



- (void)parseData{

    if(self.parsedData != nil){
        return;
    }
    
    // callback へ　渡すオブジェクト
    //   正常終了 : jsonパース後の NSArray/NSDictionary
    //   jsonパースエラー： nil
    //   アクセスキャンセル：　nil
    
    if(receivedData == nil){
        NSLog(@"cancelled. No. %@", self.uuid);
        self.parsedData = nil;
        return;
    }
    
    //NSLog(@"Session callback call.");
    NSError *error = nil;
    id json = [NSJSONSerialization JSONObjectWithData:receivedData options:0 error:&error];
    if (error) {
        NSLog(@"%@ query:%@ content: %@", error, self.query,
              [[NSString alloc] initWithData:receivedData
                                    encoding:NSUTF8StringEncoding]);
        self.parsedData = nil;
        receivedData = nil;
        return;
    }
    
    self.parsedData = json;
    receivedData = nil;
    
    if([json isKindOfClass:[NSArray class]] == NO){
        NSLog(@"ODPTDataProviderSession WARNING!! json type is not NSArray. query:%@", self.query);
    }
}




- (void)sendRequestSession{
    
    NSLog(@"start access query:%@ ", _query);
    
    // NSURLSessionオブジェクトを作成　保持する。
    NSURLSessionConfiguration *ephemeralConfig = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    ephemeralConfig.requestCachePolicy = NSURLRequestReloadIgnoringCacheData; // NSURLSession に実装してあるキャッシュは使わない。
    ephemeralConfig.timeoutIntervalForRequest = 5.0f;
    
    // セッションを作る
    urlSession = [NSURLSession sessionWithConfiguration:ephemeralConfig
                                                delegate:nil
                                           delegateQueue:[NSOperationQueue currentQueue]];
    

    NSMutableString *s_url = [[NSMutableString alloc] init];
    
    [s_url appendString:[self.delegate endPointURL]];
    
    [s_url appendString:_query];
    [s_url appendString:@"&acl:consumerKey="];

    [s_url appendString:[self.delegate token]];
    
    // データの長さを0で初期化
    [receivedData setLength:0];

    NSURLSessionDataTask *dataTask = [ urlSession dataTaskWithURL:[NSURL URLWithString:s_url] completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {

        //　通信完了時の処理
        // 最終アクセス完了時刻を記録。
        [self.delegate didReceivedResponseOfSession:self];
        
        if([self isCancelled] == YES){
            // ジョブはキャンセルされた。実行中の通信はキャンセル
            [self abortLoading];
            
            // ジョブ終了
            [self completeOperation];
            return;
        }
        
        
        if(error != nil){
            
            NSLog(@"NSUrlSession dataTaskWithURL complete with error.");
            NSLog(@"err description = %@", error.description);
            NSLog(@"err %@", error.localizedDescription);
            NSLog(@"err code = %d", (int)error.code);
            NSLog(@"err domain = %@", error.domain);
            NSLog(@"err userInfo = %@", error.userInfo);
            
            if(error.code == -1001){
                // タイムアウト
                NSLog(@"connection time out occured.");
            }else if(error.code == -1005){
                // コネクションロスト
                NSLog(@"connection was lost.");
            }
            
            // エラーが出た時もリトライする。
            // receivedData は長さゼロ。　nilではない。
            [self finishLoading];
            
        }else{
            // 受信したデータを追加
            [self->receivedData appendData:data];
            [self finishLoading];
        }
        
        // 以下の一行でObserverに準備完了を通知。 次のアクセスに移る。
        [self completeOperation];
        
    }];
    
    // 通信開始。
    [dataTask resume];
    
}

// 読み込み完了時　内容チェック。
// request rate too high が帰ってきた場合: このメソッド内で同じアクセッサを作成し、キューに追加する。slowDown させる。コールバックを呼ばずにこのアクセッサは終了。
//                                       3回同じ request rate too high が返ってきたら、諦める。_receivedData は nil でコールバックを呼ぶ。
// データ長さ50バイト以下でも、上記以外はそのまま、コールバックを通す。

- (void)finishLoading{
    
    BOOL retry = NO;
    if([receivedData length] == 0){
        // 通信エラーとなっている状態。
        retry = YES;
        
    }else if([receivedData length] < 50){
        // データが30バイトより小さい場合、うまくデータが取得できていない可能性が高い。
        // が、そうでない可能性もある。
        
        NSData *sdata = [receivedData subdataWithRange:NSMakeRange(0, [receivedData length])];
        NSString *str = [[NSString alloc] initWithData:sdata encoding:NSUTF8StringEncoding];
        
        if( [str containsString:@"Your request rate is too high"] == YES){
        //if( [str containsString:@"API rate limit exceeded"] == YES){
            NSLog(@"request rate is too high returnd %@", _query);
            retry = YES;
        }else if([str containsString:@"API rate limit exceeded"] == YES){
            NSLog(@"API rate limite exceeded %@", _query);
            retry = YES;
        }else{
            // データ長さは50バイト以下だが、読み込みは成功している可能性はある。そのまま、とする。
            NSLog(@"data:%@ %@", receivedData, str);
        }
        
    }
    
    [self.delegate didParseResponseOfSession:self withSuccess:!retry];
    
    if(retry == YES){
            // rate is too high が返ってきたとき
            // 通信がタイムアウトになった時には、
            // しばらく待ってから　再度リクエストを出す。
            //  2回まで。
            
            if(++self.retryCount <= 2){
                NSLog(@"retry start %d", (int)self.retryCount);
                
                // 再度リクエストを出す。高優先で。
                ODPTDataProviderSession *atmod = [[ODPTDataProviderSession alloc] initWithOwner:self.owner withHighPriority:YES];
                [atmod setDelegate:self.delegate];
                
                [atmod setRetryCount:self.retryCount];

                [atmod requestForQuery:_query block:callback ];
                
                atmod.relatedSessions = self.relatedSessions;
                
                return;
                
            }else{
                // 諦める。
                NSLog(@"retry giveup.");
                
                receivedData = nil;
            }
    }
    
    if(self.retryCount != 0){
        NSLog(@"retry returned.");
    }
    
    // アクセス完了時刻を記録。
    self.accessDate = [NSDate date];
        
    // コールバック呼び出し
    [self startCallBack];

}

// 読み込み中止時の処理
//  キャンセル or 通信失敗 の場合
// 中身 nil で コールバックを呼ぶ
- (void)abortLoading{

    self->receivedData = nil;
    
    [self.delegate didAbortAccessOfSession:self];
    
    // コールバック呼び出し  失敗でもコールバックを呼び出さないと処理が止まる。
    [self startCallBack];
    
    
}


// Session 終了時。　これを呼ぶと Sessionは終了する。
- (void)completeOperation{

    [self setValue:[NSNumber numberWithBool:NO] forKey:@"isExecuting"];
    [self setValue:[NSNumber numberWithBool:YES] forKey:@"isFinished"];
    // self.isFinished = [NSNumber numberWithBool:YES]
    // では、KVOは発動しない。
    
}

- (BOOL)isEqualToSession:(ODPTDataProviderSession *)ac{
    if([self.uuid isEqual:ac.uuid]){
        return YES;
    }
    
    return NO;
}

- (void)addRelatedSession:(ODPTDataProviderSession *)a{
    
    if(_relatedSessions == nil){
        _relatedSessions = [[NSMutableArray alloc] init];
    }
    
    @synchronized(self){
        [_relatedSessions addObject:a];
    }
    
}


- (void)startCallBack{
    
    [self parseData];
    //NSLog(@"startCallback");
    // 別スレッドで実行開始。 これによって、コールバックメソッドの完了を待たずに次のURLアクセスへ移ることができる。
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        // NSLog(@"start callback for query:%@ serial:%@", self.query, self.uuid);
        
        self->callback(self.parsedData);
        self->callback = nil;
        
        // このSession のコールバックを呼んだ後に、 relatedCallbackを呼ぶ。
        [self startRelatedCallBack];
        //NSLog(@"callback end.");
    });
    
    
}

- (void)startRelatedCallBack{

    // isFinished => YES とした後で。
    // relatedSessions に入っている他のSessions のコールバックを実行する。
    @synchronized(self){
        if(_relatedSessions != nil){
            for(int i=0; i<[_relatedSessions count]; i++){
                ODPTDataProviderSession *a = [_relatedSessions objectAtIndex:i];
                a.parsedData = self.parsedData;
                [a startCallBack];
            }
        }
    }
}

#pragma mark - NSOperation override
// 実際にアクセスを開始する。NSOperationQueueが自動的に呼び出す。
- (void) start{
    
    // isExecutingを　YESに。
    [self setValue:[NSNumber numberWithBool:YES] forKey:@"isExecuting"];   // -> オブザーバに通知

    [NSThread detachNewThreadSelector:@selector(main) toTarget:self withObject:nil];

}


- (void) main{
    
    if([self isCancelled] == YES){
        // このジョブはキャンセルされている。
        [self abortLoading];
        
        [self completeOperation];
        
        return;
    }
    
    
    // キャンセルされていなければ、新しいスレッドでタスクの実行を開始する。
    // このアクセッサで実行する メインの処理

    // キャッシュの有無を確認
    if([self checkCache] == YES){
        // キャッシュが存在. このSessionはこれ以上先に進まない。
        // 以下の一行でObserverに準備完了を通知。
        [self completeOperation];
        return;
    }
    

    //　最後のアクセスから100ms待ってから実行。
    float waitTime = 0.0f;
    if(self.delegate != nil){
        waitTime = [self.delegate waitTimeForNextSessionFromNow];
    }
    
    // 遅延実行
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(waitTime * NSEC_PER_SEC)),
                   dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
                       [self sendRequestSession];
                   });

}

- (void)cancel{
    
    id ownerForCancel = [self.delegate ownerForCancel];

    BOOL cancelFlag = NO;

    if(ownerForCancel != nil){
        // cancelOwnerだけキャンセル
        if(ownerForCancel == _owner){
            cancelFlag = YES;
        }
        
    }else{
        cancelFlag = YES;
    }
    
    if(cancelFlag == YES){
        // 本来のNSOperation のcancelを呼ぶ。　-> [self isCancelled] が YESを返すようになる。
        [super cancel];
    }
     
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

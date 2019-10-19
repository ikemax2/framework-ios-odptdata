//
//  EfficientLoaderQueue.m
//
//  Copyright (c) 2018 Takehito Ikema
//
//  This software is released under the MIT License.
//  https://opensource.org/licenses/mit-license.php
//

#import "EfficientLoaderQueue.h"

@implementation EfficientLoaderQueue{
     NSOperationQueue *jobQueue;
    //NSInteger gSerialNumber;
    
    __weak id m_cancelOwner;
}

NSInteger const kEfficientLoaderMaxConcurrentOperationCount = 1000;


- (id)init{
    
    self = [super init];
    if (self) {
        //Initialization
        [self refleshQueue];
        
    }
    return self;
}

- (void)clear{
    [self refleshQueue];
}

// キューだけを作り直す
- (void)refleshQueue{
    @synchronized(self){
        jobQueue = nil;
        jobQueue = [[NSOperationQueue alloc] init];
        jobQueue.maxConcurrentOperationCount = kEfficientLoaderMaxConcurrentOperationCount;
    }
}

- (void)setSuspended:(BOOL)isSuspend{
    [jobQueue setSuspended:isSuspend];
}

- (void)addLoaderInner:(EfficientLoader *) loader{
    
    [loader setQueue:self];
    
    @synchronized(jobQueue){
        
        // 今 Queue にて実行中のLoaderの中に、同じアクセスをするLoaderがないか調べる。
        EfficientLoader *rLoader = [self relatedLoaderForLoader:loader];
        
        if(rLoader != nil){
            // NSLog(@"LoaderManager addRelatedLoader q:%@", [loader query]);
            // loader の 実行終了後に、このloader(self) を呼ぶように設定。
            @synchronized(rLoader){
                
                if([rLoader addRelatedLoader:loader] == NO){
                    // 追加に失敗した。 -> jobQueue に追加して終了
                    //NSLog(@"LoaderManager addRelatedLoader failure.");
                    [jobQueue addOperation:(NSOperation *)loader];
                    return;
                }else{
                    // jobQueueに追加せず、終了.
                    [loader setWaitingRelatedLoader:YES];
                    [loader addChild:rLoader];
                    return;
                }
            }
        }
        
        [jobQueue addOperation:(NSOperation *)loader];
    }
    
}

- (EfficientLoader *) loaderWithSameQueryOfQueue:(EfficientLoader *)loader{
    
    NSString *query = [loader query];
    
    if([query isEqualToString:@""] || query == nil){
        return nil;
    }
    
    int index = -1;
    EfficientLoader *retObject = nil;
        
    NSArray *operations = [jobQueue operations];
    // NSLog(@"isNowLoading search: %@ count: %d ", query, [operations count]);
    
    for(int i=0; i<[operations count]; i++){
        
        EfficientLoader *op = [operations objectAtIndex:i];
        if([op serialNumber] == [loader serialNumber]){
            continue;
        }
        
        if( [[op query] isEqualToString:query]){
            retObject = op;
            index = i;
            break;
        }
        
    }

    // NSLog(@" -> No.%d %@", index, [retObject query]);
    BOOL flag;

    flag = [retObject isFinishedLoading];
    
    if(flag == YES){
        return nil;
    }
    return retObject;
}


- (EfficientLoader *) parentOfLoader:(EfficientLoader *)loader WithQuery:(NSString *)query{
    // loaderの親の中に、 指定したquery を持つ Loaderがないか探す。
    EfficientLoader *parent = [loader parent];
    if(parent == nil){
        // NSLog(@"loaderWithSameQueryOfParent  parent nil");
        return nil;
    }    
    
    // NSLog(@"loaderWithSameQueryOfParent  %@ <=> %@", self.parent.query, query);
    if([[parent query] isEqualToString:query]){
        //NSLog(@"loaderWithSameQueryOfParent  return %@", query);
        
        BOOL flag;
        @synchronized(parent){
            flag = [parent isFinishedLoading];
        }
        
        if(flag == YES){
            return nil;
        }
        return loader.parent;
    }
    
    // 再帰呼び出し。
    return [self parentOfLoader:loader.parent WithQuery:query];
}


- (BOOL) isExistLoader:(EfficientLoader *)searchLoader InDependedLoadersOfLoader:(EfficientLoader *)loader{
    // loader が依存している Loader の中に、　指定した loader がないか探す。
    
    NSArray *children = [loader children];
    
    for(int i=0; i<[children count]; i++){
        EfficientLoader *l = [children objectAtIndex:i];
        
        if([l serialNumber] == [searchLoader serialNumber]){
            return YES;
        }
        
        // 再帰呼び出し
        if([self isExistLoader:searchLoader InDependedLoadersOfLoader:l] == YES){
            return YES;
        }
    }
    
    return NO;
}


- (EfficientLoader *) relatedLoaderForLoader:(EfficientLoader *)loader{

    EfficientLoader *retObject = nil;
    
    NSString *query = [loader query];
        
    if([query isEqualToString:@""] || query == nil){
        return nil;
    }
    
        
    NSArray *operations = [jobQueue operations];
    //NSLog(@"isNowLoading search: %@ count: %d ", query, [operations count]);
        
    for(int i=0; i<[operations count]; i++){
            
        EfficientLoader *op = [operations objectAtIndex:i];
        if([op serialNumber] == [loader serialNumber]){
            // 全く同じ loader.
            continue;
        }
            
        if( [[op query] isEqualToString:query]){
                
            // 同じquery で、他のloader が実行中。
            // 二重アクセスを防ぐため、他方のquery の終了を待ってからこのquery のmainを始めるようにする。
                
            // 見つけた同queryの loader は、さらに別のloader の終了を待っている状態ではないことを確認。
            // 同じquery が連続してstart すると、互いに互いを待ち続ける循環参照に陥る場合がある。
                
            if([self parentOfLoader:loader WithQuery:[loader query]] == nil){
                
                // このloaderを呼び出した別のloader (親/祖父) の中に、同queryを持つloader がないか確認。
                // あった場合、子queryが、親query の終了を待つ状態となり、互いに互いを待ち続ける循環参照に陥る場合がある。
                
                    
                if([self isExistLoader:loader InDependedLoadersOfLoader:op] == NO){
                    
                    // sLoader が依存している（子/孫) loader群 の中に、loaderがないか確認する。
                    // あった場合は、循環参照に陥るケースがある。
                    
                    retObject = op;
                    break;
                }
                
                // 残りの場合は、他に存在する同query loader の完了を待たずに、そのままloaderを開始する。
                //  (同じqueryのloaderが複数、同時に処理することになる。
                //   そのため、複数あるローダの遅れてきた方は、アクセスせずにすぐ作成途中のCoredataオブジェクトを渡すように実装する必要がある)
                NSLog(@"duplicate access occur. query:%@", [loader query]);
            }
            
        }
        
    }
    
    // NSLog(@" -> No.%d %@", index, [retObject query]);
    BOOL flag;
        
    flag = [retObject isFinishedLoading];
    
    if(flag == YES){
        retObject = nil;
    }
    
    return retObject;
}

/*
- (NSInteger)nextSerialNumber{
    return gSerialNumber++;
}
*/
- (void)cancelAllLoading{
    
    [jobQueue cancelAllOperations];
    
}

- (void)cancelLoadingForOwner:(id)owner{
    
    @synchronized(jobQueue) {
        m_cancelOwner = owner;
        [jobQueue cancelAllOperations];  // キューの中にあるNSOperationクラスのcancelメソッドを呼び出す。
        m_cancelOwner = nil;
    }
    
}


- (void)printQueueInformation{
    
    NSLog(@"Queue count %d", (int)self->jobQueue.operationCount);
    NSLog(@"Queue suspended %d", [self->jobQueue isSuspended]);

    /*
    NSArray *ops = [NSArray arrayWithArray:[self->jobQueue operations]];
    for(int i=0; i<[ops count]; i++){
        id<LoaderManaging> l = [ops objectAtIndex:i];

        id<LoaderManaging> parent = [l parent];
        NSLog(@"No. %ld query: %@ parent: %@", [l serialNumber], [l query], [parent serialNumber]);
        //NSLog(@"Queue: n:%d e:%d f:%d c:%d ", a.num, [a isExecuting], [a isFinished], [a isCancelled]);
        
    }
    */
    NSArray *ops = [NSArray arrayWithArray:[self->jobQueue operations]];
    for(int i=0; i<[ops count]; i++){
        EfficientLoader *l = [ops objectAtIndex:i];
        [l printInformation];
    }
}


- (NSInteger)countLoading{
    
    return self->jobQueue.operationCount;
    
}


#pragma mark - EfficientLoaderQueue Protocol
// Loader から呼ばれる。

- (void)addLoader:(EfficientLoader *) loader{
    [self addLoaderInner:loader];
}

- (void)startRelatedCallBackForLoader:(EfficientLoader *)loader{
    
    // isFinished => YES とした後で。
    
    NSArray *relatedLoadersCopy = nil;
    @synchronized(self){
        if([loader relatedLoaders] != nil){
            relatedLoadersCopy = [loader relatedLoaders];
            [loader clearRelatedLoaders];
            // relatedLoaders = nil;
        }
    }
    
    if([loader isSuccess] == YES){
        for(int i=0; i<[relatedLoadersCopy count]; i++){
            id l = [relatedLoadersCopy objectAtIndex:i];
            // NSLog(@"relatedCallback %@", [l query]);
            [l main];
        }
    }else{
        // アクセスに失敗またはキャンセルされた時
        // まだ残っている先頭のLoaderを再実行させ、他のLoaderはそのLoaderのrelatedLoaderにさせる

        if([relatedLoadersCopy count] > 0){
            NSLog(@"loader is failed, first relatedLoader will start load.");
            EfficientLoader *leadLoader = [relatedLoadersCopy firstObject];
            [leadLoader setWaitingRelatedLoader:NO];
            
            for(int i=1; i<[relatedLoadersCopy count]; i++){
                EfficientLoader *followLoader = relatedLoadersCopy[i];
                @synchronized (leadLoader) {
                    if([leadLoader addRelatedLoader:followLoader] == YES){
                        [followLoader setWaitingRelatedLoader:YES];
                        [followLoader addChild:leadLoader];
                    }
                }
            }
            
            [self addLoaderInner:leadLoader];
        }
    }

    
}

- (id)cancelOwner{
    return m_cancelOwner;
}
    
@end

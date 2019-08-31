//
//  ODPTDataLoaderArray.m
//
//  Copyright (c) 2018 Takehito Ikema
//
//  This software is released under the MIT License.
//  https://opensource.org/licenses/mit-license.php
//
#import "ODPTDataLoaderArray.h"

NSString *const ODPTDataLoaderArrayOptionsInCompleteFinish = @"incompleteFinish";

@implementation ODPTDataLoaderArray{
    
    NSMutableDictionary *retDic;
    NSMutableArray *retArray;
    NSInteger parallelCount;
    BOOL called;  //callbackを呼ぶのは一度だけ。
    
    BOOL isIncompleteFinish;
    
}

- (id)init{
    
    NSAssert(YES, @"ODPTDataLoaderArray must not use init message.");
    
    return nil;
}

- (id) initWithLoaders:(NSArray<ODPTDataLoader *> *)loaders Block:(void (^)(NSArray<NSManagedObjectID *> *))block{

    return [self initWithLoaders:loaders withOptions:nil Block:block];
    
}

- (id) initWithLoaders:(NSArray<ODPTDataLoader *> *)loaders withOptions:(NSDictionary *)options Block:(void (^)(NSArray<NSManagedObjectID *> *))block{
    
    isIncompleteFinish = NO;
    
    if(options != nil){
        NSNumber *incompleteFinish = [options objectForKey:ODPTDataLoaderArrayOptionsInCompleteFinish];
        isIncompleteFinish = [incompleteFinish boolValue];
    }
    
    if(self = [super init]){
        self.loaderArray = loaders;
        for(int i=0; i<[loaders count]; i++){
            ODPTDataLoader *l = [loaders objectAtIndex:i];
            NSAssert([l query] != nil, @"ODPTDataLoaderArray member must have query.");
        }
        
        self.callback = [block copy]; // IMPORTANT
        
        retArray = [[NSMutableArray alloc] init];
    }
    
    return self;
}

- (void)postAccess{
    
    for(int i=0; i<[self.loaderArray count]; i++){
        ODPTDataLoader *l = [self.loaderArray objectAtIndex:i];
        NSString *key = [l query];
        NSManagedObjectID *d = [retDic objectForKey:key];
        if(d == nil){
            d = [[NSManagedObjectID alloc] init];
        }
        [retArray addObject:d];
    }
    
}


- (void)startCallBack{
    
    // 別スレッドで実行開始。 これによって、コールバックメソッドの完了を待たずに次のURLアクセスへ移ることができる。
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        if(self->retArray == nil){
            self.callback(nil);
        }else{
            self.callback([self->retArray copy]);
        }
    });
    
}


#pragma mark - ManagedLoader override

- (NSString *) query{
    return @"";
}

- (void)main{
    
    if([self isCancelled] == YES){
        
        [self startCallBack];
        [self completeOperation];
        return;
    }
    
    retDic = [[NSMutableDictionary alloc] init];
    
    parallelCount = [self.loaderArray count];
    //NSAssert(parallelCount > 0, @"ODPTDataLoaderArray count is ZERO!!");
    
    if(parallelCount == 0){
        // 空Arrayが渡された場合はそのままコールバックへ. 空Arrayが返る
        self->called = YES;
        [self startCallBack];
        [self completeOperation];
        return;
    }
    
    
    for(int i=0; i<[self.loaderArray count]; i++){
        
        ODPTDataLoader *l = [self.loaderArray objectAtIndex:i];
        
        typedef void (^callback_member)(NSManagedObjectID *);
        callback_member cbm = ^(NSManagedObjectID *moID){
            
            // isIncompleteFinish == NO の場合、一つでも読み込み失敗すれば、全体をエラーとする。

            if(self->isIncompleteFinish == NO){
                if(moID == nil || [l isCancelled] == YES){
                    self->retArray = nil;
                    @synchronized(self){
                        if(self->called == NO){
                            self->called = YES;
                            [self startCallBack];
                            [self completeOperation];
                        }
                    }
                    
                    return;
                }
            }

            
            @synchronized(self){
                NSString *key = [l query];
                if(self->isIncompleteFinish == YES){
                    if(moID == nil || [self isCancelled] == YES){
                        // 取得に失敗している loader は NSNull を返す
                        [self->retDic setObject:[NSNull null] forKey:key];
                    }else{
                        [self->retDic setObject:moID forKey:key];
                    }
                }else{
                    [self->retDic setObject:moID forKey:key];
                }
                
                if(--self->parallelCount <= 0){
                    // すべてのアクセスが完了。
                    [self postAccess];
                    
                    if(self->called == NO){
                        self->called = YES;
                        [self startCallBack];
                        [self completeOperation];
                    }
                    
                    return;
                }
            }
            
            return;
        };
        
        [l setCallback:cbm];
        
        
        l.dataProvider = self.dataProvider;
        l.dataManager = self.dataManager;
        
        [l setParent:self];
        [l setOwner:self.owner];
        
        [[self queue] addLoader:l];
        
    }
    
    
}

@end

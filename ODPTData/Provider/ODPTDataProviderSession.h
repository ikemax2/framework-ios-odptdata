//
//  ODPTDataProviderSession.h
//
//  Copyright (c) 2015 Takehito Ikema
//
//  This software is released under the MIT License.
//  https://opensource.org/licenses/mit-license.php
//

#import <Foundation/Foundation.h>


@class ODPTDataProviderSession;

@protocol ODPTDataProviderSessionDelegate
@required

- (void)readyForURLAccessOfSession:(ODPTDataProviderSession *)a;
- (void)didReceivedResponseOfSession:(ODPTDataProviderSession *)a;
- (void)didParseResponseOfSession:(ODPTDataProviderSession *)a withSuccess:(BOOL)isSuccess;
- (void)didAbortAccessOfSession:(ODPTDataProviderSession *)a;

- (ODPTDataProviderSession *) searchCacheForURL:(NSString *)url;
- (float) waitTimeForNextSessionFromNow;

- (id) ownerForCancel;
- (NSString *)token;
- (NSString *)endPointURL;

@end



@interface ODPTDataProviderSession : NSOperation

- (id)initWithOwner:(id)owner withHighPriority:(BOOL)highPriority;

- (void)requestDataSearchForType:(NSString *)type forPredicate:(NSDictionary *)pred block:(void (^)(id))block;

@property(nonatomic, weak) id<ODPTDataProviderSessionDelegate> delegate;

@property(nonatomic, weak) id owner;  // リクエストのオーナー

@property(nonatomic, strong) NSString *uuid;  // 重複しない識別子

@property(nonatomic, strong) NSString *query;

@property(nonatomic, strong) NSDate *accessDate;
@property(nonatomic) float cacheValidPeriod;  // キャッシュの有効時間[秒]

@property(nonatomic, strong) id parsedData;   // json として処理されたデータ NSArray or NSDictionary;

@property(nonatomic) NSInteger retryCount;  // アクセスの再チャレンジ数;

// このSessionがアクセス中に、同じクエリでのSessionのリスト。
// このSessionが読み込み完了後に、コールバックを実行。
@property(nonatomic, strong) NSMutableArray *relatedSessions;

@property(nonatomic) BOOL isFinished; // 結果を受けたか NSOperationQueueが参照する
@property(nonatomic) BOOL isExecuting; // 実行中か　NSOperationQueueが参照する

@end

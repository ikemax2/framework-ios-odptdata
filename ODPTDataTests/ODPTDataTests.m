//
//  ODPTDataTests.m
//
//  Copyright (c) 2019 Takehito Ikema
//
//  This software is released under the MIT License.
//  https://opensource.org/licenses/mit-license.php
//
#import <XCTest/XCTest.h>
#import "ODPTDataTests.h"
#import "ODPTDataProvider.h"
#import "TestRightAnswerContainer.h"


@implementation ODPTDataTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
    [self readToken];
    NSLog(@"ODPTData token:%@", self->token);
    
    [self readEndPointURL];
    NSLog(@"ODPTData endPointURL:%@", self->endPointURL);
    
    // YES: 正解書き込み  NO: 正解確認
    [TestRightAnswerContainer setWritingMode:YES];
    
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}


- (void)testExample {
    // This is an example of a functional test case.
    // Use XCTAssert and related functions to verify your tests produce the correct results.
}

- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}


- (void)readToken{
    // ODPTアクセス用トークンは、ソースコード,プロジェクトファイル,各種ログファイルに残さない。
    // トークンを記したファイル token.txt は、Run Script でビルドフォルダにコピーするように設定しておく。
    
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    //NSString *bundlePath = [[NSBundle mainBundle] bundlePath];   // アプリケーションの場合は、こちら。
    NSString *bundlePath = [bundle bundlePath];
   
    NSString *filename = [bundlePath stringByAppendingPathComponent:@"token.txt"];
    NSError *error = nil;
    NSString *t = [NSString stringWithContentsOfFile:filename encoding:NSUTF8StringEncoding error:&error];
    
    if(error){
        NSLog(@"token.txt read error!! %@",filename);
    }
    
    if(t == nil || [t length] == 0){
        NSError *error;
        XCTAssertNil(error, @"read Token failure.");
    }
    
    // 改行文字を削除
    NSArray *f = [t componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    
    self->token = [f firstObject];
}

- (void)readEndPointURL{
    // ODPTアクセス用エンドポイントURLは、ソースコード,プロジェクトファイル,各種ログファイルに残さない。
    // エンドポイントURLを記したファイル endpoint.txt は、Run Script でビルドフォルダにコピーするように設定しておく。
    
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *bundlePath = [bundle bundlePath];
    
    NSString *filename = [bundlePath stringByAppendingPathComponent:@"endpoint.txt"];
    NSError *error = nil;
    NSString *t = [NSString stringWithContentsOfFile:filename encoding:NSUTF8StringEncoding error:&error];
    
    if(error){
        NSLog(@"endpoint.txt read error!! %@",filename);
    }
    
    if(t == nil || [t length] == 0){
        NSError *error;
        XCTAssertNil(error, @"read EndPointURL failure.");
    }
    
    // 改行文字を削除
    NSArray *f = [t componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    
    self->endPointURL = [f firstObject];
}

- (void)prepareForAPIAccessWithReset:(BOOL)sw{
    
    queue = [[NSOperationQueue alloc] init];
    eQueue = [[EfficientLoaderQueue alloc] init];   // 並列実行キュー NSOperationは メインスレッド以外で実行される。
    // queue.maxConcurrentOperationCount = 100;  // 同時実行オペレーションは100。
    
    NSString *applicationSupportDirectory = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject];

    dataManager = [[CoreDataManager alloc] initWithStoreDirectory:applicationSupportDirectory andStoreIdent:@"ODPTAPICache" andModelIdent:@"APIModel"];
    
    if(sw == YES){
        [dataManager removeStoreURL];
    }
    
    
    dataProvider = [[ODPTDataProvider alloc] init];
    
    [dataProvider setToken:(NSString *)token];
    [dataProvider setEndPointURL:endPointURL];
}


- (void)printJobQueue:(NSOperationQueue *)queue{
    
    NSArray *ops = [queue operations];
    
    for(int i=0; i<[ops count]; i++){
        id l = [ops objectAtIndex:i];
        [l printInformation];
    }
}

- (void)sequentialOperation{
    NSLog(@"sequentialOperation start.");
    [queue cancelAllOperations];
    
    NSBlockOperation *op = [[NSBlockOperation alloc] init];
    __weak NSBlockOperation *weakOp = op;
    [op addExecutionBlock:^{
        NSLog(@"  addExecutionBlock start.");
        
        [NSThread sleepForTimeInterval:0.3f];  // 少し待つ。
        
        if( [weakOp isCancelled]){  // __weak 指示のため、参照できる。
            NSLog(@"  job cancelled.");
            return;
        }
        // 駅を選択前の処理。
        /*
         [self heavyTaskBlock:^{
         }];
         */
        [self heavyTaskCompleteUntilWaitBlock:^{
            
        }];
        
        NSLog(@"  addExecutionBlock end.");
    }];
    
    [queue addOperation:op];
    
    NSLog(@"sequentialOperation end.");
}

- (void)heavyTaskBlock:(void (^)(void))block{
    // 非同期処理を含む重い処理
    NSOperationQueue *sQueue = [[NSOperationQueue alloc] init];
    
    NSLog(@"  HeavyTaskBlock start.");
    
    
    NSBlockOperation *op = [[NSBlockOperation alloc] init];
    // __weak NSBlockOperation *weakOp = op;
    [op addExecutionBlock:^{
        [NSThread sleepForTimeInterval:3.0f];  // HeavyTask
        
        NSLog(@"    HeavyTask complete.");
        block();
    }];
    [sQueue addOperation:op];
    
    NSLog(@"  HeavyTaskBlock end.");
}

- (void)heavyTaskCompleteUntilWaitBlock:(void (^)(void))block{
    // 非同期処理を含む重い処理
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    NSOperationQueue *sQueue = [[NSOperationQueue alloc] init];
    
    NSLog(@"  HeavyTaskBlock start.");
    
    
    NSBlockOperation *op = [[NSBlockOperation alloc] init];
    // __weak NSBlockOperation *weakOp = op;
    [op addExecutionBlock:^{
        [NSThread sleepForTimeInterval:3.0f];  // HeavyTask
        
        NSLog(@"    HeavyTask complete.");
        dispatch_semaphore_signal(semaphore);
        block();
    }];
    [sQueue addOperation:op];
    
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    
    NSLog(@"  HeavyTaskBlock end.");
}

- (void)testBlockOperationSequentialCancel{
    // 非同期処理の完了を監視するオブジェクトを作成
    XCTestExpectation *expectation = [self expectationWithDescription:@"testBlockOperationCancel"];
    
    queue = [[NSOperationQueue alloc] init];
    queue.maxConcurrentOperationCount = 1;
    
    // 非同期処理を含む 関数を最後の一度だけ実施したい。
    
    [self sequentialOperation];
    [NSThread sleepForTimeInterval:1.1f];
    [self sequentialOperation];
    
    [NSThread sleepForTimeInterval:10.0f];
    [expectation fulfill];
    
    // 指定秒数（10秒）待つ
    [self waitForExpectationsWithTimeout:30 handler:^(NSError * _Nullable error) {
        
        XCTAssertNil(error, @"has error.");
    }];
}

- (void)testMutableArrayReference {
    
    NSMutableArray *ary = [[NSMutableArray alloc] init];
    
    NSMutableOrderedSet *set = [[NSMutableOrderedSet alloc] init];
    [ary addObject:set];
    
    [set addObject:@"1-1"];
    [set addObject:@"1-2"];
    
    NSMutableOrderedSet *set2 = [[NSMutableOrderedSet alloc] init];
    [ary addObject:set2];
    
    [set2 addObject:@"2-1"];
    [set2 addObject:@"2-2"];
    
    NSMutableOrderedSet *rSet = ary[0];
    [rSet addObject:@"1-3"];
    
    for(int i=0; i<[ary count]; i++){
        NSLog(@"ary %d %@", i, ary[i]);
    }
}
@end

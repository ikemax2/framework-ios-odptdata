//
//  ODPTDataTests+Provider.m
//
//  Copyright (c) 2019 Takehito Ikema
//
//  This software is released under the MIT License.
//  https://opensource.org/licenses/mit-license.php
//

#import <XCTest/XCTest.h>
#import "ODPTDataTests+Provider.h"
#import "TestRightAnswerContainer.h"

@implementation ODPTDataTests (Provider)


- (void)testProviderRequestAccess{
    
    NSString *caseName = @"testProviderRequestAccess";
    
    // 正解を管理するContainerを作成
    TestRightAnswerContainer *rightAnswer = [[TestRightAnswerContainer alloc] initWithTestCase:caseName];
    
    [self prepareForAPIAccessWithReset:YES];
    
    NSArray *shortLineIdentifiers = @[@"odpt.Railway:TokyoMetro.Tozai", @"odpt.Railway:JR-East.Yamanote"];
    
    // 非同期処理の完了を監視するオブジェクトを作成
    XCTestExpectation *expectation = [self expectationWithDescription:caseName];
    expectation.expectedFulfillmentCount = [shortLineIdentifiers count];
    
    for(int p=0; p<[shortLineIdentifiers count]; p++){
        
        NSString *shortLineIdentifier = shortLineIdentifiers[p];
        
        NSDictionary *pred = nil;
        pred = [NSDictionary dictionaryWithObjectsAndKeys:
                @"odpt:Railway", @"type",
                shortLineIdentifier, @"owl:sameAs",
                nil];
        
        __block BOOL endFlag = NO;
        [dataProvider requestAccessWithOwner:self withPredicate:pred block:^(id ary) {
            
            // アクセス失敗/キャンセル
            XCTAssertFalse(ary == nil, @"error.");
            
            // アクセス成功したが、空データ. おそらく identifierが間違っている
            XCTAssertFalse([ary count] == 0, @"error.");
            
            NSDictionary *rec = nil;
            for(int i=0; i<[ary count]; i++){
                rec = [ary objectAtIndex:i];
                if([shortLineIdentifier isEqualToString:[rec objectForKey:@"owl:sameAs"]]){
                    break;
                }
            }
            
            XCTAssertFalse(rec == nil, @"railway can't find propery record!!!");
            
            // NSLog(@"result:%@", rec);
            NSMutableArray *answer = [[NSMutableArray alloc] init];
            NSArray *stationOrder = rec[@"odpt:stationOrder"];
            for(int i=0; i<[stationOrder count]; i++){
                NSDictionary *d = stationOrder[i];
                [answer addObject:d[@"odpt:station"]];
            }
            
            // 正解記録 or 正解確認
            if([rightAnswer judgeAnswer:answer forQuery:pred] == NO){
                XCTAssertFalse(YES, @"answer is wrong or not Found. Query:%@ ", pred);
            }
            
            endFlag = YES;
        }];
        
        // 終わるまで待つ。
        while(endFlag == NO){
            [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0f]];
        }
        
        [expectation fulfill];
    }
    

     [self waitForExpectationsWithTimeout:20 handler:^(NSError * _Nullable error) {
         XCTAssertFalse(NO, @"No Answer.");
     }];

}
    
@end

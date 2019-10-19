//
//  ODPTDataTests+Controller.m
//
//  Copyright (c) 2019 Takehito Ikema
//
//  This software is released under the MIT License.
//  https://opensource.org/licenses/mit-license.php
//


#import <XCTest/XCTest.h>
#import "ODPTDataTests+Controller.h"

#import "ODPTDataController.h"
#import "ODPTDataController+LineAndStation.h"
#import "ODPTDataController+Timetable.h"
#import "ODPTDataController+Dynamic.h"
#import "ODPTDataController+Setting.h"
#import "ODPTDataController+Place.h"

#import "ODPTDataAdditional.h"

#import "CoreDataManager.h"
#import "TestRightAnswerContainer.h"

@implementation ODPTDataTests (Controller)

- (NSString *)cacheDirectory {
    return [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject];
}

- (NSString *)userDataDirectory {
    return [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
}


- (void)resetStoreURL{
    
    CoreDataManager *cdm = [[CoreDataManager alloc] initWithStoreDirectory:[self cacheDirectory] andStoreIdent:@"ODPTAPICache" andModelIdent:@"APIModel"];
    [cdm removeStoreURL];
    
    cdm = [[CoreDataManager alloc] initWithStoreDirectory:[self userDataDirectory] andStoreIdent:@"user" andModelIdent:@"UserDataModel"];
    [cdm removeStoreURL];
    
}

- (NSString *)stringForConnectionLinesLeft:(id)leftCont Right:(id)rightCont{
    
    NSMutableString *leftStr = [[NSMutableString alloc] init];
    
    if([leftCont isKindOfClass:[NSArray class]]){
        for(int j=0; j<[leftCont count]; j++){
            if([leftStr length] > 0){
                [leftStr appendString:@","];
            }
            NSDictionary *dict = [leftCont objectAtIndex:j];
            [leftStr appendString:dict[@"connectingLine"]];
        }
        
    }else if([leftCont isEqual:[NSNull null]]){
        [leftStr appendString:@"[none]"];
    }
    
    
    NSMutableString *rightStr = [[NSMutableString alloc] init];
    
    if([rightCont isKindOfClass:[NSArray class]]){
        for(int j=0; j<[rightCont count]; j++){
            if([rightStr length] > 0){
                [rightStr appendString:@","];
            }
            
            NSDictionary *dict = [rightCont objectAtIndex:j];
            [rightStr appendString:dict[@"connectingLine"] ];
        }
        
    }else if([rightCont isEqual:[NSNull null]]){
        [rightStr appendString:@"[none]"];
    }
    
    return [NSString stringWithFormat:@"%@ / %@", leftStr, rightStr];
    
}

- (void)testRequestStationInformation{
    NSString *caseName = @"testRequestStationInformation";
    
    // 正解を管理するContainerを作成
    TestRightAnswerContainer *rightAnswer = [[TestRightAnswerContainer alloc] initWithTestCase:caseName];
    
    [self resetStoreURL];
    
    ODPTDataController *dataSource = [[ODPTDataController alloc] initWithAPICacheDirectory:[self cacheDirectory]
                                                                     withUserDataDirectory:[self userDataDirectory]
                                                                           withEndPointURL:endPointURL
                                                                                 withToken:token];
    
    [dataSource prepare];
    
    // キャッシュクリア
    [dataSource clearCache];
    
    NSArray *StationIdentifiers = @[@"odpt.Station:TokyoMetro.Ginza.Shibuya",
                                    @"odpt.BusstopPole:Toei.IkebukuroStationHigashiguchi.87.3"];

    
    // 非同期処理の完了を監視するオブジェクトを作成
    XCTestExpectation *expectation = [self expectationWithDescription:caseName];
    expectation.expectedFulfillmentCount = [StationIdentifiers count];
    
    for(int p=0; p<[StationIdentifiers count]; p++){
        NSString *StationIdentifier = StationIdentifiers[p];

        [dataSource requestWithOwner:nil StationInformationForIdentifier:StationIdentifier Block:^(NSDictionary *dict) {
            NSLog(@"%@", dict);
            
            NSNumber *lat = [dict objectForKey:@"latitude"];
            NSNumber *lon = [dict objectForKey:@"longitude"];
            NSString *title_ja = [dict objectForKey:@"title_ja"];
            NSString *title_en = [dict objectForKey:@"title_en"];
            
            // connectingLinesについては、このコマンドでは取得できない。
            
            NSString *q = StationIdentifier;
            NSDictionary *answer = @{@"latitude": [lat stringValue],
                                     @"longitude": [lon stringValue],
                                     @"title_ja": title_ja,
                                     @"title_en": title_en
                                     };
            // 正解記録 or 正解確認
            if([rightAnswer judgeAnswer:answer forQuery:q] == NO){
                XCTAssertFalse(YES, @"answer is wrong or not Found. Query:%@ ", q);
            }
            [expectation fulfill];
        
        }];
    }
    
    // 指定秒数待つ
    [self waitForExpectations:@[expectation] timeout:60.0f enforceOrder:NO];
}

- (void)testRequestStationTitle{
    NSString *caseName = @"testRequestStationTitle";
    // 正解を管理するContainerを作成
    TestRightAnswerContainer *rightAnswer = [[TestRightAnswerContainer alloc] initWithTestCase:caseName];
    
    [self resetStoreURL];
 
    ODPTDataController *dataSource = [[ODPTDataController alloc] initWithAPICacheDirectory:[self cacheDirectory]
                                                                     withUserDataDirectory:[self userDataDirectory]
                                                                           withEndPointURL:endPointURL
                                                                                 withToken:token];
    [dataSource prepare];
    
    // キャッシュクリア
    [dataSource clearCache];
    
    NSArray *idents = @[@"odpt.Station:TokyoMetro.Ginza.Shibuya", @"odpt.Station:TokyoMetro.Ginza.Ueno", @"odpt.Station:JR-East.Yokosuka.Tokyo"];
    
    // 非同期処理の完了を監視するオブジェクトを作成
    XCTestExpectation *expectation = [self expectationWithDescription:caseName];
    expectation.expectedFulfillmentCount = [idents count];
    
    for(int i=0; i<[idents count]; i++){
        NSString *StationIdentifier = idents[i];
        [dataSource requestWithOwner:nil StationTitleForIdentifier:StationIdentifier Block:^(NSString *ls) {
            NSLog(@"%@",ls);
            
            NSString *q = StationIdentifier;
            NSDictionary *answer = @{@"title": ls
                                     };
            // 正解記録 or 正解確認
            if([rightAnswer judgeAnswer:answer forQuery:q] == NO){
                XCTAssertFalse(YES, @"answer is wrong or not Found. Query:%@ ", q);
            }
            
            [expectation fulfill];
        }];
    }
    
    // 指定秒数（120秒）待つ
    [self waitForExpectations:@[expectation] timeout:60.0f enforceOrder:NO];
    
}

- (void)testRequestLineTitle{
    NSString *caseName = @"testRequestLineTitle";
    // 正解を管理するContainerを作成
    TestRightAnswerContainer *rightAnswer = [[TestRightAnswerContainer alloc] initWithTestCase:caseName];
    
    [self resetStoreURL];
    
    ODPTDataController *dataSource = [[ODPTDataController alloc] initWithAPICacheDirectory:[self cacheDirectory]
                                                                     withUserDataDirectory:[self userDataDirectory]
                                                                           withEndPointURL:endPointURL
                                                                                 withToken:token];
    [dataSource prepare];
    
    // キャッシュクリア
    [dataSource clearCache];
    
    NSArray *idents = @[@"odpt.Railway:TokyoMetro.Ginza.1.1",
                        @"odpt.Railway:JR-East.Tokaido.1.1",
                        @"odpt.Railway:Tobu.Isesaki.1.1",
                        @"odpt.Railway:SaitamaRailway.SaitamaRailway.1.1"];
    
    // 非同期処理の完了を監視するオブジェクトを作成
    XCTestExpectation *expectation = [self expectationWithDescription:caseName];
    expectation.expectedFulfillmentCount = [idents count];
    
    for(int i=0; i<[idents count]; i++){
        NSString *LineIdentifier = idents[i];
        [dataSource requestWithOwner:nil LineTitleForIdentifier:LineIdentifier Block:^(NSString *title) {
            
            NSLog(@"%@ -> %@", LineIdentifier, title);
            
            NSString *q = LineIdentifier;
            NSDictionary *answer = @{@"title": title};
            
            // 正解記録 or 正解確認
            if([rightAnswer judgeAnswer:answer forQuery:q] == NO){
                XCTAssertFalse(YES, @"answer is wrong or not Found. Query:%@ ", q);
            }
            [expectation fulfill];
            
        }];
    }
    
    // 指定秒数（120秒）待つ
    [self waitForExpectations:@[expectation] timeout:20.0f enforceOrder:NO];
    
}


- (void)testIntegratedStationIdentifiers{
    NSString *caseName = @"testIntegratedStationIdentifiers";
    // 正解を管理するContainerを作成
    TestRightAnswerContainer *rightAnswer = [[TestRightAnswerContainer alloc] initWithTestCase:caseName];

    
    [self resetStoreURL];
    
    
    ODPTDataController *dataSource = [[ODPTDataController alloc] initWithAPICacheDirectory:[self cacheDirectory]
                                                                     withUserDataDirectory:[self userDataDirectory]
                                                                           withEndPointURL:endPointURL
                                                                                 withToken:token];
    
    [dataSource prepare];
    
    // キャッシュクリア
    [dataSource clearCache];
    [dataSource clearUserData];
    
    NSArray *LineIdentifiers = @[ @"odpt.Railway:JR-East.Yokosuka.1.1",
                                  @"odpt.Railway:TokyoMetro.Tozai.1.1",
                                  @"odpt.Railway:TokyoMetro.Marunouchi.1.1",
                                  @"odpt.Railway:TokyoMetro.MarunouchiBranch.1.1",
                                  @"odpt.Railway:TokyoMetro.Chiyoda.1.1",
                                  @"odpt.Railway:TokyoMetro.Marunouchi.1.2",
                                  @"odpt.Railway:Odakyu.Odawara.1.1",
                                  @"odpt.Railway:JR-East.Yokosuka.1.2",
                                  @"odpt.Railway:JR-East.Tokaido.1.2",
                                  @"odpt.Railway:JR-East.Takasaki.1.2",
                                  @"odpt.Railway:TokyoMetro.Ginza.1.1",
                                  @"odpt.Railway:TokyoMetro.Ginza.1.1",
                                  @"odpt.Railway:Toei.Oedo.1.1",
                                  @"odpt.Railway:Toei.Oedo.1.1",
                                  @"odpt.Railway:JR-East.Yamanote.1.1",
                                  @"odpt.Railway:JR-East.Yokosuka.1.2",
                                  @"odpt.Railway:JR-East.Yokosuka.1.1",
                                  @"odpt.BusroutePattern:Toei.Nari10.72502.1",
                                  @"odpt.BusroutePattern:Toei.Hashi63.16401.1",
                                  @"odpt.BusroutePattern:Toei.Hashi63.16401.1",
                                  @"odpt.BusroutePattern:Toei.Hashi63.16401.1",
                                  @"odpt.Railway:Keikyu.Main.1.2"
                                 ];
    
    NSArray *StationDicts = @[@{@"identifier":@"odpt.Station:JR-East.SobuRapid.Tokyo", @"duplication":@0},
                              @{@"identifier":@"odpt.Station:TokyoMetro.Tozai.Otemachi", @"duplication":@0},
                                    @{@"identifier":@"odpt.Station:TokyoMetro.Marunouchi.NakanoSakaue", @"duplication":@0},  // 路線の分岐点
                                    @{@"identifier":@"odpt.Station:TokyoMetro.MarunouchiBranch.NakanoFujimicho", @"duplication":@0},
                                    @{@"identifier":@"odpt.Station:TokyoMetro.Chiyoda.Akasaka", @"duplication":@0},
                                    @{@"identifier":@"odpt.Station:TokyoMetro.Marunouchi.Ikebukuro", @"duplication":@0},
                                    @{@"identifier":@"odpt.Station:Odakyu.Odawara.Shinjuku", @"duplication":@0},
                                    @{@"identifier":@"odpt.Station:JR-East.Yokosuka.Shimbashi", @"duplication":@0},
                                    @{@"identifier":@"odpt.Station:JR-East.Tokaido.Tokyo", @"duplication":@0},
                                    @{@"identifier":@"odpt.Station:JR-East.Takasaki.Omiya", @"duplication":@0},
                                    @{@"identifier":@"odpt.Station:TokyoMetro.Ginza.Shibuya", @"duplication":@0},
                                    @{@"identifier":@"odpt.Station:TokyoMetro.Ginza.Asakusa", @"duplication":@0},
                                    @{@"identifier":@"odpt.Station:Toei.Oedo.Tochomae", @"duplication":@0},  // 6の字線 大江戸線 始発駅としての都庁前駅
                                    @{@"identifier":@"odpt.Station:Toei.Oedo.Tochomae", @"duplication":@1},// 6の字線 大江戸線 途中駅としての都庁前駅
                                    @{@"identifier":@"odpt.Station:JR-East.Yamanote.Shinjuku", @"duplication":@0}, // 循環線 山手線
                                    @{@"identifier":@"odpt.Station:JR-East.Yokosuka.Kurihama", @"duplication":@0},  // 始発駅
                                    @{@"identifier":@"odpt.Station:JR-East.Yokosuka.Shimbashi", @"duplication":@0},
                                    @{@"identifier":@"odpt.BusstopPole:Toei.Shimbashi.736.1", @"duplication":@0},
                                    @{@"identifier":@"odpt.BusstopPole:Toei.ShimbashiStation.737.3", @"duplication":@0},  // 終着駅  逆方向路線は指定なし
                                    @{@"identifier":@"odpt.BusstopPole:Toei.OtakibashiShako.2361.1", @"duplication":@0}, // 始発駅
                                    @{@"identifier":@"odpt.BusstopPole:Toei.ShinjukuShobosho.2455.2", @"duplication":@0}, // 途中駅
                                    @{@"identifier":@"odpt.Station:Keikyu.Main.Yokohama", @"duplication":@0}
                                    ];
    
    [dataSource selectToDirectConnectedLine:@"odpt.Railway:TokyoMetro.MarunouchiBranch.1.2"
                                    forLine:@"odpt.Railway:TokyoMetro.Marunouchi.1.2"
                                  atStation:@"odpt.Station:TokyoMetro.Marunouchi.NakanoSakaue"];
    
    // ある路線の途中の駅から、異なる直通路線が分岐するケース
    [dataSource selectToDirectConnectedLine:@"odpt.Railway:Odakyu.Tama.1.1"
                                    forLine:@"odpt.Railway:Odakyu.Odawara.1.1"
                                  atStation:@"odpt.Station:Odakyu.Odawara.ShinYurigaoka"];
    
    // ある路線の終着駅から複数の直通路線が存在するケース
    [dataSource selectToDirectConnectedLine:@"odpt.Railway:JR-East.Uchibo.1.1"
                                    forLine:@"odpt.Railway:JR-East.SobuRapid.1.1"
                                  atStation:@"odpt.Station:JR-East.SobuRapid.Chiba"];
    
    // ある路線の終着駅から複数の直通路線が存在するケース
    [dataSource selectToDirectConnectedLine:@"odpt.Railway:JR-East.Utsunomiya.1.1"
                                    forLine:@"odpt.Railway:JR-East.Tokaido.1.2"
                                  atStation:@"odpt.Station:JR-East.Tokaido.Tokyo"];
    
    // ある路線の終着駅から1本の直通路線が存在するケース
    [dataSource selectToDirectConnectedLine:@"odpt.Railway:JR-East.Tokaido.1.1"
                                    forLine:@"odpt.Railway:JR-East.Takasaki.1.2"
                                  atStation:@"odpt.Station:JR-East.Takasaki.Tokyo"];
    
    // 非同期処理の完了を監視するオブジェクトを作成
    XCTestExpectation *expectation = [self expectationWithDescription:caseName];
    //expectation.expectedFulfillmentCount = [LineIdentifiers count];
    expectation.expectedFulfillmentCount = 1;
    
    for(int p=0; p<[LineIdentifiers count]; p++){
        NSString *LineIdentifier = LineIdentifiers[p];
        NSDictionary *stationDict = StationDicts[p];

        [dataSource requestWithOwner:nil IntegratedStationsForLine:LineIdentifier atStation:stationDict withBranchData:nil Block:^(NSArray *stationArray, NSArray *lineArray, NSArray *usedBranchData){
        
            XCTAssertFalse([stationArray count] == 0, @"error.");
        
            NSLog(@"station count:%ld, line count:%ld", [stationArray count], [lineArray count]);
            for(int i=0; i<[lineArray count]; i++){
                NSLog(@" | [%d] %@", i, lineArray[i]);
                if([stationArray count] > i){
                    NSDictionary *d = stationArray[i];
                    NSLog(@"[%d] %@(%@)", i, d[@"identifier"], d[@"duplication"]);
                }
            }
            
            NSString *q = [NSString stringWithFormat:@"%@_%@(%@)_%d", LineIdentifier,stationDict[@"identifier"],stationDict[@"duplication"],p];
            NSDictionary *answer = @{@"stations":stationArray,
                                     @"lines":lineArray};
            
            // 正解記録 or 正解確認
            if([rightAnswer judgeAnswer:answer forQuery:q] == NO){
                XCTAssertFalse(YES, @"answer is wrong or not Found. Query:%@ ", q);
            }
            [expectation fulfill];
            
        }];
        break;
    }
    
    // 指定秒数（120秒）待つ
    [self waitForExpectations:@[expectation] timeout:200.0f enforceOrder:NO];
    
    
}

- (void)testRequestDirectConnectionLinesForLine{
    NSString *caseName = @"testRequestDirectConnectionLinesForLine";
    // 正解を管理するContainerを作成
    TestRightAnswerContainer *rightAnswer = [[TestRightAnswerContainer alloc] initWithTestCase:caseName];
    
    
    [self resetStoreURL];
    
    ODPTDataController *dataSource = [[ODPTDataController alloc] initWithAPICacheDirectory:[self cacheDirectory]
                                                                     withUserDataDirectory:[self userDataDirectory]
                                                                           withEndPointURL:endPointURL
                                                                                 withToken:token];
    [dataSource prepare];
    
    // キャッシュクリア
    [dataSource clearCache];
    
    NSArray *LineIdentifiers = @[@"odpt.Railway:Odakyu.Odawara.1.1",
                                 @"odpt.Railway:JR-East.ChuoSobuLocal.1.1",
                                 @"odpt.Railway:JR-East.Tokaido.1.2"];
    
    // 非同期処理の完了を監視するオブジェクトを作成
    XCTestExpectation *expectation = [self expectationWithDescription:caseName];
    expectation.expectedFulfillmentCount = [LineIdentifiers count];

    for(int p=0; p<[LineIdentifiers count]; p++){
        NSString *LineIdentifier = LineIdentifiers[p];
        NSLog(@"Line: %@", LineIdentifier);

        [dataSource requestWithOwner:nil DirectConnectingLinesForLine:LineIdentifier Block:^(NSDictionary *dconDict) {
            NSLog(@"dict:%@", dconDict);
            
            NSString *q = LineIdentifier;
            NSMutableDictionary *answer = [[NSMutableDictionary alloc] init];
            NSArray *keys = [dconDict allKeys];
            for(int i=0; i<[keys count]; i++){
                NSString *l = keys[i];
                if([LineIdentifier isEqualToString:l] == YES){
                    NSArray *cons = dconDict[l];
                    for(int j=0; j<[cons count]; j++){
                        NSDictionary *d = cons[j];
                        NSString *dline = d[@"directConnectingLine"];
                        NSNumber *isBranch = d[@"isBranch"];
                        if(isBranch == nil){
                            isBranch = @0;
                        }
                        
                        [answer setObject:@"1" forKey:[NSString stringWithFormat:@"%@_%@", dline, [isBranch stringValue] ] ];
                        
                    }
                    break;
                }
            }
            // 正解記録 or 正解確認
            if([rightAnswer judgeAnswer:answer forQuery:q] == NO){
                XCTAssertFalse(YES, @"answer is wrong or not Found. Query:%@ ", q);
            }
            [expectation fulfill];
            
        }];
    }
    
    // 指定秒数（120秒）待つ
    [self waitForExpectations:@[expectation] timeout:100.0f enforceOrder:NO];
    
}

- (void)testRequestConnectionLines{
    NSString *caseName = @"testRequestConnectionLines";
    // 正解を管理するContainerを作成
    TestRightAnswerContainer *rightAnswer = [[TestRightAnswerContainer alloc] initWithTestCase:caseName];
    
    
    [self resetStoreURL];
    ODPTDataController *dataSource = [[ODPTDataController alloc] initWithAPICacheDirectory:[self cacheDirectory]
                                                                     withUserDataDirectory:[self userDataDirectory]
                                                                           withEndPointURL:endPointURL
                                                                                 withToken:token];
    [dataSource prepare];
    
    // キャッシュクリア
    [dataSource clearCache];
    
    NSArray *StationIdentifiers = @[@"odpt.Station:JR-East.JobanRapid.KitaSenju",
                                    @"odpt.Station:JR-East.JobanRapid.Ayase",
                                    @"odpt.BusstopPole:Toei.Takanawakitamachi.863.1",
                                    @"odpt.Station:Toei.Oedo.Kachidoki",
                                    @"odpt.Station:JR-East.Yamanote.Ikebukuro",
                                    @"odpt.Station:JR-East.Yamanote.Shinjuku",
                                    @"odpt.BusstopPole:Toei.OjiStation.196.3",
                                    @"odpt.Station:JR-East.Narita.Narita",
                                    @"odpt.Station:Keikyu.Main.Yokohama",
                                    @"odpt.Station:JR-East.Musashino.HigashiMatsudo",
                                    @"odpt.Station:TokyoMetro.Tozai.NishiFunabashi",
                                    @"odpt.Station:JR-East.Keiyo.NishiFunabashi"
                                    ];

    // 非同期処理の完了を監視するオブジェクトを作成
    XCTestExpectation *expectation = [self expectationWithDescription:caseName];
    expectation.expectedFulfillmentCount = [StationIdentifiers count];
    
    for(int p=0; p<[StationIdentifiers count]; p++){
        NSString *StationIdentifier = StationIdentifiers[p];
    
        [dataSource requestWithOwner:nil ConnectingLinesForStation:StationIdentifier ofRailway:YES ofBus:NO withSearchRadius:500 Block:^(NSArray *left, NSArray *right) {
            
            NSMutableDictionary *answer = [[NSMutableDictionary alloc] init];
            for(int i=0; i<[left count]; i++){
                id leftCont = [left objectAtIndex:i];  // leftCont は　NSArray か NSNull
                id rightCont = [right objectAtIndex:i];
                //NSLog(@"class: %@", NSStringFromClass([leftCont class]));
                
                NSLog(@"%@", [self stringForConnectionLinesLeft:leftCont Right:rightCont]);
                
                [answer setObject:leftCont forKey:@"left"];
                [answer setObject:rightCont forKey:@"right"];
                
            }

            NSString *q = StationIdentifier;
            
            // 正解記録 or 正解確認
            if([rightAnswer judgeAnswer:answer forQuery:q] == NO){
                XCTAssertFalse(YES, @"answer is wrong or not Found. Query:%@ ", q);
            }
            [expectation fulfill];
            
        }];
    }
    
    // 指定秒数待つ
    [self waitForExpectations:@[expectation] timeout:120.0f enforceOrder:NO];
    
}

- (void)testRequestTrainTimeTable{
    NSString *caseName = @"testRequestTimeTableTrain";
    // 正解を管理するContainerを作成
    TestRightAnswerContainer *rightAnswer = [[TestRightAnswerContainer alloc] initWithTestCase:caseName];
    
    
    [self resetStoreURL];
    ODPTDataController *dataSource = [[ODPTDataController alloc] initWithAPICacheDirectory:[self cacheDirectory]
                                                                     withUserDataDirectory:[self userDataDirectory]
                                                                           withEndPointURL:endPointURL
                                                                                 withToken:token];
    [dataSource prepare];
    
    // キャッシュクリア
    [dataSource clearCache];
    
    
    // フォーマットを文字列で指定
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm"];
    

    NSArray *LineIdentifiers = @[@"odpt.Railway:JR-East.JobanRapid.1.1",
                                 @"odpt.Railway:TokyoMetro.Chiyoda.1.1"];
    NSArray *StationIdentifiers = @[@"odpt.Station:JR-East.JobanRapid.Shimbashi",
                                    @"odpt.Station:TokyoMetro.Chiyoda.Hibiya"];
    NSArray *checkDateStr = @[@"2019-10-18 09:00", // Friday
                              @"2019-10-18 09:00" // Friday
                              ];

    // 非同期処理の完了を監視するオブジェクトを作成
    XCTestExpectation *expectation = [self expectationWithDescription:caseName];
    expectation.expectedFulfillmentCount = [LineIdentifiers count];

    for(int p=0; p<[LineIdentifiers count]; p++){
        NSString *LineIdentifier = LineIdentifiers[p];
        NSString *StationIdentifier = StationIdentifiers[p];
        
        NSDate *d = [dateFormatter dateFromString:checkDateStr[p]];

        [dataSource requestWithOwner:nil TrainTimetableOfLine:LineIdentifier atStation:StationIdentifier atDepartureTime:d Block:^(NSArray<NSDictionary *> *ary) {
        
            XCTAssertFalse([ary count] == 0, @"error.");
            // NSLog(@"ans: %@", ary);
            
            NSMutableArray *answer = [[NSMutableArray alloc] init];
            for(int i=0; i<[ary count]; i++){
                NSDictionary *dict = ary[i];
                NSArray *records = [dict objectForKey:@"records"];
                for(int j=0; j<[records count]; j++){
                    if([[records[j] objectForKey:@"atStation"] isEqualToString:StationIdentifier]){
                        
                        NSLog(@"%@", [dict objectForKey:@"trainNumber"]);
                        NSLog(@"%@", records[j]);
                        
                        NSDictionary *r = records[j];
                        NSDictionary *d = @{@"trainNumber":[dict objectForKey:@"trainNumber"],
                                            @"timeHour":r[@"timeHour"],
                                            @"timeMinute":r[@"timeMinute"]
                                            };
                        [answer addObject:d];
                        break;
                    }
                }
            }
            
            NSString *q = [NSString stringWithFormat:@"%@_%@_%@_%d",LineIdentifier, StationIdentifier, checkDateStr[p], p ];
            // 正解記録 or 正解確認
            if([rightAnswer judgeAnswer:answer forQuery:q] == NO){
                XCTAssertFalse(YES, @"answer is wrong or not Found. Query:%@ ", q);
            }
            NSLog(@"xy: %d", p);
            [expectation fulfill];
        }];
        
    }
    
    // 指定秒数待つ
    [self waitForExpectations:@[expectation] timeout:10.0f enforceOrder:NO];
}

- (void)testRequestStationTimeTable{
    NSString *caseName = @"testRequestTimeTableStation";
    // 正解を管理するContainerを作成
    TestRightAnswerContainer *rightAnswer = [[TestRightAnswerContainer alloc] initWithTestCase:caseName];
    
    [self resetStoreURL];
    ODPTDataController *dataSource = [[ODPTDataController alloc] initWithAPICacheDirectory:[self cacheDirectory]
                                                                     withUserDataDirectory:[self userDataDirectory]
                                                                           withEndPointURL:endPointURL
                                                                                 withToken:token];
    [dataSource prepare];
    // キャッシュクリア
    [dataSource clearCache];
    
    // フォーマットを文字列で指定
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm"];
    
    NSArray<NSString *> *LineIdentifiers = @[@"odpt.Railway:JR-East.Yamanote.1.1",
                                             @"odpt.Railway:TokyoMetro.Chiyoda.1.2",
                                             @"odpt.Railway:Keikyu.Main.1.2"];
    
    NSArray<NSString *> *StationIdentifiers = @[@"odpt.Station:JR-East.Yamanote.Shimbashi",
                                                @"odpt.Station:TokyoMetro.Chiyoda.Ayase",
                                                @"odpt.Station:Keikyu.Main.Shinagawa"];
    
    NSArray *checkDateStr = @[@"2019-10-18 09:00", // Friday
                              @"2019-10-18 09:00", // Friday
                              @"2019-10-18 09:00" // Friday
                              ];
    
    // 非同期処理の完了を監視するオブジェクトを作成
    XCTestExpectation *expectation = [self expectationWithDescription:caseName];
    expectation.expectedFulfillmentCount = [LineIdentifiers count];
    
    for(int p=0; p<[LineIdentifiers count]; p++){
        NSString *l = LineIdentifiers[p];
        NSString *s = StationIdentifiers[p];
        NSDate *d = [dateFormatter dateFromString:checkDateStr[p]];
        
        [dataSource requestWithOwner:nil StationTimetableOfLineArray:@[l] atStationArray:@[s] atDepartureTime:d Block:^(NSArray<NSDictionary *> *ary) {
        
            XCTAssertFalse([ary count] == 0, @"error.");
            
            NSMutableArray *answer = [[NSMutableArray alloc] init];
            for(int i=0; i<[ary count]; i++){
                NSLog(@"%@", ary[i]);
                
                NSDictionary *r = ary[i];
                NSDictionary *d = @{@"timeHour":r[@"timeHour"],
                                    @"timeMinute":r[@"timeMinute"]
                                    };
                
                [answer addObject:d];
            }

            NSString *q = [NSString stringWithFormat:@"%@_%@_%@_%d", l, s, checkDateStr[p], p];
            
            // 正解記録 or 正解確認
            if([rightAnswer judgeAnswer:answer forQuery:q] == NO){
                XCTAssertFalse(YES, @"answer is wrong or not Found. Query:%@ ", q);
            }
            [expectation fulfill];
        }];
        
    }
    
    // 指定秒数待つ
    [self waitForExpectations:@[expectation] timeout:30.0f enforceOrder:NO];
    
}

- (void)testRequestStationTimeTableAllRecord{
    NSString *caseName = @"testRequestTimeTableStationAllRecord";
    
    // 正解を管理するContainerを作成
    TestRightAnswerContainer *rightAnswer = [[TestRightAnswerContainer alloc] initWithTestCase:caseName];
    
    ODPTDataController *dataSource = [[ODPTDataController alloc] initWithAPICacheDirectory:[self cacheDirectory]
                                                                     withUserDataDirectory:[self userDataDirectory]
                                                                           withEndPointURL:endPointURL
                                                                                 withToken:token];
    [dataSource prepare];
    // キャッシュクリア
    [dataSource clearCache];
    
    // フォーマットを文字列で指定
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm"];
    
    NSString *LineIdentifier = @"odpt.Railway:TokyoMetro.MarunouchiBranch.1.2";
    NSString *StationIdentifier = @"odpt.Station:TokyoMetro.MarunouchiBranch.NakanoSakaue";
    
    NSString *checkDateStr = @"2019-10-18 09:00"; // Friday
    
    
    // 非同期処理の完了を監視するオブジェクトを作成
    XCTestExpectation *expectation = [self expectationWithDescription:caseName];
    expectation.expectedFulfillmentCount = 1;
    
    NSDate *d = [dateFormatter dateFromString:checkDateStr];
    [dataSource requestWithOwner:nil StationTimetableAllRecordsOfLineArray:@[LineIdentifier] atStationArray:@[StationIdentifier] atDepartureTime:d Block:^(NSArray<NSDictionary *> *ary, NSDictionary *status) {
        
        XCTAssertFalse([ary count] == 0, @"error.");
        
        NSMutableArray *answer = [[NSMutableArray alloc] init];
        for(int i=0; i<[ary count]; i++){
            NSDictionary *dict = ary[i];
            NSLog(@"%d %@:%@", i, [dict objectForKey:@"timeHour"] ,[dict objectForKey:@"timeMinute"]);

            NSString *ts = [NSString stringWithFormat:@"%02d:%02d",
                            [[dict objectForKey:@"timeHour"] intValue],
                            [[dict objectForKey:@"timeMinute"] intValue]];
            [answer addObject:ts];
        }
        
        NSString *q = [NSString stringWithFormat:@"%@_%@_%@_%d", LineIdentifier, StationIdentifier, checkDateStr, 0];
        // 正解記録 or 正解確認
        if([rightAnswer judgeAnswer:answer forQuery:q] == NO){
            XCTAssertFalse(YES, @"answer is wrong or not Found. Query:%@ ", q);
        }
        [expectation fulfill];
    }];
    
    // 指定秒数待つ
    [self waitForExpectations:@[expectation] timeout:30.0f enforceOrder:NO];
    
}

- (void)testRequestApplicableCalendar{
    NSString *caseName = @"testRequestApplicableCalendar";
    // 正解を管理するContainerを作成
    TestRightAnswerContainer *rightAnswer = [[TestRightAnswerContainer alloc] initWithTestCase:caseName];
    
    [self resetStoreURL];
    ODPTDataController *dataSource = [[ODPTDataController alloc] initWithAPICacheDirectory:[self cacheDirectory]
                                                                     withUserDataDirectory:[self userDataDirectory]
                                                                           withEndPointURL:endPointURL
                                                                                 withToken:token];
    [dataSource prepare];
    // キャッシュクリア
    [dataSource clearCache];
    
    NSArray *calendars = @[@[@"odpt.Calendar:SaturdayHoliday", @"odpt.Calendar:Weekday"],
                           @[@"odpt.Calendar:Weekday", @"odpt.Calendar:Specific.OdakyuBus.Setagaya.Holiday82" ],
                           @[@"odpt.Calendar:Specific.OdakyuBus.Kichijouji.Weekday01", @"odpt.Calendar:Specific.OdakyuBus.Kichijouji.Saturday21", @"odpt.Calendar:Specific.OdakyuBus.Kichijouji.Holiday41" ]
                           ];
    
    NSArray *dateStrs = @[@"2018-11-1 15:00", // 木曜日.
                          @"2018-12-28 15:00", // 金曜日.
                          @"2019-09-07 15:00"
                          ];
    
    // フォーマットを文字列で指定
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm"];
    
    // 非同期処理の完了を監視するオブジェクトを作成
    XCTestExpectation *expectation = [self expectationWithDescription:caseName];
    expectation.expectedFulfillmentCount = [calendars count];
    
    for(int p=0; p<[calendars count]; p++){
        NSArray *cals = calendars[p];
        NSString *dateString = dateStrs[p];
        
        // 文字列からNSDateオブジェクトを生成
        NSDate *aDate = [dateFormatter dateFromString:dateString];
        [dataSource requestWithOwner:nil ApplicableCalendarForDate:aDate fromCalendars:cals Block:^(NSString *aCalendar) {
            
            XCTAssertFalse(aCalendar == nil, @"error.");
            
            NSMutableString *calStr = [[NSMutableString alloc] init];
            for(int i=0; i<[cals count]; i++){
                NSLog(@" c: %@", cals[i]);
                [calStr appendString:cals[i]];
                if(i < [cals count]-1){
                    [calStr appendString:@"_"];
                }
            }
            NSLog(@"  -> %@", aCalendar);
            
            NSString *q = [NSString stringWithFormat:@"%@_%@_%d", calStr, dateString, 0];
            NSString *answer = aCalendar;
            
            // 正解記録 or 正解確認
            if([rightAnswer judgeAnswer:answer forQuery:q] == NO){
                XCTAssertFalse(YES, @"answer is wrong or not Found. Query:%@ ", q);
            }
            [expectation fulfill];
        }];
    }
    
    // 指定秒数待つ
    [self waitForExpectations:@[expectation] timeout:30.0f enforceOrder:NO];
    
}


- (void)testLinesNearPoints{
    NSString *caseName = @"testLinesNearPoint";
    // 正解を管理するContainerを作成
    TestRightAnswerContainer *rightAnswer = [[TestRightAnswerContainer alloc] initWithTestCase:caseName];
    
    
    [self resetStoreURL];
    
    ODPTDataController *dataSource = [[ODPTDataController alloc] initWithAPICacheDirectory:[self cacheDirectory]
                                                                     withUserDataDirectory:[self userDataDirectory]
                                                                           withEndPointURL:endPointURL
                                                                                 withToken:token];
    [dataSource prepare];
    
    // キャッシュクリア
    [dataSource clearCache];
    
    NSArray *positions = @[@35.673094, @139.742789,  // 溜池山王;
                           @35.46602380, @139.62267730,  // 横浜
                           @35.6897419, @139.6981972,  // 新宿
                           @35.690575, @139.693436 // 都庁前
                           ];
    int count = [positions count] / 2.0f;
    
    // 非同期処理の完了を監視するオブジェクトを作成
    XCTestExpectation *expectation = [self expectationWithDescription:caseName];
    expectation.expectedFulfillmentCount = count;
    
    for(int p=0; p<count; p++){
        NSNumber *lat = positions[p*2];
        NSNumber *lon = positions[p*2+1];
        
        CLLocationCoordinate2D testPosition = CLLocationCoordinate2DMake([lat floatValue], [lon floatValue]);
        [dataSource requestWithOwner:self NearLinesAtPoint:testPosition ofRailway:YES ofBus:YES withSearchRadius:500  Block:^(NSArray *lines, NSArray *stations) {
            for(int i=0; i<[lines count]; i++){
                NSLog(@"nearLine:%@ at %@", lines[i], stations[i]);
            }
            
            NSString *q = [NSString stringWithFormat:@"%@_%@_%d", lat, lon, p];
            NSDictionary *answer = @{@"lines":lines, @"sations":stations};
            
            // 正解記録 or 正解確認
            if([rightAnswer judgeAnswer:answer forQuery:q] == NO){
                XCTAssertFalse(YES, @"answer is wrong or not Found. Query:%@ ", q);
            }
            [expectation fulfill];
        }];
    }
    
    // 指定秒数待つ
    [self waitForExpectations:@[expectation] timeout:60.0f enforceOrder:NO];
    
    
}

- (void)testLineInformation{
    // 非同期処理の完了を監視するオブジェクトを作成
    XCTestExpectation *expectation = [self expectationWithDescription:@"testLineInformation"];
    
    [self resetStoreURL];
    
    ODPTDataController *dataSource = [[ODPTDataController alloc] initWithAPICacheDirectory:[self cacheDirectory]
                                                                     withUserDataDirectory:[self userDataDirectory]
                                                                           withEndPointURL:endPointURL
                                                                                 withToken:token];
    [dataSource prepare];
    
    // キャッシュクリア
    [dataSource clearCache];
    
    //NSString *LineIdentifier = @"odpt.Railway:TokyoMetro.Tozai.1.1";
    NSString *LineIdentifier = @"odpt.Railway:JR-East.Tokaido.1.1";
    
    [dataSource requestWithOwner:self LineInformationForLineIdentifier:LineIdentifier Block:^(NSDictionary *dict, NSDate *d){
        
        NSLog(@"dict: %@", dict);
        NSLog(@"date: %@", d);
        
        [expectation fulfill];
    }];
    
    // 指定秒数（120秒）待つ
    [self waitForExpectationsWithTimeout:120 handler:^(NSError * _Nullable error) {
        XCTAssertNil(error, @"has error.");
    }];
    
}


- (void)testSweepOldObject{
    // 非同期処理の完了を監視するオブジェクトを作成
    XCTestExpectation *expectation = [self expectationWithDescription:@"testSweepOldObject"];
    
    // [self resetStoreURL];
    ODPTDataController *dataSource = [[ODPTDataController alloc] initWithAPICacheDirectory:[self cacheDirectory]
                                                                     withUserDataDirectory:[self userDataDirectory]
                                                                           withEndPointURL:endPointURL
                                                                                 withToken:token];
    [dataSource prepare];
    
    // キャッシュクリア
    [dataSource clearCache];
    
    // ダミーのデータ取得
    CLLocationCoordinate2D testLocation = CLLocationCoordinate2DMake(35.698697, 139.772343); // 秋葉原
    
    [dataSource requestWithOwner:self NearLinesAtPoint:testLocation ofRailway:YES ofBus:YES withSearchRadius:500 Block:^(NSArray *lineIdents, NSArray *stationDicts) {
        
        NSString *nextLine = [lineIdents firstObject];
        NSDictionary *stationDict = [stationDicts firstObject];
        // NSString *station = stationDict[@"identifier"];
        
        [dataSource requestWithOwner:self IntegratedStationsForLine:nextLine atStation:stationDict withBranchData:nil Block:^(NSArray *iLines, NSArray *iStations, NSArray *branches) {
            
            NSLog(@"");
            NSLog(@"Before delete.");
            [dataSource printAPICacheLinesAndStations];
            [dataSource printAPICachePoint];
            
            // lineを削除
            CoreDataManager *manager = [dataSource dataManager];
            
            NSManagedObjectContext *moc = [manager managedObjectContextForConcurrent];
            [moc performBlockAndWait:^{
                NSArray *results = nil;
                NSError *error = nil;
                
                // 残っている Lineオブジェクトを表示
                NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Line"];
                [request setPredicate:[NSPredicate predicateWithFormat:@"identifier == %@", nextLine]];
                results = [moc executeFetchRequest:request error:&error];
                if (results == nil) {
                    NSLog(@"Error fetching objects: %@\n%@", [error localizedDescription], [error userInfo]);
                    abort();
                }
                
                NSManagedObject *obj = [results firstObject];
                
                [moc deleteObject:obj];
                
            }];
            
            NSLog(@"");
            NSLog(@"After delete.");
            [dataSource printAPICacheLinesAndStations];
            [dataSource printAPICachePoint];
            
            [expectation fulfill];
        }];
        
        
    }];
    
    
    // 指定秒数（120秒）待つ
    [self waitForExpectationsWithTimeout:120 handler:^(NSError * _Nullable error) {
        XCTAssertNil(error, @"has error.");
    }];
    
}

- (void)testWriteTransfer{
    
    // 非同期処理の完了を監視するオブジェクトを作成
    // XCTestExpectation *expectation = [self expectationWithDescription:@"testBackupTransfer"];
    
    // [self resetStoreURL];
    ODPTDataController *dataSource = [[ODPTDataController alloc] initWithAPICacheDirectory:[self cacheDirectory]
                                                                     withUserDataDirectory:[self userDataDirectory]
                                                                           withEndPointURL:endPointURL
                                                                                 withToken:token];
    [dataSource prepare];
    
    [dataSource clearUserData];
    
    NSArray *departures = @[@"odpt.Station:TokyoMetro.Fukutoshin.ShinjukuSanchome",
                            @"odpt.Station:JR-East.SaikyoKawagoe.Kawagoe",
                            @"odpt.Station:JR-East.Keiyo.ShinKiba",
                            @"odpt.Station:JR-East.ChuoRapid.NishiKokubunji",
                            @"odpt.Station:JR-East.Keiyo.Tokyo"];
    
    NSArray *destinations = @[@"odpt.Station:Tobu.Tojo.Kawagoe",
                              @"odpt.Station:TWR.Rinkai.ShinKiba",
                              @"odpt.Station:JR-East.Musashino.NishiKokubunji",
                              @"odpt.Station:JR-East.ChuoRapid.Tokyo",
                              @"odpt.Station:JR-East.Sotobo.Oami"];
    
    NSArray *lines = @[@"odpt.Railway:TokyoMetro.Fukutoshin.1.2",
                       @"odpt.Railway:JR-East.SaikyoKawagoe.1.2",
                       @"odpt.Railway:JR-East.Keiyo.1.2",
                       @"odpt.Railway:JR-East.ChuoRapid.1.2",
                       @"odpt.Railway:JR-East.Keiyo.1.1"];
    
    NSArray *reverseLines = @[@"odpt.Railway:TokyoMetro.Fukutoshin.1.1",
                              @"odpt.Railway:JR-East.SaikyoKawagoe.1.1",
                              @"odpt.Railway:JR-East.Keiyo.1.1",
                              @"odpt.Railway:JR-East.ChuoRapid.1.1",
                              @"odpt.Railway:JR-East.Keiyo.1.2"];
    
    
    NSArray *departureDeps = @[@0, @0, @0, @0, @0];
    NSArray *destinationDeps = @[@0, @0, @0, @0, @0];
    NSArray *isLineReverse = @[@0, @0, @1, @0, @0];
    
    NSArray *types = @[@2, @2, @2, @2, @1];
    
    NSDictionary *b1 = @{@"atStation":@"odpt.Station:JR-East.Keiyo.Ichikawashiohama", @"ofLine":@"odpt.Railway:JR-East.Keiyo.1.1", @"selectedLine":@"odpt.Railway:JR-East.Keiyo.2.1", @"systemDefault":[NSNumber numberWithBool:NO]};
    
    NSArray *branches = @[[NSNull null], [NSNull null], @[b1], [NSNull null], [NSNull null]];
    
    NSMutableArray *transferArray = [[NSMutableArray alloc] init];
    for(int i=0; i<[departures count]; i++){
        NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
        
        [dict setObject:departures[i] forKey:@"departureStation"];
        [dict setObject:destinations[i] forKey:@"destinationStation"];
        [dict setObject:lines[i] forKey:@"line"];
        [dict setObject:reverseLines[i] forKey:@"reverseLine"];
        
        [dict setObject:departureDeps[i] forKey:@"departureStationDuplication"];
        [dict setObject:destinationDeps[i] forKey:@"destinationStationDuplication"];
        
        [dict setObject:isLineReverse[i] forKey:@"isLineReverse"];
        [dict setObject:types[i] forKey:@"type"];
        
        if([branches[i] isKindOfClass:[NSNull class]] == NO){
            [dict setObject:branches[i] forKey:@"branchData"];
        }
        
        [transferArray addObject:[dict copy]];
    }
    
    [dataSource writeTransferArray:transferArray forTitle:@"" asCurrent:YES];
    
    NSArray *readTransferArray = [dataSource readCurrentTransferArray];
    
    
    // NSLog(@"readTransferArray:%@", readTransferArray);
    for (int i=0; i<[readTransferArray count]; i++){
        NSDictionary *d = transferArray[i];
        NSDictionary *dr = readTransferArray[i];
        
        if([d isEqualToDictionary:dr] == NO){
            NSLog(@"originalTransfer:%@", d);
            NSLog(@"readTransfer:%@", dr);
            XCTAssertFalse(YES, @"error");
        }
    }
    
    // 指定秒数（120秒）待つ
    /*
     [self waitForExpectationsWithTimeout:120 handler:^(NSError * _Nullable error) {
     XCTAssertNil(error, @"has error.");
     }];
     */
}

- (void)testHoliday{
    
    NSArray *strings = @[@"2019-02-11 15:00", // 月曜日だが 祝日
                         @"2019-04-29 15:00", // 月曜日だが 祝日
                         @"2019-05-05 15:00", // 日曜日であり 祝日
                         ];
    
    for(int i=0; i<[strings count]; i++){
        NSString *dateString = strings[i];
        
        // フォーマットを文字列で指定
        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm"];
        
        // 文字列からNSDateオブジェクトを生成
        NSDate *testDate = [dateFormatter dateFromString:dateString];
        
        if([[ODPTDataAdditional sharedData] isHolidayForDate:testDate] == YES){
            
        }else{
            XCTAssertFalse(YES, @"error");
        }
    }
    
    
}


- (void)testOriginPoints{
    // 非同期処理の完了を監視するオブジェクトを作成
    // XCTestExpectation *expectation = [self expectationWithDescription:@"testOriginPoint"];
    
    [self resetStoreURL];
    ODPTDataController *dataSource = [[ODPTDataController alloc] initWithAPICacheDirectory:[self cacheDirectory]
                                                                     withUserDataDirectory:[self userDataDirectory]
                                                                           withEndPointURL:endPointURL
                                                                                 withToken:token];
    [dataSource prepare];
    
    // キャッシュクリア
    [dataSource clearCache];
    
    CLLocationCoordinate2D testPosition = CLLocationCoordinate2DMake(35.673094, 139.742789);  // 溜池山王
    CLLocation *testLocation = [[CLLocation alloc] initWithCoordinate:testPosition altitude:0.0f horizontalAccuracy:0.0f verticalAccuracy:0.0f timestamp:[NSDate date]];
    NSLog(@"addNewPlaceAsOrigin: %@", testLocation);
    
    //[dataSource addNewPlaceAsOriginWithPosition:testLocation];
    [dataSource addNewPlaceWithTitle:@"" withAddressString:@"" withPosition:testLocation];
    
    CLLocation *testLocation2 = [dataSource originPlacePosition];
    NSLog(@"originPlace: %@", testLocation2);
    
    [dataSource printUserDataPlace];
    
    
    // 指定秒数（120秒）待つ
    /*
     [self waitForExpectationsWithTimeout:120 handler:^(NSError * _Nullable error) {
     XCTAssertNil(error, @"has error.");
     }];
     */
    
}

- (void)testRequestBranchLines{
    // 非同期処理の完了を監視するオブジェクトを作成
    XCTestExpectation *expectation = [self expectationWithDescription:@"testBranchLines"];
    
    [self resetStoreURL];
    // MapViewHandlerクラス内 stationIndexForPickingIndex: と pickingIndexForStationIndex: の確認
    
    ODPTDataController *dataSource = [[ODPTDataController alloc] initWithAPICacheDirectory:[self cacheDirectory]
                                                                     withUserDataDirectory:[self userDataDirectory]
                                                                           withEndPointURL:endPointURL
                                                                                 withToken:token];
    [dataSource prepare];
    
    // キャッシュクリア
    [dataSource clearCache];
    
    NSString *branchStationIdentifier = @"odpt.Station:JR-East.Keiyo.Soga";
    NSString *lineIdentifier = @"odpt.Railway:JR-East.Keiyo.1.1";
    
    [dataSource requestWithOwner:self BranchLinesForStation:branchStationIdentifier forLine:lineIdentifier withBranchData:nil
                           Block:^(NSArray *branchLines, NSInteger selectedIndex) {
                               for(int i=0; i<[branchLines count]; i++){
                                   NSString *checked = @" ";
                                   if(selectedIndex == i){
                                       checked = @"o";
                                   }
                                   NSLog(@"branchLines: %@ %@  ", checked, branchLines[i]);
                               }
                               [expectation fulfill];
                           }];
    // 指定秒数（10秒）待つ
    [self waitForExpectationsWithTimeout:30 handler:^(NSError * _Nullable error) {
        
        XCTAssertNil(error, @"has error.");
    }];
}

@end

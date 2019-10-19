//
//  ODPTDataTests+Loader.m
//
//  Copyright (c) 2019 Takehito Ikema
//
//  This software is released under the MIT License.
//  https://opensource.org/licenses/mit-license.php
//

#import <XCTest/XCTest.h>
#import "ODPTDataTests+Loader.h"

#import "CoreDataManager.h"
#import "ODPTDataProvider.h"
#import "ODPTDataLoaderLine.h"
#import "ODPTDataLoaderStation.h"
#import "ODPTDataLoaderArray.h"
#import "ODPTDataLoaderPoint.h"
#import "ODPTDataLoaderCalendar.h"
#import "ODPTDataLoaderConnectingLines.h"
#import "ODPTDataLoaderOperator.h"
#import "ODPTDataLoaderTimetableLine.h"
#import "ODPTDataLoaderTimetableVehicle.h"
#import "ODPTDataLoaderTimetableStation.h"
#import "EfficientLoader.h"
#import "TestRightAnswerContainer.h"


@implementation ODPTDataTests (Loader)

// ODPTDataLoaderLine のテスト
- (void)testODPTDataLoaderLine{
    NSString *caseName =@"testODPTDataLoaderLine";
    
    // 正解を管理するContainerを作成
    TestRightAnswerContainer *rightAnswer = [[TestRightAnswerContainer alloc] initWithTestCase:caseName];
    
    [self prepareForAPIAccessWithReset:YES];
    
    NSArray *lineIdents = @[@"odpt.Railway:TokyoMetro.Tozai.1.2",
                            @"odpt.Railway:JR-East.JobanRapid.1.1",
                            @"odpt.Railway:Seibu.Ikebukuro.1.1",
                            @"odpt.BusroutePattern:Toei.Tan96.1712.1",
                            @"odpt.Railway:Hokuso.Hokuso.1.2",  // inaccessible Lineとして登録。
                            @"odpt.Railway:SaitamaRailway.SaitamaRailway.1.1"  // inaccessible Lineとして登録。
                            ];
    
    // 非同期処理の完了を監視するオブジェクトを作成
    XCTestExpectation *expectation = [self expectationWithDescription:caseName];
    expectation.expectedFulfillmentCount = [lineIdents count];
    
    for(int p=0; p<[lineIdents count]; p++){
        NSString *lineIdent = lineIdents[p];
        
        __block BOOL endFlag = NO;
        __block ODPTDataLoaderLine *l = [[ODPTDataLoaderLine alloc] initWithLine:lineIdent Block:^(NSManagedObjectID *moID) {
        
            NSManagedObjectContext *moc = [self->dataManager managedObjectContextForConcurrent];
            
            __block NSMutableDictionary *answer = [[NSMutableDictionary alloc] init];
            [moc performBlockAndWait:^{
                
                NSManagedObject *mo = [moc objectWithID:moID];
                
                [answer setObject:[mo valueForKey:@"identifier"] forKey:@"identifier"];
                NSLog(@"line:%@", [mo valueForKey:@"identifier"]);
                
                NSLog(@" title:%@", [l lineTitleForLineObject:mo]);
                
                NSArray *stations = [l stationArrayForLineObject:mo];
                NSMutableArray *answer_stations = [[NSMutableArray alloc] init];
                for(int i=0; i<[stations count]; i++){
                    NSManagedObject *s = stations[i];  // Entity:Station
                    NSString *ident = [s valueForKey:@"identifier"];
                    NSString *title_ja = [s valueForKey:@"title_ja"];
                    NSLog(@"  %@(%@)", ident, title_ja);
                    
                    NSSet *set = [s valueForKey:@"lines"];
                    NSArray *lines = [set allObjects];
                    for(int j=0; j<[lines count]; j++){
                        NSLog(@"    l: %@", [lines[j] valueForKey:@"identifier"]);
                    }
                    
                    [answer_stations addObject:ident];
                }
                [answer setObject:answer_stations forKey:@"stations"];
                
                NSArray *cons = [l directConnectingLinesForLineObject:mo];
                NSMutableArray *answer_cons = [[NSMutableArray alloc] init];
                
                for(int j=0; j<[cons count]; j++){
                    NSDictionary *dict = cons[j];
                    
                    NSString *dconLine = [[dict objectForKey:@"directConnectingToLine"] valueForKey:@"identifier"];
                    XCTAssertFalse(dconLine == nil, @"directConnectingLine error.");

                    NSString *dconStation = [dict objectForKey:@"station"];
                    XCTAssertFalse(dconStation == nil, @"directConnectingStation error.");

                    NSLog(@" ->(direct)  %@ at %@", dconLine, dconStation);
                    
                    NSDictionary *answer_d = @{@"directConnectingLine":dconLine, @"directConnectingStation":dconStation};
                    [answer_cons addObject:answer_d];
                }
                [answer setObject:answer_cons forKey:@"directConnectingLines"];
                
                NSString *reverseLine = [[mo valueForKey:@"reverseDirectionLine"] valueForKey:@"identifier"];
                NSLog(@"(reverse) %@", reverseLine);
                if(reverseLine != nil){
                    [answer setObject:reverseLine forKey:@"reverseDirectionLine"];
                }
                
                NSArray *directions = [l directionIdentifierForLineObject:mo];
                NSLog(@"directions:%@", directions);
                [answer setObject:directions forKey:@"directions"];
                
                // [(ODPTDataProvider *)self->dataProvider printQueue];
                
            }];
            
            // 正解記録 or 正解確認
            if([rightAnswer judgeAnswer:answer forQuery:lineIdent] == NO){
                XCTAssertFalse(YES, @"answer is wrong or not Found. Query:%@ ", lineIdent);
            }
            
            endFlag = YES;
        }];
        
        l.dataProvider = dataProvider;
        l.dataManager = dataManager;
        
        [eQueue addLoader:l];
        
        // 終わるまで待つ。
        while(endFlag == NO){
            [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0f]];
            
        }
        
        [expectation fulfill];
        
    }
    
    // 完了を待つ
    [self waitForExpectationsWithTimeout:60 handler:^(NSError * _Nullable error) {
        [(ODPTDataProvider *)self->dataProvider printQueue];
        XCTAssertNil(error, @"timeout.");
    }];
}


// ODPTDataLoaderLine の連続実行（完了を待たずに連続してリクエスト発行）　テスト
- (void)testODPTDataLoaderLineBurst{
    
    NSString *caseName = @"testODPTDataLoaderLineBurst";
    // 正解を管理するContainerを作成
    TestRightAnswerContainer *rightAnswer = [[TestRightAnswerContainer alloc] initWithTestCase:caseName];
    
    [self prepareForAPIAccessWithReset:YES];
    
    NSArray *lineIdents = @[@"odpt.Railway:TokyoMetro.Tozai.1.2",
                            @"odpt.Railway:JR-East.KeihinTohokuNegishi.1.2",
                            @"odpt.Railway:JR-East.JobanRapid.1.1",
                            @"odpt.Railway:Seibu.Ikebukuro.1.1",
                            @"odpt.BusroutePattern:Toei.Tan96.1712.1",
                            @"odpt.Railway:Hokuso.Hokuso.1.2",  // inaccessible Lineとして登録。
                            @"odpt.Railway:SaitamaRailway.SaitamaRailway.1.1", // inaccessible Lineとして登録。
                            @"odpt.Railway:TokyoMetro.Tozai.1.2",  // 以前アクセスしたのと同じもの。同じ結果が返るはず。
                            @"odpt.Railway:Seibu.Ikebukuro.1.1",
                            @"odpt.Railway:Seibu.Ikebukuro.1.1"
                            ];

    // 非同期処理の完了を監視するオブジェクトを作成
    XCTestExpectation *expectation = [self expectationWithDescription:caseName];
    expectation.expectedFulfillmentCount = [lineIdents count];
    
    for(int p=0; p<[lineIdents count]; p++){
        NSString *lineIdent = lineIdents[p];
        __block ODPTDataLoaderLine *l = [[ODPTDataLoaderLine alloc] initWithLine:lineIdent Block:^(NSManagedObjectID *moID) {
        
            NSManagedObjectContext *moc = [self->dataManager managedObjectContextForConcurrent];
            
            [moc performBlockAndWait:^{
                NSManagedObject *mo = [moc objectWithID:moID];
                
                NSArray *stations = [l stationArrayForLineObject:mo];
                NSMutableArray *answer = [[NSMutableArray alloc] init];
                for(int i=0; i<[stations count]; i++){
                    NSManagedObject *obj = stations[i];
                    [answer addObject:[obj valueForKey:@"identifier"]];
                }

                NSString *q = [NSString stringWithFormat:@"%@_%d", lineIdent, p];  // 2回目の lineIdentを区別するため。

                // 正解記録 or 正解確認
                if([rightAnswer judgeAnswer:answer forQuery:q] == NO){
                    XCTAssertFalse(YES, @"answer is wrong or not Found. Query:%@ ", q);
                }
                [expectation fulfill];
                
            }];
            
        }];
        
        l.dataProvider = dataProvider;
        l.dataManager = dataManager;
        
        [eQueue addLoader:l];
    }
    
    // 指定秒数待つ
    [self waitForExpectations:@[expectation] timeout:60.0f enforceOrder:NO];

}

// ODPTDataLoaderArray のテスト。
- (void)testODPTDataLoaderLineArray{
    
    NSString *caseName = @"testODPTDataLoaderLineArray";
    
    // 正解を管理するContainerを作成
    TestRightAnswerContainer *rightAnswer = [[TestRightAnswerContainer alloc] initWithTestCase:caseName];
    
    [self prepareForAPIAccessWithReset:YES];
    
    /*
     NSArray *lineArray = @[@"odpt.Railway:TokyoMetro.Ginza.1.1", @"odpt.Railway:TokyoMetro.Ginza.1.2", @"odpt.Railway:Tokyu.Toyoko.1.2",
     @"odpt.Railway:TokyoMetro.Tozai.1.1", @"odpt.Railway:TokyoMetro.Namboku.1.1", @"odpt.Railway:SaitamaRailway.SaitamaRailway.1.1"];
     */
    NSArray *lineArray = @[@"odpt.Railway:TokyoMetro.Tozai.1.1",@"odpt.Railway:TokyoMetro.Hibiya.1.1"];
    
    // 非同期処理の完了を監視するオブジェクトを作成
    XCTestExpectation *expectation = [self expectationWithDescription:caseName];
    expectation.expectedFulfillmentCount = 1;
    
    
    NSMutableArray *loaders = [[NSMutableArray alloc] init];
    for(int i=0; i<[lineArray count]; i++){
        NSString *lineIdent = [lineArray objectAtIndex:i];
        ODPTDataLoaderLine *l = [[ODPTDataLoaderLine alloc] initWithLine:lineIdent Block:nil];
        
        l.dataProvider = dataProvider;
        l.dataManager = dataManager;
        [loaders addObject:l];
    }
    
    __block ODPTDataLoaderArray *job = [[ODPTDataLoaderArray alloc] initWithLoaders:loaders Block:^(NSArray<NSManagedObjectID *> *ary) {
        
        NSManagedObjectContext *moc = [self->dataManager managedObjectContextForConcurrent];
        
        __block NSMutableArray *answer_array = [[NSMutableArray alloc] init];
        [moc performBlockAndWait:^{
            for(int i=0; i<[ary count]; i++){
                NSMutableDictionary *answer = [[NSMutableDictionary alloc] init];
                
                NSManagedObjectID *moID = [ary objectAtIndex:i];
                NSManagedObject *mo = [moc objectWithID:moID];
                
                [answer setObject:[mo valueForKey:@"identifier"] forKey:@"identifier"];
                NSLog(@"line:%@", [mo valueForKey:@"identifier"]);
                
                NSLog(@" title:%@", [mo valueForKey:@"title_ja"]);
                
                NSArray *stations = [job stationArrayForLineObject:mo];
                NSMutableArray *answer_stations = [[NSMutableArray alloc] init];
                for(int i=0; i<[stations count]; i++){
                    NSManagedObject *s = stations[i];  // Entity:Station
                    NSString *ident = [s valueForKey:@"identifier"];
                    NSLog(@"  %@", ident);
                    
                    NSSet *set = [s valueForKey:@"lines"];
                    NSArray *lines = [set allObjects];
                    for(int j=0; j<[lines count]; j++){
                        NSLog(@"    l: %@", [lines[j] valueForKey:@"identifier"]);
                    }
                    [answer_stations addObject:ident];
                }
                [answer setObject:answer_stations forKey:@"stations"];
                
                NSArray *cons = [job directConnectingLinesForLineObject:mo];
                NSMutableArray *answer_cons = [[NSMutableArray alloc] init];
                
                for(int j=0; j<[cons count]; j++){
                    NSDictionary *dict = cons[j];
                    
                    NSString *dconLine = [[dict objectForKey:@"directConnectingToLine"] valueForKey:@"identifier"];
                    XCTAssertFalse(dconLine == nil, @"directConnectingLine error.");
                    
                    NSString *dconStation = [dict objectForKey:@"station"];
                    XCTAssertFalse(dconStation == nil, @"directConnectingStation error.");
                    
                    NSLog(@" ->(direct)  %@ at %@", dconLine, dconStation);
                    
                    NSDictionary *answer_d = @{@"directConnectingLine":dconLine, @"directConnectingStation":dconStation};
                    [answer_cons addObject:answer_d];
                }
                [answer setObject:answer_cons forKey:@"directConnectingLines"];
                
                NSString *reverseLine = [[mo valueForKey:@"reverseDirectionLine"] valueForKey:@"identifier"];
                NSLog(@"(reverse) %@", reverseLine);
                if(reverseLine != nil){
                    [answer setObject:reverseLine forKey:@"reverseDirectionLine"];
                }
                
                NSArray *directions = [job directionIdentifierForLineObject:mo];
                NSLog(@"directions:%@", directions);
                [answer setObject:directions forKey:@"directions"];
                
                [answer_array addObject:answer];
            }
            
            NSMutableString *q = [[NSMutableString alloc] init];
            for(int i=0; i<[ary count]; i++){
                NSManagedObjectID *moID = [ary objectAtIndex:i];
                NSManagedObject *mo = [moc objectWithID:moID];
                

                [q appendString:[mo valueForKey:@"identifier"]];
                if(i < [ary count] - 1){
                    [q appendString:@"_"];
                }
            }
        
            // 正解記録 or 正解確認
            if([rightAnswer judgeAnswer:answer_array forQuery:q] == NO){
                XCTAssertFalse(YES, @"answer is wrong or not Found. Query:%@ ", q);
            }
            
            [expectation fulfill];
        }];
    }];
    
    job.dataProvider = dataProvider;
    job.dataManager = dataManager;
    
    
    [eQueue addLoader:job];
    
    
    // 指定秒数待つ
    [self waitForExpectations:@[expectation] timeout:30.0f enforceOrder:NO];
}


- (void)testODPTDataLoaderPoint{
    NSString *caseName = @"testODPTDataLoaderPoint";
    // 正解を管理するContainerを作成
    TestRightAnswerContainer *rightAnswer = [[TestRightAnswerContainer alloc] initWithTestCase:caseName];
    
    [self prepareForAPIAccessWithReset:YES];
    
    NSDictionary *opt = @{ODPTDataLoaderPointOptionsSearchRadius:[NSNumber numberWithInt:500],
                          ODPTDataLoaderPointOptionsNeedToLoadRailway:[NSNumber numberWithBool:YES],
                          ODPTDataLoaderPointOptionsNeedToLoadBusRoutePattern:[NSNumber numberWithBool:YES]
                          };
    
    CLLocationCoordinate2D loc = CLLocationCoordinate2DMake(35.6811586,139.7648629); // 東京駅付近
    
    // 非同期処理の完了を監視するオブジェクトを作成
    XCTestExpectation *expectation = [self expectationWithDescription:caseName];
    expectation.expectedFulfillmentCount = 1;
    
    __block ODPTDataLoaderPoint *l = [[ODPTDataLoaderPoint alloc] initWithLocation:loc withOptions:opt Block:^(NSManagedObjectID *moID) {
                                                                                 
        NSManagedObjectContext *moc = [self->dataManager managedObjectContextForConcurrent];
        
        [moc performBlockAndWait:^{
            NSManagedObject *pointObj = [moc objectWithID:moID];
            
            NSMutableSet *nearStations = [pointObj valueForKey:@"nearStations"];
            NSArray *nearStationsArray = [nearStations allObjects];
            
            NSMutableDictionary *answer = [[NSMutableDictionary alloc] init];
            NSLog(@"location: (%f,%f)", loc.latitude, loc.longitude);
            for(int i=0; i<[nearStationsArray count]; i++){
                NSManagedObject *stationObj = nearStationsArray[i];
                NSString *stationIdent = [stationObj valueForKey:@"identifier"];
                NSLog(@"nearStation:%@", stationIdent);
                
                [answer setObject:@"1" forKey:stationIdent];  // 順序なしのSet とするため、dictionary で保存
            }
            
            NSString *q = [NSString stringWithFormat:@"%f_%f", loc.latitude, loc.longitude];
            
            // 正解記録 or 正解確認
            if([rightAnswer judgeAnswer:answer forQuery:q] == NO){
                XCTAssertFalse(YES, @"answer is wrong or not Found. Query:%@ ", q);
            }

            [expectation fulfill];
        }];
        
    }];
    
    l.dataProvider = dataProvider;
    l.dataManager = dataManager;
    
    [eQueue addLoader:l];
    
    // 指定秒数待つ
    [self waitForExpectations:@[expectation] timeout:20.0f enforceOrder:NO];
    
}

- (void)testODPTDataLoaderFunc{
    
    ODPTDataLoader *loader = [[ODPTDataLoader alloc] init];
    
    //NSString *lineIdent = @"odpt.Railway:JR-East.JobanRapid.1.1";
    NSString *lineIdent = @"odpt.BusroutePattern:TokyuBus.Hin94.0004600115";
    NSInteger dirNum = [loader directionNumberForLineIdentifier:lineIdent];
    
    NSLog(@"dirNum: %d", (int)dirNum);
    
}

- (void)testODPTDataLoaderFunc2{
    // Coredata object の初期値はどんな型か確認
    
    // 非同期処理の完了を監視するオブジェクトを作成
    // XCTestExpectation *expectation = [self expectationWithDescription:@"testODPTDataLoaderFunc2"];
    
    [self prepareForAPIAccessWithReset:YES];
    
    NSManagedObjectContext *moc = [self->dataManager managedObjectContextForConcurrent];
    
    [moc performBlockAndWait:^{
        NSManagedObject *trainObj = [NSEntityDescription insertNewObjectForEntityForName:@"TimetableVehicle" inManagedObjectContext:moc];
        NSLog(@"trainObj: %@", trainObj);
        NSMutableSet *set = [trainObj valueForKey:@"records"];
        NSLog(@"set: %@", set);  // 何も設定していなくても nilは返ってこない
        
        NSManagedObject *recordObj = [NSEntityDescription insertNewObjectForEntityForName:@"TimetableVehicleRecord" inManagedObjectContext:moc];
        
        [set addObject:recordObj];   // 新たに NSMutableSet を alloc/init しなくても addできる
        
        NSLog(@"trainObj: %@", trainObj);
        
        
        
        NSManagedObject *trainObj2 = [NSEntityDescription insertNewObjectForEntityForName:@"TimetableVehicle" inManagedObjectContext:moc];
        NSManagedObject *recordObj2 = [NSEntityDescription insertNewObjectForEntityForName:@"TimetableVehicleRecord" inManagedObjectContext:moc];
        
        NSMutableOrderedSet *set2 = [[NSMutableOrderedSet alloc] init];
        [set2 addObject:recordObj2];
        
        [trainObj2 setValue:set2 forKey:@"records"];
        
        
        NSLog(@"trainObj2: %@", trainObj2);
        
        NSManagedObject *obj = nil;
        NSManagedObject *sobj = [obj valueForKey:@"records"];  // abortにはならない
        
        NSLog(@"sObj: %@", sobj);
        
    }];
    
    
    // [expectation fulfill];
}


- (void)testODPTDataLoaderConnectingLines{
    NSString *caseName = @"testODPTDataLoaderConnectingLines";
    
    // 正解を管理するContainerを作成
    TestRightAnswerContainer *rightAnswer = [[TestRightAnswerContainer alloc] initWithTestCase:caseName];
    
    [self prepareForAPIAccessWithReset:YES];
    
    NSArray *stationIdentiiers = @[@"odpt.Station:JR-East.Yamanote.Ikebukuro",
                                   @"odpt.Station:JR-East.Yamanote.Shinjuku",
                                   @"odpt.BusstopPole:Toei.OjiStation.196.3",
                                   @"odpt.Station:JR-East.Narita.Narita",
                                   @"odpt.Station:JR-East.SobuRapid.Chiba",
                                   @"odpt.Station:JR-East.SobuRapid.Ichikawa",
                                   @"odpt.Station:JR-East.Yokosuka.Kurihama",
                                   @"odpt.Station:Keikyu.Main.Yokohama",
                                   @"odpt.Station:JR-East.Musashino.HigashiMatsudo",
                                   @"odpt.Station:TokyoMetro.Tozai.NishiFunabashi"];
    
    NSDictionary *opt = @{ODPTDataLoaderConnectingLinesOptionsSearchRadius:[NSNumber numberWithInt:500],
                          ODPTDataLoaderConnectingLinesOptionsNeedToLoadRailway:[NSNumber numberWithBool:YES],
                          ODPTDataLoaderConnectingLinesOptionsNeedToLoadBusRoutePattern:[NSNumber numberWithBool:NO]
                          };
    
    // 非同期処理の完了を監視するオブジェクトを作成
    XCTestExpectation *expectation = [self expectationWithDescription:caseName];
    expectation.expectedFulfillmentCount = [stationIdentiiers count];
    
    for(int p=0; p<[stationIdentiiers count]; p++){
        NSString *stationIdentifier = stationIdentiiers[p];

        __block ODPTDataLoaderConnectingLines *job;
        job = [[ODPTDataLoaderConnectingLines alloc] initWithStaion:stationIdentifier withOptions:opt Block:^(NSManagedObjectID *moID) {
                                                              
            NSManagedObjectContext *moc = [self->dataManager managedObjectContextForConcurrent];
            
            [moc performBlockAndWait:^{
                NSManagedObject *obj = [moc objectWithID:moID];
                // ここでは station entity のオブジェクトが返ってくる。
                
                NSSet *set = [obj valueForKey:@"connectingLines"];
                
                NSMutableDictionary *answer = [[NSMutableDictionary alloc] init];
                NSArray *cons_orig = [set allObjects];
                for(int i=0; i<[cons_orig count]; i++){
                    NSManagedObject *cObj = [cons_orig objectAtIndex:i]; // connectingLine entity のオブジェクト
                    
                    NSString *cLineIdentifier = [cObj valueForKey:@"identifier"];
                    NSString *cStationIdentifier = [cObj valueForKey:@"atStation"];
                    XCTAssert([cStationIdentifier hasPrefix:@"unknown"] == NO, @"cStationIdentifier is unknown!!");
                    
                    NSLog(@" cline:%@ at %@", cLineIdentifier, cStationIdentifier);
                    
                    [answer setObject:@"1" forKey:[NSString stringWithFormat:@"%@_%@", cLineIdentifier, cStationIdentifier]];
                }
                
                NSString *q = stationIdentifier;
                
                // 正解記録 or 正解確認
                if([rightAnswer judgeAnswer:answer forQuery:q] == NO){
                    XCTAssertFalse(YES, @"answer is wrong or not Found. Query:%@ ", q);
                }
                
                [expectation fulfill];
            }];
        }];
        
        job.dataProvider = dataProvider;
        job.dataManager = dataManager;
        
        [eQueue addLoader:job];
    
    }
    
    // 指定秒数待つ
    [self waitForExpectations:@[expectation] timeout:120.0f enforceOrder:NO];
}

- (void)testODPTDataAdditionalConnectStationOfLine{
    
    // 非同期処理の完了を監視するオブジェクトを作成
    XCTestExpectation *expectation = [self expectationWithDescription:@"testODPTDataAdditionalConnectStationofLine"];
    
    [self prepareForAPIAccessWithReset:YES];
    
    NSString *stationIdentifier = @"odpt.Station:TokyoMetro.Fukutoshin.Zoshigaya";
    NSString *lineIdentifier = @"odpt.Railway:Toei.Arakawa.1.1";
    
    __block ODPTDataLoaderLine *job = [[ODPTDataLoaderLine alloc] initWithLine:lineIdentifier Block:^(NSManagedObjectID *moIDL) {
        
        __block ODPTDataLoaderStation *job2 = [[ODPTDataLoaderStation alloc] initWithStation:stationIdentifier Block:^(NSManagedObjectID *moIDS) {
            
            NSManagedObjectContext *moc = [self->dataManager managedObjectContextForConcurrent];
            
            [moc performBlockAndWait:^{
                NSManagedObject *lineObject = [moc objectWithID:moIDL];
                NSManagedObject *stationObject = [moc objectWithID:moIDS];
                
                NSString *new_cs = [job2 connectStationOfLine:lineObject forStation:stationObject];
                
                NSLog(@"new_cs: %@",new_cs);
            }];
            [expectation fulfill];
        }];
        
        job2.dataProvider = self->dataProvider;
        job2.dataManager = self->dataManager;
        
        [self->eQueue addLoader:job2];
        
    }];
    
    job.dataProvider = dataProvider;
    job.dataManager = dataManager;
    
    [eQueue addLoader:job];
    
    // 指定秒数待つ
    [self waitForExpectations:@[expectation] timeout:20.0f enforceOrder:NO];
    
}

- (void)testODPTDataLoaderApplicableCalendar{
    NSString *caseName = @"testODPTDataLoaderApplicableCalendar";
    
    // 正解を管理するContainerを作成
    TestRightAnswerContainer *rightAnswer = [[TestRightAnswerContainer alloc] initWithTestCase:caseName];

    [self prepareForAPIAccessWithReset:YES];
    
    NSArray *calendars = @[@"odpt.Calendar:Weekday",
                           @"odpt.Calendar:SaturdayHoliday",
                           @"odpt.Calendar:Specific.Toei.21-170",   // means (almost) weekday.
                           @"odpt.Calendar:Specific.Toei.37-100"   // means (almost) sunday.
                           ];
    
    NSArray *checkDateStr = @[@"2019-01-06 10:42",  // Sunday.
                              @"2019-01-05 10:42", // Satarday
                              @"2019-01-14 11:00",  // Monday but Holiday(@holidays.json).
                              @"2019-10-18 09:00",  // Friday
                              @"2019-12-23 09:00"  // Monday
                              ];
    
    // フォーマットを文字列で指定
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm"];
    
    
    // 非同期処理の完了を監視するオブジェクトを作成
    XCTestExpectation *expectation = [self expectationWithDescription:caseName];
    expectation.expectedFulfillmentCount = [checkDateStr count];
    
    NSMutableArray *loaders = [[NSMutableArray alloc] init];
    
    for(int i=0; i<[calendars count]; i++){
        NSString *calendarIdent = calendars[i];
        ODPTDataLoaderCalendar *j = [[ODPTDataLoaderCalendar alloc] initWithCalendar:calendarIdent Block:nil];
        
        j.dataProvider = dataProvider;
        j.dataManager = dataManager;
        
        [loaders addObject:j];
    }
    
    __block ODPTDataLoaderArray *job = [[ODPTDataLoaderArray alloc] initWithLoaders:loaders Block:^(NSArray<NSManagedObjectID *> *ary) {
        
        NSManagedObjectContext *moc = [self->dataManager managedObjectContextForConcurrent];
        
        [moc performBlockAndWait:^{
            
            NSMutableArray *calendarObjs = [[NSMutableArray alloc] init];
            for(int i=0; i<[ary count]; i++){
                NSManagedObjectID *moID = ary[i];
                NSManagedObject *calendarObj = [moc objectWithID:moID];
                [calendarObjs addObject:calendarObj];
            }
            
            for(int i=0; i<[checkDateStr count]; i++){
                NSDate *d = [dateFormatter dateFromString:checkDateStr[i]];

                NSString *hitCalendarIdent = [job applicableCalendarIdentifierForDate:d fromCalendars:calendarObjs];
                NSLog(@"date:%@ -> hitCalendar:%@", d, hitCalendarIdent);
                
                NSString *q = checkDateStr[i];
                
                NSString *answer = hitCalendarIdent;
                // 正解記録 or 正解確認
                if([rightAnswer judgeAnswer:answer forQuery:q] == NO){
                    XCTAssertFalse(YES, @"answer is wrong or not Found. Query:%@ ", q);
                }
                [expectation fulfill];
            }
            
        }];
        
    }];
    
    job.dataProvider = dataProvider;
    job.dataManager = dataManager;
    
    [eQueue addLoader:job];
    
    // 指定秒数待つ
    [self waitForExpectations:@[expectation] timeout:30.0f enforceOrder:NO];
    
}


- (void)testODPTDataLoaderOperator{
    NSString *caseName = @"testODPTDataLoaderOperator";
    
    // 正解を管理するContainerを作成
    TestRightAnswerContainer *rightAnswer = [[TestRightAnswerContainer alloc] initWithTestCase:caseName];
    
    [self prepareForAPIAccessWithReset:YES];
    
    NSArray *operatorIdents = @[@"odpt.Operator:JR-East",
                               @"odpt.Operator:Tobu",
                               @"odpt.Operator:Toei"
                               ];
    
    // 非同期処理の完了を監視するオブジェクトを作成
    XCTestExpectation *expectation = [self expectationWithDescription:caseName];
    expectation.expectedFulfillmentCount = [operatorIdents count];
    
    for(int p=0; p<[operatorIdents count]; p++){
        NSString *operatorIdentifier = operatorIdents[p];
    
        __block ODPTDataLoaderOperator *job;
        job = [[ODPTDataLoaderOperator alloc] initWithOperator:operatorIdentifier Block:^(NSManagedObjectID *moID) {
        
            NSManagedObjectContext *moc = [self->dataManager managedObjectContextForConcurrent];
            
            [moc performBlockAndWait:^{
                NSManagedObject *obj = [moc objectWithID:moID];
                // ここでは operator entity のオブジェクトが返ってくる。
                
                //NSString *operatorIdentifier = [obj valueForKey:@"identifier"];
                NSString *operatorTitle = [obj valueForKey:@"title_ja"];
                
                NSLog(@" operator :%@ -> %@", operatorIdentifier, operatorTitle);
                
                NSString *q = operatorIdentifier;
                NSDictionary *answer = @{@"title":operatorTitle};
                
                // 正解記録 or 正解確認
                if([rightAnswer judgeAnswer:answer forQuery:q] == NO){
                    XCTAssertFalse(YES, @"answer is wrong or not Found. Query:%@ ", q);
                }
            }];
            
            [expectation fulfill];
        }];
        
        job.dataProvider = dataProvider;
        job.dataManager = dataManager;
        
        [eQueue addLoader:job];
    }
    
    // 指定秒数待つ
    [self waitForExpectations:@[expectation] timeout:30.0f enforceOrder:NO];
    
}


- (void)testODPTDataLoaderTimetableVehicle{
    NSString *caseName = @"testODPTDataLoaderTimetableVehicle";
    
    // 正解を管理するContainerを作成
    TestRightAnswerContainer *rightAnswer = [[TestRightAnswerContainer alloc] initWithTestCase:caseName];
    
    
    [self prepareForAPIAccessWithReset:YES];
    
    NSArray *timetableIdents = @[@"odpt.TrainTimetable:TokyoMetro.Chiyoda.A1001K.SaturdayHoliday"
                                ];
    
    // 非同期処理の完了を監視するオブジェクトを作成
    XCTestExpectation *expectation = [self expectationWithDescription:caseName];
    expectation.expectedFulfillmentCount = [timetableIdents count];
    
    for(int p=0; p<[timetableIdents count]; p++){
        NSString *timetableIdentifier = timetableIdents[p];
        
        __block ODPTDataLoaderTimetableVehicle *job;
        job = [[ODPTDataLoaderTimetableVehicle alloc] initWithTimetableVehicle:timetableIdentifier Block:^(NSManagedObjectID *moID) {
            
            NSManagedObjectContext *moc = [self->dataManager managedObjectContextForConcurrent];
            
            [moc performBlockAndWait:^{
                NSManagedObject *obj = [moc objectWithID:moID];
                // ここでは operator entity のオブジェクトが返ってくる。
                
                NSLog(@"ident:%@", [obj valueForKey:@"identifier"]);
                NSLog(@"trainNumber:%@", [obj valueForKey:@"trainNumber"]);
                
                NSArray *records = [obj valueForKey:@"records"];
                for(int i=0; i<[records count]; i++){
                    NSManagedObject *recObj = records[i];
                    NSLog(@"time: %@:%@ %@", [recObj valueForKey:@"timeHour"], [recObj valueForKey:@"timeMinute"],
                          [recObj valueForKey:@"atStation"]);
                }
                
                NSMutableOrderedSet *refSet = [obj valueForKey:@"referenceTimetable"];
                for(int j=0; j<[[refSet array] count]; j++){
                    NSManagedObject *robj = [refSet objectAtIndex:j];
                    
                    NSLog(@"ident:%@", [robj valueForKey:@"identifier"]);
                    NSLog(@"trainNumber:%@", [robj valueForKey:@"trainNumber"]);
                    NSArray *records = [robj valueForKey:@"records"];
                    for(int i=0; i<[records count]; i++){
                        NSManagedObject *recObj = records[i];
                        NSLog(@"time: %@:%@ %@", [recObj valueForKey:@"timeHour"], [recObj valueForKey:@"timeMinute"],
                              [recObj valueForKey:@"atStation"]);
                    }
                }
                
                /*
                // 正解記録 or 正解確認
                if([rightAnswer judgeAnswer:answer forQuery:q] == NO){
                    XCTAssertFalse(YES, @"answer is wrong or not Found. Query:%@ ", q);
                }
                 */
            }];
            
            [expectation fulfill];
        }];
        
        job.dataProvider = dataProvider;
        job.dataManager = dataManager;
        
        [eQueue addLoader:job];
    }
    
    // 指定秒数待つ
    [self waitForExpectations:@[expectation] timeout:30.0f enforceOrder:NO];
    
}

- (void)testODPTDataLoaderTimetableLine{
    NSString *caseName = @"testODPTDataLoaderTimetableLine";
    
    // 正解を管理するContainerを作成
    TestRightAnswerContainer *rightAnswer = [[TestRightAnswerContainer alloc] initWithTestCase:caseName];
    
    [self prepareForAPIAccessWithReset:YES];
    
    NSArray *lineIdents = @[@"odpt.Railway:TokyoMetro.Chiyoda.1.1"];
    
    // 非同期処理の完了を監視するオブジェクトを作成
    XCTestExpectation *expectation = [self expectationWithDescription:caseName];
    expectation.expectedFulfillmentCount = [lineIdents count];
    
    for(int p=0; p<[lineIdents count]; p++){
        NSString *lineIdentifier = lineIdents[p];
        
        __block ODPTDataLoaderTimetableLine *job;
        job = [[ODPTDataLoaderTimetableLine alloc] initWithLine:lineIdentifier Block:^(NSManagedObjectID *moID) {
            
            NSManagedObjectContext *moc = [self->dataManager managedObjectContextForConcurrent];
            
            [moc performBlockAndWait:^{
                NSManagedObject *timetableSetObj = [moc objectWithID:moID]; //  entity: TimetableLineSet
                
                NSArray *timetableLines = [[timetableSetObj valueForKey:@"timetableLines"] allObjects];
                
                // departureDate に対してマッチする calendarを選ぶ -> hitCalendarIdent
                NSMutableArray *calendars = [[NSMutableArray alloc] init];
                for(int j=0; j<[timetableLines count]; j++){
                    NSManagedObject *timetableObj = timetableLines[j];
                    NSManagedObject *calendarObject = [timetableObj valueForKey:@"calendar"];
                    
                    if(calendarObject != nil){
                        [calendars addObject:calendarObject];
                    }else{
                        NSLog(@"requestTrainTimetableOfLine nil calendar detect. line:%@ ", lineIdentifier);
                    }
                }
                
                NSDate *departureTime = [NSDate date];
                NSManagedObject *timetableObj = nil;
                NSString *hitCalendarIdent = nil;
                if([calendars count] > 0){
                    hitCalendarIdent = [job applicableCalendarIdentifierForDate:departureTime fromCalendars:calendars];
                    
                    for(int j=0; j<[timetableLines count]; j++){
                        NSManagedObject *calendarObject = [timetableLines[j] valueForKey:@"calendar"];
                        NSString *calendarIdent = [calendarObject valueForKey:@"identifier"];
                        //NSLog(@"xx ci:%@", calendarIdent);
                        
                        if([calendarIdent isEqualToString:hitCalendarIdent] == YES){
                            timetableObj = timetableLines[j];
                            break;
                        }
                    }
                }
                
                NSArray *vehicles = nil;
                if(timetableObj == nil){
                    NSLog(@"requestTrainTimetableOfLine detect cannot find timetableObj for now calendar. l:%@ c:%@", lineIdentifier, hitCalendarIdent);
                    vehicles = @[];
                }else{
                    NSOrderedSet *set = [timetableObj valueForKey:@"vehicles"];
                    vehicles = [set array];
                }
                
                for(int p=0; p<[vehicles count]; p++){
                    NSManagedObject *vehicle = vehicles[p];  // vehicle は TimeTableVehicle エンティティ
                    
                    NSNumber *isValidReference = [vehicle valueForKey:@"isValidReference"];
                    NSLog(@"isValidReference:%@", isValidReference);
                    NSOrderedSet *records = [vehicle valueForKey:@"records"];
                    for(int q=0; q<[records count]; q++){
                        NSManagedObject *rec = [records objectAtIndex:q];
                        NSLog(@"%@ (%@:%@)", [rec valueForKey:@"atStation"], [rec valueForKey:@"timeHour"], [rec valueForKey:@"timeMinute"]);
                    }
                    break;
                }
                /*
                 // 正解記録 or 正解確認
                 if([rightAnswer judgeAnswer:answer forQuery:q] == NO){
                 XCTAssertFalse(YES, @"answer is wrong or not Found. Query:%@ ", q);
                 }
                 */
            }];
            
            [expectation fulfill];
        }];
        
        job.dataProvider = dataProvider;
        job.dataManager = dataManager;
        
        [eQueue addLoader:job];
    }
    
    // 指定秒数待つ
    [self waitForExpectations:@[expectation] timeout:30.0f enforceOrder:NO];
    
}

- (void)testODPTDataLoaderTimetableStation{
    NSString *caseName = @"testODPTDataLoaderTimetableStation";
    
    // 正解を管理するContainerを作成
    TestRightAnswerContainer *rightAnswer = [[TestRightAnswerContainer alloc] initWithTestCase:caseName];
    
    [self prepareForAPIAccessWithReset:YES];
    
    NSArray *lineIdents = @[@"odpt.Railway:JR-East.Yokosuka.1.1"];
    NSArray *stationIdents = @[@"odpt.Station:JR-East.SobuRapid.Tokyo"];
    
    // 非同期処理の完了を監視するオブジェクトを作成
    XCTestExpectation *expectation = [self expectationWithDescription:caseName];
    expectation.expectedFulfillmentCount = [lineIdents count];
    
    for(int p=0; p<[lineIdents count]; p++){
        NSString *lineIdentifier = lineIdents[p];
        NSString *stationIdentifier = stationIdents[p];
        
        __block ODPTDataLoaderTimetableStation *job;
        job = [[ODPTDataLoaderTimetableStation alloc] initWithLine:lineIdentifier andStation:stationIdentifier Block:^(NSManagedObjectID *moID) {
            
            NSManagedObjectContext *moc = [self->dataManager managedObjectContextForConcurrent];
            
            [moc performBlockAndWait:^{
                
                NSManagedObject *timetableSetObj = [moc objectWithID:moID]; //  entity: TimetableStationSet
                
                NSArray *timetableStations = [[timetableSetObj valueForKey:@"timetableStations"] allObjects];
                // departureDate に対してマッチする calendarを選ぶ -> hitCalendarIdent
                NSMutableArray *calendars = [[NSMutableArray alloc] init];
                for(int j=0; j<[timetableStations count]; j++){
                    NSManagedObject *timetableObj = timetableStations[j];
                    NSManagedObject *calendarObject = [timetableObj valueForKey:@"calendar"];
                    
                    if(calendarObject != nil){
                        [calendars addObject:calendarObject];
                    }else{
                        NSLog(@"requestStationTimetableOfLine nil calendar detect. line:%@ ", lineIdentifier);
                    }
                }
                
                NSDate *departureTime = [NSDate date];
                NSManagedObject *timetableObj = nil;
                NSString *hitCalendarIdent = nil;
                if([calendars count] > 0){
                    hitCalendarIdent = [job applicableCalendarIdentifierForDate:departureTime fromCalendars:calendars];
                    
                    for(int j=0; j<[timetableStations count]; j++){
                        NSManagedObject *calendarObject = [timetableStations[j] valueForKey:@"calendar"];
                        NSString *calendarIdent = [calendarObject valueForKey:@"identifier"];
                        //NSLog(@"xx ci:%@", calendarIdent);
                        
                        if([calendarIdent isEqualToString:hitCalendarIdent] == YES){
                            timetableObj = timetableStations[j];
                            break;
                        }
                    }
                }
                
                NSArray *records = nil;
                if(timetableObj == nil){
                    NSLog(@"requestStationTimetableOfLine detect cannot find timetableObj for now calendar. l:%@ c:%@", lineIdentifier, hitCalendarIdent);
                    records = @[];
                }else{
                    NSOrderedSet *set = [timetableObj valueForKey:@"records"];
                    records = [set array];
                }
                
                for(int p=0; p<3; p++){
                    NSManagedObject *record = records[p];  // record は TimeTableStationRecord エンティティ
                    
                    NSLog(@"%@ (%@:%@)", [record valueForKey:@"destination"], [record valueForKey:@"timeHour"],
                          [record valueForKey:@"timeMinute"]);
                }
                
            }];
        
            [expectation fulfill];
        }];
        
        job.dataProvider = dataProvider;
        job.dataManager = dataManager;
        
        [eQueue addLoader:job];
    }
    
    // 指定秒数待つ
    [self waitForExpectations:@[expectation] timeout:30.0f enforceOrder:NO];

}
@end

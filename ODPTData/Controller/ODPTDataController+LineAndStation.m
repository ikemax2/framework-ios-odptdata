//
//  ODPTDataController+LineAndStation.m
//
//  Copyright (c) 2019 Takehito Ikema
//
//  This software is released under the MIT License.
//  https://opensource.org/licenses/mit-license.php
//

#import <UIKit/UIKit.h>
#import "ODPTDataController+LineAndStation.h"
#import "ODPTDataLoaderStation.h"
#import "ODPTDataLoaderLine.h"
#import "ODPTDataLoaderArray.h"
#import "ODPTDataLoaderPoint.h"
#import "ODPTDataLoaderConnectingLines.h"
#import "ODPTDataAdditional.h"
#import "ODPTDataLoaderOperator.h"
#import "EfficientLoaderQueue.h"


#import "ODPTDataController+Common.h"

@implementation ODPTDataController (LineAndStation)

- (void)requestWithOwner:(id _Nullable)owner StationLocationsForStations:(NSArray<NSString *> *)identArray Block:(void (^)(NSArray * _Nullable))block{
    
    NSMutableArray *loaders = [[NSMutableArray alloc] init];
    for(int i=0; i<[identArray count]; i++){
        NSString *stationIdent = [identArray objectAtIndex:i];
        ODPTDataLoaderStation *job = [[ODPTDataLoaderStation alloc] initWithStation:stationIdent Block:nil];
        
        job.dataProvider = self->dataProvider;
        job.dataManager = self->APIDataManager;
        
        [loaders addObject:job];
    }
    
    ODPTDataLoaderArray *job2 = [[ODPTDataLoaderArray alloc] initWithLoaders:loaders Block:^(NSArray<NSManagedObjectID *> *sts) {
        
        if(sts == nil){
            // APIアクセスに失敗。
            NSLog(@"ODPTDataLoaderStation return nil.");
            // メインスレッドで実行。
            dispatch_async(
                           dispatch_get_main_queue(),
                           ^{
                               block(nil);
                           }
                           );
            return;
        }
        
        __block NSMutableArray *locArray = [[NSMutableArray alloc] init];
        
        NSManagedObjectContext *moc = [self->APIDataManager managedObjectContextForConcurrent];
        
        [moc performBlockAndWait:^{
            
            for(int i=0; i<[sts count]; i++){
                NSManagedObjectID *moID = [sts objectAtIndex:i];
                NSManagedObject *mo = [moc objectWithID:moID];
                
                double lon = [[mo valueForKey:@"longitude"] doubleValue];
                double lat = [[mo valueForKey:@"latitude"] doubleValue];
                
                CLLocation *loc = [[CLLocation alloc] initWithCoordinate:CLLocationCoordinate2DMake(lat, lon)
                                                                altitude:0
                                                      horizontalAccuracy:0
                                                        verticalAccuracy:0
                                                                  course:0
                                                                   speed:0
                                                               timestamp:[NSDate date]];
                [locArray addObject:loc];
            }
            
        }];
        
        // メインスレッドで実行。
        dispatch_async(
                       dispatch_get_main_queue(),
                       ^{
                           block([locArray copy]);
                       }
                       );
    }];
    
    job2.dataProvider = dataProvider;
    job2.dataManager = APIDataManager;
    [job2 setOwner:owner];
    
    [self->queue addLoader:job2];
}

- (void)requestWithOwner:(id _Nullable)owner StationLocationsForLine:(NSString *)LineIdentifier Block:(void (^)(NSArray * _Nullable))block{
    
    //
    //[self requestStationIdentifiersForLine:LineIdentifier Block:^(NSArray<NSString *> *identArray) {
    
    __block ODPTDataLoaderLine *job;
    
    // まず  stationIdentifier を取得。
    job = [[ODPTDataLoaderLine alloc] initWithLine:LineIdentifier Block:^(NSManagedObjectID *moID) {
        
        if(moID == nil){
            // APIアクセスに失敗。
            NSLog(@"ODPTDataLoaderLine return nil. ident:%@", LineIdentifier);
            // メインスレッドで実行。
            dispatch_async(
                           dispatch_get_main_queue(),
                           ^{
                               block(nil);
                           }
                           );
            return;
        }
        
        NSManagedObjectContext *moc = [self->APIDataManager managedObjectContextForConcurrent];
        
        __block NSMutableArray *identArray = [[NSMutableArray alloc] init];
        [moc performBlockAndWait:^{
            NSManagedObject *mo = [moc objectWithID:moID];
            NSArray *stations = [job stationArrayForLineObject:mo];
            
            for(int i=0; i<[stations count]; i++){
                NSManagedObject *s = stations[i];  // Entity:Station
                NSString *ident = [s valueForKey:@"identifier"];
                
                [identArray addObject:ident];
            }
        }];
        
        NSMutableArray *loaders = [[NSMutableArray alloc] init];
        for(int i=0; i<[identArray count]; i++){
            NSString *stationIdent = [identArray objectAtIndex:i];
            ODPTDataLoaderStation *job = [[ODPTDataLoaderStation alloc] initWithStation:stationIdent Block:nil];
            
            job.dataProvider = self->dataProvider;
            job.dataManager = self->APIDataManager;
            
            [loaders addObject:job];
        }
        
        ODPTDataLoaderArray *job2 = [[ODPTDataLoaderArray alloc] initWithLoaders:loaders Block:^(NSArray<NSManagedObjectID *> *sts) {
            
            if(sts == nil){
                // APIアクセスに失敗。
                NSLog(@"ODPTDataLoaderStation return nil. ident:%@", LineIdentifier);
                // メインスレッドで実行。
                dispatch_async(
                               dispatch_get_main_queue(),
                               ^{
                                   block(nil);
                               }
                               );
                return;
            }
            
            __block NSMutableArray *locArray = [[NSMutableArray alloc] init];
            
            NSManagedObjectContext *moc = [self->APIDataManager managedObjectContextForConcurrent];
            
            [moc performBlockAndWait:^{
                
                for(int i=0; i<[sts count]; i++){
                    NSManagedObjectID *moID = [sts objectAtIndex:i];
                    NSManagedObject *mo = [moc objectWithID:moID];
                    
                    double lon = [[mo valueForKey:@"longitude"] doubleValue];
                    double lat = [[mo valueForKey:@"latitude"] doubleValue];
                    
                    CLLocation *loc = [[CLLocation alloc] initWithCoordinate:CLLocationCoordinate2DMake(lat, lon)
                                                                    altitude:0
                                                          horizontalAccuracy:0
                                                            verticalAccuracy:0
                                                                      course:0
                                                                       speed:0
                                                                   timestamp:[NSDate date]];
                    [locArray addObject:loc];
                }
                
            }];
            
            // メインスレッドで実行。
            dispatch_async(
                           dispatch_get_main_queue(),
                           ^{
                               block([locArray copy]);
                           }
                           );
        }];
        
        job2.dataProvider = self->dataProvider;
        job2.dataManager = self->APIDataManager;
        job2.parent = job;
        
        [self->queue addLoader:job2];
        
    }];
    
    job.dataProvider = dataProvider;
    job.dataManager = APIDataManager;
    [job setOwner:owner];
    
    [self->queue addLoader:job];
    
}

- (void)requestWithOwner:(id _Nullable)owner StationIdentifiersForLine:(NSString *)LineIdentifier Block:(void (^)(NSArray<NSString *>* _Nullable ))block{
    
    __block ODPTDataLoaderLine *job;
    
    job = [[ODPTDataLoaderLine alloc] initWithLine:LineIdentifier Block:^(NSManagedObjectID *moID) {
        
        if(moID == nil){
            // APIアクセスに失敗。
            NSLog(@"ODPTDataLoaderLine return nil. ident:%@", LineIdentifier);
            // メインスレッドで実行。
            dispatch_async(
                           dispatch_get_main_queue(),
                           ^{
                               block(nil);
                           }
                           );
            return;
        }
        
        NSManagedObjectContext *moc = [self->APIDataManager managedObjectContextForConcurrent];
        
        __block NSMutableArray *identArray = [[NSMutableArray alloc] init];
        [moc performBlockAndWait:^{
            NSManagedObject *mo = [moc objectWithID:moID];
            NSArray *stations = [job stationArrayForLineObject:mo];
            
            for(int i=0; i<[stations count]; i++){
                NSManagedObject *s = stations[i];  // Entity:Station
                NSString *ident = [s valueForKey:@"identifier"];
                
                [identArray addObject:ident];
            }
        }];
        
        // メインスレッドで実行。
        dispatch_async(
                       dispatch_get_main_queue(),
                       ^{
                           block(identArray);
                       });
        
    }];
    
    job.dataProvider = dataProvider;
    job.dataManager = APIDataManager;
    [job setOwner:owner];
    
    [self->queue addLoader:job];
    
}


- (void)requestWithOwner:(id _Nullable)owner StationDictsForLineArray:(NSArray<NSString *> *)LineIdentifiers Block:(void (^)(NSArray * _Nullable))block{
    
    
    NSMutableArray *loaders = [[NSMutableArray alloc] init];
    for(int i=0; i<[LineIdentifiers count]; i++){
        NSString *lineIdent = LineIdentifiers[i];
        ODPTDataLoaderLine *job = [[ODPTDataLoaderLine alloc] initWithLine:lineIdent Block:nil];
        
        job.dataProvider = self->dataProvider;
        job.dataManager = self->APIDataManager;
        
        [loaders addObject:job];
    }
    
    __block ODPTDataLoaderArray *job2 = [[ODPTDataLoaderArray alloc] initWithLoaders:loaders Block:^(NSArray<NSManagedObjectID *> *moIDs) {
        
        if(moIDs == nil){
            // APIアクセスに失敗。
            NSLog(@"ODPTDataLoaderLineArray return nil");
            // メインスレッドで実行。
            dispatch_async(
                           dispatch_get_main_queue(),
                           ^{
                               block(nil);
                           }
                           );
            return;
        }
        
        
        NSManagedObjectContext *moc = [self->APIDataManager managedObjectContextForConcurrent];
        
        // LineObjを取得したばかりの時は、stationObjには、緯度・経度が取得されていない場合があるので、その確認。
        
        NSMutableArray *needToFetchStations = [[NSMutableArray alloc] init]; // 取得が必要なstationObj identifier のリスト
        
        [moc performBlockAndWait:^{
            
            for(int i=0; i<[moIDs count]; i++){
                NSManagedObjectID *moID = moIDs[i];
                NSManagedObject *lineObj = [moc objectWithID:moID];  // Line エンティティのオブジェクト
                
                NSArray *stationObjArray = [job2 stationArrayForLineObject:lineObj];
                
                
                for(int j=0; j<[stationObjArray count]; j++){
                    NSManagedObject *stationObj = stationObjArray[j];
                    NSString *stationIdent = [stationObj valueForKey:@"identifier"];
                    
                    if([[stationObj valueForKey:@"longitude"] isKindOfClass:[NSNumber class]] == NO){
                        [needToFetchStations addObject:stationIdent];
                    }else{
                        if([[stationObj valueForKey:@"longitude"] doubleValue] < 0.0f){
                            [needToFetchStations addObject:stationIdent];
                        }
                    }
                }
            }
        }];
        
        NSMutableArray *sLoaders = [[NSMutableArray alloc] init];
        
        for(int i=0; i<[needToFetchStations count]; i++){
            NSString *stationIdent = [needToFetchStations objectAtIndex:i];
            ODPTDataLoaderStation *job = [[ODPTDataLoaderStation alloc] initWithStation:stationIdent Block:nil];
            
            job.dataProvider = self->dataProvider;
            job.dataManager = self->APIDataManager;
            
            [sLoaders addObject:job];
        }
        
        
        ODPTDataLoaderArray *job3 = [[ODPTDataLoaderArray alloc] initWithLoaders:sLoaders Block:^(NSArray<NSManagedObjectID *> *sts) {
            // loaders が空Array でも、コールバックは返る。
            if(sts == nil){
                // APIアクセスに失敗。
                NSLog(@"ODPTDataLoaderStation return nil.");
                // メインスレッドで実行。
                dispatch_async(
                               dispatch_get_main_queue(),
                               ^{
                                   block(nil);
                               }
                               );
                return;
            }
            
            NSManagedObjectContext *moc = [self->APIDataManager managedObjectContextForConcurrent];
            
            NSMutableArray *retLineArray = [[NSMutableArray alloc] init];
            [moc performBlockAndWait:^{
                
                // これは、Line を取得した際の moIDs.
                for(int i=0; i<[moIDs count]; i++){
                    NSManagedObjectID *moID = moIDs[i];
                    NSManagedObject *lineObj = [moc objectWithID:moID];  // Line エンティティのオブジェクト
                    
                    NSArray *stationObjArray = [job2 stationArrayForLineObject:lineObj];
                    NSArray *duplications = [job2 stationDuplicationArrayForLineObject:lineObj];
                    
                    NSMutableArray *retStationArray = [[NSMutableArray alloc] init];
                    for(int j=0; j<[stationObjArray count]; j++){
                        NSManagedObject *stationObj = stationObjArray[j];
                        NSString *stationIdent = [stationObj valueForKey:@"identifier"];
                        NSNumber *dup = duplications[j];
                        
                        double lon =[[stationObj valueForKey:@"longitude"] doubleValue];
                        double lat = [[stationObj valueForKey:@"latitude"] doubleValue];
                        
                        CLLocation *loc = [[CLLocation alloc] initWithCoordinate:CLLocationCoordinate2DMake(lat, lon)
                                                                        altitude:0
                                                              horizontalAccuracy:0
                                                                verticalAccuracy:0
                                                                          course:0
                                                                           speed:0
                                                                       timestamp:[NSDate date]];
                        
                        NSDictionary *stationDict = nil;
                        if(loc != nil && loc.coordinate.latitude > 0.0f && loc.coordinate.longitude > 0.0f){
                            stationDict = @{@"identifier":stationIdent, @"duplication":dup, @"location":loc};
                        }else{
                            stationDict = @{@"identifier":stationIdent, @"duplication":dup, @"location":[NSNull null]};
                        }
                        
                        [retStationArray addObject:stationDict];
                    }
                    [retLineArray addObject:[retStationArray copy]];
                }
            }];
            
            // メインスレッドで実行。
            dispatch_async(
                           dispatch_get_main_queue(),
                           ^{
                               block([retLineArray copy]);
                           }
                           );
        }];
        
        job3.dataProvider = self->dataProvider;
        job3.dataManager = self->APIDataManager;
        job3.parent = job2;
        
        [self->queue addLoader:job3];
        
    }];
    
    job2.dataProvider = dataProvider;
    job2.dataManager = APIDataManager;
    [job2 setOwner:owner];
    
    [self->queue addLoader:job2];
    
}

- (void)requestWithOwner:(id _Nullable)owner ColorForLine:(NSString *)LineIdentifier Block:(void (^)(UIColor * _Nullable))block{
    
    ODPTDataLoaderLine *job = [[ODPTDataLoaderLine alloc] initWithLine:LineIdentifier Block:^(NSManagedObjectID *moID) {
        
        if(moID == nil){
            // APIアクセスに失敗。
            NSLog(@"ODPTDataLoaderLine return nil. ident:%@", LineIdentifier);
            // メインスレッドで実行。
            dispatch_async(
                           dispatch_get_main_queue(),
                           ^{
                               block(nil);
                           }
                           );
            return;
        }
        
        NSManagedObjectContext *moc = [self->APIDataManager managedObjectContextForConcurrent];
        
        __block NSString *colorString;
        [moc performBlockAndWait:^{
            NSManagedObject *mo = [moc objectWithID:moID];
            
            colorString = [mo valueForKey:@"color"];
            
        }];
        // メインスレッドで実行。
        dispatch_async(
                       dispatch_get_main_queue(),
                       ^{
                           block([self colorFromString:colorString]);
                       });
        
    }];
    
    job.dataProvider = dataProvider;
    job.dataManager = APIDataManager;
    [job setOwner:owner];
    
    [self->queue addLoader:job];
    
}



- (void)requestWithOwner:(id _Nullable)owner IsCirculationForLine:(NSString *)LineIdentifier Block:(void (^)(BOOL))block{
    
    ODPTDataLoaderLine *job = [[ODPTDataLoaderLine alloc] initWithLine:LineIdentifier Block:^(NSManagedObjectID *moID) {
        
        if(moID == nil){
            // APIアクセスに失敗。
            NSLog(@"ODPTDataLoaderLine return nil. ident:%@", LineIdentifier);
            // メインスレッドで実行。
            dispatch_async(
                           dispatch_get_main_queue(),
                           ^{
                               block(nil);
                           }
                           );
            return;
        }
        
        NSManagedObjectContext *moc = [self->APIDataManager managedObjectContextForConcurrent];
        
        __block NSNumber *isCirculation;
        [moc performBlockAndWait:^{
            NSManagedObject *mo = [moc objectWithID:moID];
            
            isCirculation = [mo valueForKey:@"circulation"];
            
        }];
        
        // メインスレッドで実行。
        dispatch_async(
                       dispatch_get_main_queue(),
                       ^{
                           block([isCirculation boolValue]);
                       });
        
    }];
    
    job.dataProvider = dataProvider;
    job.dataManager = APIDataManager;
    [job setOwner:owner];
    
    [self->queue addLoader:job];
    
}

// APIによる位置->近傍駅検出
// 未使用
- (void)requestWithOwner:(id _Nullable)owner NearStationsAtPoint:(CLLocationCoordinate2D)point Block:(void (^)(NSArray * _Nullable))block{
    
    NSDictionary *opt;
    
    ODPTDataLoaderPoint *job = [[ODPTDataLoaderPoint alloc] initWithLocation:point
                                                                 withOptions:opt
                                                                       Block:^(NSManagedObjectID *moID) {
                                                                           __block NSMutableArray *stationIdentsArray = [[NSMutableArray alloc] init];
                                                                           NSManagedObjectContext *moc = [self->APIDataManager managedObjectContextForConcurrent];
                                                                           
                                                                           [moc performBlockAndWait:^{
                                                                               if(moID == nil){
                                                                                   // APIアクセスに失敗。
                                                                                   NSLog(@"ODPTDataLoaderLine return nil. ident");
                                                                                   // メインスレッドで実行。
                                                                                   dispatch_async(
                                                                                                  dispatch_get_main_queue(),
                                                                                                  ^{
                                                                                                      block(nil);
                                                                                                  }
                                                                                                  );
                                                                                   return;
                                                                               }
                                                                               
                                                                               NSManagedObject *pointObj = [moc objectWithID:moID];
                                                                               
                                                                               NSMutableSet *nearStations = [pointObj valueForKey:@"nearStations"];
                                                                               NSArray *nearStationsArray = [nearStations allObjects];
                                                                               
                                                                               for(NSManagedObject *obj in nearStationsArray){
                                                                                   NSString *stationIdent = [obj valueForKey:@"identifier"];
                                                                                   [stationIdentsArray addObject:stationIdent];
                                                                               }
                                                                           }];
                                                                           
                                                                           // メインスレッドで実行。
                                                                           dispatch_async(
                                                                                          dispatch_get_main_queue(),
                                                                                          ^{
                                                                                              block([stationIdentsArray copy]);
                                                                                          });
                                                                       }];
    
    job.dataProvider = dataProvider;
    job.dataManager = APIDataManager;
    [job setOwner:owner];
    
    [self->queue addLoader:job];
    
}

// APIによる位置->近傍路線とその駅を検出
- (void)requestWithOwner:(id _Nullable )owner NearLinesAtPoint:(CLLocationCoordinate2D)point ofRailway:(BOOL)loadRailway ofBus:(BOOL)loadBus withSearchRadius:(int)radius Block:(void (^)(NSArray * _Nullable, NSArray * _Nullable))block{
    
    NSDictionary *opt = @{ODPTDataLoaderPointOptionsSearchRadius:[NSNumber numberWithInt:radius],
                          ODPTDataLoaderPointOptionsNeedToLoadRailway:[NSNumber numberWithBool:loadRailway],
                          ODPTDataLoaderPointOptionsNeedToLoadBusRoutePattern:[NSNumber numberWithBool:loadBus]
                          };
    
    __block ODPTDataLoaderPoint *job = [[ODPTDataLoaderPoint alloc] initWithLocation:point withOptions:opt Block:^(NSManagedObjectID *moID) {
                                                                                   
        NSMutableArray *ridingStations = [[NSMutableArray alloc] init];
        NSMutableArray *ridingLines = [[NSMutableArray alloc] init];
        
        NSManagedObjectContext *moc = [self->APIDataManager managedObjectContextForConcurrent];
        
        [moc performBlockAndWait:^{
            if(moID == nil){
                // APIアクセスに失敗。
                NSLog(@"ODPTDataLoaderLine return nil. ident");
                // メインスレッドで実行。
                dispatch_async(
                               dispatch_get_main_queue(),
                               ^{
                                   block(nil,nil);
                               }
                               );
                return;
            }
            
            NSManagedObject *pointObj = [moc objectWithID:moID];
            
            NSMutableSet *nearStations = [pointObj valueForKey:@"nearStations"];
            NSLog(@"point:(%@, %@)  nearStationCount:%d",[pointObj valueForKey:@"longitude"],
                  [pointObj valueForKey:@"latitude"], (int)[nearStations count]);
            NSArray *nearStationsArray = [nearStations allObjects];
            
            for(NSManagedObject *stationObj in nearStationsArray){
                NSString *stationIdent = [stationObj valueForKey:@"identifier"];
                
                NSMutableSet *lineSet = [stationObj valueForKey:@"lines"];
                for(NSManagedObject *lineObj in [lineSet allObjects]){
                    NSString *lineIdent = [lineObj valueForKey:@"identifier"];
                    
                    NSArray *stationArray = [job stationArrayForLineObject:lineObj];
                    NSArray *duplications = [job stationDuplicationArrayForLineObject:lineObj];
                    
                    
                    for(int j=0; j<[stationArray count]-1; j++){
                        // 終着駅は追加しない
                        NSManagedObject *sObj = stationArray[j];
                        NSString *sIdent = [sObj valueForKey:@"identifier"];
                        if([sIdent isEqualToString:stationIdent] == YES){
                            NSDictionary *dict = @{@"identifier":sIdent, @"duplication":duplications[j]};
                            
                            // これまでに追加した路線と同じ路線がないか確認。
                            BOOL flag = YES;
                            NSUInteger li = [ridingLines indexOfObject:lineIdent];
                            if(li != NSNotFound){
                                NSDictionary *d = ridingStations[li];
                                // 駅識別子が同じか、確認。
                                if([sIdent isEqualToString:d[@"identifier"]] == YES){
                                    // duplicationだけが異なり、 同じ駅識別子。  大江戸線都庁前駅。追加する。
                                    flag = YES;
                                }else{
                                    // 同じ路線で、駅識別子が異なる。　駅近くの複数のバス停を検出。追加しない。
                                    flag = NO;
                                }
                            }
                            
                            if(flag == YES){
                                [ridingStations addObject:dict];
                                [ridingLines addObject:lineIdent];
                            }
                        }
                    }
                    
                }
            }
            
        }];
        
        // メインスレッドで実行。
        dispatch_async(
                       dispatch_get_main_queue(),
                       ^{
                           block(ridingLines, ridingStations);
                       });
    }];
    
    job.dataProvider = dataProvider;
    job.dataManager = APIDataManager;
    [job setOwner:owner];
    
    [self->queue addLoader:job];
}

- (void)requestWithOwner:(id _Nullable)owner LineTitleForIdentifier:(NSString *)LineIdentifier Block:(void (^)(NSString * _Nullable))block{
    
    __block ODPTDataLoaderLine *job = [[ODPTDataLoaderLine alloc] initWithLine:LineIdentifier Block:^(NSManagedObjectID *moID) {
        
        if(moID == nil){
            // APIアクセスに失敗。
            NSLog(@"ODPTDataLoaderLine return nil. ident:%@", LineIdentifier);
            // メインスレッドで実行。
            dispatch_async(
                           dispatch_get_main_queue(),
                           ^{
                               block(nil);
                           }
                           );
            return;
        }
        
        NSManagedObjectContext *moc = [self->APIDataManager managedObjectContextForConcurrent];
        
        //__block NSString *operator;
        __block NSString *lineTitle;
        
        [moc performBlockAndWait:^{
            NSManagedObject *obj = [moc objectWithID:moID];
            lineTitle = [job lineTitleForLineObject:obj];
        }];
        
        // メインスレッドで実行。
        dispatch_async(
                       dispatch_get_main_queue(),
                       ^{
                           block(lineTitle);
                       });
    }];
    
    job.dataProvider = dataProvider;
    job.dataManager = APIDataManager;
    [job setOwner:owner];
    
    [self->queue addLoader:job];
}

- (void)requestWithOwner:(id)owner LineTitleForIdentifierArray:(NSArray<NSString *> *)identifiers Block:(void (^)(NSArray<NSString *> *))block{
    
    NSMutableArray *loaders = [[NSMutableArray alloc] init];
    for(int i=0; i<[identifiers count]; i++){
        NSString *lineIdent = identifiers[i];
        ODPTDataLoaderLine *l = [[ODPTDataLoaderLine alloc] initWithLine:lineIdent Block:nil];
        
        l.dataProvider = dataProvider;
        l.dataManager = APIDataManager;
        
        [loaders addObject:l];
    }
    
    __block ODPTDataLoaderArray *job = [[ODPTDataLoaderArray alloc] initWithLoaders:loaders Block:^(NSArray<NSManagedObjectID *> *moIDArray) {
        
        if(moIDArray == nil){
            // APIアクセスに失敗。
            NSLog(@"ODPTDataLoaderLine return nil. ident:%@", identifiers);
            // メインスレッドで実行。
            dispatch_async(
                           dispatch_get_main_queue(),
                           ^{
                               block(nil);
                           }
                           );
            return;
        }

        NSManagedObjectContext *moc = [self->APIDataManager managedObjectContextForConcurrent];


        __block NSMutableArray *retTitles = [[NSMutableArray alloc] init];
        [moc performBlockAndWait:^{
            for(int i=0; i<[moIDArray count]; i++){
                NSManagedObjectID *moID = moIDArray[i];
                NSManagedObject *obj = [moc objectWithID:moID];
                NSString *lineTitle = [job lineTitleForLineObject:obj];
                [retTitles addObject:lineTitle];
            }
        }];
        
        // メインスレッドで実行。
        dispatch_async(
                       dispatch_get_main_queue(),
                       ^{
                           block(retTitles);
                       });
    }];
    
    job.dataProvider = dataProvider;
    job.dataManager = APIDataManager;
    [job setOwner:owner];
    
    [self->queue addLoader:job];
    
}

// API にアクセスして駅名を得るタイプ
- (void)requestWithOwner:(id _Nullable)owner StationTitleForIdentifier:(NSString *)identifier Block:(void (^)(NSString * _Nullable))block{
    
    // 駅か路線のIdentifierを与えて、そのタイトルを返す。
    NSInteger type = [self typeForIdentifier:identifier];
    
    if(type != ODPTDataIdentifierTypeStation){
        // メインスレッドで実行。
        dispatch_async(
                       dispatch_get_main_queue(),
                       ^{
                           block(nil);
                       }
                       );
        return;
    }
    
    // 駅名だけはODPTDataLoaderLine によって取得する。
    // 現時点ではODPTDataLoaderStation単独では動作しない
    
    //ODPTDataLoader *dmy = [[ODPTDataLoader alloc] init];  // ダミーローダ
    //NSString *lineIdentifier = [dmy lineIdentifierForStationIdentifier:identifier];
    
    NSArray *stationsArray = @[identifier];
    
    NSMutableArray *loaders = [[NSMutableArray alloc] init];
    for(int i=0; i<[stationsArray count]; i++){
        NSString *stationIdent = [stationsArray objectAtIndex:i];
        ODPTDataLoaderStation *l = [[ODPTDataLoaderStation alloc] initWithStation:stationIdent Block:nil];
        
        l.dataProvider = dataProvider;
        l.dataManager = APIDataManager;
        
        [loaders addObject:l];
    }
    
    __block ODPTDataLoaderArray *job = [[ODPTDataLoaderArray alloc] initWithLoaders:loaders Block:^(NSArray<NSManagedObjectID *> *dictArray) {
        
        if(dictArray == nil){
            // APIアクセスに失敗。
            NSLog(@"ODPTDataLoaderStation return nil. ident:%@ ...", stationsArray[0]);
            // メインスレッドで実行。
            dispatch_async(
                           dispatch_get_main_queue(),
                           ^{
                               block(nil);
                           }
                           );
            return;
        }
        
        NSManagedObjectContext *moc = [self->APIDataManager managedObjectContextForConcurrent];
        
        __block NSString *title = nil;
        [moc performBlockAndWait:^{
            NSManagedObjectID *moID = [dictArray firstObject];
            if([moID isKindOfClass:[NSManagedObjectID class]] == YES){
                NSManagedObject *stationObj = [moc objectWithID:moID]; // station Entity object.
                if([[stationObj valueForKey:@"identifier"] isEqualToString:identifier] == YES){
                    title = [job stationTitleForStationObject:stationObj];
                }
            }
        }];
        
        // メインスレッドで実行。
        dispatch_async(
                       dispatch_get_main_queue(),
                       ^{
                           block(title);
                       });
    }];
    
    
    job.dataProvider = dataProvider;
    job.dataManager = APIDataManager;
    [job setOwner:owner];
    
    [self->queue addLoader:job];
}


- (void)requestWithOwner:(id _Nullable)owner LineAndStationInformationsForIdentifier:(NSArray <NSString *> *)identifiers  Block:(void (^)(NSArray<NSDictionary *> *))block{
    
    //NSLog(@"requestLineAndStationInformationsForIdentifier: identifiers %@", identifiers);
    if([identifiers count] == 0){
        block(@[]);
        return;
    }
    
    ODPTDataLoader *dmyLoader = [[ODPTDataLoader alloc] init];
    __block NSMutableArray *lineIdents = [[NSMutableArray alloc] init];
    __block NSMutableArray *stationIdents = [[NSMutableArray alloc] init];
    
    for(int i=0; i<[identifiers count]; i++){
        NSString *ident = identifiers[i];
        NSInteger type = [dmyLoader identifierTypeForIdentifier:ident];
        
        if(type == ODPTDataIdentifierTypeLine){
            [lineIdents addObject:ident];
        }else if(type == ODPTDataIdentifierTypeStation){
            [stationIdents addObject:ident];
        }else{
            // 無視. 数が合わなくなるのでエラーとする
            NSAssert(NO, @"requestLineAndStationInformations identifier error.");
        }
    }
    
    NSMutableArray *loaders = [[NSMutableArray alloc] init];
    for(int i=0; i<[lineIdents count]; i++){
        NSString *ident = lineIdents[i];
        
        ODPTDataLoaderLine *l = [[ODPTDataLoaderLine alloc] initWithLine:ident Block:nil];
        
        l.dataProvider = self->dataProvider;
        l.dataManager = self->APIDataManager;
        [loaders addObject:l];
    }
    
    // NSAssert([loaders count] > 0, @"requestLineAndStationInformationsForIdentifier: lines count zero!!");
    
    __block ODPTDataLoaderArray *job2 = [[ODPTDataLoaderArray alloc] initWithLoaders:loaders Block:^(NSArray<NSManagedObjectID *> *moIDArray) {
        
        // NSAssert([lineIdents count] == [moIDArray count], @"requestLineAndStationInformations result count is not match");
        if([lineIdents count] != [moIDArray count]){
            // アクセスに失敗している。
            // メインスレッドで実行。
            dispatch_async(
                           dispatch_get_main_queue(),
                           ^{
                               block(@[]);
                           });
            return;
        }
        
        __block NSMutableArray *retArray = [[NSMutableArray alloc] init];
        
        NSManagedObjectContext *moc = [self->APIDataManager managedObjectContextForConcurrent];
        __block NSMutableArray *endStationIdents = [[NSMutableArray alloc] init];
        
        [moc performBlockAndWait:^{
            for(int i=0; i<[lineIdents count]; i++){
                NSString *ident = lineIdents[i];
                NSManagedObjectID *moID = moIDArray[i];
                
                if(moID == nil || [moID isKindOfClass:[NSNull class]]){
                    // APIアクセスに失敗。 -> 空のdictionaryを追加
                    NSLog(@"ODPTDataLoaderLine return nil. ident:%@", ident);
                    [retArray addObject:@{}];
                    continue;
                }
                
                NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
                NSManagedObject *obj = [moc objectWithID:moID];
                
                [dict setObject:[job2 lineTitleForLineObject:obj] forKey:@"title"];
                
                NSString *colorString = [obj valueForKey:@"color"];
                [dict setObject:[self colorFromString:colorString] forKey:@"color"];
                
                [retArray addObject:dict];
                
                // endStationIdentifier を取得. stationIdents と合わせて取得.
                NSManagedObject *endStationObj = [job2 endStationForLineObject:obj];
                NSString *endStationIdentifier = [endStationObj valueForKey:@"identifier"];
                [endStationIdents addObject:endStationIdentifier];
                
            }
        }];
        
        __block NSMutableArray *stationIdentsAccess = [[NSMutableArray alloc] init];
        [stationIdentsAccess addObjectsFromArray:endStationIdents];
        [stationIdentsAccess addObjectsFromArray:stationIdents];
        
        
        NSMutableArray *sloaders = [[NSMutableArray alloc] init];
        for(int i=0; i<[stationIdentsAccess count]; i++){
            NSString *ident = stationIdentsAccess[i];
            
            ODPTDataLoaderStation *l = [[ODPTDataLoaderStation alloc] initWithStation:ident Block:nil];
            
            l.dataProvider = self->dataProvider;
            l.dataManager = self->APIDataManager;
            [sloaders addObject:l];
        }
        
        // NSAssert([sloaders count] > 0, @"requestLineAndStationInformationsForIdentifier: stations count zero!!");
        
        __block ODPTDataLoaderArray *job3 = [[ODPTDataLoaderArray alloc] initWithLoaders:sloaders Block:^(NSArray<NSManagedObjectID *> *moIDArray_C) {
            
            // NSAssert([stationIdents count] + [endStationIdents count] == [moIDArray_C count], @"requestLineAndStationInformations result count is not match");
            if([stationIdents count] + [endStationIdents count] != [moIDArray_C count]){
                // アクセスに失敗している。
                // メインスレッドで実行。
                dispatch_async(
                               dispatch_get_main_queue(),
                               ^{
                                   block(@[]);
                               });
                return;
            }
            
            
            NSManagedObjectContext *moc = [self->APIDataManager managedObjectContextForConcurrent];
            [moc performBlockAndWait:^{
                for(int k=0; k<[stationIdentsAccess count]; k++){
                    NSManagedObjectID *moID = moIDArray_C[k];
                    NSManagedObject *obj = [moc objectWithID:moID];
                    
                    if(k <[endStationIdents count]){
                        // lineIdents の endStation の内容
                        NSMutableDictionary *dict = retArray[k];
                        
                        NSString *endStationTitle = [job3 stationTitleForStationObject:obj];
                        [dict setObject:endStationTitle forKey:@"endPoint"];
                        
                    }else{
                        // stationIdents の内容
                        // int j = k - [endStationIdents count];
                        
                        NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
                        [dict setObject:[job3 stationTitleForStationObject:obj] forKey:@"title"];
                        
                        [retArray addObject:dict];
                    }
                    
                }
                
            }];
            // NSLog(@"requestLineAndStationInformationsForIdentifier: ret:%@", retArray);
            // メインスレッドで実行。
            dispatch_async(
                           dispatch_get_main_queue(),
                           ^{
                               block([retArray copy]);
                           });
        }];
        
        job3.dataProvider = self->dataProvider;
        job3.dataManager = self->APIDataManager;
        job3.parent = job2;
        
        [self->queue addLoader:job3];
    }];
    
    job2.dataProvider = dataProvider;
    job2.dataManager = APIDataManager;
    [job2 setOwner:owner];
    
    [self->queue addLoader:job2];
    
}

- (void)requestWithOwner:(id _Nullable)owner IntegratedStationsForLine:(NSString *)LineIdentifier atStation:(NSDictionary *)startStationDict withBranchData:(NSArray * _Nullable)branchData Block:(void (^)(NSArray * _Nullable, NSArray * _Nullable, NSArray * _Nullable))block{
    
    [self innerRequestWithOwner:owner IntegratedStationsForLine:LineIdentifier atStation:startStationDict withBranchData:branchData Block:^(NSArray *integratedStations, NSArray *integratedLines, NSArray *usedBranchData) {
        
        // メインスレッドで実行。
        dispatch_async(
                       dispatch_get_main_queue(),
                       ^{
                           block(integratedStations, integratedLines, usedBranchData);
                       }
                       );
        
    }];
}

- (void)innerRequestWithOwner:(id _Nullable)owner IntegratedStationsForLine:(NSString *)LineIdentifier atStation:(NSDictionary *)startStationDict withBranchData:(NSArray * _Nullable)branchData Block:(void (^)(NSArray * _Nullable, NSArray * _Nullable, NSArray * _Nullable))block{
    
    
    __block NSMutableArray  *integratedStations = [[NSMutableArray alloc] init];
    __block NSMutableArray  *integratedLines = [[NSMutableArray alloc] init];
    
    __block NSMutableArray  *usedBranchData = [[NSMutableArray alloc] init];
    
    __block NSString  *bottomLine = @"";
    __block ODPTDataLoaderLine *job;
    
    NSAssert(startStationDict != nil,@"integratedStationsForLine startStationDict is nil");
    
    // 再帰呼び出しされるメソッド
    __block void (^recursive)(NSManagedObject *, NSInteger, BOOL) = ^(NSManagedObject *lineObj, NSInteger index, BOOL reverse) {
        
        NSString *lineIdent = [lineObj valueForKey:@"identifier"];
        NSArray *stations = [job stationArrayForLineObject:lineObj];
        // NSLog(@"integratedLine recursive lineIdent:%@", lineIdent);
        NSArray *dLines = [job directConnectingLinesForLineObject:lineObj];
        
        NSArray *duplications = [job stationDuplicationArrayForLineObject:lineObj];
        // バスの場合は dLines count = 0 となる.
        
        NSInteger indexOverStations = 0;
        
        if([stations count] <= index){
            // ある路線の終端駅から、終端駅方向を調べる時などには、 indexとして [stations count] が入ってくる。
            
            indexOverStations = index - [stations count] + 1;
            index = [stations count] - 1;
        }
        
        
        BOOL lastFlag = NO;
        NSInteger j = index;
        while( j < [stations count] ){
            NSManagedObject *stationObj = [stations objectAtIndex:j];
            NSString *stationIdent = [stationObj valueForKey:@"identifier"];
            
            if(indexOverStations == 0){
                if(reverse == YES){
                    // 追加するline だけは逆方向.
                    NSManagedObject *reverseLineObj = [lineObj valueForKey:@"reverseDirectionLine"];
                    NSAssert(reverseLineObj != nil, @"reverseLineObj is nil!!");
                    [integratedLines addObject:[reverseLineObj valueForKey:@"identifier"]];
                }else{
                    [integratedLines addObject:lineIdent];
                }
                
                NSDictionary *dict = @{@"identifier":stationIdent, @"duplication":duplications[j]};
                [integratedStations addObject:dict];
            }
            
            // この駅から分岐する他の路線がないか調べる。  バスの場合は dLines count = 0 となる.
            for(int i=0; i<[dLines count]; i++){
                NSDictionary *dict = [dLines objectAtIndex:i];
                
                
                if( [stationIdent isEqualToString:[dict objectForKey:@"station"]] ){
                    // 分岐点に達した。
                    // dconLineObj は Line エンティティ　のオブジェクト
                    NSManagedObject *dconLineObj = [dict objectForKey:@"directConnectingToLine"];
                    NSString *dconLineIdent = [dconLineObj valueForKey:@"identifier"];
                    
                    // 分岐設定を読み込む. branchData があれば、その分岐設定となる。
                    // NSDictionary *dconLineDict = [self selectedDirectConnectedLineForLine:lineIdent atStation:stationIdent withBranchData:branchData];
                    // NSLog(@"IntegratedStations at:%@ ofLine:%@", stationIdent, lineIdent);
                    NSDictionary *dconLineDict = [self branchOfLine:lineIdent atStation:stationIdent withBranchArray:branchData];
                    NSAssert(dconLineDict != nil, @"dconLineDict is nil!!");
                    // この計算で使用した branchData を保存する。
                    [usedBranchData addObject:[dconLineDict copy]];
                    
                    NSString *selectedLineIdent = [dconLineDict objectForKey:@"selectedLine"];
                    //NSLog(@"selectedLine:%@", selectedLineIdent);
                    if(j == [stations count] - 1){
                        if([selectedLineIdent isEqualToString:lineIdent] == YES){
                            // 終着駅にも関わらず、選択路線が、今の路線と同じ。 -> 直通路線があれば、そちらに切り替える
                            selectedLineIdent = dconLineIdent;
                        }
                    }
                    // dconLineIdent が選択されていれば、先へ進む
                    if([selectedLineIdent isEqualToString:dconLineIdent] == NO){
                        continue;
                    }
                    
                    
                    // APIにアクセス可能な路線でない場合は終了
                    if( [[ODPTDataAdditional sharedData] isAbleToAccessAPIOfRailway:dconLineIdent] == NO){
                        bottomLine = dconLineIdent;
                        return;
                    }
                    
                    // 次の路線における、分岐駅の 駅index を得る。 -> newIndex
                    NSInteger newIndex = -1;
                    NSArray *dStations = [job stationArrayForLineObject:dconLineObj];
                    for(int k=0; k<[dStations count]; k++){
                        NSManagedObject *sObj = [dStations objectAtIndex:k];
                        // NSLog(@"%@ <=> %@", [sObj valueForKey:@"identifier"], stationIdent);
                        if([[ODPTDataAdditional sharedData] isConnectStation:[sObj valueForKey:@"identifier"] andStation:stationIdent]){
                            newIndex = k;
                            break;
                        }
                    }
                    NSAssert(newIndex != -1, @"requestIntegratedStationIdentifiers error!! s:%@ l:%@", stationIdent, dconLineIdent);
                    
                    NSAssert(newIndex+1 < [dStations count], @"requestIntegratedStationIdentifiers error!! s:%@ l:%@", stationIdent, dconLineIdent);
                    
                    recursive(dconLineObj, newIndex+1, reverse);
                    lastFlag = YES;
                    break;
                    
                    
                }
            }
            
            
            if(lastFlag == YES){
                break;
            }
            
            j++;
        }
        
    };
    
    
    job = [[ODPTDataLoaderLine alloc] initWithLine:LineIdentifier Block:^(NSManagedObjectID *moID) {
        
        if(moID == nil){
            // APIアクセスに失敗。
            NSLog(@"ODPTDataLoaderLine return nil. ident:%@", LineIdentifier);

            block(nil, nil, nil);
            
            return;
        }
        
        NSManagedObjectContext *moc = [self->APIDataManager managedObjectContextForConcurrent];
        [moc performBlockAndWait:^{
            int startIndexOffset = 0;
            
            NSManagedObject *obj = [moc objectWithID:moID];
            

            NSString *startStationIdentifier = startStationDict[@"identifier"];
            NSNumber *startStationDuplication = startStationDict[@"duplication"];
            
            if([job lineTypeForLineIdentifier:LineIdentifier] == ODPTDataLineTypeRailway){
                // startStationIdentifier が LineIdentifier の路線にない場合、 路線上の駅名となるように変換する。
                startStationIdentifier = [job connectStationOfLine:obj forStationIdentifier:startStationDict[@"identifier"]];
                
                if([startStationIdentifier isEqualToString:startStationDict[@"identifier"]] == NO){
                    NSLog(@"WARNING. integratedStationsForLine station changed. %@ -> %@", startStationDict[@"identifier"], startStationIdentifier);
                }
            }
            
            // 逆方向を探す。
            int startIndex = -1;
            
            NSManagedObject *reverseObj = [obj valueForKey:@"reverseDirectionLine"];
            if(reverseObj != nil){

                NSArray *stations = [job stationArrayForLineObject:reverseObj];
                NSArray *duplications = [job stationDuplicationArrayForLineObject:reverseObj];
                for(int i=0; i<[stations count]; i++){
                    NSString *sIdent = [[stations objectAtIndex:i] valueForKey:@"identifier"];
                    NSNumber *sDup = [duplications objectAtIndex:i];
                    
                    if([startStationIdentifier isEqualToString:sIdent] == YES &&
                       [startStationDuplication isEqualToNumber:sDup]){
                        startIndex = i;
                        break;
                    }
                }
                
                NSAssert(startIndex >= 0, @"requestIntegratedStationIdentifiers(reverse) startIndex invalid. line:%@, station:%@", LineIdentifier, startStationIdentifier);

                recursive(reverseObj, startIndex, YES);
                
                [integratedLines addObject:bottomLine];
                bottomLine = @"";
                
                NSArray *reverseArray = [[integratedStations reverseObjectEnumerator] allObjects];
                integratedStations = [[NSMutableArray alloc] initWithArray:reverseArray];
                
                reverseArray = [[integratedLines reverseObjectEnumerator] allObjects];
                integratedLines = [[NSMutableArray alloc] initWithArray:reverseArray];
                
                [integratedLines removeLastObject];
                
            }else{
                // 逆方向は存在しない場合
                
                NSArray *stations = [job stationArrayForLineObject:obj];
                NSArray *duplications = [job stationDuplicationArrayForLineObject:obj];
                
                NSString *sIdent = [[stations objectAtIndex:0] valueForKey:@"identifier"];
                NSNumber *sDup = [duplications objectAtIndex:0];
                
                if([sIdent isEqualToString:startStationIdentifier] == YES &&
                   [sDup isEqualToNumber:startStationDuplication] == YES){
                    // 始発駅の場合, はじめに始発駅・始発路線（なし）を追加し、あとは通常動作。
                    
                    NSDictionary *dict = @{@"identifier":sIdent, @"duplication":startStationDuplication};
                    [integratedStations addObject:dict];
                    [integratedLines addObject:@""];
                }else{
                    // それ以外の場合は,startIndex を一つ下げて、通常動作。
                    startIndexOffset = -1;
                }
                
            }
            
            // 順方向を探す。
            startIndex = -1;
            NSArray *stations = [job stationArrayForLineObject:obj];
            NSArray *duplications = [job stationDuplicationArrayForLineObject:obj];
            
            for(int i=0; i<[stations count]; i++){
                NSString *sIdent = [[stations objectAtIndex:i] valueForKey:@"identifier"];
                NSNumber *sDup = [duplications objectAtIndex:i];
                
                if([startStationIdentifier isEqualToString:sIdent] == YES &&
                   [startStationDuplication isEqualToNumber:sDup] == YES){
                    startIndex = i;
                    break;
                }
            }
            
            NSAssert(startIndex >= 0, @"requestIntegratedStationIdentifiers(forward) startIndex invalid. line:%@ station:%@", LineIdentifier, startStationIdentifier);
            
            recursive(obj, startIndex+1+startIndexOffset, NO);
            
            [integratedLines addObject:bottomLine];
            
            // 始発駅の場合は integratedLines[0] を 空にする
            /*if(startIndex == 0){
             [integratedLines replaceObjectAtIndex:0 withObject:@""];
             }*/
        }];
        
        block([integratedStations copy], [integratedLines copy], [usedBranchData copy]);
        
    }];
    
    job.dataProvider = dataProvider;
    job.dataManager = APIDataManager;
    [job setOwner:owner];
    
    [self->queue addLoader:job];
}

// 未使用
- (void)requestWithOwner:(id _Nullable)owner SelectedDirectConnectedLineForLine:(NSString *)lineIdentifier atStation:(NSString *)branchStationIdentifier withBranchData:(NSArray * _Nullable)branchData Block:(void (^)(NSString * _Nullable))block{
    
    // 非APIデータである、直通路線のデータを調べる。
    __block ODPTDataLoaderLine *job = [[ODPTDataLoaderLine alloc] initWithLine:lineIdentifier Block:^(NSManagedObjectID *moID) {
        
        __block NSString *selectedLine = nil;
        
        // branchStationIdentifier は終着駅か確認する。
        __block BOOL needForAccessUserData = YES;
        __block BOOL isLastStation = NO;
        NSManagedObjectContext *mocAPI = [self->APIDataManager managedObjectContextForConcurrent];
        [mocAPI performBlockAndWait:^{
            if(moID == nil){
                // APIアクセスに失敗。
                NSLog(@"ODPTDataLoaderLine return nil. ident:%@", lineIdentifier);
                // メインスレッドで実行。
                dispatch_async(
                               dispatch_get_main_queue(),
                               ^{
                                   block(nil);
                               }
                               );
                return;
            }
            
            NSManagedObject *lineObj = [mocAPI objectWithID:moID];
            NSArray *stations = [job stationArrayForLineObject:lineObj];
            
            NSManagedObject *lastStationObj = [stations lastObject];
            NSString *lastStationIdent = [lastStationObj valueForKey:@"identifier"];
            
            if([lastStationIdent isEqualToString:branchStationIdentifier]){
                isLastStation = YES;
            }
            
            NSMutableArray *dconLines = [[NSMutableArray alloc] init];
            
            NSArray<NSDictionary *> *dconDicts = [job directConnectingLinesForLineObject:lineObj];
            // バスの場合は dconDicts count = 0 となる
            for(int i=0; i<[dconDicts count]; i++){
                NSDictionary *dconDict = [dconDicts objectAtIndex:i];
                
                if([[ODPTDataAdditional sharedData] isConnectStation:branchStationIdentifier andStation:[dconDict objectForKey:@"station"]]){
                    NSManagedObject *obj = [dconDict objectForKey:@"directConnectingToLine"];
                    [dconLines addObject:[obj valueForKey:@"identifier"]];
                }
            }
            
            // NSLog(@" isLastStation:%d", isLastStation);
            
            if([dconLines count] == 0){
                // 直通・分岐路線はない。
                needForAccessUserData = NO;
                
            }else if([dconLines count] == 1){
                
                if(isLastStation == YES){
                    // 直通路線が一つで、終着駅である。
                    NSString *dconLineIdent = [dconLines firstObject];
                    selectedLine = dconLineIdent;
                    needForAccessUserData = NO;
                }
            }
            
        }];
        
        
        if(needForAccessUserData == NO){
            // メインスレッドで実行。
            dispatch_async(
                           dispatch_get_main_queue(),
                           ^{
                               block(selectedLine);
                           }
                           );
            return;
        }
        
        // ユーザーデータへアクセス。
        //NSDictionary *dict = [self selectedDirectConnectedLineForLine:lineIdentifier atStation:branchStationIdentifier withBranchData:branchData];
        NSDictionary *dict = [self branchOfLine:lineIdentifier atStation:branchStationIdentifier withBranchArray:branchData];
        selectedLine = [dict objectForKey:@"selectedLine"];
        
        // メインスレッドで実行。
        dispatch_async(
                       dispatch_get_main_queue(),
                       ^{
                           block(selectedLine);
                       }
                       );
        
    }];
    
    job.dataProvider = dataProvider;
    job.dataManager = APIDataManager;
    [job setOwner:owner];
    
    [self->queue addLoader:job];
}



- (void)selectToDirectConnectedLine:(NSString *)selectedLine forLine:(NSString *)lineIdentifier atStation:(NSString *)branchStationIdentifier{
    
    NSLog(@"selectToDirectConnectedLine  line:%@ at:%@  dcon:%@", lineIdentifier, branchStationIdentifier, selectedLine);
    
    [self writeBranchForSelectedLine:selectedLine ofLine:lineIdentifier atStation:branchStationIdentifier];
    
    return;
}

- (void)requestWithOwner:(id _Nullable)owner ConnectingLinesForStation:(NSString *)StationIdentifier ofRailway:(BOOL)loadRailway ofBus:(BOOL)loadBus withSearchRadius:(int)radius Block:(void (^)(NSArray * _Nullable, NSArray * _Nullable))block{
    
    NSDictionary *opt = @{ODPTDataLoaderConnectingLinesOptionsSearchRadius:[NSNumber numberWithInt:radius],
                          ODPTDataLoaderConnectingLinesOptionsNeedToLoadRailway:[NSNumber numberWithBool:loadRailway],
                          ODPTDataLoaderConnectingLinesOptionsNeedToLoadBusRoutePattern:[NSNumber numberWithBool:loadBus]
                          };
    
    __block ODPTDataLoaderConnectingLines *job;
    job = [[ODPTDataLoaderConnectingLines alloc] initWithStaion:StationIdentifier withOptions:opt Block:^(NSManagedObjectID *moID) {
        
        if(moID == nil){
            // APIアクセスに失敗。
            NSLog(@"ODPTDataLoaderConnectingLines return nil. ident:%@ ...", StationIdentifier);
            // メインスレッドで実行。
            dispatch_async(
                           dispatch_get_main_queue(),
                           ^{
                               block(nil, nil);
                           }
                           );
            return;
        }
        
        NSManagedObjectContext *moc = [self->APIDataManager managedObjectContextForConcurrent];
        
        NSMutableDictionary *conStationsForLine = [[NSMutableDictionary alloc] init];  // key: 接続路線　value: 乗車駅のArray(バスの場合は複数になりうる）
        NSMutableArray *cons_orig_idents = [[NSMutableArray alloc] init];   // 対象の接続路線のリスト
        
        NSMutableSet *conStationsSet = [[NSMutableSet alloc] init];  // 接続路線の乗車駅のセット（重複しない）
        NSMutableDictionary *conLinesForStation = [[NSMutableDictionary alloc] init];  // key: 乗車駅 value: 乗車路線のArray
        
        [moc performBlockAndWait:^{
            NSManagedObject *obj = [moc objectWithID:moID];
            // ここでは station entity のオブジェクトが返ってくる。
            
            NSSet *set = [obj valueForKey:@"connectingLines"];
            
            
            NSArray *cons_orig = [set allObjects];
            for(int i=0; i<[cons_orig count]; i++){
                NSManagedObject *cObj = [cons_orig objectAtIndex:i]; // connectingLine entity のオブジェクト
                
                NSString *cLineIdentifier = [cObj valueForKey:@"identifier"];
                
                if([cLineIdentifier hasPrefix:@"odpt.Railway"] == YES){
                    if(loadRailway == NO){
                        continue;
                    }
                }else if([cLineIdentifier hasPrefix:@"odpt.BusroutePattern"] == YES){
                    if(loadBus == NO){
                        continue;
                    }
                }
                
                [cons_orig_idents addObject:cLineIdentifier];
                NSString *cStationIdentifier = [cObj valueForKey:@"atStation"];
                [conStationsSet addObject:cStationIdentifier];
                
                NSArray *ary2 = [conLinesForStation objectForKey:cStationIdentifier];
                if(ary2 != nil){
                    [conLinesForStation setObject:[ary2 arrayByAddingObject:cLineIdentifier]
                                           forKey:cStationIdentifier];
                }else{
                    [conLinesForStation setObject:@[cLineIdentifier]
                                           forKey:cStationIdentifier];
                }
                
                
                NSArray *ary = [conStationsForLine objectForKey:cLineIdentifier];
                if(ary != nil){
                    [conStationsForLine setObject:[ary arrayByAddingObject:cStationIdentifier]
                                           forKey:cLineIdentifier];
                }else{
                    [conStationsForLine setObject:@[cStationIdentifier]
                                           forKey:cLineIdentifier];
                }
            }
        }];
        
        if([cons_orig_idents count] == 0){
            
            // メインスレッドで実行。
            dispatch_async(
                           dispatch_get_main_queue(),
                           ^{
                               block(@[], @[]);
                               
                           }
                           );
            return;
        }
        
        // connectingLines エンティティのオブジェクトを Line オブジェクトに変換する。
        
        NSMutableArray *loaders = [[NSMutableArray alloc] init];
        for(int i=0; i<[cons_orig_idents count]; i++){
            NSString *cLineIdentifier = [cons_orig_idents objectAtIndex:i];
            
            ODPTDataLoaderLine *l = [[ODPTDataLoaderLine alloc] initWithLine:cLineIdentifier Block:nil];
            l.dataProvider = self->dataProvider;
            l.dataManager = self->APIDataManager;
            [loaders addObject:l];
        }
        
        __block ODPTDataLoaderArray *job2 = [[ODPTDataLoaderArray alloc] initWithLoaders:loaders Block:^(NSArray<NSManagedObjectID *> *moIDArray) {
            
            NSMutableArray *right = [[NSMutableArray alloc] init];  // 重複させない
            NSMutableArray *left = [[NSMutableArray alloc] init];
            
            [moc performBlockAndWait:^{
                
                NSMutableDictionary *conLineObjects = [[NSMutableDictionary alloc] init];
                for(int i=0; i<[moIDArray count]; i++){
                    NSManagedObjectID *moID = [moIDArray objectAtIndex:i];
                    NSManagedObject *lineObject = [moc objectWithID:moID];
                    NSString *conLineIdent = [lineObject valueForKey:@"identifier"];
                    [conLineObjects setObject:lineObject forKey:conLineIdent];
                }
                
                // 駅を並び替え
                NSMutableArray *conStationsArray = [[[conStationsSet allObjects] sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
                    
                    NSString *str1 = obj1;
                    NSString *str2 = obj2;
                    
                    NSStringCompareOptions compareOptions = (NSCaseInsensitiveSearch);
                    
                    return [str1 compare:str2 options:compareOptions];
                    
                }] mutableCopy];
                
                // 直通路線がある場合、異なる路線の複数の駅を統合する。
                
                for(int i=0; i<[conStationsArray count]; i++){
                    NSString *conStation = conStationsArray[i];
                    if([conStation isKindOfClass:[NSString class]] == NO){
                        continue;
                    }
                    
                    // NSMutableArray *sLeft = [[NSMutableArray alloc] init];
                    // NSMutableArray *sRight = [[NSMutableArray alloc] init];
                    NSMutableOrderedSet *sLeft = [[NSMutableOrderedSet alloc] init];
                    NSMutableOrderedSet *sRight = [[NSMutableOrderedSet alloc] init];
                    
                    [left addObject:sLeft];
                    [right addObject:sRight];
                    
                    NSArray *conLines = [conLinesForStation objectForKey:conStation];
                    for(int j=0; j<[conLines count]; j++){
                        NSString *conLineIdent = conLines[j];
                        NSManagedObject *conLineObject = [conLineObjects objectForKey:conLineIdent];
                        /*
                         NSString *familyIdent = [conLineObject valueForKey:@"familyIdentifier"];
                         if([familyIdent isKindOfClass:[NSString class]]){
                         if([familyIdent length] > 0){
                         [familyIdentForLine setObject:familyIdent forKey:conLineIdent];
                         }
                         }
                         */
                        
                        NSMutableArray *revLines = [[NSMutableArray alloc] init];
                        
                        // conLineIdent/Object の逆方向路線で、この駅で直通する路線がないか、を確認。 基本的にはrailway のみ。
                        // 見つけた直通路線は　revLines に格納。
                        NSManagedObject *revLineObject = [conLineObject valueForKey:@"reverseDirectionLine"];
                        if(revLineObject != nil){
                            NSArray *dconLinesArray = [job directConnectingLinesForLineObject:revLineObject];
                            
                            if([dconLinesArray count] > 0){
                                for(int p=0; p<[dconLinesArray count]; p++){
                                    NSDictionary *d = dconLinesArray[p];
                                    
                                    NSString *dconStation = d[@"station"];
                                    if( [[ODPTDataAdditional sharedData] isConnectStation:dconStation andStation:conStation] == NO){
                                        continue;
                                    }
                                    
                                    NSManagedObject *dconLineObj = d[@"directConnectingToLine"];
                                    NSString *dconStationIdent = [job connectStationOfLine:dconLineObj forStationIdentifier:conStation];
                                    if(dconStationIdent == nil){
                                        continue;
                                    }
                                    
                                    NSString *dconLineIdent = [dconLineObj valueForKey:@"identifier"];
                                    NSDictionary *dict = @{@"connectingLine":dconLineIdent, @"connectingStation":dconStationIdent};
                                    
                                    [revLines addObject:dict];
                                }
                            }
                        }
                        
                        // revLinesの路線が、これから処理する他の路線に含まれていないか、探す。
                        // conStationArray から 探す。見つけた場合は stationごと削除。
                        for(int k=0; k<[revLines count]; k++){
                            NSDictionary *d = revLines[k];
                            NSString *dconLineIdent = [d valueForKey:@"connectingLine"];
                            NSArray *tcss = [conStationsForLine objectForKey:dconLineIdent];
                            
                            for(int p=0; p<[tcss count]; p++){
                                NSUInteger index = [ conStationsArray indexOfObject:tcss[p]];
                                if(index != NSNotFound){
                                    [conStationsArray replaceObjectAtIndex:index withObject:[NSNull null]];
                                }
                                
                            }
                        }
                        
                        // revLinesの路線が、これまでに処理した他の路線に含まれていないか、探す。
                        // left / right から探す。
                        
                        NSMutableOrderedSet *shouldBeAddSet = nil;  // 見つけた場合に、この路線を追加すべきArrayを返す。
                        
                        for(int k=0; k<[revLines count]; k++){
                            NSDictionary *d = revLines[k];
                            NSString *dconLineIdent = [d valueForKey:@"connectingLine"];
                            
                            for(int q=0; q<[left count]; q++){
                                NSMutableOrderedSet *set = left[q];
                                for(int r=0; r<[set count]; r++){
                                    NSDictionary *d = [set objectAtIndex:r];
                                    NSString *cline = d[@"connectingLine"];
                                    
                                    if([dconLineIdent isEqualToString:cline] == YES){
                                        shouldBeAddSet = right[q];
                                        // alreadyExistRevLine = YES;
                                        // isRevLineLeft = YES;
                                        break;
                                    }
                                }
                            }
                            
                            if(shouldBeAddSet != nil){
                                break;
                            }
                            
                            for(int q=0; q<[right count]; q++){
                                NSMutableOrderedSet *set = right[q];
                                for(int r=0; r<[set count]; r++){
                                    NSDictionary *d = [set objectAtIndex:r];
                                    NSString *conLine = d[@"connectingLine"];
                                    
                                    if([dconLineIdent isEqualToString:conLine] == YES){
                                        shouldBeAddSet = left[q];
                                        //alreadyExistRevLine = YES;
                                        //isRevLineLeft = NO;
                                        break;
                                    }
                                }
                            }
                            
                        }
                        
                        NSDictionary *dict = @{@"connectingLine":conLineIdent, @"connectingStation":conStation};
                        
                        if(shouldBeAddSet != nil){
                            [shouldBeAddSet addObject:dict];
                            
                        }else{
                            NSInteger direction = [job2 directionNumberForLineIdentifier:conLineIdent];
                            
                            if(direction == 1){
                                [sLeft addObject:dict];
                                [sRight addObjectsFromArray:revLines];
                            }else if(direction == 2){
                                [sRight addObject:dict];
                                [sLeft addObjectsFromArray:revLines];
                            }else{
                                [sLeft addObject:dict];
                                [sRight addObjectsFromArray:revLines];
                            }
                        }
                    }
                    
                }
            }];
            
            // NSMutableOrderedSet を NSArrayに変換
            NSMutableArray *fLeft = [[NSMutableArray alloc] init];
            NSMutableArray *fRight = [[NSMutableArray alloc] init];
            for(int i=0; i<[left count]; i++){
                NSMutableOrderedSet *setLeft = left[i];
                [fLeft addObject:[setLeft array]];
                
                NSMutableOrderedSet *setRight = right[i];
                [fRight addObject:[setRight array]];
            }
            
            
            // メインスレッドで実行。
            dispatch_async(
                           dispatch_get_main_queue(),
                           ^{
                               block([fLeft copy], [fRight copy]);
                               
                           }
                           );
            
        }];
        
        job2.dataProvider = self->dataProvider;
        job2.dataManager = self->APIDataManager;
        [job2 setParent:job];
        
        [self->queue addLoader:job2];
    }];
    
    job.dataProvider = dataProvider;
    job.dataManager = APIDataManager;
    [job setOwner:owner];
    
    [self->queue addLoader:job];
    
}




- (void)requestWithOwner:(id _Nullable)owner LineEndPointForIdentifier:(NSString *)identifierOriginal Block:(void (^)(NSString * _Nullable))block{
    
    __block ODPTDataLoaderLine *job;
    job = [[ODPTDataLoaderLine alloc] initWithLine:identifierOriginal Block:^(NSManagedObjectID *moID) {
        
        if(moID == nil){
            // APIアクセスに失敗。
            NSLog(@"ODPTDataLoaderLine return nil. ident:%@", identifierOriginal);
            // メインスレッドで実行。
            dispatch_async(
                           dispatch_get_main_queue(),
                           ^{
                               block(nil);
                           }
                           );
            return;
        }
        
        NSManagedObjectContext *moc = [self->APIDataManager managedObjectContextForConcurrent];
        
        __block NSString *endStationIdentifier;
        
        [moc performBlockAndWait:^{
            NSManagedObject *obj = [moc objectWithID:moID];
            NSManagedObject *endStationObj = [job endStationForLineObject:obj];
            
            endStationIdentifier = [endStationObj valueForKey:@"identifier"];
        }];
        
        __block ODPTDataLoaderStation *job2 = [[ODPTDataLoaderStation alloc] initWithStation:endStationIdentifier Block:^(NSManagedObjectID *moID) {
            
            if(moID == nil){
                // APIアクセスに失敗。
                NSLog(@"ODPTDataLoaderStation return nil. ident:%@", endStationIdentifier);
                // メインスレッドで実行。
                dispatch_async(
                               dispatch_get_main_queue(),
                               ^{
                                   block(nil);
                               }
                               );
                return;
            }
            
            NSManagedObjectContext *moc = [self->APIDataManager managedObjectContextForConcurrent];
            
            __block NSString *endStationTitle;
            [moc performBlockAndWait:^{
                NSManagedObject *obj = [moc objectWithID:moID];
                
                endStationTitle = [job2 stationTitleForStationObject:obj];
            }];
            
            
            // メインスレッドで実行。
            dispatch_async(
                           dispatch_get_main_queue(),
                           ^{
                               // NSLog(@"endpoint: %@ ident:%@", title, endStationIdentifier);
                               block(endStationTitle);
                           });
        }];
        
        job2.dataProvider = self->dataProvider;
        job2.dataManager = self->APIDataManager;
        [job2 setParent:job];
        [self->queue addLoader:job2];
    }];
    
    job.dataProvider = dataProvider;
    job.dataManager = APIDataManager;
    [self->queue addLoader:job];
    [job setOwner:owner];
}

// ある路線・駅における直通・分岐路線とそのうち、現在Activeな路線のインデックスを返す
- (void)requestWithOwner:(id _Nullable)owner BranchLinesForStation:(NSString *)StationIdentifier forLine:(NSString *)LineIdentifier withBranchData:(NSArray * _Nullable)branchData Block:(void (^)(NSArray * _Nullable, NSInteger))block{
    
    __block ODPTDataLoaderLine *job;
    job = [[ODPTDataLoaderLine alloc] initWithLine:LineIdentifier Block:^(NSManagedObjectID *moID) {
        
        if(moID == nil){
            // APIアクセスに失敗。
            NSLog(@"ODPTDataLoaderLine return nil. ident:%@", LineIdentifier);
            // メインスレッドで実行。
            dispatch_async(
                           dispatch_get_main_queue(),
                           ^{
                               block(nil, -1);
                           }
                           );
            return;
        }
        
        NSManagedObjectContext *moc = [self->APIDataManager managedObjectContextForConcurrent];
        
        __block NSMutableArray *dconLines = [[NSMutableArray alloc] init];
        
        __block BOOL needForAccessUserData = YES;
        
        __block NSInteger selectedLineIndex = -1;
        
        [moc performBlockAndWait:^{
            NSManagedObject *lineObj = [moc objectWithID:moID];
            
            NSArray *dLines = [job directConnectingLinesForLineObject:lineObj];
            
            for(int i=0; i<[dLines count]; i++){
                NSDictionary *dict = dLines[i];
                
                if(! [StationIdentifier isEqualToString:dict[@"station"]] ){
                    continue;
                }
                
                NSManagedObject *obj = dict[@"directConnectingToLine"];  // obj は Line エンティティのオブジェクト
                
                NSString *conStation = [job connectStationOfLine:obj forStationIdentifier:StationIdentifier];
                NSDictionary *d = @{@"identifier":[obj valueForKey:@"identifier"], @"connectingStation":conStation};
                
                [dconLines addObject:d];
            }
            
            if([dconLines count] == 0){
                // 直通・分岐路線はない。
                needForAccessUserData = NO;
                
            }else if([dconLines count] > 0){
                
                // 直通路線があり、かつ終端駅でなければ、元の路線も追加。
                NSArray *stations = [job stationArrayForLineObject:lineObj];
                
                NSManagedObject *endStation = [stations lastObject];
                NSString *endStationIdent = [endStation valueForKey:@"identifier"];
                
                if([endStationIdent isEqualToString:StationIdentifier] == NO){
                    NSDictionary *d = @{@"identifier":LineIdentifier, @"connectingStation":StationIdentifier};
                    [dconLines addObject:d];
                }else{
                    // 終着駅である。
                    if([dconLines count] == 1){
                        // 直通路線が一つで、終着駅である。 -> 分岐はない。
                        selectedLineIndex = 0;
                        needForAccessUserData = NO;
                    }else{
                        // 直通路線が複数あり、終着駅である。
                        
                    }
                    
                }
            }
            
        }];
        
        if(needForAccessUserData == YES){
            // ユーザーデータへアクセス。
            NSDictionary *dict = [self branchOfLine:LineIdentifier atStation:StationIdentifier withBranchArray:branchData];
            NSString *selectedLine = [dict objectForKey:@"selectedLine"];
            
            for(int j=0; j<[dconLines count]; j++){
                NSDictionary *d = dconLines[j];
                if([selectedLine isEqualToString:d[@"identifier"]] == YES){
                    selectedLineIndex = j;
                    break;
                }
            }
            
            if(selectedLineIndex == -1){
                // まだユーザーデータに登録していない LineIdent/branchStationIdentの場合、branchOfLineは selectedLineとしてLineIdnetを返すときなど。
                selectedLineIndex = 0;
            }
        }
        
        if([dconLines count] > 0){
            NSAssert(selectedLineIndex >= 0, @"BranchLinesForStation:ForLine: selectedLineIndex is invalid.");
        }
        
        // メインスレッドで実行。
        dispatch_async(
                       dispatch_get_main_queue(),
                       ^{
                           block(dconLines, selectedLineIndex);
                       }
                       );
    }];
    
    job.dataProvider = dataProvider;
    job.dataManager = APIDataManager;
    [job setOwner:owner];
    
    [self->queue addLoader:job];
    
}

// 未使用
- (void)requestWithOwner:(id _Nullable)owner DirectConnectingLinesForStation:(NSString *)StationIdentifier OfLine:(NSString *)LineIdentifier Block:(void (^)(NSArray * _Nullable))block{
    
    
    __block ODPTDataLoaderLine *job;
    job = [[ODPTDataLoaderLine alloc] initWithLine:LineIdentifier Block:^(NSManagedObjectID *moID) {
        
        if(moID == nil){
            // APIアクセスに失敗。
            NSLog(@"ODPTDataLoaderLine return nil. ident:%@", LineIdentifier);
            // メインスレッドで実行。
            dispatch_async(
                           dispatch_get_main_queue(),
                           ^{
                               block(nil);
                           }
                           );
            return;
        }
        
        NSManagedObjectContext *moc = [self->APIDataManager managedObjectContextForConcurrent];
        
        
        __block NSMutableArray *dconLines = [[NSMutableArray alloc] init];
        
        [moc performBlockAndWait:^{
            NSManagedObject *lineObj = [moc objectWithID:moID];
            
            NSArray *dLines = [job directConnectingLinesForLineObject:lineObj];
            
            for(int i=0; i<[dLines count]; i++){
                NSDictionary *dict = [dLines objectAtIndex:i];
                
                if(! [StationIdentifier isEqualToString:[dict objectForKey:@"station"]] ){
                    continue;
                }
                
                NSManagedObject *obj = [dict objectForKey:@"directConnectingToLine"];
                [dconLines addObject:[obj valueForKey:@"identifier"] ];
            }
            
            if([dconLines count] > 0){
                // 直通路線がすでにあり、かつ終端駅でなければ、元の路線も追加。
                NSArray *stations = [job stationArrayForLineObject:lineObj];
                
                NSManagedObject *endStation = [stations lastObject];
                NSString *endStationIdent = [endStation valueForKey:@"identifier"];
                
                if([endStationIdent isEqualToString:StationIdentifier] == NO){
                    [dconLines addObject:LineIdentifier];
                }
            }
            //NSLog(@"station:%@ line:%@ -> dcon:%@", StationIdentifier, LineIdentifier, dconLines);
            
        }];
        
        // メインスレッドで実行。
        dispatch_async(
                       dispatch_get_main_queue(),
                       ^{
                           block([dconLines copy]);
                       });
    }];
    
    job.dataProvider = dataProvider;
    job.dataManager = APIDataManager;
    [job setOwner:owner];
    
    [self->queue addLoader:job];
}

- (void)requestWithOwner:(id _Nullable)owner IntegratedReverseDirectionLineForLine:(NSString *)LineIdentifier atStation:(NSDictionary *)startStationDict withBranchData:(NSArray * _Nullable)branchData Block:(void (^)(NSString * _Nullable, NSDictionary * _Nullable))block{

    [self innerRequestWithOwner:owner IntegratedStationsForLine:LineIdentifier atStation:startStationDict withBranchData:branchData Block:^(NSArray *integratedStations, NSArray *integratedLines, NSArray *usedBranchData) {
        
        NSString *backLineIdentifier = nil;
        for(int i=0; i<[integratedStations count]; i++){
            if([startStationDict isEqualToDictionary:integratedStations[i]] == YES){
                backLineIdentifier = integratedLines[i];
                break;
            }
        }
        
        NSAssert(backLineIdentifier != nil, @"integratedReverseDirectionLine cannot found station. %@", startStationDict[@"identifier"]);
        
        if([backLineIdentifier isEqualToString:@""] == YES){
           
            // メインスレッドで実行。
            dispatch_async(
                           dispatch_get_main_queue(),
                           ^{
                               block(nil, nil);
                           }
                           );
            return;
        }
        
        __block ODPTDataLoaderLine *job;
        job = [[ODPTDataLoaderLine alloc] initWithLine:backLineIdentifier Block:^(NSManagedObjectID *moID) {
            
            if(moID == nil){
                // APIアクセスに失敗。
                NSLog(@"ODPTDataLoaderLine return nil. ident:%@", backLineIdentifier);
                
                // メインスレッドで実行。
                dispatch_async(
                               dispatch_get_main_queue(),
                               ^{
                                   block(nil, nil);
                               });
                
                return;
            }
            
            NSManagedObjectContext *moc = [self->APIDataManager managedObjectContextForConcurrent];
            
            __block NSString *reverseDirectionLine = nil;
            __block NSDictionary *reverseStartStation = nil;;
            
            [moc performBlockAndWait:^{
                NSManagedObject *obj = [moc objectWithID:moID];
                
                NSManagedObject *reverseObj = [obj valueForKey:@"reverseDirectionLine"];
                
                if(reverseObj != nil){
                    reverseDirectionLine = [reverseObj valueForKey:@"identifier"];
                
                    NSString *reverseStartStationIdent = [job connectStationOfLine:reverseObj forStationIdentifier:startStationDict[@"identifier"]];
                    reverseStartStation = @{@"identifier":reverseStartStationIdent, @"duplication":startStationDict[@"duplication"] };
                }                    
                
            }];
            
            // メインスレッドで実行。
            dispatch_async(
                           dispatch_get_main_queue(),
                           ^{
                               block(reverseDirectionLine, reverseStartStation);
                           }
                           );
            
        }];
        
        job.dataProvider = self->dataProvider;
        job.dataManager = self->APIDataManager;
        [job setOwner:owner];
        
        [self->queue addLoader:job];
    }];
    
}

- (void)requestWithOwner:(id _Nullable)owner ReverseDirectionLineForLine:(NSString *)LineIdentifier Block:(void (^)(NSString * _Nullable))block{
    
    [self innerRequestWithOwner:owner ReverseDirectionLineForLine:LineIdentifier Block:^(NSString *reverseDirectionLine) {
        
        // メインスレッドで実行。
        dispatch_async(
                       dispatch_get_main_queue(),
                       ^{
                           block(reverseDirectionLine);
                       });
    }];
}

- (void)innerRequestWithOwner:(id _Nullable)owner ReverseDirectionLineForLine:(NSString *)LineIdentifier Block:(void (^)(NSString * _Nullable))block{
    
    __block ODPTDataLoaderLine *job;
    job = [[ODPTDataLoaderLine alloc] initWithLine:LineIdentifier Block:^(NSManagedObjectID *moID) {
        
        if(moID == nil){
            // APIアクセスに失敗。
            NSLog(@"ODPTDataLoaderLine return nil. ident:%@", LineIdentifier);
            
            block(nil);

            return;
        }
        
        NSManagedObjectContext *moc = [self->APIDataManager managedObjectContextForConcurrent];
        
        
        __block NSString *reverseDirectionLine;
        
        [moc performBlockAndWait:^{
            NSManagedObject *obj = [moc objectWithID:moID];
            
            NSManagedObject *reverseObj = [obj valueForKey:@"reverseDirectionLine"];
            
            reverseDirectionLine = [reverseObj valueForKey:@"identifier"];
            
        }];
        
        block(reverseDirectionLine);
        
    }];
    
    job.dataProvider = dataProvider;
    job.dataManager = APIDataManager;
    [job setOwner:owner];
    
    [self->queue addLoader:job];
}

- (void)requestWithOwner:(id _Nullable)owner StationInformationForIdentifier:(NSString *)StationIdentifier Block:(void (^)(NSDictionary * _Nullable))block{
    
    __block ODPTDataLoaderStation *job = [[ODPTDataLoaderStation alloc] initWithStation:StationIdentifier Block:^(NSManagedObjectID *moID) {
        
        if(moID == nil){
            // APIアクセスに失敗。
            // メインスレッドで実行。
            dispatch_async(
                           dispatch_get_main_queue(),
                           ^{
                               block(nil);
                           }
                           );
            return;
        }
        
        NSManagedObjectContext *moc = [self->APIDataManager managedObjectContextForConcurrent];
        
        __block NSMutableDictionary *dict = nil;
        
        __block NSArray *operators = nil;
        [moc performBlockAndWait:^{
            NSManagedObject *stationObj = [moc objectWithID:moID]; // station Entity object.
            dict = [NSMutableDictionary dictionaryWithDictionary:[job dictionaryForStation:stationObj]];
            
            for(NSString *key in [dict allKeys]){
                NSString *val = dict[key];
                if([val isKindOfClass:[NSNull class]] == YES){
                    [dict removeObjectForKey:key];
                }
            }
            
            NSString *title = [job stationTitleForStationObject:stationObj];
            [dict setObject:title forKey:@"title"];
            
            operators = dict[@"operator"];
        }];
        
        NSMutableArray *loaders = [[NSMutableArray alloc] init];
        
        for(int i=0; i<[operators count]; i++){
            NSString *operatorIdent = operators[i];
            ODPTDataLoaderOperator *j = [[ODPTDataLoaderOperator alloc] initWithOperator:operatorIdent Block:nil];
            
            j.dataProvider = self->dataProvider;
            j.dataManager = self->APIDataManager;
            
            [loaders addObject:j];
        }
        
        __block ODPTDataLoaderArray *job2 = [[ODPTDataLoaderArray alloc] initWithLoaders:loaders Block:^(NSArray<NSManagedObjectID *> *ary) {
            
            NSMutableArray *operatorNames = [[NSMutableArray alloc] init];
            [moc performBlockAndWait:^{
                for(int i=0; i<[ary count]; i++){
                    
                    NSManagedObjectID *moID = ary[i];
                    NSManagedObject *operatorObject = [moc objectWithID:moID]; // operator Entity object.
                    
                    NSString *locale = [[NSLocale preferredLanguages] objectAtIndex:0];
                    
                    NSString *title = nil;
                    NSString *key = @"title_en";
                    if([locale hasPrefix:@"ja"] == YES){
                        key = @"title_ja";
                    }
                    title = [operatorObject valueForKey:key];
                    
                    if([title isKindOfClass:[NSString class]] == NO){
                        title = [operatorObject valueForKey:@"identifier"];
                    }
                    
                    [operatorNames addObject:title];
                }
            }];
            
            [dict setObject:[operatorNames copy] forKey:@"operator"];
            
            // メインスレッドで実行。
            dispatch_async(
                           dispatch_get_main_queue(),
                           ^{
                               block([dict copy]);
                           });
            
        }];
        
        job2.dataProvider = self->dataProvider;
        job2.dataManager = self->APIDataManager;
        [job2 setParent:job];
        
        [self->queue addLoader:job2];
    }];
    
    
    job.dataProvider = dataProvider;
    job.dataManager = APIDataManager;
    [job setOwner:owner];
    
    [self->queue addLoader:job];
}



- (BOOL)isConnectStation:(NSString *)stationA andStation:(NSString *)stationB{
    return [[ODPTDataAdditional sharedData] isConnectStation:stationA andStation:stationB];
}

- (void)requestWithOwner:(id _Nullable)owner DirectConnectingLinesForLine:(NSString *)LineIdent Block:(void (^)(NSDictionary * _Nullable))block{
    // 指定した路線に直通するすべての路線を得る。　再帰処理。
    
    __block ODPTDataLoaderLine *job;
    
    __block NSMutableDictionary *dconDictionary = [[NSMutableDictionary alloc] init];
    
    // 再帰呼び出しされるメソッド
    __block void (^recursive)(NSManagedObject *) = ^(NSManagedObject *lineObj) {
        // 下記 ODPTDataLoaderLine において、直通路線は再帰的にすべてAPIから取得する。
        //NSLog(@"requestDirectConnectingLinesForLine recursive start lineObj: %@", [lineObj valueForKey:@"identifier"]);
        
        NSMutableArray *recursiveObjs = [[NSMutableArray alloc] init];
        NSArray *dLines = [job directConnectingLinesForLineObject:lineObj];
        // NSLog(@"requestDirectConnectingLinesForLine Line:%@", [lineObj valueForKey:@"identifier"]);
        NSMutableArray *dconLines = [[NSMutableArray alloc] init];
        for(int i=0; i<[dLines count]; i++){
            NSDictionary *dict = [dLines objectAtIndex:i];
            
            NSManagedObject *obj = [dict objectForKey:@"directConnectingToLine"];  // Line エンティティのオブジェクト
            NSString *connectingStationIdent = [dict objectForKey:@"station"];
            
            NSString *directConnectingLineIdent = [obj valueForKey:@"identifier"];
            // NSLog(@"  dconLine:%@", directConnectingLineIdent);
            
            NSMutableDictionary *entry = [[NSMutableDictionary alloc] init];
            [entry setObject:directConnectingLineIdent forKey:@"directConnectingLine"];
            [entry setObject:connectingStationIdent forKey:@"connectingStation"];
            
            // 路線の途中駅からの分岐の場合、　isBranch は YES
            // 路線の終着駅からの直通の場合、 isBranch は NO
            NSArray *stationArray = [job stationArrayForLineObject:lineObj];
            NSManagedObject *lastStationObj = [stationArray lastObject];
            if([[lastStationObj valueForKey:@"identifier"] isEqualToString:connectingStationIdent] == NO){
                [entry setObject:[NSNumber numberWithBool:YES] forKey:@"isBranch"];
            }
            
            [dconLines addObject:entry];
            
            [recursiveObjs addObject:obj];
        }
        
        [dconDictionary setObject:[dconLines copy] forKey:[lineObj valueForKey:@"identifier"]];
        
        for(int i=0; i<[recursiveObjs count]; i++){
            NSManagedObject *rObj = [recursiveObjs objectAtIndex:i];
            if([dconDictionary objectForKey:[rObj valueForKey:@"identifier"]] == nil){
                recursive(rObj);
            }
        }
        
    };
    
    
    job = [[ODPTDataLoaderLine alloc] initWithLine:LineIdent Block:^(NSManagedObjectID *moID) {
        
        NSManagedObjectContext *moc = [self->APIDataManager managedObjectContextForConcurrent];
        // __block NSString *reverseLineIdent;
        
        [moc performBlockAndWait:^{
            if(moID == nil){
                // APIアクセスに失敗。
                NSLog(@"ODPTDataLoaderLine return nil. ident");
                // メインスレッドで実行。
                dispatch_async(
                               dispatch_get_main_queue(),
                               ^{
                                   //block(nil, nil);
                                   block(nil);
                               }
                               );
                return;
            }
            
            NSManagedObject *obj = [moc objectWithID:moID];
            
            recursive(obj);
            
            // メインスレッドで実行。
            dispatch_async(
                           dispatch_get_main_queue(),
                           ^{
                               //block([retDconLines copy], [retDconStations copy]);
                               block([dconDictionary copy]);
                           });
            
        }];
        
    }];
    
    job.dataProvider = dataProvider;
    job.dataManager = APIDataManager;
    [job setOwner:owner];
    
    [self->queue addLoader:job];
}

- (BOOL)isAccessibleLine:(NSString *)lineIdentifier{
    return [[ODPTDataAdditional sharedData] isAbleToAccessAPIOfRailway:lineIdentifier];
}

- (BOOL)isSameStation:(NSDictionary * _Nullable)dictA withStation:(NSDictionary * _Nullable)dictB{
    // NSAssert(dictA != nil && dictB != nil, @"isSameStation given nil. a:%@ b:%@", dictA, dictB);
    if(dictA == nil || dictB == nil){
        return NO;
    }
    
    if([dictA[@"duplication"] isKindOfClass:[NSNumber class]] == NO ||
       [dictB[@"duplication"] isKindOfClass:[NSNumber class]] == NO ){
        NSLog(@"xx");
    }
    
    if([dictA[@"identifier"] isEqualToString:dictB[@"identifier"]] == YES){
        if([dictA[@"duplication"] isEqualToNumber:dictB[@"duplication"]] == YES){
            return YES;
        }
    }
    
    return NO;
}

// 未使用
/*
 - (void)requestWithOwner:(id _Nullable)owner ConnectingStationsForLineArray:(NSArray<NSString *> *)lineIdentifiers forStation:(NSString *)stationIdentifier Block:(void (^)(NSArray<NSString *>*))block{
 
 ODPTDataLoaderConnectingLines *job;
 job = [[ODPTDataLoaderConnectingLines alloc] initWithStaion:stationIdentifier Block:^(NSManagedObjectID *moID) {
 
 if(moID == nil){
 // APIアクセスに失敗。
 NSLog(@"ODPTDataLoaderConnectingLines return nil. ident:%@", stationIdentifier);
 // メインスレッドで実行。
 dispatch_async(
 dispatch_get_main_queue(),
 ^{
 block(nil);
 }
 );
 return;
 }
 
 NSManagedObjectContext *moc = [self->APIDataManager managedObjectContextForConcurrent];
 
 __block NSMutableArray *retIdents = [[NSMutableArray alloc] init];
 
 [moc performBlockAndWait:^{
 NSManagedObject *mo = [moc objectWithID:moID];
 NSSet *set = [mo valueForKey:@"connectingLines"];
 NSArray *connectingLines = [set allObjects];
 
 //for(int i=0; i<[connectingLines count]; i++){
 //    NSManagedObject *conLineObj = connectingLines[i];
 //    NSString *conLineIdent = [conLineObj valueForKey:@"identifier"];
 //    NSString *stationIdent = [conLineObj valueForKey:@"atStation"];
 //    NSLog(@" conObj %@ %@", conLineIdent, stationIdent);
 //}
 
 for(int j=0; j<[lineIdentifiers count]; j++){
 NSString *lineIdent = lineIdentifiers[j];
 
 NSString *retIdent = nil;
 for(int i=0; i<[connectingLines count]; i++){
 NSManagedObject *conLineObj = connectingLines[i];
 // TODO: 複数のconLineObjで、同じ identifier、異なる atStationを持つ場合がある。
 
 NSString *conLineIdent = [conLineObj valueForKey:@"identifier"];
 if([conLineIdent isEqualToString:lineIdent] == YES){
 retIdent = [conLineObj valueForKey:@"atStation"];
 break;
 }
 }
 if(retIdent == nil){
 NSLog(@"ConnectingStationsForLineArray not found station for %@", lineIdent);
 [retIdents addObject:[NSNull null]];
 }else{
 [retIdents addObject:retIdent];
 }
 }
 }];
 // メインスレッドで実行。
 dispatch_async(
 dispatch_get_main_queue(),
 ^{
 block([retIdents copy]);
 }
 );
 return;
 
 }];
 job.dataProvider = dataProvider;
 job.dataManager = APIDataManager;
 [job setOwner:owner];
 
 [self->queue addLoader:job];
 
 }
 */

@end

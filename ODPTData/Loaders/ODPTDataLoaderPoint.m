//
//  ODPTDataLoaderPoint.m
//
//  Copyright (c) 2018 Takehito Ikema
//
//  This software is released under the MIT License.
//  https://opensource.org/licenses/mit-license.php
//

#import "ODPTDataLoaderPoint.h"
#import "ODPTDataLoaderArray.h"
#import "ODPTDataLoaderStation.h"
#import "ODPTDataLoaderLine.h"

NSString *const ODPTDataLoaderPointOptionsNeedToLoadRailway = @"needToLoadRailway";
NSString *const ODPTDataLoaderPointOptionsNeedToLoadBusRoutePattern = @"needToLoadBusRoutePattern";
NSString *const ODPTDataLoaderPointOptionsSearchRadius = @"searchRadius";

@implementation ODPTDataLoaderPoint{
    
    NSManagedObjectID *retID;
    CLLocationCoordinate2D point;
    
    BOOL needToLoadRailway;
    BOOL needToLoadBusRoutePattern;
    int searchRadius;
    
}

- (id)init{
    
    NSAssert(YES, @"ODPTDataLoaderPoint must not use init message.");
    
    return nil;
}

- (id) initWithLocation:(CLLocationCoordinate2D)p withOptions:(NSDictionary *)option Block:(void (^)(NSManagedObjectID *))block{
    if(self = [super init]){
        point = p;
        
        needToLoadRailway = YES;
        needToLoadBusRoutePattern = YES;
        searchRadius = 500;
        
        NSNumber *nlr = option[ODPTDataLoaderPointOptionsNeedToLoadRailway];
        if([nlr isKindOfClass:[NSNumber class]] == YES){
            needToLoadRailway = [nlr boolValue];
        }
        
        NSNumber *nlb = option[ODPTDataLoaderPointOptionsNeedToLoadBusRoutePattern];
        if([nlb isKindOfClass:[NSNumber class]] == YES){
            needToLoadBusRoutePattern = [nlb boolValue];
        }
        
        NSNumber *sr = option[ODPTDataLoaderPointOptionsSearchRadius];
        if([sr isKindOfClass:[NSNumber class]] == YES){
            if([sr intValue] > 1 && [sr intValue] < 2000){
                searchRadius = [sr intValue];
            }
        }
        
        self.callback = [block copy]; // IMPORTANT
    }
    
    return self;
}



- (BOOL)isCompleteObject:(NSManagedObject *)obj{
    // オブジェクトの完全性を確認. // performBlock 内から呼び出すこと
    NSDate *date = [obj valueForKey:@"fetchDate"];
    if(date == nil){
        return NO;
    }
    
    // 記録されている探索半径と、本Loaderにセットされた探索半径が異なれば、リセット。
    NSNumber *searchR = [obj valueForKey:@"searchRadius"];
    if([searchR intValue] != self->searchRadius){
        return NO;
    }
    
    // 本Loaderによって求められている情報を、既存のobjは含んでいるか。
    BOOL cr = [[obj valueForKey:@"isContainRailway"] boolValue];
    BOOL cb = [[obj valueForKey:@"isContainBus"] boolValue];
    
    if(needToLoadRailway != cr){
        return NO;
    }
    
    if(needToLoadBusRoutePattern != cb){
        return NO;
    }
    
    return YES;
    
}

- (void) makeObjectOfPoint:(CLLocationCoordinate2D)point ForArray:(NSArray *)array Block:(void (^)(NSManagedObjectID *))block {
    
    NSMutableArray *stationIdents = [[NSMutableArray alloc] init];
    
    NSMutableSet *lineSet = [[NSMutableSet alloc] init];
    for(int i=0; i<[array count]; i++){
        
        NSDictionary *dict = [array objectAtIndex:i];
        
        NSString *stationIdent = [dict objectForKey:@"owl:sameAs"];
        [stationIdents addObject:stationIdent];

        id lineIdentObj = [dict objectForKey:@"odpt:railway"];
        
        if(lineIdentObj == nil){
            lineIdentObj = [dict objectForKey:@"odpt:busroutePattern"];
            if(lineIdentObj != nil){
                // lineIdentObj は busroutePattern
                if(self->needToLoadBusRoutePattern == NO){
                    continue;
                }
            }
            
        }else{
            // lineIdentObj は railway.
            if(self->needToLoadRailway == NO){
                continue;
            }
        }
        
        if(lineIdentObj != nil){
            if([lineIdentObj isKindOfClass:[NSArray class]] == YES){
                for(NSString *l in lineIdentObj){
                    [lineSet addObject:l];
                }
            }else if([lineIdentObj isKindOfClass:[NSString class]] == YES){
                [lineSet addObject:lineIdentObj];
            }
        }else{
            NSLog(@"ODPTDataLoaderPoint station record without line detected. at %@", stationIdent);
        }
        

    }
    
    // まず station に対応する line をすべて取得。
    //  lineSet は重複なしの line一覧
    NSMutableArray *loaders = [[NSMutableArray alloc] init];
    for(NSString *lineIdent in [lineSet allObjects]){
        // 独自拡張
        NSArray *relatedLineIdents = [self addAllSuffixLineIdentifierExtension:lineIdent];
        
        for(NSString *rLineIdent in relatedLineIdents){
            ODPTDataLoaderLine *s = [[ODPTDataLoaderLine alloc] initWithLine:rLineIdent Block:nil];
            s.dataProvider = self.dataProvider;
            s.dataManager = self.dataManager;
            [loaders addObject:s];
        }
    }
    
    NSDictionary *option = @{ODPTDataLoaderArrayOptionsInCompleteFinish : [NSNumber numberWithBool:YES]};
    
    __block ODPTDataLoaderArray *job2 = [[ODPTDataLoaderArray alloc] initWithLoaders:loaders withOptions:option Block:^(NSArray<NSManagedObjectID *> *moIDArrayL) {
        
        // 続いて、 stationの一覧をすべて取得。
        NSMutableArray *loaders = [[NSMutableArray alloc] init];
        for(int i=0; i<[stationIdents count]; i++){
            NSString *stationIdentifier = [stationIdents objectAtIndex:i];
            
            ODPTDataLoaderStation *s = [[ODPTDataLoaderStation alloc] initWithStation:stationIdentifier Block:nil];
            s.dataProvider = self.dataProvider;
            s.dataManager = self.dataManager;
            [loaders addObject:s];
        }
        
        NSManagedObjectContext *moc = [self.dataManager managedObjectContextForConcurrent];
        
        ODPTDataLoaderArray *job = [[ODPTDataLoaderArray alloc] initWithLoaders:loaders withOptions:option Block:^(NSArray<NSManagedObjectID *> *moIDArrayS) {
            
            __block NSManagedObjectID *moID = nil;
            [moc performBlockAndWait:^{
                
                // CoreData DBから書き換えるべき object を受け取る。
                NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Point"];
                [request setPredicate:[NSPredicate predicateWithFormat:@"longitude == %lf and latitude == %lf", point.longitude, point.latitude]];
                
                NSError *error = nil;
                NSArray *results = [moc executeFetchRequest:request error:&error];
                
                if (results == nil) {
                    NSLog(@"Error fetching objects: %@\n%@", [error localizedDescription], [error userInfo]);
                    abort();
                    return;
                }
                
                NSManagedObject *pointObject = nil;
                
                if([results count] == 0){
                    abort();
                }else{
                    // レコードが存在するので、書き換える。
                    pointObject = [results objectAtIndex:0];
                }
                
                
                NSMutableArray *stationArray = [[NSMutableArray alloc] init];
                // pointからの距離を得る。
                
                NSMutableDictionary *distanceFromPoint = [[NSMutableDictionary alloc] init];
                for(int i=0; i<[moIDArrayS count]; i++){
                    NSManagedObjectID *moID = [moIDArrayS objectAtIndex:i];
                    
                    if([moID isKindOfClass:[NSManagedObjectID class] ] == NO){
                        
                        continue;
                    }
                    
                    NSManagedObject *stationObject = [moc objectWithID:moID];
                    NSString *stationIdent = [stationObject valueForKey:@"identifier"];
                    
                    CLLocationCoordinate2D toCoord = CLLocationCoordinate2DMake([[stationObject valueForKey:@"latitude"] doubleValue],
                                                                                [[stationObject valueForKey:@"longitude"] doubleValue]);
                    
                    CLLocationDistance distance = [self distanceFromPoint:self->point toPoint:toCoord];
                    [distanceFromPoint setObject:[NSNumber numberWithDouble:distance] forKey:stationIdent];
                    
                    [stationArray addObject:stationObject];
                }
                
                // 近い順に並び替え
                NSMutableArray *sortedStationArray = [[stationArray sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
                    
                    // obj1, obj2 は NSManagedObject
                    NSAssert([obj1 isKindOfClass:[NSManagedObject class]], @"requestConnectingLinesForStation error.");
                    NSAssert([obj2 isKindOfClass:[NSManagedObject class]], @"requestConnectingLinesForStation error.");
                    
                    NSString *ident1 = [obj1 valueForKey:@"identifier"];
                    NSString *ident2 = [obj2 valueForKey:@"identifier"];
                    
                    if( [[distanceFromPoint objectForKey:ident1] doubleValue] < [[distanceFromPoint objectForKey:ident2] doubleValue]){
                        return NSOrderedAscending;
                    }else{
                        return NSOrderedDescending;
                    }
                    
                }] mutableCopy];
                
                
                NSMutableSet *stationSet = [[NSMutableSet alloc] init];
                
                NSMutableArray *checkedLineIdents = [[NSMutableArray alloc] init];
                
                for(int i=0; i<[sortedStationArray count]; i++){
                    BOOL skipFlag = NO;
                    
                    NSManagedObject *stationObj = sortedStationArray[i];
                    
                    NSArray *lines = [[stationObj valueForKey:@"lines"] allObjects];
                    for(int k=0; k<[lines count]; k++){
                        NSManagedObject *lineObj = lines[k];
                        NSString *lineIdent = [lineObj valueForKey:@"identifier"];
                        if( [checkedLineIdents containsObject:lineIdent] == YES){
                            skipFlag = YES;
                            break;
                        }
                    }
                    
                    if(skipFlag == YES){
                        continue;
                    }
                    
                    [stationSet addObject:sortedStationArray[i]];
                    for(int k=0; k<[lines count]; k++){
                        NSManagedObject *lineObj = lines[k];
                        NSString *lineIdent = [lineObj valueForKey:@"identifier"];
                        [checkedLineIdents addObject:lineIdent];
                    }
                }
                
                
                [pointObject setValue:stationSet forKey:@"nearStations"];
                [pointObject setValue:[NSDate date] forKey:@"fetchDate"];
                
                [pointObject setValue:[NSNumber numberWithBool:self->needToLoadRailway] forKey:@"isContainRailway"];
                [pointObject setValue:[NSNumber numberWithBool:self->needToLoadBusRoutePattern] forKey:@"isContainBus"];
                [pointObject setValue:[NSNumber numberWithInt:self->searchRadius] forKey:@"searchRadius"];
                
                // Save the context.
                if (![moc save:&error]) {
                    // Replace this implementation with code to handle the error appropriately.
                    // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                    NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
                    abort();
                }
                // 永続保存は,別途
                
                moID = [pointObject objectID];
            }];
            
        block(moID);
            
        }];
                                                                                   
        job.dataProvider = self.dataProvider;
        job.dataManager = self.dataManager;
        [job setParent:job2];
        [[self queue] addLoader:job];
        
    }];
    
    job2.dataProvider = self.dataProvider;
    job2.dataManager = self.dataManager;
    [job2 setParent:self];
    [[self queue] addLoader:job2];
    
}


- (void)requestBy:(id)owner stationsNearPoint:(CLLocationCoordinate2D)point Block:(void (^)(NSManagedObjectID *))block{
    
    //  CoreData データベースにアクセス。
    
    __block NSManagedObjectID *moID = nil;
    
    NSManagedObjectContext *moc = [self.dataManager managedObjectContextForConcurrent];
    [moc performBlockAndWait:^{
        
        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Point"];
        [request setPredicate:[NSPredicate predicateWithFormat:@"longitude == %lf and latitude == %lf", point.longitude, point.latitude]];
        
        NSError *error = nil;
        
        NSArray *results = [moc executeFetchRequest:request error:&error];
        
        if (results == nil) {
            NSLog(@"Error fetching objects: %@\n%@", [error localizedDescription], [error userInfo]);
            abort();
        }
        
        if([results count] == 0){
            //  該当する Point の レコードがない。 -> APIへアクセス。
            // レコードが存在しないので、新たに作る。
            NSManagedObject *obj = [NSEntityDescription insertNewObjectForEntityForName:@"Point" inManagedObjectContext:moc];
            
            [obj setValue:[NSNumber numberWithDouble:point.longitude] forKey:@"longitude"];
            [obj setValue:[NSNumber numberWithDouble:point.latitude] forKey:@"latitude"];
            
            // Save the context.
            if (![moc save:&error]) {
                NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
                abort();
            }
            // 永続保存は,別途
            
        }else{
            
            NSManagedObject *obj = [results objectAtIndex:0];
            if([self isCompleteObject:obj] == YES){
                moID = [obj objectID];
            }else{
                // 掃除
                NSLog(@"ODPTDataLoaderPoint object incompleted. clean up. at %f,%f", point.latitude, point.longitude);
                [obj setValue:[NSNumber numberWithDouble:point.longitude] forKey:@"longitude"];
                [obj setValue:[NSNumber numberWithDouble:point.latitude] forKey:@"latitude"];
                [obj setValue:[[NSSet alloc] init]  forKey:@"nearStations"];
                [obj setValue:[NSNumber numberWithBool:NO] forKey:@"isContainRailway"];
                [obj setValue:[NSNumber numberWithBool:NO] forKey:@"isContainBus"];
                [obj setValue:@0 forKey:@"searchRadius"];
                
                // Save the context.
                if (![moc save:&error]) {
                    NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
                    abort();
                }
                // 永続保存は,別途
            }
        }
    }];

    
    if(moID != nil){
        block(moID);
        return;
    }
    
    // APIアクセス開始。
    
    NSString *lonStr = [NSString stringWithFormat:@"%f", point.longitude];
    NSString *latStr = [NSString stringWithFormat:@"%f", point.latitude];
    NSString *radiusStr = [NSString stringWithFormat:@"%d", searchRadius];
    
    NSMutableArray *preds = [[NSMutableArray alloc] init];
    if(needToLoadRailway == YES){
        NSDictionary *predStation = [NSDictionary dictionaryWithObjectsAndKeys:
                                     @"places/odpt:Station", @"type",
                                     latStr, @"lat",
                                     lonStr, @"lon",
                                     radiusStr, @"radius",
                                     nil];
        [preds addObject:predStation];
    }
    
    if(needToLoadBusRoutePattern == YES){
        NSDictionary *predBusStopPole = [NSDictionary dictionaryWithObjectsAndKeys:
                                         @"places/odpt:BusstopPole", @"type",
                                         latStr, @"lat",
                                         lonStr, @"lon",
                                         radiusStr, @"radius",
                                         nil];
        [preds addObject:predBusStopPole];
    }

    // preds count がゼロの場合は、 results count ゼロですぐに返る。
    [self.dataProvider requestSequentialAccessWithOwner:owner withPredicates:[preds copy] block:^(NSArray<id> *results) {
       
        if(results == nil || [results count] == 0){
            // アクセスキャンセルまたは失敗
            block(nil);
            return;
        }
        
        
        NSMutableArray *nextArray = [[NSMutableArray alloc] init];
        for(int i=0; i<[results count]; i++){
            NSArray *ary = results[i];
            if([ary isKindOfClass:[NSArray class]] == YES){
                [nextArray addObjectsFromArray:ary];
            }
        }
        
        [self makeObjectOfPoint:point ForArray:nextArray Block:^(NSManagedObjectID *moID) {
            block(moID);
            return;
        }];
    }];
    
}




- (void)startCallBack{
    
    // 別スレッドで実行開始。 これによって、コールバックメソッドの完了を待たずに次のURLアクセスへ移ることができる。
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        self.callback(self->retID);
    });
    
    
}

#pragma mark - ManagedLoader override

- (NSString *)query{
    return [NSString stringWithFormat:@"Point_%lf_%lf", point.longitude, point.latitude];
}

- (void)main{
    if([self isCancelled] == YES){
        [self setFailure];
        [self startCallBack];
        [self completeOperation];
        return;
    }
    
    [self requestBy:self stationsNearPoint:point Block:^(NSManagedObjectID *moID) {
        
        if(moID == nil || [self isCancelled] == YES){
            [self setFailure];
            [self startCallBack];
            [self completeOperation];
            return;
        }
        
        self->retID = moID;
        
        [self startCallBack];
        [self completeOperation];
        return;
    }];
    
}

@end

//
//  ODPTDataLoaderConnectingLines.m
//
//  Copyright (c) 2018 Takehito Ikema
//
//  This software is released under the MIT License.
//  https://opensource.org/licenses/mit-license.php
//

#import "ODPTDataLoaderConnectingLines.h"
#import "ODPTDataLoaderLine.h"
#import "ODPTDataLoaderArray.h"
#import "ODPTDataAdditional.h"

NSString *const ODPTDataLoaderConnectingLinesOptionsNeedToLoadRailway = @"needToLoadRailway";
NSString *const ODPTDataLoaderConnectingLinesOptionsNeedToLoadBusRoutePattern = @"needToLoadBusRoutePattern";
NSString *const ODPTDataLoaderConnectingLinesOptionsSearchRadius = @"searchRadius";

@interface ODPTDataLoaderConnectingLines(){
    
    NSManagedObjectID *retID;
    
    // イニシャライザで設定される Railway/Bus フラグ
    BOOL needToLoadRailway;
    BOOL needToLoadBusRoutePattern;
    
    // 実際にAPIにアクセスするかのフラグ。（すでにアクセス済みのものはアクセスしない）isCompleteObjectにて設定。
    BOOL needToAccessRailway;
    BOOL needToAccessBusRoutePattern;
    
    
    int searchRadius;
}
@end

@implementation ODPTDataLoaderConnectingLines

- (id)init{
    
    NSAssert(YES, @"ODPTDataLoaderConnectingLines must not use init message.");
    
    return nil;
}

- (id) initWithStaion:(NSString *)stationIdentifier withOptions:(NSDictionary *)option Block:(void (^)(NSManagedObjectID *))block{
    
    if(self = [super init]){
        self.stationIdentifier = stationIdentifier;
        
        needToLoadRailway = YES;
        needToLoadBusRoutePattern = YES;
        searchRadius = 500;
        
        NSNumber *nlr = option[ODPTDataLoaderConnectingLinesOptionsNeedToLoadRailway];
        if([nlr isKindOfClass:[NSNumber class]] == YES){
            needToLoadRailway = [nlr boolValue];
        }
        
        NSNumber *nlb = option[ODPTDataLoaderConnectingLinesOptionsNeedToLoadBusRoutePattern];
        if([nlb isKindOfClass:[NSNumber class]] == YES){
            needToLoadBusRoutePattern = [nlb boolValue];
        }
        
        NSNumber *sr = option[ODPTDataLoaderConnectingLinesOptionsSearchRadius];
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
    
    NSNumber *isValid = [obj valueForKey:@"isValidConnectingLines"];
    
    int validLevel = [isValid intValue];

    // すでに途中まで読み込んであっても、記録してある探索半径が異なっていれば、全て無効とする。
    if(validLevel != ODPTDataLoaderConnectingLinesInValid){
        NSNumber *conRadius = [obj valueForKey:@"connectingRadius"];
        if([conRadius intValue] != searchRadius){
            validLevel = ODPTDataLoaderConnectingLinesInValid;
        }
    }
    
    if(needToLoadRailway == YES){
        switch(validLevel){
            case ODPTDataLoaderConnectingLinesInValid:
            case ODPTDataLoaderConnectingLinesValidForBus:
                needToAccessRailway = YES;
                break;
            case ODPTDataLoaderConnectingLinesValidForRailway:
            case ODPTDataLoaderConnectingLinesValidComplete:
                needToAccessRailway = NO;
            default:
                break;
        }
    }

    if(needToLoadBusRoutePattern == YES){
        switch(validLevel){
            case ODPTDataLoaderConnectingLinesInValid:
            case ODPTDataLoaderConnectingLinesValidForRailway:
                needToAccessBusRoutePattern = YES;
                break;
            case ODPTDataLoaderConnectingLinesValidForBus:
            case ODPTDataLoaderConnectingLinesValidComplete:
                needToAccessBusRoutePattern = NO;
            default:
                break;
        }
    }
    
    
    if(needToAccessRailway == YES || needToAccessBusRoutePattern == YES){
        return NO;
    }
    
    return YES;
}


- (void)setValidConnectingLines:(NSManagedObject *)obj{
    
    NSNumber *isValidNum = [obj valueForKey:@"isValidConnectingLines"];
    int isValid = [isValidNum intValue];
    
    BOOL validRailway = NO;
    BOOL validBus = NO;
    
    switch(isValid){
        case ODPTDataLoaderConnectingLinesValidForRailway:
            validRailway = YES;
            break;
        case ODPTDataLoaderConnectingLinesValidForBus:
            validBus = YES;
            break;
        case ODPTDataLoaderConnectingLinesValidComplete:
            validRailway = YES;
            validBus = YES;
            break;
        case ODPTDataLoaderConnectingLinesInValid:
        default:
            break;
    }
    
    if(needToAccessRailway == YES){
        validRailway = YES;
    }
    
    if(needToAccessBusRoutePattern == YES){
        validBus = YES;
    }
    
    int nextIsValid;
    if(validRailway == YES){
        if(validBus == YES){
            nextIsValid = ODPTDataLoaderConnectingLinesValidComplete;
        }else{
            nextIsValid = ODPTDataLoaderConnectingLinesValidForRailway;
        }
    }else{
        if(validBus == YES){
            nextIsValid = ODPTDataLoaderConnectingLinesValidForBus;
        }else{
            nextIsValid = ODPTDataLoaderConnectingLinesInValid;
        }
    }
    
    [obj setValue:[NSNumber numberWithInt:nextIsValid] forKey:@"isValidConnectingLines"];
    
    
}

- (void)makeObjectOfIdentifier:(NSString *)StationIdentifier ForArray:(NSArray *)origArray Block:(void (^)(NSManagedObjectID *))block{
    
    NSArray *array = [origArray sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        
        NSNumber *dist1 = [obj1 valueForKey:@"distance"];
        NSNumber *dist2 = [obj2 valueForKey:@"distance"];
        
        if(dist1 == nil){ return NSOrderedAscending; }
        if(dist2 == nil){ return NSOrderedAscending; }
        
        return [dist1 floatValue] < [dist2 floatValue] ? NSOrderedAscending : NSOrderedDescending;
    }];
    
    NSMutableSet *set = [[NSMutableSet alloc] init];  // set: 重複を削除
    for(int i=0; i<[array count]; i++){
        NSDictionary *dict = array[i];
        NSArray *connectingLines = dict[@"connectingLines"];
        
        [set addObjectsFromArray:connectingLines];
    }
    
    NSMutableArray *con = [[NSMutableArray alloc] init];
    [con addObjectsFromArray:[set allObjects]];
    
    __block NSManagedObject *stationObject = nil;
    NSManagedObjectContext *moc = [self.dataManager managedObjectContextForConcurrent];

    if([con count] == 0){
        // 接続路線なし。
        [moc performBlockAndWait:^{
            // CoreData DBから書き換えるべき object を受け取る。
            NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Station"];
            [request setPredicate:[NSPredicate predicateWithFormat:@"identifier == %@", StationIdentifier]];
            
            NSError *error = nil;
            NSArray *results = [moc executeFetchRequest:request error:&error];
            
            if (results == nil) {
                NSLog(@"Error fetching objects: %@\n%@", [error localizedDescription], [error userInfo]);
                abort();
                return;
            }
            
            if([results count] == 0){
                NSLog(@"can't find station Object %@", self.stationIdentifier);
                abort();
            }else{
                // レコードが存在する。
                stationObject = [results objectAtIndex:0];
            }
            
            [self setValidConnectingLines:stationObject];
            [stationObject setValue:[NSNumber numberWithInt:self->searchRadius] forKey:@"connectingRadius"];
            
            // Save the context.
            if (![moc save:&error]) {
                // Replace this implementation with code to handle the error appropriately.
                // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
                abort();
            }
            // 永続保存は,別途
            
        }];
        
        block([stationObject objectID]);
        return;
    }

    
    NSMutableArray *loaders = [[NSMutableArray alloc] init];
    for(int i=0; i<[con count]; i++){
        NSString *cLineIdentifier = [con objectAtIndex:i];
        ODPTDataLoaderLine *l = [[ODPTDataLoaderLine alloc] initWithLine:cLineIdentifier Block:nil];
        l.dataProvider = self.dataProvider;
        l.dataManager = self.dataManager;
        [loaders addObject:l];
    }
    
    
    ODPTDataLoaderArray *job = [[ODPTDataLoaderArray alloc] initWithLoaders:loaders Block:^(NSArray<NSManagedObjectID *> *moIDArray) {
        
        if(moIDArray == nil || [loaders count] != [moIDArray count]){
            block(nil);
            return;
        }
        
        NSManagedObjectContext *moc = [self.dataManager managedObjectContextForConcurrent];
        __block NSManagedObjectID *retMoID = nil;
        [moc performBlockAndWait:^{
            
            // CoreData DBから書き換えるべき object を受け取る。
            NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Station"];
            [request setPredicate:[NSPredicate predicateWithFormat:@"identifier == %@", StationIdentifier]];
            
            NSError *error = nil;
            NSArray *results = [moc executeFetchRequest:request error:&error];
            
            if (results == nil) {
                NSLog(@"Error fetching objects: %@\n%@", [error localizedDescription], [error userInfo]);
                abort();
                return;
            }
            
            if([results count] == 0){
                NSLog(@"can't find station Object %@", self.stationIdentifier);
                abort();
            }else{
                // レコードが存在するので、書き換える。
                stationObject = [results objectAtIndex:0];
            }
            
            // 本線の直通路線を　接続路線から除外する。-> 除外すべきlineを dcrsへ
            NSMutableArray *dcrs = [[NSMutableArray alloc] init];
            
            NSSet *lineSet = [stationObject valueForKey:@"lines"];
            NSArray *lineArray = [lineSet allObjects];
            
            for(int i=0; i<[lineArray count]; i++){
                NSManagedObject *obj = [lineArray objectAtIndex:i];
                NSString *lineIdent = [obj valueForKey:@"identifier"];
                
                // NSLog(@"additional: %@ %@", StationIdentifier, lineIdent);
                [dcrs addObjectsFromArray:[[ODPTDataAdditional sharedData] directConnectionLinesForLine:lineIdent AtStation:StationIdentifier]];
            }
            
            
            NSSet *l = [stationObject valueForKey:@"connectingLines"];
            NSMutableSet *connectingLines = nil;
            if([l isKindOfClass:[NSSet class]] == YES){
                connectingLines = [l mutableCopy];
            }else{
                connectingLines = [[NSMutableSet alloc] init];
            }

            for(int i=0; i<[moIDArray count]; i++){
                NSManagedObjectID *moID = [moIDArray objectAtIndex:i];
                NSManagedObject *lineObject = [moc objectWithID:moID];
                NSString *lineIdent = [lineObject valueForKey:@"identifier"];
                
                //NSString *connectStation = nil;
                NSMutableArray *connectStations = [[NSMutableArray alloc] init];
                
                // NSLog(@"line: %@", lineIdent);
                NSInteger lineType = [self lineTypeForLineIdentifier:lineIdent];
                
                if(lineType == ODPTDataLineTypeRailway){
                    
                    if([dcrs containsObject:lineIdent]){
                        // 鉄道の場合、直通路線は除外
                        continue;
                    }
                }
                
                // この路線に対し、connectStationをセット
                
                // for(NSString *csi in [lineIdentsForConnectingStation allKeys]){
                // array は今の駅からの距離で短い順にソートしてある
                //   connectStations は複数になる場合がある。　バス　往復路線の場合など、乗り場が異なる複数のstation が選択される。
                for(int i=0; i<[array count]; i++){
                    NSDictionary *d = array[i];
                    NSString *csi = d[@"stationIdentifier"];
                    // NSArray *routes = [lineIdentsForConnectingStation objectForKey:csi];
                    NSArray *routes = d[@"connectingLines"];

                    NSUInteger rIndex = [routes indexOfObject:lineIdent];
                    if(rIndex != NSNotFound){
                        [connectStations addObject:csi];
                    }
                }
                
                if(lineType == ODPTDataLineTypeRailway){
                    if([connectStations count] > 1){
                        // 通常、ODPTDataLineTypeRailwayのばあい、connectStationは一つのみ。
                        NSLog(@"ODPTDataLoaderConnectingLines detect multiple station for railway.");
                    }
                    /*
                    for(int j=0; j<[connectStations count]; j++){
                        NSString *cs = connectStations[j];
                        if([cs hasPrefix:@"unknown"] == YES){
                            // connectStationが unknownの場合は書き換える. APIのconnectingRailwayを使う場合.
                            NSString *new_cs = [self connectStationOfLine:lineObject forStation:stationObject];
                            if(new_cs == nil){
                                // 路線の停車駅の中に、この駅に接続する駅が見当たらない場合 -> connectingLines に追加しない。                                
                                continue;
                            }
                            [connectStations replaceObjectAtIndex:j withObject:new_cs];
                        }
                    }
                     */
                }
                
                
                NSManagedObject *endStation = [self endStationForLineObject:lineObject];
                NSAssert(endStation != nil, @"ODPTDataLoaderConnectingLines no endStation. failure. conLine:%@", [lineObject valueForKey:@"identifier"] );
                
                NSString *endStationIdentifier = [endStation valueForKey:@"identifier"];
                
                for(int j=0; j<[connectStations count]; j++){
                    NSString *cs = connectStations[j];
                    
                    if(lineType == ODPTDataLineTypeRailway){
                        if([cs hasPrefix:@"unknown"] == YES){
                            // connectStationが unknownの場合は書き換える. APIのconnectingRailwayを使う場合.
                            NSString *new_cs = [self connectStationOfLine:lineObject forStation:stationObject];
                            if(new_cs == nil){
                                // 路線の停車駅の中に、この駅に接続する駅が見当たらない場合 -> connectingLines に追加しない。
                                continue;
                            }
                            //[connectStations replaceObjectAtIndex:j withObject:new_cs];
                            cs = new_cs;
                        }
                    }

                    // NSLog(@"cc %@ <=> %@", endStationIdentifier, cs);
                    if([endStationIdentifier isEqualToString:cs] == YES){
                        // 接続駅は、路線の終着駅　-> connectingLines に追加しない。
                        continue;
                    }
                    
                    //NSLog(@"connectingLines line:%@ t:%d", [lineObject valueForKey:@"identifier"], [moID isTemporaryID]);
                
                    NSManagedObject *obj = [NSEntityDescription insertNewObjectForEntityForName:@"ConnectingLine" inManagedObjectContext:moc];
                    [obj setValue:lineIdent forKey:@"identifier"];
                    [obj setValue:cs forKey:@"atStation"];
                    [connectingLines addObject:obj];
                }
            }
            
            [stationObject setValue:connectingLines forKey:@"connectingLines"];
            //[stationObject setValue:[NSNumber numberWithBool:YES] forKey:@"isValidConnectingLines"];
            [self setValidConnectingLines:stationObject];
            [stationObject setValue:[NSNumber numberWithInt:self->searchRadius] forKey:@"connectingRadius"];
            
            // Save the context.
            if (![moc save:&error]) {
                // Replace this implementation with code to handle the error appropriately.
                // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
                abort();
            }
            //[self.dataManager saveContext]; // 永続保管
            
            retMoID = [stationObject objectID];
        }];
        
        block(retMoID);
        return;
    }];
    
    job.dataProvider = self.dataProvider;
    job.dataManager = self.dataManager;
    [job setParent:self];
    //[[LoaderManager sharedManager] addLoader:job];
    [[self queue] addLoader:job];
}





// 並び替え 東京メトロ路線を最初に。
/*
 NSMutableArray *lcon = [[NSMutableArray alloc] init];
 for(int i=0; i<[ncon count]; i++){
 NSString *r = [ncon objectAtIndex:i];
 if([r rangeOfString:@"TokyoMetro"].location != NSNotFound){
 [lcon addObject:r];
 [ncon replaceObjectAtIndex:i withObject:@"xx"];
 }
 }
 
 
 
 for(int i=0; i<[ncon count]; i++){
 id r = [ncon objectAtIndex:i];
 if([r isKindOfClass:[Railway class]]){
 [lcon addObject:r];
 }
 }
 
 self.connectingRailways = [lcon copy];
 */



- (void)requestBy:(id)owner ConnectingLinesAtBusstopPole:(NSString *)stationIdentifier Block:(void (^)(NSManagedObjectID *))block{
    
    //  CoreData データベースにアクセス。
    
    NSManagedObjectContext *moc = [self.dataManager managedObjectContextForConcurrent];
    
    __block NSManagedObjectID *moID = nil;
    [moc performBlockAndWait:^{
        
        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Station"];
        [request setPredicate:[NSPredicate predicateWithFormat:@"identifier == %@", stationIdentifier]];
        
        NSError *error = nil;
        
        NSArray *results = [moc executeFetchRequest:request error:&error];
        
        if (results == nil) {
            NSLog(@"Error fetching objects: %@\n%@", [error localizedDescription], [error userInfo]);
            abort();
        }
        
        NSManagedObject *obj = nil;
        if([results count] == 0){
            //  該当する Station の レコードがない。 -> APIへアクセス。
            // レコードが存在しないので、新たに作る。
            obj = [NSEntityDescription insertNewObjectForEntityForName:@"Station" inManagedObjectContext:moc];
            [obj setValue:stationIdentifier forKey:@"identifier"];
            
        }else{
            obj = [results objectAtIndex:0];
        }
        
        if([self isCompleteObject:obj] == YES){
            moID = [obj objectID];
        }else{
            // 掃除しない。
        }
        
        // Save the context.
        if (![moc save:&error]) {
            // Replace this implementation with code to handle the error appropriately.
            // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
            abort();
        }
        
    }];
    
    if(moID != nil){
        block(moID);
        return;
    }
    
    // APIアクセス開始。
    NSString *ltype = @"odpt:BusstopPole";
    
    NSDictionary *pred;
    
    pred = [NSDictionary dictionaryWithObjectsAndKeys:
            ltype, @"type",
            stationIdentifier, @"owl:sameAs",
            nil];
    
    
    [self.dataProvider requestAccessWithOwner:owner withPredicate:pred block:^(id fary) {
        
        if(fary == nil || [fary count] == 0){
            block(nil);
            return;
        }
        
        NSDictionary *dict = nil;
        
        BOOL flag = NO;
        for(int i=0; i<[fary count]; i++){
            dict = [fary objectAtIndex:i];
            if([stationIdentifier isEqualToString:[dict objectForKey:@"owl:sameAs"]]){
                flag = YES;
                break;
            }
        }
        
        if(flag == NO){
            NSLog(@"station can't find propery record!!!");
            block(nil);
            return;
        }
        
        
        id lon = [dict objectForKey:@"geo:long"];
        id lat = [dict objectForKey:@"geo:lat"];
        
        double rlon = [self convertLocationDataString:lon];
        double rlat = [self convertLocationDataString:lat];
        
        CLLocationCoordinate2D stationPoint = CLLocationCoordinate2DMake(rlat, rlon);

        NSString *lonStr = [NSString stringWithFormat:@"%f", rlon];
        NSString *latStr = [NSString stringWithFormat:@"%f", rlat];
        NSString *radiusStr = [NSString stringWithFormat:@"%d", self->searchRadius];
        
        
        NSMutableArray *preds = [[NSMutableArray alloc] init];
        
        if(self->needToAccessRailway == YES){
            NSDictionary *predStation = [NSDictionary dictionaryWithObjectsAndKeys:
                                         @"places/odpt:Station", @"type",
                                         latStr, @"lat",
                                         lonStr, @"lon",
                                         radiusStr, @"radius",
                                         nil];
            [preds addObject:predStation];
        }
        
        if(self->needToAccessBusRoutePattern == YES){
            NSDictionary *predBusStopPole = [NSDictionary dictionaryWithObjectsAndKeys:
                                             @"places/odpt:BusstopPole", @"type",
                                             latStr, @"lat",
                                             lonStr, @"lon",
                                             radiusStr, @"radius",
                                             nil];
            [preds addObject:predBusStopPole];
        }
        // NSArray *preds = @[predStation, predBusStopPole];
        
        [self.dataProvider requestSequentialAccessWithOwner:owner withPredicates:[preds copy] block:^(NSArray<id> *results) {
        
            if(results == nil || [results count] == 0){
                block(nil);
                return;
            }
            
            // NSAssert([results count] == 2, @"ODPTDataLoaderConnectingLines count error. at %@", self.stationIdentifier);
            NSArray *railwayArray = nil;
            NSArray *busArray = nil;
            if(self->needToAccessRailway == YES){
                if(self->needToAccessBusRoutePattern == YES){
                    railwayArray = results[0];
                    busArray = results[1];
                }else{
                    railwayArray = results[0];
                }
            
            }else{
                if(self->needToAccessBusRoutePattern == YES){
                    busArray = results[0];
                }else{
                    
                }
            }
            
            NSMutableArray *nextArray = [[NSMutableArray alloc] init];
            
            // Station
            if([railwayArray isKindOfClass:[NSArray class]] == YES){
                
                for(int i=0; i<[railwayArray count]; i++){
                    NSDictionary *d = [railwayArray objectAtIndex:i];
                    NSString *s = [d objectForKey:@"owl:sameAs"];
                    NSString *cLineIdent = [d objectForKey:@"odpt:railway"];
                    
                    // 独自拡張　lineIdentifier
                    NSArray *con2 = [self addAllSuffixLineIdentifierExtension:cLineIdent];
                    //[cr_dict setObject:con2 forKey:s];
                    NSDictionary *nd = @{@"stationIdentifier":s, @"connectingLines":con2, @"distance":@0};
                    
                    [nextArray addObject:nd];
                }
                
            }
            
            
            // BusstopPole
            if([busArray isKindOfClass:[NSArray class]] == YES){
                
                for(int i=0; i<[busArray count]; i++){
                    
                    NSDictionary *d = [busArray objectAtIndex:i];
                    NSString *busstopPole = [d objectForKey:@"owl:sameAs"];
                    NSArray *routePatterns = [d objectForKey:@"odpt:busroutePattern"];
                    
                    double slon = [self convertLocationDataString:[d objectForKey:@"geo:long"]];
                    double slat = [self convertLocationDataString:[d objectForKey:@"geo:lat"]];
                    
                    CLLocationCoordinate2D c = CLLocationCoordinate2DMake(slat, slon);
                    CLLocationDistance dist = [self distanceFromPoint:stationPoint toPoint:c];
                    
                    NSDictionary *nd = @{@"stationIdentifier":busstopPole, @"connectingLines":routePatterns, @"distance":[NSNumber numberWithDouble:dist]};
                    [nextArray addObject:nd];
                }
            }
            
            [self makeObjectOfIdentifier:stationIdentifier ForArray:[nextArray copy] Block:^(NSManagedObjectID *moID) {
                block(moID);
            }];
            return;
            
        }];
            
    }];
    
    
};



- (void)requestBy:(id)owner ConnectingLinesAtTrainStop:(NSString *)stationIdentifier Block:(void (^)(NSManagedObjectID *))block{
    //  CoreData データベースにアクセス。
    
    NSManagedObjectContext *moc = [self.dataManager managedObjectContextForConcurrent];
    
    __block NSManagedObjectID *moID = nil;
    [moc performBlockAndWait:^{
        
        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Station"];
        [request setPredicate:[NSPredicate predicateWithFormat:@"identifier == %@", stationIdentifier]];
        
        NSError *error = nil;
        
        NSArray *results = [moc executeFetchRequest:request error:&error];
        
        if (results == nil) {
            NSLog(@"Error fetching objects: %@\n%@", [error localizedDescription], [error userInfo]);
            abort();
        }
        
        NSManagedObject *obj = nil;
        if([results count] == 0){
            //  該当する Station の レコードがない。 -> APIへアクセス。
            // レコードが存在しないので、新たに作る。
            obj = [NSEntityDescription insertNewObjectForEntityForName:@"Station" inManagedObjectContext:moc];
            [obj setValue:stationIdentifier forKey:@"identifier"];
            
        }else{
            obj = [results objectAtIndex:0];
        }
        
        if([self isCompleteObject:obj] == YES){
            moID = [obj objectID];
        }else{
            // 掃除
            
        }
        
        // Save the context.
        if (![moc save:&error]) {
            // Replace this implementation with code to handle the error appropriately.
            // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
            abort();
        }
        
    }];
    
    if(moID != nil){
        block(moID);
        return;
    }
    
    // LineIdentifier を調べる.
    // 接続路線は 同一路線の駅を続けて得ることが多い. 高速化のため.
    NSArray *f = [stationIdentifier componentsSeparatedByString:@":"];
    NSArray *g = [f[1] componentsSeparatedByString:@"."];
    NSString *LineIdentifier = [NSString stringWithFormat:@"odpt.Railway:%@.%@.1.1", g[0], g[1] ];
    
    // APIへアクセス可能な路線か確認
    if(! [self isAbleToAccessAPIOfLine:LineIdentifier]){
        /*
        NSDictionary *rec = [NSDictionary dictionaryWithObjectsAndKeys:
                             stationIdentifier, @"owl:sameAs",
                             @"", @"dc:title",
                             nil];
        */
        [self makeObjectOfIdentifier:stationIdentifier ForArray:@[] Block:^(NSManagedObjectID *moID) {
            if(moID != nil){
                block(moID);
                return;
            }
            block(nil);
            return;
        }];
        return;
    }

    // APIアクセス開始
    NSDictionary *pred;
    if(LineIdentifier != nil){
        // 独自拡張
        //  odpt.Railway:xxxxx.1.1 を一時的に消して、APIへアクセス。
        NSString *shortLineIdentifier = [self removeFooterFromLineIdentifier:LineIdentifier];
        
        pred = [NSDictionary dictionaryWithObjectsAndKeys:
                @"odpt:Station", @"type",
                shortLineIdentifier, @"odpt:railway",
                nil];
        
    }else{
        pred = [NSDictionary dictionaryWithObjectsAndKeys:
                @"odpt:Station", @"type",
                stationIdentifier, @"owl:sameAs",
                nil];
    }
    
    
    
    [self.dataProvider requestAccessWithOwner:owner withPredicate:pred block:^(id ary) {
        
        if(ary == nil || [ary count] == 0){
            block(nil);
            return;
        }

        //__block NSMutableDictionary *nextDict = [[NSMutableDictionary alloc] init];
        __block NSMutableArray *nextArray = [[NSMutableArray alloc] init];
        
        NSDictionary *dict = nil;

        BOOL flag = NO;
        for(int i=0; i<[ary count]; i++){
            dict = [ary objectAtIndex:i];
            if([stationIdentifier isEqualToString:[dict objectForKey:@"owl:sameAs"]]){
                flag = YES;
                break;
            }
        }
        
        if(flag == NO){
            NSLog(@"station can't find propery record!!!");
            block(nil);
            return;
        }
        
        if(self->needToAccessRailway == YES){
            // odpt:connectingRailway を変換 -> nextDict にセット
            NSArray *connectingRailway = [dict objectForKey:@"odpt:connectingRailway"];
            
            for(int i=0; i<[connectingRailway count]; i++){
                
                NSString *cLineIdent = connectingRailway[i];
                
                NSString *key = [NSString stringWithFormat:@"unknown_%d", i];
                
                // 独自拡張　lineIdentifier
                NSArray *con2 = [self addAllSuffixLineIdentifierExtension:cLineIdent];
                
                NSDictionary *nd = @{@"stationIdentifier":key, @"connectingLines":con2, @"distance":@0};
                [nextArray addObject:nd];
            }
        }
        
        if(self->needToAccessBusRoutePattern == NO){
            // バスは不要の場合。
            [self makeObjectOfIdentifier:stationIdentifier ForArray:[nextArray copy] Block:^(NSManagedObjectID *moID) {
                block(moID);
            }];
            return;
        }
        
        // バス停を調べる。 API place を使って。
        
        double rlon = [self convertLocationDataString:[dict objectForKey:@"geo:long"]];
        double rlat = [self convertLocationDataString:[dict objectForKey:@"geo:lat"]];
        
        CLLocationCoordinate2D stationPoint = CLLocationCoordinate2DMake(rlat, rlon);
        
        NSString *lonStr = [NSString stringWithFormat:@"%f", rlon];
        NSString *latStr = [NSString stringWithFormat:@"%f", rlat];
        NSString *radiusStr = [NSString stringWithFormat:@"%d", self->searchRadius];
        
        NSDictionary *predB = [NSDictionary dictionaryWithObjectsAndKeys:
                               @"places/odpt:BusstopPole", @"type",
                               latStr, @"lat",
                               lonStr, @"lon",
                               radiusStr, @"radius",
                               nil];
        
        [self.dataProvider requestAccessWithOwner:owner withPredicate:predB block:^(id ary) {
            
            if(ary == nil){
                block(nil);
                return;
            }
            
            if([ary count] == 0){
                [self makeObjectOfIdentifier:stationIdentifier ForArray:[nextArray copy] Block:^(NSManagedObjectID *moID) {
                    block(moID);
                }];
                return;
            }

            for(int i=0; i<[ary count]; i++){
                NSDictionary *d = [ary objectAtIndex:i];
                NSString *busstopPoleIdentifier = [d objectForKey:@"owl:sameAs"];
                NSArray *routePatterns = [d objectForKey:@"odpt:busroutePattern"];
                
                double slon = [self convertLocationDataString:[d objectForKey:@"geo:long"]];
                double slat = [self convertLocationDataString:[d objectForKey:@"geo:lat"]];
                
                CLLocationCoordinate2D c = CLLocationCoordinate2DMake(slat, slon);
                CLLocationDistance dist = [self distanceFromPoint:stationPoint toPoint:c];
                
                NSDictionary *nd = @{@"stationIdentifier":busstopPoleIdentifier, @"connectingLines":routePatterns,
                                     @"distance":[NSNumber numberWithDouble:dist]};
                [nextArray addObject:nd];
            }
            
            [self makeObjectOfIdentifier:stationIdentifier ForArray:[nextArray copy] Block:^(NSManagedObjectID *moID) {
                block(moID);
            }];
            
        }];
        
    }];
        
};

- (void)startCallBack{
    
    // 別スレッドで実行開始。 これによって、コールバックメソッドの完了を待たずに次のURLアクセスへ移ることができる。
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{

        self.callback(self->retID);
    });
}


#pragma mark - ManagedLoader override

- (NSString *)query{
    return [@"ConnectingLines_" stringByAppendingString:self.stationIdentifier];
    
}


- (void)main{
    
    if([self isCancelled] == YES){
        
        [self startCallBack];
        [self completeOperation];
        return;
    }
    
    
    NSInteger type = [self stationTypeForStationIdentifier:self.stationIdentifier];
    
    // NSString *LineIdentifier = nil;
    if(type == ODPTDataStationTypeTrainStop){
    // if([self.stationIdentifier hasPrefix:@"odpt.Station:"]){
        
        [self requestBy:self ConnectingLinesAtTrainStop:self.stationIdentifier Block:^(NSManagedObjectID *moID) {
            
            if(moID == nil || [self isCancelled] == YES){
                NSLog(@"ODPTDataLoaderConnectingLine requestStations returns nil or cancelled. ident:%@", self.stationIdentifier);
                
                [self startCallBack];
                [self completeOperation];
                return;
            }
            
            self->retID = moID; // 最終的には entity:station のオブジェクトを返す
            
            [self startCallBack];
            [self completeOperation];
            return;
        }];

    }else if(type == ODPTDataStationTypeBusStop){
        [self requestBy:self ConnectingLinesAtBusstopPole:self.stationIdentifier Block:^(NSManagedObjectID *moID) {
            
            if(moID == nil || [self isCancelled] == YES){
                NSLog(@"ODPTDataLoaderConnectingLines requestStations returns nil or cancelled. ident:%@", self.stationIdentifier);
                
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
    
    
}


@end

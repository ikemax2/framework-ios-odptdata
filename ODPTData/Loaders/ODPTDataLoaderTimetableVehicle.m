//
//  ODPTDataLoaderTimetableVehicle.h
//
//  Copyright (c) 2019 Takehito Ikema
//
//  This software is released under the MIT License.
//  https://opensource.org/licenses/mit-license.php
//

#import "ODPTDataLoaderTimetableVehicle.h"
#import "ODPTDataLoaderLine.h"
#import "ODPTDataLoaderArray.h"

@implementation ODPTDataLoaderTimetableVehicle{
    
    NSManagedObjectID *retID;
    BOOL objectCompletionCheck;
}


- (id)init{
    
    NSAssert(YES, @"ODPTDataLoaderTimetableVehicle must not use init message.");
    
    return nil;
}

- (id) initWithTimetableVehicle:(NSString *)timetableVehicleIdentifier Block:(void (^)(NSManagedObjectID *))block{
    
    if(self = [super init]){
        self.timetableVehicleIdentifier = timetableVehicleIdentifier;
        NSAssert(self.timetableVehicleIdentifier != nil,  @"ODPTDataLoaderTimetableVehicle timetableVehicleIdentifier is nil!!");
        
        self.callback = [block copy]; // IMPORTANT
        objectCompletionCheck = YES;
    }
    
    return self;
    
}

// 内部の再帰呼び出し時のみに適用する
//  チェクフラグを NOとし、オブジェクトが未完成でもLoaderが完了するようにする。  循環参照を防止する。
- (id) initWithTimetableVehicle:(NSString *)timetableVehicleIdentifier withoutCheck:(BOOL)noCheck Block:(void (^)(NSManagedObjectID *))block{
    
    if(self = [super init]){
        self.timetableVehicleIdentifier = timetableVehicleIdentifier;
        NSAssert(self.timetableVehicleIdentifier != nil,  @"ODPTDataLoaderTimetableVehicle timetableVehicleIdentifier is nil!!");
        
        self.callback = [block copy]; // IMPORTANT
        objectCompletionCheck = NO;
    }   
    
    return self;
    
}


- (BOOL)isCompleteObject:(NSManagedObject *)obj{
    // オブジェクトの完全性を確認. // performBlock 内から呼び出すこと
    /*
    NSDate *fetchDate = [obj valueForKey:@"fetchDate"];
    if(fetchDate == nil || [fetchDate isKindOfClass:[NSDate class]] == NO){
        return NO;
    }
     */
    
    if(objectCompletionCheck == NO){
        // チェックフラグがNoであれば、完全性チェックはパス
        return YES;
    }
    
    
    NSNumber *validFlag = [obj valueForKey:@"isValidReference"];
    if([validFlag boolValue] == NO){
        return NO;
    }
    
    return YES;
}



// 関連する Next/Previous Timetable の内容を全て取得。  makeObject の後に呼ぶ。
- (void) loadReferenceTimetableObjectOfID:(NSManagedObjectID *)ttobjID Block:(void (^)(NSManagedObjectID *))block {
    
    __block NSMutableArray *loadRefTTIdents = [[NSMutableArray alloc] init];
    
    NSManagedObjectContext *moc = [self.dataManager managedObjectContextForConcurrent];
    [moc performBlockAndWait:^{
        NSManagedObject *newTimetableObject = [moc objectWithID:ttobjID];
        
        NSMutableOrderedSet *referenceTimetables = [newTimetableObject valueForKey:@"referenceTimetable"];
        
        for(int i=0; i<[referenceTimetables count]; i++){
            NSManagedObject *obj = [referenceTimetables objectAtIndex:i];
            NSString *ttIdent = [obj valueForKey:@"identifier"];
            //NSLog(@" xx %@", ttIdent);
            // 循環参照を抑止。 isValidReference(=読み込み完了)がNoの場合だけ、読み込む。
            NSNumber *validFlag = [obj valueForKey:@"isValidReference"];
            if([validFlag boolValue] == NO){
                [loadRefTTIdents addObject:ttIdent];
            }
        }
    }];
    
    if([loadRefTTIdents count] == 0){
        block(ttobjID);
        return;
    }
    
    //NSLog(@"refload:%@", loadRefTTIdents);
    NSMutableArray *loaders = [[NSMutableArray alloc] init];
    for(int i=0; i<[loadRefTTIdents count]; i++){
        NSString *ttIdent = [loadRefTTIdents objectAtIndex:i];
        ODPTDataLoaderTimetableVehicle *l = [[ODPTDataLoaderTimetableVehicle alloc] initWithTimetableVehicle:ttIdent Block:nil];

        l.dataProvider = self.dataProvider;
        l.dataManager = self.dataManager;
        [loaders addObject:l];
    }
    
    __block NSManagedObjectID *retMoID = nil;
    
    ODPTDataLoaderArray *job = [[ODPTDataLoaderArray alloc] initWithLoaders:loaders Block:^(NSArray<NSManagedObjectID *> *moIDArray) {
        
        if(moIDArray == nil || [loadRefTTIdents count] != [moIDArray count]){
            NSLog(@"WARNING!! ODPTDataLoaderTimetableVehicle can't get reference timetable. %@", loadRefTTIdents);
            block(nil);
            return;
        }
        
        NSManagedObjectContext *moc = [self.dataManager managedObjectContextForConcurrent];
        [moc performBlockAndWait:^{
            
            NSManagedObject *newTimetableObject = [moc objectWithID:ttobjID];
            
            NSMutableArray *ary = [[NSMutableArray alloc] init];
            
            for(int i=0; i<[moIDArray count]; i++){
                id moID = [moIDArray objectAtIndex:i];
                
                if([moID isKindOfClass:[NSManagedObjectID class]] == YES){
                    NSManagedObject *refTtObj = [moc objectWithID:moID];
                    [ary addObject:refTtObj];
                    // NSLog(@"   set:%@", [refTtObj valueForKey:@"identifier"]);
                }else{
                    // 多分 NSNull. 取得に失敗
                }
            }
            
            NSMutableOrderedSet *set = [NSMutableOrderedSet orderedSetWithArray:ary];
            [newTimetableObject setValue:set forKey:@"referenceTimetable"];
            [newTimetableObject setValue:[NSNumber numberWithBool:YES] forKey:@"isValidReference"];
            
            NSError *error = nil;
            // Save the context.
            if (![moc save:&error]) {
                // Replace this implementation with code to handle the error appropriately.
                // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
                abort();
            }
            
            retMoID = [newTimetableObject objectID];
        }];
        
        block(retMoID);
        
    }];
    
    job.dataProvider = self.dataProvider;
    job.dataManager = self.dataManager;
    [job setParent:self];
    
    [[self queue] addLoader:job];
    
}


- (NSManagedObjectID *) makeObjectOfTimetableIdentifier:(NSString *)TimetableIdentifier ForDictionary:(NSDictionary *)dict{

    NSString *ttIdent = [dict objectForKey:@"owl:sameAs"];
    NSAssert([ttIdent isEqualToString:TimetableIdentifier] == YES, @"makeObjectOfTimetableIdentifier %@", TimetableIdentifier);
    
    __block NSManagedObjectID *moID = nil;
    
    NSAssert(self.dataManager != nil, @"ODPTDataLoaderTimetableVehicle makeObject dataManager is nil!");
    NSManagedObjectContext *moc = [self.dataManager managedObjectContextForConcurrent];
                
    [moc performBlockAndWait:^{
        
        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"TimetableVehicle"];
        [request setPredicate:[NSPredicate predicateWithFormat:@"identifier == %@", TimetableIdentifier]];
        
        NSError *error = nil;
        NSArray *results = [moc executeFetchRequest:request error:&error];
        
        if(results == nil){
            NSLog(@"Error fetching objects: %@\n%@", [error localizedDescription], [error userInfo]);
            abort();
            return;
        }
        
        NSManagedObject *trainObj = nil;
        if( [results count] == 0) {
            // レコードを新たに作る。
            trainObj = [NSEntityDescription insertNewObjectForEntityForName:@"TimetableVehicle" inManagedObjectContext:moc];
            [trainObj setValue:TimetableIdentifier forKey:@"identifier"];
        }else{
            trainObj = [results firstObject];
        }
        
        // [trainObj setValue:LineIdentifier forKey:@"ofLine"];
        
        
        NSInteger type = [self lineTypeForTimetableIdentifier:TimetableIdentifier];
        NSArray *recs = nil;
        if(type == ODPTDataLineTypeRailway){
            [trainObj setValue:[dict objectForKey:@"odpt:trainNumber"] forKey:@"trainNumber"];
            NSArray *originStations = [dict objectForKey:@"odpt:originStation"];
            if(originStations != nil){
                [trainObj setValue:[originStations componentsJoinedByString:@","] forKey:@"originStations"];
            }
            
            NSArray *destinationStations = [dict objectForKey:@"odpt:destinationStation"];
            if(destinationStations != nil){
                [trainObj setValue:[destinationStations componentsJoinedByString:@","] forKey:@"destinationStations"];
            }
            
            [trainObj setValue:[dict objectForKey:@"odpt:trainType"] forKey:@"trainType"];
            
            recs = [dict objectForKey:@"odpt:trainTimetableObject"];
            
        }else if (type == ODPTDataLineTypeBus){
            
            recs = [dict objectForKey:@"odpt:busTimetableObject"];
            
        }
        
        NSMutableOrderedSet *set = [[NSMutableOrderedSet alloc] init];
        for(int i=0; i<[recs count]; i++){
            
            NSDictionary *recordDict = [recs objectAtIndex:i];
            
            // たまに arrivalStationだけで arrivalTimeが存在しないレコードがある。無視する。
            if([recordDict objectForKey:@"odpt:departureTime"] == nil && [recordDict objectForKey:@"odpt:arrivalTime"] == nil){
                continue;
            }
            
            // レコードを新たに作る。
            NSManagedObject *record = [NSEntityDescription insertNewObjectForEntityForName:@"TimetableVehicleRecord" inManagedObjectContext:moc];
            [record setValue:[NSNumber numberWithInteger:i] forKey:@"index"];
            
            NSString *timeStr = [recordDict objectForKey:@"odpt:departureTime"];
            if(timeStr == nil || [timeStr isKindOfClass:[NSString class]] == NO){
                timeStr = [recordDict objectForKey:@"odpt:arrivalTime"];
                
                if(timeStr == nil || [timeStr isKindOfClass:[NSString class]] == NO){
                    NSAssert(NO, @"timeTableLine record invalid.");
                }
                
                if(type == ODPTDataLineTypeRailway){
                    [record setValue:[recordDict objectForKey:@"odpt:arrivalStation"] forKey:@"atStation"];
                }else if(type == ODPTDataLineTypeBus){
                    [record setValue:[recordDict objectForKey:@"odpt:busstopPole"] forKey:@"atStation"];
                }
                [record setValue:[NSNumber numberWithBool:YES] forKey:@"isArrival"];
                
                
            }else{
                if(type == ODPTDataLineTypeRailway){
                    [record setValue:[recordDict objectForKey:@"odpt:departureStation"] forKey:@"atStation"];
                }else if(type == ODPTDataLineTypeBus){
                    [record setValue:[recordDict objectForKey:@"odpt:busstopPole"] forKey:@"atStation"];
                }
                [record setValue:[NSNumber numberWithBool:NO] forKey:@"isArrival"];
            }
            
            // NSAssert([timeStr isKindOfClass:[NSString class]] == YES, @"ODPTDataLoaderTimetable timeStr is not NSString!!");
            NSArray *f = [timeStr componentsSeparatedByString:@":"];
            if(f == nil || [f count] == 0){
                NSAssert(NO, @"requestTimetableSubBlock error. timeFormat is invalid.");
            }
            
            NSInteger timeHour = [f[0] integerValue];
            NSInteger timeMinute = [f[1] integerValue];
            NSInteger timeSecond = 0;
            
            // 午後12時をすぎる電車の場合は、24を足す。
            if(timeHour < 3){
                timeHour += 24;
            }
            [record setValue:[NSNumber numberWithInteger:timeHour] forKey:@"timeHour"];
            [record setValue:[NSNumber numberWithInteger:timeMinute] forKey:@"timeMinute"];
            [record setValue:[NSNumber numberWithInteger:timeSecond] forKey:@"timeSecond"];
            
            
            [set addObject:record];
        }
        
        [trainObj setValue:[set copy] forKey:@"records"];
        
        
        // referenceTimetable を検索、なければ、空オブジェクトを作成。APIアクセスは まだ、しない。
        
        NSMutableArray *refTimetables = [[NSMutableArray alloc] init];
        
        NSArray *nextTrainTimetables = [dict objectForKey:@"odpt:nextTrainTimetable"];
        if(nextTrainTimetables != nil){
            [refTimetables addObjectsFromArray:nextTrainTimetables];
        }
        
        NSArray *previousTrainTimetables = [dict objectForKey:@"odpt:previousTrainTimetable"];
        if(previousTrainTimetables != nil){
            [refTimetables addObjectsFromArray:previousTrainTimetables];
        }
        //NSLog(@"ref:%@", refTimetables);
        NSMutableOrderedSet *referenceObjects = [[NSMutableOrderedSet alloc] init];
        for(int i=0; i<[refTimetables count]; i++){
            NSString *refTTIdent = refTimetables[i];
            NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"TimetableVehicle"];
            [request setPredicate:[NSPredicate predicateWithFormat:@"identifier == %@", refTTIdent]];
            
            NSError *error = nil;
            NSArray *results = [moc executeFetchRequest:request error:&error];
            
            if(results == nil){
                NSLog(@"Error fetching objects: %@\n%@", [error localizedDescription], [error userInfo]);
                abort();
                return;
            }
            
            NSManagedObject *refTrainObj = nil;
            if( [results count] == 0) {
                // レコードを新たに作る。
                refTrainObj = [NSEntityDescription insertNewObjectForEntityForName:@"TimetableVehicle" inManagedObjectContext:moc];
                [refTrainObj setValue:refTTIdent forKey:@"identifier"];
            }else{
                refTrainObj = [results firstObject];
            }
            
            [referenceObjects addObject:refTrainObj];
        }
        
        [trainObj setValue:[referenceObjects copy] forKey:@"referenceTimetable"];
        [trainObj setValue:[NSNumber numberWithBool:YES] forKey:@"isValidReference"];
        
        
        // Save the context.
        if (![moc save:&error]) {
            // Replace this implementation with code to handle the error appropriately.
            // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
            abort();
        }
        
        moID = [trainObj objectID];
        
    }];
    
    return moID;
}


- (void)requestBy:(id)owner TimetableOfVehicle:(NSString *)ttVehicleIdentifier Block:(void (^)(NSManagedObjectID *))block{
    
    //  CoreData データベースにアクセス。
    __block NSManagedObjectID *moID = nil;
    __block BOOL needToAccess = YES;
    NSManagedObjectContext *moc = [self.dataManager managedObjectContextForConcurrent];
    [moc performBlockAndWait:^{
        
        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"TimetableVehicle"];
        [request setPredicate:[NSPredicate predicateWithFormat:@"identifier == %@", ttVehicleIdentifier]];
        
        NSError *error = nil;
        
        NSArray *results = [moc executeFetchRequest:request error:&error];
        
        if (results == nil) {
            NSLog(@"Error fetching objects: %@\n%@", [error localizedDescription], [error userInfo]);
            abort();
        }
        
        if([results count] == 0){
            //  該当する Station の レコードがない。 -> APIへアクセス。
            // レコードが存在しないので、新たに作る。
            
            NSManagedObject *obj = [NSEntityDescription insertNewObjectForEntityForName:@"TimetableVehicle" inManagedObjectContext:moc];
            [obj setValue:ttVehicleIdentifier forKey:@"identifier"];
            
            // Save the context.
            if (![moc save:&error]) {
                NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
                abort();
            }
            
        }else{
            
            NSManagedObject *obj = [results objectAtIndex:0];
            if([self isCompleteObject:obj] == YES){
                moID = [obj objectID];
                needToAccess = NO;
            }
        }
        
    }];
    
    /*
    if(moID != nil){
        block(moID);
        return;
    }
    */
    
    if(needToAccess == YES){
        // APIアクセス開始。
    
        NSDictionary *pred = nil;
        NSInteger type = [self lineTypeForTimetableIdentifier:self.timetableVehicleIdentifier];
        if(type == ODPTDataLineTypeRailway){
            
            pred = [NSDictionary dictionaryWithObjectsAndKeys:
                    @"odpt:TrainTimetable", @"type",
                    self.timetableVehicleIdentifier, @"owl:sameAs",
                    nil];
            
        }else if(type == ODPTDataLineTypeBus){
            pred = [NSDictionary dictionaryWithObjectsAndKeys:
                    @"odpt:BusTimetable", @"type",
                    self.timetableVehicleIdentifier, @"owl:sameAs",
                    nil];
            
        }else{
            NSLog(@"invalid type. timetable=%@", self.timetableVehicleIdentifier);
            abort();
        }
        
        [self.dataProvider requestAccessWithOwner:owner withPredicate:pred block:^(id result) {
            
            if(result == nil){
                block(nil);
                return;
            }
            
            if([result isKindOfClass:[NSArray class]] == NO){
                block(nil);
                return;
            }
            
            NSDictionary *dict = [result firstObject];
            NSManagedObjectID *moID = [self makeObjectOfTimetableIdentifier:self.timetableVehicleIdentifier ForDictionary:dict];
            
            [self loadReferenceTimetableObjectOfID:moID Block:^(NSManagedObjectID *rMoID) {
                block(rMoID);
            }];
            
            
        }];
        
    }else{
        // NSLog(@"moID:%@", moID);
        [self loadReferenceTimetableObjectOfID:moID Block:^(NSManagedObjectID *rMoID) {
            
            block(rMoID);
        }];
        
    }
    
    
}



- (void)startCallBack{
    
    // 別スレッドで実行開始。 これによって、コールバックメソッドの完了を待たずに次のURLアクセスへ移ることができる。
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        self.callback(self->retID);
    });
    
    
}

#pragma mark - ManagedLoader override

- (NSString *)query{
    return [NSString stringWithFormat:@"TimetableVehicle_%@", self.timetableVehicleIdentifier];
}

- (void)main{
    if([self isCancelled] == YES){
        [self setFailure];
        [self startCallBack];
        [self completeOperation];
        return;
    }
    
    
    [self requestBy:self TimetableOfVehicle:self.timetableVehicleIdentifier Block:^(NSManagedObjectID *moID) {
        
        if(moID == nil || [self isCancelled] == YES){
            NSLog(@"ODPTDataLoaderTimetableVehicle requestTimetableOfVehicle returns nil or cancelled. ident:%@", self.timetableVehicleIdentifier);
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

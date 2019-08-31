//
//  ODPTDataLoaderTimetableStation.m
//
//  Copyright (c) 2018 Takehito Ikema
//
//  This software is released under the MIT License.
//  https://opensource.org/licenses/mit-license.php
//

#import "ODPTDataLoaderTimetableStation.h"
#import "ODPTDataLoaderLine.h"
#import "ODPTDataAdditional.h"
#import "ODPTDataLoaderCalendar.h"
#import "ODPTDataLoaderArray.h"

@implementation ODPTDataLoaderTimetableStation{
    
    NSManagedObjectID *retID;
    
}

- (id)init{
    
    NSAssert(YES, @"ODPTDataLoaderStation must not use init message.");
    
    return nil;
}
/*
- (id) initWithLine:(NSString *)lineIdentifier andStation:(NSString *)stationIdentifier{
    
    if(self = [super init]){
        self.lineIdentifier = lineIdentifier;
        self.stationIdentifier = stationIdentifier;
        // self.dayType = dayType;
        
        self.callback = nil;
    }
    
    return self;    
}
*/

- (id) initWithLine:(NSString *)lineIdentifier andStation:(NSString *)stationIdentifier Block:(void (^)(NSManagedObjectID *))block{
    
    if(self = [super init]){
        self.lineIdentifier = lineIdentifier;
        self.stationIdentifier = stationIdentifier;
        NSAssert(self.lineIdentifier != nil,  @"ODPTDataLoaderTimetableStation lineIdentifier is nil!!");
        NSAssert(self.stationIdentifier != nil,  @"ODPTDataLoaderTimetableStation stationIdentifier is nil!!");
        // self.dayType = dayType;
        
        self.callback = [block copy]; // IMPORTANT
        
        //self.query = [NSString stringWithFormat:@"TimetableStation_%@_%@_%ld", lineIdentifier, stationIdentifier, dayType];
    }
    
    return self;
    
}


- (BOOL)isCompleteObject:(NSManagedObject *)obj{
    // オブジェクトの完全性を確認. // performBlock 内から呼び出すこと
    NSSet *set = [obj valueForKey:@"timetableStations"];
    
    if(set == nil || [set count] == 0){
        NSLog(@"ODPTDataLoaderTimetableStation timetableStations nil.");
        return NO;
    }
    
    if(set == nil){
        NSLog(@"ODPTDataLoaderTimetableStation timetableStations nil.");
        return NO;
    }
    
    NSArray *tts = [set allObjects];
    for(NSManagedObject *timetableObj in tts){

        if([timetableObj valueForKey:@"calendar"] == nil){
            NSLog(@"ODPTDataLoaderTimetableStation calendar not set.");
            return NO;
        }
        
        NSOrderedSet *recordsSet = [timetableObj valueForKey:@"records"];
        if(recordsSet == nil){
            NSLog(@"ODPTDataLoaderTimetableStation records not set.");
            return NO;
        }else{
            if([recordsSet count] == 0){
                NSLog(@"ODPTDataLoaderTimetableStation records count zero.");
                return NO;
            }
        }
    }
    
    return YES;
    
}

- (void) makeObjectOfLineIdentifier:(NSString *)LineIdentifier andStationIdentifier:(NSString *)StationIdentifier ForDictionaries:(NSArray<NSDictionary *> *)ary Block:(void (^)(NSManagedObjectID *))block {
    
    __block NSManagedObjectID *moID = nil;
    
    NSMutableSet *calendarIdentsSet = [[NSMutableSet alloc] init]; // 重複防止
    
    for(int k=0; k<[ary count]; k++){
        // weekday, holiday などで複数存在するはず。
        NSDictionary *dict = [ary objectAtIndex:k];
        NSString *calendarIdent = [dict objectForKey:@"odpt:calendar"];
        
        // 一部のバス停時刻表には、calendarを含まないものがあるようだ. 後の処理ができないので、無視する。
        // NSAssert(calendarIdent != nil,@"ODPTDataLoaderTimetableStation calendar is nil.");
        if(calendarIdent != nil){
            [calendarIdentsSet addObject:calendarIdent];
        }
    }
    
    NSArray *calendarIdents = [calendarIdentsSet allObjects];
    // NSAssert([calendarIdents count] > 0, @"ODPTDataLoaderTimetableStation timetableStation record is zero. l: %@ s:%@", LineIdentifier, StationIdentifier);
    
    if([calendarIdents count] == 0){
        
        NSManagedObjectContext *moc = [self.dataManager managedObjectContextForConcurrent];
        
        [moc performBlockAndWait:^{
            
            // CoreData DBから書き換えるべき object を受け取る。
            NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"TimetableStationSet"];
            [request setPredicate:[NSPredicate predicateWithFormat:@"ofLine == %@ and atStation == %@", LineIdentifier, StationIdentifier]];
            
            NSError *error = nil;
            NSArray *results = [moc executeFetchRequest:request error:&error];
            
            if (results == nil) {
                NSLog(@"Error fetching objects: %@\n%@", [error localizedDescription], [error userInfo]);
                abort();
                return;
            }
            
            if([results count] == 0){
                NSLog(@"can't find station Object %@", StationIdentifier);
                abort();
            }
            
            NSManagedObject *timeTableStationSetObject = [results objectAtIndex:0];
            
            moID = [timeTableStationSetObject objectID];
        }];
        
        block(moID);
        return;
    }
    
    NSMutableArray *loaders = [[NSMutableArray alloc] init];
    for(int i=0; i<[calendarIdents count]; i++){
        NSString *calendarIdent = calendarIdents[i];
        ODPTDataLoaderCalendar *j = [[ODPTDataLoaderCalendar alloc] initWithCalendar:calendarIdent Block:nil];
        
        j.dataProvider = self.dataProvider;
        j.dataManager = self.dataManager;
        
        [loaders addObject:j];
    }
    
    __block ODPTDataLoaderArray *job = [[ODPTDataLoaderArray alloc] initWithLoaders:loaders Block:^(NSArray<NSManagedObjectID *> *calendarAry) {
        
        if(calendarAry == nil){
            // APIアクセスに失敗。
            NSLog(@"ODPTDataLoaderCalendar return nil. ");
            block(nil);
            return;
        }
    
        NSManagedObjectContext *moc = [self.dataManager managedObjectContextForConcurrent];
    
        [moc performBlockAndWait:^{
            NSMutableDictionary *calendarObjForCalendar = [[NSMutableDictionary alloc] init];
            
            for(int k=0; k<[calendarAry count]; k++){
                NSManagedObjectID *moID = calendarAry[k];
                
                NSManagedObject *obj = [moc objectWithID:moID];
                [calendarObjForCalendar setObject:obj forKey:calendarIdents[k]];
            }
            
        
            // NSManagedObject *retObj = nil;
        
            // CoreData DBから書き換えるべき object を受け取る。
            NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"TimetableStationSet"];
            [request setPredicate:[NSPredicate predicateWithFormat:@"ofLine == %@ and atStation == %@", LineIdentifier, StationIdentifier]];
            
            NSError *error = nil;
            NSArray *results = [moc executeFetchRequest:request error:&error];
            
            if (results == nil) {
                NSLog(@"Error fetching objects: %@\n%@", [error localizedDescription], [error userInfo]);
                abort();
                return;
            }
            
            if([results count] == 0){
                NSLog(@"can't find station Object %@", StationIdentifier);
                abort();
            }
            
        
        /*
        NSNumber *dayTypeWeekday = [NSNumber numberWithInteger:kDayTypeWeekday];
        NSNumber *dayTypeHoliday = [NSNumber numberWithInteger:kDayTypeHoliday];
        NSNumber *dayTypeSaturday = [NSNumber numberWithInteger:kDayTypeSaturday];
        //NSArray *dayTypeDB = @[dayTypeWeekday, dayTypeHoliday, dayTypeSaturday];
        NSArray *dayTypeDB = @[dayTypeWeekday, dayTypeHoliday, dayTypeSaturday];
        
        //NSArray *dayTypeApi = @[ @"odpt:weekdays", @"odpt:holidays", @"odpt:saturdays"];
        NSArray *dayTypeApi = @[ @"odpt.Calendar:Weekday", @"odpt.Calendar:SaturdayHoliday", @"odpt.Calendar:SaturdayHoliday"];
        */
            
            NSManagedObject *timeTableStationSetObject = [results objectAtIndex:0];
            
            /*
            for(int k=0; k<[results count]; k++){
                NSManagedObject *obj = [results objectAtIndex:k];
                if([[obj valueForKey:@"dayType"] isEqualToNumber:dayTypeDB[p]] ){
                    timetableStationObject = obj;
                    break;
                }
            }
            */
            
            NSMutableSet *timetableStationSet = [[NSMutableSet alloc] init];
            
            for(int k=0; k<[ary count]; k++){
                
                NSDictionary *dict = [ary objectAtIndex:k];
                
            
                // レコードを新たに作る。
                NSManagedObject *ttStationObj = [NSEntityDescription insertNewObjectForEntityForName:@"TimetableStation" inManagedObjectContext:moc];
                
                [ttStationObj setValue:LineIdentifier forKey:@"ofLine"];
                [ttStationObj setValue:StationIdentifier forKey:@"atStation"];
                
                NSArray *ts = nil;
                NSInteger type = [self stationTypeForStationIdentifier:StationIdentifier];
                if(type == ODPTDataStationTypeTrainStop){
                    ts = [dict objectForKey:@"odpt:stationTimetableObject"];
                }else if(type == ODPTDataStationTypeBusStop){
                    ts = [dict objectForKey:@"odpt:busstopPoleTimetableObject"];
                }
                
                if(ts == nil){
                    // 時刻表を取得できなかった
                    ts = @[];
                }
                
                NSMutableDictionary *searchHourIndex = [[NSMutableDictionary alloc] init];
                
                NSMutableOrderedSet *recordSet = [[NSMutableOrderedSet alloc] init];
                for(int i=0; i<[ts count]; i++){
                    
                    NSDictionary *recordDict = [ts objectAtIndex:i];
                    
                    // レコードを新たに作る。
                    NSManagedObject *record = [NSEntityDescription insertNewObjectForEntityForName:@"TimetableStationRecord" inManagedObjectContext:moc];
                    
                    NSString *timeStr = [recordDict objectForKey:@"odpt:departureTime"];
                    
                    NSArray *f = [timeStr componentsSeparatedByString:@":"];
                    if(f == nil || [f count] == 0){
                        NSLog(@"requestTimetableSubBlock error. timeFormat is invalid.");
                        abort();
                    }
                    
                    [record setValue:[NSNumber numberWithInt:i] forKey:@"index"];
                    
                    /*
                     if([tmpSearchHourIndex objectForKey:[f firstObject]] == nil){
                     [tmpSearchHourIndex setObject:[NSNumber numberWithInt:i] forKey:[f firstObject]];
                     }
                     */
                    
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
                    
                    // searchHourIndexに値を入れる。次回以降は、検索が多少早くなる。
                    NSString *searchHourKey = [NSString stringWithFormat:@"%02ld", timeHour];
                    if([searchHourIndex objectForKey:searchHourKey] == nil){
                        [searchHourIndex setObject:[NSNumber numberWithInt:i] forKey:searchHourKey];
                    }
                    
            
                    id destinations = nil;
                    if(type == ODPTDataStationTypeTrainStop){
                        [record setValue:[recordDict objectForKey:@"odpt:trainType"] forKey:@"trainType"];
                        [record setValue:[recordDict objectForKey:@"odpt:notes"] forKey:@"notes"];
                        destinations = [recordDict objectForKey:@"odpt:destinationStation"];
                    }else if(type == ODPTDataStationTypeBusStop){
                        destinations = [recordDict objectForKey:@"odpt:destinationBusstopPole"];
                    }
                    
                    NSString *destinationStation = nil;
                    if(destinations  == nil || [destinations isKindOfClass:[NSNull class]] == YES){
                        // yamanote line など destinationの記載がない
                        // togane line など nullの行き先がえ帰ってくるケース
                        destinationStation = @"";
                        
                    }else if([destinations isKindOfClass:[NSArray class]] == YES){
                        /*
                        NSMutableString *str = [[NSMutableString alloc] init];
                        for(int i=0; i<[(NSArray *)destinations count]; i++){
                            if(i != 0){
                                [str appendString:@","];
                            }
                            [str appendString:[(NSArray *)destinations objectAtIndex:i]];
                        }
                        destinationStation = [str copy];
                         */
                        destinationStation = [(NSArray *)destinations objectAtIndex:0];
                    }else if([destinations isKindOfClass:[NSString class]] == YES){
                        destinationStation = (NSString *)destinations;
                    }else{
                        NSAssert(NO, @"ODPTDataLoaderTimetableStation invalid data type. %@", destinations);
                    }
                
                    [record setValue:destinationStation forKey:@"destination"];
                    
                    [recordSet addObject:record];
                }
            
                [ttStationObj setValue:recordSet forKey:@"records"];
                
                // timetableStation オブジェクトに trains をセット
                NSString *calendarIdent = [dict objectForKey:@"odpt:calendar"];
                
                NSManagedObject *calendarObj = [calendarObjForCalendar objectForKey:calendarIdent];
                [ttStationObj setValue:calendarObj forKey:@"calendar"];

                NSData *indexData = [NSKeyedArchiver archivedDataWithRootObject:[searchHourIndex copy]];
                [ttStationObj setValue:indexData forKey:@"hourIndexForSearch"];
                
                [timetableStationSet addObject:ttStationObj];
            }
            
            [timeTableStationSetObject setValue:[timetableStationSet copy] forKey:@"timetableStations"];
            
            // Save the context.
            if (![moc save:&error]) {
                // Replace this implementation with code to handle the error appropriately.
                // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
                abort();
            }
            //[self.dataManager saveContext]; // 永続保管
            
            moID = [timeTableStationSetObject objectID];
            
        }];
    
        block(moID);
    }];
    
    job.dataProvider = self.dataProvider;
    job.dataManager = self.dataManager;
    [job setParent:self];
    
    // [[LoaderManager sharedManager] addLoader:job];
    [[self queue] addLoader:job];
}


- (void)requestBy:(id)owner TimetableOfLine:(NSString *)LineIdentifier atStaion:(NSString *)StationIdentifier Block:(void (^)(NSManagedObjectID *))block{
    
    //  CoreData データベースにアクセス。
    
    __block NSManagedObjectID *moID = nil;
    
    NSManagedObjectContext *moc = [self.dataManager managedObjectContextForConcurrent];
    [moc performBlockAndWait:^{
        
        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"TimetableStationSet"];
        [request setPredicate:[NSPredicate predicateWithFormat:@"ofLine == %@ and atStation == %@", LineIdentifier, StationIdentifier]];
        
        NSError *error = nil;
        
        NSArray *results = [moc executeFetchRequest:request error:&error];
        
        if (results == nil) {
            NSLog(@"Error fetching objects: %@\n%@", [error localizedDescription], [error userInfo]);
            abort();
        }
        
        if([results count] == 0){
            //  該当する Station の レコードがない。 -> APIへアクセス。
            // レコードがぞんざいしないので、新たに作る
            
            NSManagedObject *obj = [NSEntityDescription insertNewObjectForEntityForName:@"TimetableStationSet" inManagedObjectContext:moc];
            [obj setValue:LineIdentifier forKey:@"ofLine"];
            [obj setValue:StationIdentifier forKey:@"atStation"];
            
            /*
             // レコードが存在しないので、新たに作る。平日/土曜日/休日　の3つ。
            NSNumber *dayTypeWeekday = [NSNumber numberWithInteger:kDayTypeWeekday];
            NSNumber *dayTypeHoliday = [NSNumber numberWithInteger:kDayTypeHoliday];
            NSNumber *dayTypeSaturday = [NSNumber numberWithInteger:kDayTypeSaturday];
            
            NSArray *dayTypeDB = @[dayTypeWeekday, dayTypeHoliday, dayTypeSaturday];
            for(int i=0; i<[dayTypeDB count]; i++){
                NSManagedObject *obj = [NSEntityDescription insertNewObjectForEntityForName:@"TimetableStation" inManagedObjectContext:moc];
                [obj setValue:LineIdentifier forKey:@"ofLine"];
                [obj setValue:StationIdentifier forKey:@"atStation"];
                [obj setValue:dayTypeDB[i] forKey:@"dayType"];
            }
            */
            
            // Save the context.
            if (![moc save:&error]) {
                NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
                abort();
            }
            
            //[self.dataManager saveContext]; // 永続保管 非同期で。
            
        }else{
            /*
            for(int i=0; i<[results count]; i++){
                NSManagedObject *obj = [results objectAtIndex:i];

                NSNumber *numberDayType = [obj valueForKey:@"dayType"];
                if([numberDayType integerValue] == dayType){
                    moID = [obj objectID];
                    break;
                }
            }
            */

            NSManagedObject *obj = [results objectAtIndex:0];
            if([self isCompleteObject:obj] == YES){
                moID = [obj objectID];
            }else{
                // 掃除
                NSLog(@"ODPTDataLoaderTimetableStation object incompleted. clean up. ident: %@,%@", self.stationIdentifier, self.lineIdentifier);
                NSSet *set = [obj valueForKey:@"timetableStations"];
                NSArray *ary = [set allObjects];
                for(NSManagedObject *tts in ary){
                    [moc deleteObject:tts];
                }
                
                // Save the context.
                if (![moc save:&error]) {
                    NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
                    abort();
                }
                
                //[self.dataManager saveContext]; // 永続保管 非同期で。
                
            }
        }
    }];
    
    
    if(moID != nil){
        block(moID);
        return;
    }
    
    NSString *LineIdentifierAccess = LineIdentifier;
    NSString *StationIdentifierAccess = StationIdentifier;
    
    // 千代田線支線用の対応
    /*
    if([LineIdentifierAccess containsString:@"ChiyodaBranch"] ){
        LineIdentifierAccess = [LineIdentifier stringByReplacingOccurrencesOfString:@"ChiyodaBranch" withString:@"Chiyoda"];
        StationIdentifierAccess = [StationIdentifier stringByReplacingOccurrencesOfString:@"ChiyodaBranch" withString:@"Chiyoda"];
    }
    */
    
    // APIへアクセス可能な路線か確認
    if(! [self isAbleToAccessAPIOfLine:LineIdentifierAccess]){
        
        NSDictionary *rec = [NSDictionary dictionaryWithObjectsAndKeys:
                             StationIdentifier, @"owl:sameAs",
                             @"", @"dc:title",
                             nil];
        
        [self makeObjectOfLineIdentifier:LineIdentifier andStationIdentifier:StationIdentifier ForDictionaries:@[rec] Block:^(NSManagedObjectID *moID) {
            if(moID != nil){
                block(moID);
                return;
            }
        }];
        
        return;
    }
    
    // APIアクセス開始。
    
    __block ODPTDataLoaderLine *job;
    job = [[ODPTDataLoaderLine alloc] initWithLine:LineIdentifier Block:^(NSManagedObjectID *moID) {
        
        if(moID == nil){
            // APIアクセスに失敗。
            NSLog(@"ODPTDataLoaderLine return nil. ident:%@", LineIdentifier);
            // メインスレッドで実行。
            /*
            dispatch_async(
                           dispatch_get_main_queue(),
                           ^{
                               block(nil);
                           }
                           );
             */
            block(nil);
            return;
        }
        
        NSManagedObjectContext *moc = [self.dataManager managedObjectContextForConcurrent];
        
        // __block NSString *endStationIdentifier;
        __block NSArray *directions;
        
        [moc performBlockAndWait:^{
            NSManagedObject *obj = [moc objectWithID:moID];
            
            //NSManagedObject *endStationObj = [job endStationForLineObject:obj];
            //endStationIdentifier = [endStationObj valueForKey:@"identifier"];
            
            directions  = [job directionIdentifierForLineObject:obj];
        }];
        

        NSMutableArray *preds = [[NSMutableArray alloc] init];
        
        // railDirectionは複数帰ってくる場合がある。
        // NSMutableArray *directions = [[job directionIdentifierForEndStation:endStationIdentifier withLine:LineIdentifier] mutableCopy];
        NSInteger type = [self stationTypeForStationIdentifier:StationIdentifier];

        if(type == ODPTDataStationTypeTrainStop){
            
            for(int i=0; i<[directions count]; i++){
                NSDictionary *pred = [NSDictionary dictionaryWithObjectsAndKeys:
                                      @"odpt:StationTimetable", @"type",
                                      directions[i], @"odpt:railDirection",
                                      StationIdentifierAccess, @"odpt:station",
                                      nil];
                [preds addObject:pred];
            }
            
        }else if(type == ODPTDataStationTypeBusStop){
            
            for(int i=0; i<[directions count]; i++){
                NSDictionary *pred = [NSDictionary dictionaryWithObjectsAndKeys:
                                      @"odpt:BusstopPoleTimetable", @"type",
                                      directions[i], @"odpt:busDirection",
                                      StationIdentifierAccess, @"odpt:busstopPole",
                                      nil];
                [preds addObject:pred];
            }
            
        }else{
            NSLog(@"invalid type. line=%@, station=%@", LineIdentifier, StationIdentifier);
            abort();
        }
        
        
        [self.dataProvider requestSequentialAccessWithOwner:owner withPredicates:[preds copy] block:^(NSArray<id> *results) {
            
            if(results == nil || [results count] == 0){
                block(nil);
                return;
            }
            
            NSMutableArray *nextArray = [[NSMutableArray alloc] init];
            for(int i=0; i<[results count]; i++){
                id obj = [results objectAtIndex:i];
                //NSAssert([obj isKindOfClass:[NSArray class]], @"ODPTDataLoaderTimetableStation return value is abnormal.");
                if([obj isKindOfClass:[NSArray class]] == YES){
                    [nextArray addObjectsFromArray:obj];
                }else{
                    // NSnull クラスが返ってくる可能性がある -> 追加しない
                }
            }
            
            [self makeObjectOfLineIdentifier:LineIdentifier andStationIdentifier:StationIdentifier ForDictionaries:nextArray Block:^(NSManagedObjectID *moID) {
                
                block(moID);
                return;
            }];
            
        }];
        
    }];
    
    job.dataProvider = self.dataProvider;
    job.dataManager = self.dataManager;
    
    //[[LoaderManager sharedManager] addLoader:job];
    [[self queue] addLoader:job];
    
}


- (void)startCallBack{
    
    // 別スレッドで実行開始。 これによって、コールバックメソッドの完了を待たずに次のURLアクセスへ移ることができる。
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        self.callback(self->retID);
    });
    
    
}

#pragma mark - ManagedLoader override

- (NSString *)query{
    return [NSString stringWithFormat:@"TimetableStation_%@_%@", self.lineIdentifier, self.stationIdentifier];
}

- (void)main{
    if([self isCancelled] == YES){
        [self setFailure];
        [self startCallBack];
        [self completeOperation];
        return;
    }
        
    [self requestBy:self TimetableOfLine:self.lineIdentifier atStaion:self.stationIdentifier Block:^(NSManagedObjectID *moID) {
            
            if(moID == nil || [self isCancelled] == YES){
                NSLog(@"ODPTDataLoaderTimetableStation requestStations returns nil or cancelled. ident:%@", self.stationIdentifier);                
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

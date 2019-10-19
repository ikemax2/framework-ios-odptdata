//
//  ODPTDataLoaderTimetableLine.m
//
//  Copyright (c) 2018 Takehito Ikema
//
//  This software is released under the MIT License.
//  https://opensource.org/licenses/mit-license.php
//

#import "ODPTDataLoaderTimetableLine.h"
#import "ODPTDataLoaderLine.h"
#import "ODPTDataAdditional.h"
#import "ODPTDataLoaderCalendar.h"
#import "ODPTDataLoaderArray.h"
#import "ODPTDataLoaderTimetableVehicle.h"

@implementation ODPTDataLoaderTimetableLine{
    
    NSManagedObjectID *retID;
}


- (id)init{
    
    NSAssert(YES, @"ODPTDataLoaderTimetableLine must not use init message.");
    
    return nil;
}

- (id) initWithLine:(NSString *)lineIdentifier Block:(void (^)(NSManagedObjectID *))block{
    
    if(self = [super init]){
        self.lineIdentifier = lineIdentifier;
        NSAssert(self.lineIdentifier != nil,  @"ODPTDataLoaderTimetableLine lineIdentifier is nil!!");
        
        self.callback = [block copy]; // IMPORTANT
        
    }
    
    return self;
    
}

- (BOOL)isCompleteObject:(NSManagedObject *)obj{
    // オブジェクトの完全性を確認. // performBlock 内から呼び出すこと
    
    NSDate *fetchDate = [obj valueForKey:@"fetchDate"];
    if(fetchDate == nil || [fetchDate isKindOfClass:[NSDate class]] == NO){
        return NO;
    }
    
    
    NSSet *set = [obj valueForKey:@"timetableLines"];
    if(set == nil){
        // ここに入ることは、多分、無い。
        NSLog(@"ODPTDataLoaderTimetableLine timetableLines nil.");
        return NO;
    }
    
    NSArray *tts = [set allObjects];
    
    for(NSManagedObject *timetableObj in tts){
        
        if([timetableObj valueForKey:@"calendar"] == nil){
            NSLog(@"ODPTDataLoaderTimetableLine calendar not set.");
            return NO;
        }
        
        NSOrderedSet *vehiclesSet = [timetableObj valueForKey:@"vehicles"];
        if(vehiclesSet == nil){
            NSLog(@"ODPTDataLoaderTimetableLine vehicles not set.");
            return NO;
        }else{
            if([vehiclesSet count] == 0){
                NSLog(@"ODPTDataLoaderTimetableLine vehicles count zero.");
                return NO;
            }
        }
    }
    
    return YES;
    
}

// 未使用
- (NSDictionary *)modifyTrainTimeTable:(NSDictionary *)orig_dict withData:(NSDictionary *)modifyData{
    
    if(modifyData == nil){
        return orig_dict;
    }
    
    // Errata
    //   有楽町線として取得できる一部列車の平日の時刻表は、正しくは副都心線の時刻表である。（和光市と小竹向原間のみ記載）
    // 　有楽町線の時刻表を取得し、列車番号で絞り込み、副都心線の平日の同じ列車番号の時刻表にマージ、駅名を書き換え(Yurakucho->Fukutoshin)
    
    
    NSMutableDictionary *new_dict = [orig_dict mutableCopy];

    NSString *r_identifier = [new_dict objectForKey:@"odpt:railway"];
    NSArray *orig_ts = [new_dict objectForKey:@"odpt:weekdays"];
    
    NSString *trainNumber = [new_dict objectForKey:@"odpt:trainNumber"];
    
    // 修正対象は平日のみ。
    if(orig_ts == nil){
        return orig_dict;
    }
    
    if([r_identifier isEqualToString:@"odpt.Railway:TokyoMetro.Fukutoshin"]){
        // 副都心線の時刻表を取得している場合に、修正処理に入る。
        
        // modifyData 確認  修正すべきデータがなければそのまま返す。
        NSDictionary *modify_dict = [modifyData objectForKey:trainNumber];
        
        if(modify_dict == nil){
            return orig_dict;
        }
        
        // このレコードは、修正対象である
            
        NSArray *ts = [modify_dict objectForKey:@"odpt:weekdays"];
            
        if(ts == nil || [ts count] == 0){
            // 時刻表を取得できなかった  そのまま返す。
            return orig_dict;
        }
            
        // orig_ts と ts をマージ。
        // 副都心線と有楽町線を単純に足し合わせた後、 departureStationとarrivalStationが同じレコードを消す。
        NSMutableArray *new_ts = [[NSMutableArray alloc] init];
        
        NSMutableDictionary *ds = [[NSMutableDictionary alloc] init];  // 副都心線のdepartureStationsを格納
        
        // 副都心線データ は 無条件で 新データに追加。
        for(int i=0; i<[orig_ts count]; i++){
            NSDictionary *d = [orig_ts objectAtIndex:i];
            
            [new_ts addObject:d];
            
            [ds setObject:@"1" forKey:[d objectForKey:@"odpt:departureStation"]];
        }
        
        // 有楽町線データ は　駅名変更 して追加。  同じ駅名が存在する場合は、 副都心線データを優先。
        for(int i=0; i<[ts count]; i++){
            NSMutableDictionary *md = [[ts objectAtIndex:i] mutableCopy];
                
            // 駅名を変更
            if( [md objectForKey:@"odpt:departureStation"] != nil){
                NSString *old_str = [md objectForKey:@"odpt:departureStation"];
                NSString *new_str = [old_str stringByReplacingOccurrencesOfString:@"Yurakucho" withString:@"Fukutoshin"];
                
                [md setObject:new_str forKey:@"odpt:departureStation"];
            }
            
            if( [md objectForKey:@"odpt:arrivalStation"] != nil){
                NSString *old_str = [md objectForKey:@"odpt:arrivalStation"];
                NSString *new_str = [old_str stringByReplacingOccurrencesOfString:@"Yurakucho" withString:@"Fukutoshin"];
                
                [md setObject:new_str forKey:@"odpt:arrivalStation"];
            }
 
            
            if([md objectForKey:@"odpt:arrivalStation"] != nil){
                if( [ds objectForKey:[md objectForKey:@"odpt:arrivalStation"]] != nil){
                    // このdictは登録しない。
                    continue;
                }
            }

            [new_ts addObject:[md copy]];
        }

        [new_dict setObject:new_ts forKey:@"odpt:weekdays"];
            
        
        return [new_dict copy];
        
        
    }else if([r_identifier isEqualToString:@"odpt.Railway:TokyoMetro.Yurakucho"]){
        // 有楽町線の時刻表を取得している場合に、修正処理に入る。
        
        // modifyData 確認  修正すべきデータがなければそのまま返す。
        NSDictionary *modify_dict = [modifyData objectForKey:trainNumber];
        
        if(modify_dict == nil){
            return orig_dict;
        }
        
        // 修正対象。
        // 有楽町線の列車時刻表に　副都心線のものが混ざっている。空のNSArrayで置き換える。
        
        [new_dict setObject:@[] forKey:@"odpt:weekdays"];
        
        return [new_dict copy];
    }
    
    return orig_dict;
}


// 未使用
/*
- (void)prepareModifyTrainTimetableForLine:(NSString *)LineIdentifier andDayType:(NSInteger)dayType Block:(void (^)(NSDictionary *))block{
    
    ODPTDataLoader *loader = [[ODPTDataLoader alloc] init];
    NSString *shortLineIdentifier = [loader removeFooterFromLineIdentifier:LineIdentifier];

    // 修正対象は平日のみ。
    if(dayType != kDayTypeWeekday){
        block(nil);
        return;
    }
    
    
    // 列車番号確認
    NSArray *m_tnum = [NSArray arrayWithObjects:@"A0613T",@"A0293S", @"A1071S", @"A1133S", @"A1141S", @"A1907T", @"A2023S", @"A2061S", @"B0720M", @"B0813T", @"B1041S", @"B1341S", @"B1651S", @"B1971S", @"B2003T", @"B2007T", @"B2121S", nil];
    
    if([shortLineIdentifier isEqualToString:@"odpt.Railway:TokyoMetro.Fukutoshin"]){
        
        NSString *ltype = @"odpt:TrainTimetable" ;
        
        NSMutableArray *preds = [[NSMutableArray alloc] init];
        for(int i=0; i<[m_tnum count]; i++){
            NSString *trainNumber = [m_tnum objectAtIndex:i];
            NSDictionary *pred = [NSDictionary dictionaryWithObjectsAndKeys:
                                  ltype, @"type",
                                  trainNumber, @"odpt:trainNumber",
                                  @"odpt.Railway:TokyoMetro.Yurakucho", @"odpt:railway",
                                  nil];
            [preds addObject:pred];
        }
    
        // 複数APIアクセス
        [self.dataProvider requestSequentialAccessWithOwner:nil withPredicates:preds block:^(NSArray<id> *p_ary) {
            
            NSMutableDictionary *retDict = [[NSMutableDictionary alloc] init];
            
            for(int i=0; i<[m_tnum count]; i++){
                NSString *trainNumber = [m_tnum objectAtIndex:i];
                NSArray *ary = [p_ary objectAtIndex:i];
            
                if([ary count] == 0 || ary == nil){
                    [retDict setObject:[NSNull null] forKey:trainNumber];
                }else{
                    NSDictionary *rec = [ary objectAtIndex:0];
                    [retDict setObject:rec forKey:trainNumber];
                }
            }
            
            block([retDict copy]) ;
        }];
    
    }else if([shortLineIdentifier isEqualToString:@"odpt.Railway:TokyoMetro.Yurakucho"]){
        NSMutableDictionary *retDict = [[NSMutableDictionary alloc] init];
        for(int i=0; i<[m_tnum count]; i++){
            NSString *trainNumber = [m_tnum objectAtIndex:i];
            [retDict setObject:@[] forKey:trainNumber];
        }
        block([retDict copy]);
        return;
    }
    
    block(nil);
}
*/

- (void) makeObjectOfLineIdentifier:(NSString *)LineIdentifier ForArray:(NSArray *)ary Block:(void (^)(NSManagedObjectID *))block {
    
    __block NSManagedObjectID *moID = nil;
    
    NSMutableSet *calendarIdentsSet = [[NSMutableSet alloc] init]; // 重複防止
    
    for(int k=0; k<[ary count]; k++){
        // weekday, holiday などで複数存在するはず。
        NSDictionary *dict = [ary objectAtIndex:k];
        NSString *calendarIdent = [dict objectForKey:@"odpt:calendar"];
        [calendarIdentsSet addObject:calendarIdent];
    }
    
    NSArray *calendarIdents = [calendarIdentsSet allObjects];
    //NSAssert([calendarIdents count] > 0, @"timetableLine record is zero. ident:%@", LineIdentifier);
    if([calendarIdents count] == 0){
        
        
        NSManagedObjectContext *moc = [self.dataManager managedObjectContextForConcurrent];
        
        [moc performBlockAndWait:^{
            
            // CoreData DBから書き換えるべき object を受け取る。
            NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"TimetableLineSet"];
            [request setPredicate:[NSPredicate predicateWithFormat:@"ofLine == %@", LineIdentifier]];
            
            NSError *error = nil;
            NSArray *results = [moc executeFetchRequest:request error:&error];
            
            if (results == nil) {
                NSLog(@"Error fetching objects: %@\n%@", [error localizedDescription], [error userInfo]);
                abort();
                return;
            }
            
            if([results count] == 0){
                NSLog(@"can't find TrainTimetable Object %@", self.lineIdentifier);
                abort();
            }
            
            NSManagedObject *timeTableLineSetObject = [results objectAtIndex:0];
            
            // Save the context.
            if (![moc save:&error]) {
                // Replace this implementation with code to handle the error appropriately.
                // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
                abort();
            }
           // [self.dataManager saveContext]; // 永続保管
            
            moID = [timeTableLineSetObject objectID];
        }];
        block(moID);
        
        return;
    }
    
    NSMutableArray *loaders = [[NSMutableArray alloc] init];
    for(int i=0; i<[calendarIdents count]; i++){
        NSString *calendarIdent = calendarIdents[i];
        ODPTDataLoaderCalendar *j = [[ODPTDataLoaderCalendar alloc] initWithCalendar:calendarIdent Block:nil];
        [loaders addObject:j];
        
        j.dataProvider = self.dataProvider;
        j.dataManager = self.dataManager;
        
    }
    
    __block ODPTDataLoaderArray *job = [[ODPTDataLoaderArray alloc] initWithLoaders:loaders Block:^(NSArray<NSManagedObjectID *> *calendarAry) {
        
        if(ary == nil){
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
        
            // NSInteger type = [self lineTypeForLineIdentifier:self.lineIdentifier];
        
            // CoreData DBから書き換えるべき object を受け取る。
            NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"TimetableLineSet"];
            [request setPredicate:[NSPredicate predicateWithFormat:@"ofLine == %@", LineIdentifier]];
            
            NSError *error = nil;
            NSArray *results = [moc executeFetchRequest:request error:&error];
            
            if (results == nil) {
                NSLog(@"Error fetching objects: %@\n%@", [error localizedDescription], [error userInfo]);
                abort();
                return;
            }
            
            if([results count] == 0){
                NSLog(@"can't find TrainTimetable Object %@", self.lineIdentifier);
                abort();
            }
            
            NSManagedObject *timeTableLineSetObject = [results objectAtIndex:0];
            
            NSMutableDictionary *timeTableObjForCalendar = [[NSMutableDictionary alloc] init];
            
            NSInteger index = 0;
            for(int k=0; k<[ary count]; k++){
                // weekday, holiday などで複数存在するはず。
                NSDictionary *dict = [ary objectAtIndex:k];
                NSString *timetableIdentifier = [dict objectForKey:@"owl:sameAs"];
                
                // object entity:TimetableVehicle  を作成・取得。
                // ODPTDataLoaderTimetableVehicle 内のメソッドを利用。
                ODPTDataLoaderTimetableVehicle *loader = [[ODPTDataLoaderTimetableVehicle alloc] initWithTimetableVehicle:timetableIdentifier Block:nil];
                loader.dataManager = self.dataManager;
                
                NSManagedObjectID *moID = [loader makeObjectOfTimetableIdentifier:timetableIdentifier ForDictionary:dict];
                
                NSManagedObject *trainObj = [moc objectWithID:moID];
                
                [trainObj setValue:[NSNumber numberWithInteger:index++] forKey:@"index"];
                
                // timetableLine オブジェクトに trains をセット
                NSString *calendarIdent = [dict objectForKey:@"odpt:calendar"];
                NSManagedObject *timetableLineObj = [timeTableObjForCalendar objectForKey:calendarIdent];
                
                if(timetableLineObj == nil){
                    // 存在しなければ entity: timetableLine のオブジェクトを新たに作る。
                    timetableLineObj = [NSEntityDescription insertNewObjectForEntityForName:@"TimetableLine" inManagedObjectContext:moc];
                    [timetableLineObj setValue:LineIdentifier forKey:@"ofLine"];
                    NSManagedObject *calendarObj = [calendarObjForCalendar objectForKey:calendarIdent];
                    if(calendarObj != nil){
                        [timetableLineObj setValue:calendarObj forKey:@"calendar"];
                    }
                    [timeTableObjForCalendar setObject:timetableLineObj forKey:calendarIdent];
                }
                
                NSMutableOrderedSet *trainSet = [[timetableLineObj valueForKey:@"vehicles"] mutableCopy];
                
                [trainSet addObject:trainObj];
                [timetableLineObj setValue:[trainSet copy] forKey:@"vehicles"];
                
                
            }

            NSMutableSet *timetableLineObjs = [[NSMutableSet alloc] init];
            for(NSManagedObject *timetableLineObj in [timeTableObjForCalendar allValues]){
                [timetableLineObjs addObject:timetableLineObj];
            }
            
            [timeTableLineSetObject setValue:[timetableLineObjs copy] forKey:@"timetableLines"];
    
            [timeTableLineSetObject setValue:[NSDate date] forKey:@"fetchDate"];
    
            // Save the context.
            if (![moc save:&error]) {
                // Replace this implementation with code to handle the error appropriately.
                // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
                abort();
            }
            
            moID = [timeTableLineSetObject objectID];
            
        }];
        
        block(moID);
    }];
    
    job.dataProvider = self.dataProvider;
    job.dataManager = self.dataManager;
    [job setParent:self];
    
    [[self queue] addLoader:job];

}


- (void)requestBy:(id)owner TimetableOfLine:(NSString *)LineIdentifier Block:(void (^)(NSManagedObjectID *))block{
    
    //  CoreData データベースにアクセス。
    
    __block NSManagedObjectID *moID = nil;
    
    NSManagedObjectContext *moc = [self.dataManager managedObjectContextForConcurrent];
    [moc performBlockAndWait:^{
        
        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"TimetableLineSet"];
        [request setPredicate:[NSPredicate predicateWithFormat:@"ofLine == %@", LineIdentifier]];
        
        NSError *error = nil;
        
        NSArray *results = [moc executeFetchRequest:request error:&error];
        
        if (results == nil) {
            NSLog(@"Error fetching objects: %@\n%@", [error localizedDescription], [error userInfo]);
            abort();
        }
        
        if([results count] == 0){
            //  該当する Station の レコードがない。 -> APIへアクセス。
            // レコードが存在しないので、新たに作る。
            
            NSManagedObject *obj = [NSEntityDescription insertNewObjectForEntityForName:@"TimetableLineSet" inManagedObjectContext:moc];
            [obj setValue:LineIdentifier forKey:@"ofLine"];
            // [obj setValue:[NSNumber numberWithInteger:dayType] forKey:@"dayType"];
            
            // Save the context.
            if (![moc save:&error]) {
                NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
                abort();
            }
            
            //[self.dataManager saveContext]; // 永続保管 非同期で。
            
        }else{
            
            NSManagedObject *obj = [results objectAtIndex:0];
            if([self isCompleteObject:obj] == YES){
                moID = [obj objectID];
            }else{
                // 掃除
                NSLog(@"ODPTDataLoaderTimetableLine object incompleted. clean up. ident: %@", self.lineIdentifier);
                NSSet *set = [obj valueForKey:@"timetableLines"];
                NSArray *ary = [set allObjects];
                for(NSManagedObject *tts in ary){
                    [moc deleteObject:tts];
                }
                
                // Save the context.
                if (![moc save:&error]) {
                    NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
                    abort();
                }
                
            }

        }
        
    }];
    
    
    if(moID != nil){
        block(moID);
        return;
    }
    
    
    // 東京メトロ以外の駅は、APIへアクセスしない。
    /*
    if(! [[self operatorIdentifierForLineIdentifier:LineIdentifier] isEqualToString:@"TokyoMetro"]){
        
        NSDictionary *rec = [NSDictionary dictionaryWithObjectsAndKeys:
                             StationIdentifier, @"owl:sameAs",
                             @"", @"dc:title",
                             nil];
        
        [self makeObjectOfLineIdentifier:self.lineIdentifier andDayType:dayType Block:^(NSManagedObjectID *moID) {
            if(moID != nil){
                block(moID);
                return;
            }
        }];
        
        return;
    }
    */
    
    // APIアクセス開始。
    
    __block ODPTDataLoaderLine *job;
    job = [[ODPTDataLoaderLine alloc] initWithLine:self.lineIdentifier Block:^(NSManagedObjectID *moID) {
        
        if(moID == nil){
            // APIアクセスに失敗。
            NSLog(@"ODPTDataLoaderLine return nil. ident:%@", self.lineIdentifier);
            // メインスレッドで実行。
            block(nil);
            return;
        }
        
        NSManagedObjectContext *moc = [self.dataManager managedObjectContextForConcurrent];
        
        //__block NSString *endStationIdentifier;
        __block NSArray *directions;
        
        [moc performBlockAndWait:^{
            NSManagedObject *obj = [moc objectWithID:moID];
            //NSManagedObject *endStationObj = [job endStationForLineObject:obj];
            
            //endStationIdentifier = [endStationObj valueForKey:@"identifier"];
            
            directions  = [job directionIdentifierForLineObject:obj];
        }];
        
        NSMutableArray *preds = [[NSMutableArray alloc] init];
        
        NSInteger type = [self lineTypeForLineIdentifier:self.lineIdentifier];
        if(type == ODPTDataLineTypeRailway){
            
            // railDirectionは複数帰ってくる場合がある。
            // NSMutableArray *railDirections = [[job directionIdentifierForEndStation:endStationIdentifier withLine:self.lineIdentifier] mutableCopy];
            NSArray *railDirections = directions;
            
            NSMutableArray *lineIdentifiers = [[NSMutableArray alloc] init];
            NSString *shortLineIdentifier = [job removeFooterFromLineIdentifier:self.lineIdentifier];

            for(int i=0; i<[railDirections count]; i++){
                [lineIdentifiers addObject:shortLineIdentifier];
            }
            
            for(int i=0; i<[railDirections count]; i++){
                NSDictionary *pred = [NSDictionary dictionaryWithObjectsAndKeys:
                                      @"odpt:TrainTimetable", @"type",
                                      railDirections[i], @"odpt:railDirection",
                                      lineIdentifiers[i], @"odpt:railway",
                                      nil];
                [preds addObject:pred];
            }
            
        }else if(type == ODPTDataLineTypeBus){
            NSDictionary *pred = [NSDictionary dictionaryWithObjectsAndKeys:
                                  @"odpt:BusTimetable", @"type",
                                  self.lineIdentifier, @"odpt:busroutePattern",
                                  nil];
            [preds addObject:pred];
            
        }else{
            NSLog(@"invalid type. line=%@", LineIdentifier);
            abort();
        }
        
        [self.dataProvider requestSequentialAccessWithOwner:owner withPredicates:preds block:^(NSArray<id> *results) {
            
            if(results == nil || [results count] == 0){
                block(nil);
                return;
            }
            
            
            NSMutableArray *nextArray = [[NSMutableArray alloc] init];
            for(int i=0; i<[results count]; i++){
                id obj = [results objectAtIndex:i];
                // NSAssert([obj isKindOfClass:[NSArray class]], @"ODPTDataLoaderTimetableLine return value is abnormal.");
                
                if([obj isKindOfClass:[NSNull class]] == YES){
                    // いくつかアクセスに失敗した -> アクセス失敗とみなす
                    block(nil);
                    return;
                }
                
                [nextArray addObjectsFromArray:obj];
            }
            
            //NSLog(@"railDirection:%@ count:%d", railDirections[i], [ary count]);
            
            [self makeObjectOfLineIdentifier:self.lineIdentifier ForArray:nextArray Block:^(NSManagedObjectID *moID) {
                block(moID) ;
                return;
            }];
            
        }];
        
    }];
    
    job.dataProvider = self.dataProvider;
    job.dataManager = self.dataManager;
    
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
    return [NSString stringWithFormat:@"TimetableLine_%@", self.lineIdentifier];
}

- (void)main{
    if([self isCancelled] == YES){
        [self setFailure];
        [self startCallBack];
        [self completeOperation];
        return;
    }
    
    
    [self requestBy:self TimetableOfLine:self.lineIdentifier Block:^(NSManagedObjectID *moID) {
        
        if(moID == nil || [self isCancelled] == YES){
            NSLog(@"ODPTDataLoaderTimetableLine requestStations returns nil or cancelled. ident:%@", self.lineIdentifier);
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

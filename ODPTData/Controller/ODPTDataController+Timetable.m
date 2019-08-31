//
//  ODPTDataController+Timetable.m
//
//  Copyright (c) 2019 Takehito Ikema
//
//  This software is released under the MIT License.
//  https://opensource.org/licenses/mit-license.php
//
#import "ODPTDataController+Timetable.h"
#import "ODPTDataLoaderTimetableStation.h"
#import "ODPTDataLoaderTimetableLine.h"
#import "ODPTDataLoaderArray.h"
#import "ODPTDataLoaderCalendar.h"
#import "ODPTDataLoaderTrainType.h"
#import "EfficientLoaderQueue.h"

@implementation ODPTDataController (Timetable)

- (void)requestWithOwner:(id _Nullable)owner StationTimetableOfLineArray:(NSArray<NSString *> *)lineIdentifiers atStationArray:(NSArray<NSString *> *)stationIdentifiers atDepartureTime:(NSDate *)departureTime Block:(void (^)(NSArray<NSDictionary *> * _Nullable))block {
    
    [self innerRequestWithOwner:owner StationTimetableAllRecordsOfLineArray:lineIdentifiers atStationArray:stationIdentifiers atDepartureTime:departureTime Block:^(NSArray<NSDictionary *> *timeTableArray, NSDictionary *statusDict) {
        
        NSCalendar* calendar = [NSCalendar currentCalendar];
        NSDateComponents* components = [calendar components:NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond fromDate:departureTime];
        
        NSInteger hour = components.hour;
        NSInteger minute = components.minute;
        NSInteger second = components.second;
        if(hour < 4){
            hour += 24;
        }
        float departureTime = hour * 3600 + minute * 60 + second;
        
        NSMutableArray *ret = [[NSMutableArray alloc] init];
        
        if([timeTableArray count] > 0){
            int p = 0;
            for(; p<[timeTableArray count]; p++){
                NSDictionary *dict = timeTableArray[p];
                
                float time =  [[dict objectForKey:@"timeHour"] floatValue] * 3600 + [[dict objectForKey:@"timeMinute"] floatValue] * 60 + [[dict objectForKey:@"timeSecond"] floatValue] ;
                
                float interval = time - departureTime;
                if(interval > 0){
                    break;
                }
            }
            
            // NSLog(@"p:%d / %d", p, (int)[table count]);
            int i = 0;
            for(; i<self.searchCountOfTimetable; i++){
                
                if(p+i < [timeTableArray count]){
                    NSDictionary *dict = timeTableArray[p+i];
                    [ret addObject:dict];
                }
            }
            
            if(p+i >= [timeTableArray count]){
                NSDictionary *dict = @{@"last":[NSNumber numberWithBool:YES]};
                [ret addObject:dict];
            }
        }
        
        // メインスレッドで実行。
        dispatch_async(
                       dispatch_get_main_queue(),
                       ^{
                           block([ret copy]);
                       });
    }];
    
}



- (void)requestWithOwner:(id _Nullable)owner TrainTimetableOfLine:(NSString *)lineIdentifier atStation:(NSString *)stationIdentifier atDepartureTime:(NSDate *)departureTime Block:(void (^)(NSArray<NSDictionary *> * _Nullable))block {
    
    __block NSMutableArray *ret = [[NSMutableArray alloc] init];
    
    if(departureTime == nil){
        // メインスレッドで実行。
        dispatch_async(
                       dispatch_get_main_queue(),
                       ^{
                           block(@[]);
                       });
        return;
    }
    
    __block ODPTDataLoaderTimetableLine *job;
    job = [[ODPTDataLoaderTimetableLine alloc] initWithLine:lineIdentifier Block:^(NSManagedObjectID *moID) {
        
        if(moID == nil){
            // APIアクセスに失敗。
            NSLog(@"ODPTDataLoaderTimetableLine return nil. ident:%@", lineIdentifier);
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
                    NSLog(@"requestTrainTimetableOfLine nil calendar detect. line:%@ sta:%@", lineIdentifier, stationIdentifier);
                }
            }
            
            NSManagedObject *timetableObj = nil;
            NSString *hitCalendarIdent = nil;
            if([calendars count] > 0){
                hitCalendarIdent = [job applicableCalendarIdentifierForDate:departureTime fromCalendars:calendars];
                
                for(int j=0; j<[timetableLines count]; j++){
                    NSManagedObject *calendarObject = [timetableLines[j] valueForKey:@"calendar"];
                    NSString *calendarIdent = [calendarObject valueForKey:@"identifier"];
                    NSLog(@"xx ci:%@", calendarIdent);
                    
                    if([calendarIdent isEqualToString:hitCalendarIdent] == YES){
                        timetableObj = timetableLines[j];
                        break;
                    }
                }
            }
            
            NSArray *vehicles = nil;
            if(timetableObj == nil){
                NSLog(@"requestTrainTimetableOfLine detect cannot find timetableObj for now calendar. l:%@ s:%@ c:%@", lineIdentifier, stationIdentifier, hitCalendarIdent);
                vehicles = @[];
            }else{
                NSOrderedSet *set = [timetableObj valueForKey:@"vehicles"];
                vehicles = [set array];
            }
            
            
            NSMutableDictionary *diffs = [[NSMutableDictionary alloc] init];
            for(int p=0; p<[vehicles count]; p++){
                NSManagedObject *vehicle = vehicles[p];  // vehicle は TimeTableVehicle エンティティ
                
                NSNumber *vehicleIndex = [vehicle valueForKey:@"index"];
                NSString *key = [NSString stringWithFormat:@"%@", vehicleIndex];
                
                NSOrderedSet *records = [vehicle valueForKey:@"records"];
                for(int i=0; i<[records count]; i++){
                    NSManagedObject *record = [records objectAtIndex:i];
                    
                    if([stationIdentifier isEqualToString:[record valueForKey:@"atStation"]] == YES){
                        
                        NSTimeInterval interval = [job timeIntervalOfTimetableRecord:record SinceDate:departureTime];
                        [diffs setObject:[NSNumber numberWithDouble:interval] forKey:key];
                        //NSLog(@"  index:%@  time:%@:%@", [train valueForKey:@"index"], [record valueForKey:@"timeHour"], [record valueForKey:@"timeMinute"]);
                        break;
                    }
                }
            }
            
            NSArray *sortedVehicles = [vehicles sortedArrayUsingComparator:^NSComparisonResult(NSManagedObject *obj1, NSManagedObject *obj2) {
                // obj1/obj2 は TimeTableTrain エンティティ
                NSString *index1 = [NSString stringWithFormat:@"%@", [obj1 valueForKey:@"index"] ];
                NSString *index2 = [NSString stringWithFormat:@"%@", [obj2 valueForKey:@"index"] ];
                
                if( [[diffs objectForKey:index1] doubleValue] < [[diffs objectForKey:index2] doubleValue]){
                    return NSOrderedAscending;
                }else{
                    return NSOrderedDescending;
                }
            }];
            
            if([sortedVehicles count] > 0){
                int p = 0;
                for(; p<[sortedVehicles count]; p++){
                    NSManagedObject *vehicle = sortedVehicles[p];
                    NSString *key = [NSString stringWithFormat:@"%@", [vehicle valueForKey:@"index"] ];
                    
                    double interval = [[diffs objectForKey:key] doubleValue];
                    if(interval > 0){
                        break;
                    }
                }
                
                int i = 0;
                for(; i<self.searchCountOfTimetable; i++){
                    if(p+i < [sortedVehicles count]){
                        NSManagedObject *vehicle = sortedVehicles[p+i];
                        NSDictionary *dict = [job dictionaryForTrainTimetable:vehicle];
                        [ret addObject:dict];
                    }
                }
                
                if(p+i >= [sortedVehicles count]){
                    NSDictionary *dict = @{@"last":[NSNumber numberWithBool:YES]};
                    [ret addObject:dict];
                }
            }
            
        }];
        
        // メインスレッドで実行。
        dispatch_async(
                       dispatch_get_main_queue(),
                       ^{
                           block([ret copy]);
                       });
    }];
    
    job.dataProvider = self->dataProvider;
    job.dataManager = self->APIDataManager;
    [job setOwner:owner];
    
    [self->queue addLoader:job];
}

- (void)requestWithOwner:(id _Nullable)owner StationTimetableAllRecordsOfLineArray:(NSArray<NSString *> *)lineIdentifiers atStationArray:(NSArray<NSString *> *)stationIdentifiers atDepartureTime:(NSDate *)departureTime Block:(void (^)(NSArray<NSDictionary *> * _Nullable, NSDictionary * _Nullable))block{
    
    [self innerRequestWithOwner:owner StationTimetableAllRecordsOfLineArray:lineIdentifiers atStationArray:stationIdentifiers atDepartureTime:departureTime Block:^(NSArray<NSDictionary *> *timeTableArray, NSDictionary *statusDict) {
        
        // メインスレッドで実行。
        dispatch_async(
                       dispatch_get_main_queue(),
                       ^{
                           block(timeTableArray, statusDict);
                       });
    }];
}

- (void)innerRequestWithOwner:(id _Nullable)owner StationTimetableAllRecordsOfLineArray:(NSArray<NSString *> *)lineIdentifiers atStationArray:(NSArray<NSString *> *)stationIdentifiers atDepartureTime:(NSDate *)departureTime Block:(void (^)(NSArray<NSDictionary *> * _Nullable, NSDictionary * _Nullable))block{
    
    NSMutableArray *jobs = [[NSMutableArray alloc] init];
    for(int i=0; i<[lineIdentifiers count]; i++){
        NSString *lineIdent = [lineIdentifiers objectAtIndex:i];
        NSString *stationIdent = [stationIdentifiers objectAtIndex:i];
        
        if([lineIdent isKindOfClass:[NSString class]] == YES &&
           [stationIdent isKindOfClass:[NSString class]] == YES){
            ODPTDataLoaderTimetableStation *job;
            
            job = [[ODPTDataLoaderTimetableStation alloc] initWithLine:lineIdent andStation:stationIdent Block:nil];
            
            job.dataProvider = self->dataProvider;
            job.dataManager = self->APIDataManager;
            
            [jobs addObject:job];
        }
    }
    
    if([jobs count] == 0){
        block(@[], @{});
        return;
    }
    
    __block ODPTDataLoaderArray *aLoader = [[ODPTDataLoaderArray alloc] initWithLoaders:jobs Block:^(NSArray<NSManagedObjectID *> *moIDs) {
        
        if(moIDs == nil){
            // APIアクセスに失敗。
            NSLog(@"ODPTDataLoaderArray return nil.");
            block(nil, nil);
            return;
        }
        
        __block NSMutableDictionary *statusDict = [[NSMutableDictionary alloc] init];
        NSMutableArray *timetableArray = [[NSMutableArray alloc] init];
        
        NSManagedObjectContext *moc = [self->APIDataManager managedObjectContextForConcurrent];
        
        [moc performBlockAndWait:^{
            NSMutableArray *ttObjs = [[NSMutableArray alloc] init];
            for(int i=0; i<[moIDs count]; i++){
                NSManagedObjectID *moID = [moIDs objectAtIndex:i];
                NSManagedObject *timetableSetObj = [moc objectWithID:moID];  // entity: timetableStationSet
                
                NSArray *timetableStations = [[timetableSetObj valueForKey:@"timetableStations"] allObjects];
                
                // departureDate に対してマッチする calendarを選ぶ -> hitCalendarIdent
                NSMutableDictionary *calendars = [[NSMutableDictionary alloc] init];
                for(int j=0; j<[timetableStations count]; j++){
                    NSManagedObject *timetableObj = timetableStations[j];
                    NSManagedObject *calendarObject = [timetableObj valueForKey:@"calendar"];
                    NSString *calendarIdent = [calendarObject valueForKey:@"identifier"];
                    [calendars setObject:calendarObject forKey:calendarIdent];
                }
                // NSLog(@" requestStationTimetableOfLine line:%@ station:%@", lineIdentifier, stationIdentifierForTimetable);
                
                NSManagedObject *timetableObj = nil;
                if([calendars count] > 0){
                    NSString *hitCalendarIdent = nil;
                    hitCalendarIdent = [aLoader applicableCalendarIdentifierForDate:departureTime fromCalendars:[calendars allValues]];
                    
                    for(int j=0; j<[timetableStations count]; j++){
                        NSManagedObject *calendarObject = [timetableStations[j] valueForKey:@"calendar"];
                        NSString *calendarIdent = [calendarObject valueForKey:@"identifier"];
                        
                        if([calendarIdent isEqualToString:hitCalendarIdent] == YES){
                            timetableObj = timetableStations[j];
                            
                            NSString *locale = [[NSLocale preferredLanguages] objectAtIndex:0];
                            
                            // カレンダータイトルを作成.
                            NSString *title = nil;
                            NSString *key = @"title_en";
                            if([locale hasPrefix:@"ja"] == YES){
                                key = @"title_ja";
                                NSString *calendarTitle = [calendarObject valueForKey:key];
                                title = [NSString stringWithFormat:@"%@ ダイヤ", calendarTitle];
                            }else{
                                NSString *calendarTitle = [calendarObject valueForKey:key];
                                title = [NSString stringWithFormat:@"%@ Schedule", calendarTitle];
                            }
                            
                            [statusDict setObject:title forKey:@"title"];
                            
                            break;
                        }
                    }
                }
                
                if(timetableObj != nil){
                    [ttObjs addObject:timetableObj];
                }
            }
            
            for(int i=0; i<[ttObjs count]; i++){
                NSManagedObject *obj = ttObjs[i];
                
                NSOrderedSet *records = [obj valueForKey:@"records"];
                NSArray *table = [records array];
                
                for(int p=0; p<[table count]; p++){
                    NSManagedObject *record = table[p];
                    
                    NSDictionary *dict = [aLoader dictionaryForStationTimetableRecord:record];
                    [timetableArray addObject:dict];
                }
            }
            
            NSInteger objCount = [ttObjs count];
            [statusDict setObject:[NSNumber numberWithInteger:objCount] forKey:@"dataCount"];
            
            if(objCount >= 2){
                // 複数データを合成している場合はタイトル変更
                [statusDict setObject:NSLocalizedString(@"multiple_diagram", @"") forKey:@"calendarTitle"];
            }
            
        }];
        
        // 時間順に並び替え
        NSArray *sortedTimetableArray = [timetableArray sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *dict1, NSDictionary *dict2) {
            
            float time1 =  [[dict1 objectForKey:@"timeHour"] floatValue] * 3600 + [[dict1 objectForKey:@"timeMinute"] floatValue] * 60 + [[dict1 objectForKey:@"timeSecond"] floatValue] ;
            float time2 =  [[dict2 objectForKey:@"timeHour"] floatValue] * 3600 + [[dict2 objectForKey:@"timeMinute"] floatValue] * 60 + [[dict2 objectForKey:@"timeSecond"] floatValue] ;
            
            if( time1 < time2){
                return NSOrderedAscending;
            }else{
                return NSOrderedDescending;
            }
        }];
        
        block(sortedTimetableArray, [statusDict copy]);
        
    }];
    
    aLoader.dataProvider = self->dataProvider;
    aLoader.dataManager = self->APIDataManager;
    [aLoader setOwner:owner];
    
    [self->queue addLoader:aLoader];
}

- (void) requestWithOwner:(id _Nullable)owner ApplicableCalendarForDate:(NSDate *)date fromCalendars:(NSArray<NSString *> *)calendars Block:(void (^)(NSString * _Nullable))block{
    
    if(calendars == nil || [calendars count] == 0 || date == nil){
        NSAssert(NO, @"requestApplicableDate invalid.");
    }
    
    NSMutableArray *loaders = [[NSMutableArray alloc] init];
    
    for(int i=0; i<[calendars count]; i++){
        NSString *calendarIdent = calendars[i];
        ODPTDataLoaderCalendar *j = [[ODPTDataLoaderCalendar alloc] initWithCalendar:calendarIdent Block:nil];
        
        j.dataProvider = self->dataProvider;
        j.dataManager = self->APIDataManager;
        
        [loaders addObject:j];
    }
    
    __block ODPTDataLoaderArray *job = [[ODPTDataLoaderArray alloc] initWithLoaders:loaders Block:^(NSArray<NSManagedObjectID *> *ary) {
        
        if(ary == nil){
            // APIアクセスに失敗。
            NSLog(@"ODPTDataLoaderCalendar return nil. ");
            // メインスレッドで実行。
            dispatch_async(
                           dispatch_get_main_queue(),
                           ^{
                               block(nil);
                           }
                           );
            return;
        }
        
        
        
        __block NSString *hitCalendarIdent = nil;
        
        NSManagedObjectContext *moc = [self->APIDataManager managedObjectContextForConcurrent];
        [moc performBlockAndWait:^{
            NSMutableArray *objArray = [[NSMutableArray alloc] init];
            
            for(int k=0; k<[ary count]; k++){
                NSManagedObjectID *moID = ary[k];
                
                NSManagedObject *obj = [moc objectWithID:moID];
                [objArray addObject:obj];
            }
            
            hitCalendarIdent = [job applicableCalendarIdentifierForDate:date fromCalendars:objArray];
        }];
        
        // メインスレッドで実行。
        dispatch_async(
                       dispatch_get_main_queue(),
                       ^{
                           block(hitCalendarIdent);
                       }
                       );
        return;
        
        
    }];
    
    job.dataProvider = dataProvider;
    job.dataManager = APIDataManager;
    
    [self->queue addLoader:job];
}

- (void)requestWithOwner:(id _Nullable)owner TrainTypeTitleForTrainTypeIdentifier:(NSString *)trainTypeIdentifier Block:(void (^)(NSString * _Nullable))block{
    NSAssert(trainTypeIdentifier != nil, @"requestTrainTypeTitle  identifier is nil");
    
    __block ODPTDataLoaderTrainType *job;
    
    job = [[ODPTDataLoaderTrainType alloc] initWithTrainType:trainTypeIdentifier Block:^(NSManagedObjectID *moID) {
        
        if(moID == nil){
            // APIアクセスに失敗。
            NSLog(@"ODPTDataLoaderTrainType return nil. ident:%@", trainTypeIdentifier);
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
        
        __block NSString *retTitle = nil;
        
        NSString *locale = [[NSLocale preferredLanguages] objectAtIndex:0];
        __block NSString *localePrefix = @"en";
        if([locale hasPrefix:@"ja"] == YES){
            localePrefix = @"ja";
        }
        
        [moc performBlockAndWait:^{
            NSManagedObject *mo = [moc objectWithID:moID];
            NSString *key = [@"title_" stringByAppendingString:localePrefix];
            retTitle = [mo valueForKey:key];
        }];
        
        // メインスレッドで実行。
        dispatch_async(
                       dispatch_get_main_queue(),
                       ^{
                           block(retTitle);
                       }
                       );
        
    }];
    
    job.dataProvider = dataProvider;
    job.dataManager = APIDataManager;
    [job setOwner:owner];
    
    [self->queue addLoader:job];
}



@end

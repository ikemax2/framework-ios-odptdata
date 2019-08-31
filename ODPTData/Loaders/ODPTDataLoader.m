//
//  ODPTDataLoader.m
//
//  Copyright (c) 2018 Takehito Ikema
//
//  This software is released under the MIT License.
//  https://opensource.org/licenses/mit-license.php
//
#import <MapKit/MapKit.h>
#import "ODPTDataLoader.h"
#import "ODPTDataAdditional.h"


@implementation ODPTDataLoader{
    
}


- (id)init{
    if(self = [super init]){
        
    }
    
    return self;
}

- (void) cancelAction{
    // このローダーによるアクセスをキャンセル
    [self.dataProvider cancelAccessForOwner:self];
    
}


- (void) main{
    
    NSAssert(self.dataManager != nil, @"ODPTDataLoader dataManager is nil! ");
    NSAssert(self.dataProvider != nil, @"ODPTDataLoader URL Accessor is nil! ");
    
}


- (BOOL)stringIsDigit:(NSString *)text{
    NSCharacterSet *digitCharSet = [NSCharacterSet characterSetWithCharactersInString:@"0123456789"];
    
    NSScanner *aScanner = [NSScanner localizedScannerWithString:text];
    [aScanner setCharactersToBeSkipped:nil];
    
    [aScanner scanCharactersFromSet:digitCharSet intoString:NULL];
    return [aScanner isAtEnd];
    
}

- (NSInteger)identifierTypeForIdentifier:(NSString *)identifier{
    
    NSInteger type = ODPTDataIdentifierTypeUndefined;
    
    //
    NSArray *f = [identifier componentsSeparatedByString:@":"];
    NSAssert([f count] == 2, @"identifierTypeForIdentifier identifier is invalid. %@", identifier);
    

    if( [f[0] hasPrefix:@"odpt.Railway"] == YES ){
        type = ODPTDataIdentifierTypeLine;
    }else if( [f[0] hasPrefix:@"odpt.BusroutePattern"] == YES ){
        type = ODPTDataIdentifierTypeLine;
    }else if( [ f[0] hasPrefix:@"odpt.Station"] == YES ){
        type = ODPTDataIdentifierTypeStation;
    }else if( [ f[0] hasPrefix:@"odpt.BusstopPole"] == YES ){
        type = ODPTDataIdentifierTypeStation;
    }else{
        // そのほか
        NSLog(@"Station Class invalid Identifier!!");
    }

    return type;
}

- (NSInteger)stationTypeForStationIdentifier:(NSString *)StationIdentifier{
    
    NSInteger type = ODPTDataStationTypeUndefined;
    
    //鉄道かバスか
    NSArray *f = [StationIdentifier componentsSeparatedByString:@":"];
    NSAssert([f count] == 2, @"stationTypeForLineIdentifier identifier is invalid. %@", StationIdentifier);
    
    if( [ [f objectAtIndex:0] containsString:@"Station"] == YES ){
        // 鉄道
        type = ODPTDataStationTypeTrainStop;
    }else if( [ [f objectAtIndex:0] containsString:@"Bus"] == YES ){
        // バス
        type = ODPTDataStationTypeBusStop;
    }else{
        // そのほか
        NSLog(@"Station Class invalid Identifier!!");
    }
    
    return type;
}

- (NSInteger)lineTypeForLineIdentifier:(NSString *)LineIdentifier{
    
    NSInteger type = ODPTDataLineTypeUndefined;
    //鉄道かバスか
    NSArray *f = [LineIdentifier componentsSeparatedByString:@":"];
    NSAssert([f count] == 2, @"lineTypeForLineIdentifier identifier is invalid. %@", LineIdentifier);
    
    if( [ [f objectAtIndex:0] containsString:@"Railway"] == YES ){
        // 鉄道
        type = ODPTDataLineTypeRailway;
    }else if( [ [f objectAtIndex:0] containsString:@"Bus"] == YES ){
        // バス
        type = ODPTDataLineTypeBus;
    }else{
        // そのほか
        NSLog(@"Line Class invalid Identifier!! ident:%@", LineIdentifier);
    }
    
    return type;
    
}

- (NSString *)operatorIdentifierForLineIdentifier:(NSString *)LineIdentifier{
    
    NSArray *f = [LineIdentifier componentsSeparatedByString:@":"];
    
    NSAssert([f count] == 2, @"operatorIdentifierForLineIdentifier identifier is invalid.");
    
    NSArray *g = [f[1] componentsSeparatedByString:@"."];
    
    NSString *mstr = [NSString stringWithFormat:@"odpt.Operator:%@", g[0]];
    
    return mstr;
}

// 未使用
- (NSString *)operatorIdentifierForStationIdentifier:(NSString *)StationIdentifier{
    
    NSArray *f = [StationIdentifier componentsSeparatedByString:@":"];
    
    NSAssert([f count] == 2, @"operatorIdentifierForStationIdentifier identifier is invalid.");
    
    NSArray *g = [f[1] componentsSeparatedByString:@"."];
    
    return g[0];
}

// 与えた文字列が、緯度・経度を表す文字列（小数）か、確認し、NSNumber クラスに変換。
- (double)convertLocationDataString:(id)text{
    
    if([text isKindOfClass:[NSNull class]] ){
        // NSLog(@"isLocationDataString NSNull class object detect.");
        return 0.0f;
    }else if([text isKindOfClass:[NSNumber class]]){
        return [(NSNumber *)text doubleValue];
        
    }else if([text isKindOfClass:[NSString class]]){
        // 文字列の内容を確認
        NSCharacterSet *digitCharSet = [NSCharacterSet characterSetWithCharactersInString:@"0123456789."];
        
        NSScanner *aScanner = [NSScanner localizedScannerWithString:text];
        [aScanner setCharactersToBeSkipped:nil];
        
        [aScanner scanCharactersFromSet:digitCharSet intoString:NULL];
        if([aScanner isAtEnd]){
            // 文字列は数値。
            return [(NSString *)text doubleValue];
            
        }
    }
    
    return 0.0f;
    
    
}

- (NSString *)reverseDirectingLineForLineIdentifier:(NSString *)l{
    
    // 逆向きの路線を取得。
    NSString *l_reverse;
    NSRange range = [l rangeOfString:@"." options:NSBackwardsSearch];
    NSString *lb = [l substringToIndex:range.location];
    NSString *lf = [l substringFromIndex:range.location+1];
    if([lf isEqualToString:@"1"]){
        l_reverse = [lb stringByAppendingString:@".2"];
    }else{
        l_reverse = [lb stringByAppendingString:@".1"];
    }
    
    //NSLog(@"l:%@",l);
    //NSLog(@"lf:%@",lf);
    //NSLog(@"l_reverse:%@",l_reverse);
    return l_reverse;
}

- (NSString *)busRouteIdentifierFromBusRoutePatternIdentifier:(NSString *)brpIdentifier{
    // busRoutePattern 識別子から busRoute 識別子を得る
    
    NSArray *f = [brpIdentifier componentsSeparatedByString:@":"];
    NSArray *g = [f[1] componentsSeparatedByString:@"."];
    
    NSString *mstr = [NSString stringWithFormat:@"odpt.Busroute:%@.%@", g[0], g[1]];
    
    return mstr;
}

// 方向を表す番号を得る  identifier末尾の数字 1 or 2

- (NSInteger)directionNumberForLineIdentifier:(NSString *)lineIdent{
    
    NSArray *f = [lineIdent componentsSeparatedByString:@":"];
    NSAssert([f count] == 2, @"directionNumberForLineIdentifier identifier is invalid. %@", lineIdent);
    
    NSArray *g = [f[1] componentsSeparatedByString:@"."];
    
    NSString *operator = g[0];
    
    NSInteger directionNum = ODPTDataLoaderDirectionNumberNotDefined;
    
    if([operator isEqualToString:@"TokyuBus"] == YES){

    }else{
        NSUInteger cnum = [lineIdent rangeOfString:@"." options:NSBackwardsSearch].location;
        NSString *direction = [lineIdent substringFromIndex:cnum+1];
        
        directionNum = [direction integerValue];
        if(directionNum == 1 || directionNum == 2){
        }else{
            directionNum = ODPTDataLoaderDirectionNumberNotDefined;
        }
    }
    
    return directionNum;
}


- (CLLocationDistance)distanceFromPoint:(CLLocationCoordinate2D)pointA toPoint:(CLLocationCoordinate2D)pointB{
    MKMapPoint mkPointA = MKMapPointForCoordinate(pointA);
    MKMapPoint mkPointB = MKMapPointForCoordinate(pointB);
    
    CLLocationDistance distance = MKMetersBetweenMapPoints(mkPointA, mkPointB);
    
    return distance;
}

#pragma mark - NSManagedObject Utility
- (NSArray<NSManagedObject *> *)stationArrayForLineObject:(NSManagedObject *)object{
    // objectは Lineエンティティ
    NSAssert([object.entity.name isEqualToString:@"Line"], @"endStationForLine entity type is invalid.");
    
    NSString *order = [object valueForKey:@"stationOrder"];
    NSArray *f = [order componentsSeparatedByString:@","];
    
    NSOrderedSet *set = [object valueForKey:@"stations"];
    
    NSMutableArray *dicArray = [[NSMutableArray alloc] init];
    for(int i=0; i < [f count]; i++){
        int index = [f[i] intValue];
        
        NSAssert(index < [set count], @"stationArrayForLineObject count error.");
        NSAssert(index >= 0, @"stationArrayForLineObject count error.");
        
        NSManagedObject *station = [set objectAtIndex:index];
        NSAssert(station != nil, @"stationArrayForLineObject station object is nil!!");
        [dicArray addObject:station];
    }
    
    return [dicArray copy];
}

- (NSArray<NSNumber *> *)stationDuplicationArrayForLineObject:(NSManagedObject *)object{
    // objectは Lineエンティティ
    NSAssert([object.entity.name isEqualToString:@"Line"], @"endStationForLine entity type is invalid.");
    
    NSString *order = [object valueForKey:@"stationOrder"];
    NSArray *f = [order componentsSeparatedByString:@","];
    
    NSString *dupString = [object valueForKey:@"duplication"];
    NSArray *ds = nil;
    if(dupString != nil){
        NSMutableArray *dsn = [[NSMutableArray alloc] init];
        NSArray *dst = [dupString componentsSeparatedByString:@","];
        for(int i=0; i<[dst count]; i++){
            NSString *str = dst[i];
            [dsn addObject:[NSNumber numberWithInteger:[str integerValue]]];
        }
        ds = [dsn copy];
        
    }else{
        NSMutableArray *dsc = [[NSMutableArray alloc] init];
        for(int i=0; i<[f count]; i++){
            [dsc addObject:@0];
        }
        ds = [dsc copy];
    }
    NSAssert([f count] == [ds count], @"stationDictArray illegal duplication count.");
    
    return ds;
}

// 始発駅を返す。
- (NSManagedObject *)startStationForLineObject:(NSManagedObject *)object{
    // objectは Lineエンティティ
    NSAssert([object.entity.name isEqualToString:@"Line"], @"startStationForLine entity type is invalid.");
    
    NSString *order = [object valueForKey:@"stationOrder"];
    NSArray *f = [order componentsSeparatedByString:@","];
    
    NSOrderedSet *set = [object valueForKey:@"stations"];
    
    //NSLog(@"set: %@", set);
    if([set count] == 0){
        // object に stationsがセットされていない。 API対象外の路線など。
        return nil;
    }
    
    int index = [[f firstObject] intValue];
    
    NSAssert(index < [set count], @"stationArrayForLineObject count error. index:%d, count:%lu", index, (unsigned long)[set count]);
    NSAssert(index >= 0, @"stationArrayForLineObject count error. index:%d", index);
    
    NSManagedObject *station = [set objectAtIndex:index];
    
    return station;
}

// 終着駅を返す。
- (NSManagedObject *)endStationForLineObject:(NSManagedObject *)object{
    // objectは Lineエンティティ
    NSAssert([object.entity.name isEqualToString:@"Line"], @"endStationForLineObject entity type is invalid.");
    
    NSString *order = [object valueForKey:@"stationOrder"];
    NSArray *f = [order componentsSeparatedByString:@","];
    
    NSOrderedSet *set = [object valueForKey:@"stations"];
    
    //NSLog(@"set: %@", set);
    if([set count] == 0){
        // object に stationsがセットされていない。 API対象外の路線など。
        return nil;
        
    }
    
    int index = [[f lastObject] intValue];
        
    NSAssert(index < [set count], @"endStationForLineObject count error. index:%d, count:%lu at line: %@", index, (unsigned long)[set count], [object valueForKey:@"identifier"]);
    NSAssert(index >= 0, @"endStationForLineObject count error. index:%d at %@", index, [object valueForKey:@"identifier"]);
    
    NSManagedObject *station = [set objectAtIndex:index];
    
    return station;
}


// 直通路線を返す。
- (NSArray<NSDictionary *> *) directConnectingLinesForLineObject:(NSManagedObject *)obj{

    NSMutableArray *retArray = [[NSMutableArray alloc] init];
    
    NSString *stsString = [obj valueForKey:@"directConnectingStationNumbers"];
    NSArray *sts = nil;
    if([stsString length] > 0){
        sts = [stsString componentsSeparatedByString:@","];
    }else{
        return retArray;
    }
    //NSLog(@"directConnectingLinesForLineObject sts:%@", stsString);
    
    NSOrderedSet *set = [obj valueForKey:@"directConnectingToLines"];
    //NSLog(@"directConnectingLinesForLineObject dconLines count:%d", [set count]);
    
    NSOrderedSet *stations = [obj valueForKey:@"stations"];
    //NSLog(@"directConnectingLinesForLineObject station count:%d", [stations count]);

    for(int i=0; i<[sts count]; i++){
        NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
        int index = [sts[i] intValue];
        NSAssert(index >= 0 && index < [stations count], @"directConnectingLinesForLineObject index error. index:%d",index   );
        NSManagedObject *s = [stations objectAtIndex:index];

        [dict setObject:[s valueForKey:@"identifier"] forKey:@"station"];
        NSManagedObject *dcObj = [set objectAtIndex:i];
        [dict setObject:dcObj forKey:@"directConnectingToLine"];
        
        [retArray addObject:dict];
    }
    //NSLog(@"retArray count:%d", [retArray count]);
    return [retArray copy];
}

// 路線の停車駅に、特定の駅が含まれるか、確認する。
- (NSString *) connectStationOfLine:(NSManagedObject *)lineObject forStation:(NSManagedObject *)stationObject{
    NSAssert([stationObject.entity.name isEqualToString:@"Station"], @"isContainStation entity type is invalid.");
    NSString *stationIdent  = [stationObject valueForKey:@"identifier"];
    
    return [self connectStationOfLine:lineObject forStationIdentifier:stationIdent];
}
    
- (NSString *) connectStationOfLine:(NSManagedObject *)lineObject forStationIdentifier:(NSString *)stationIdent{

    NSAssert([lineObject.entity.name isEqualToString:@"Line"], @"isContainStation entity type is invalid.");
    
    NSOrderedSet *set = [lineObject valueForKey:@"stations"];
    NSArray *ary = [set array];

    for(int i=0; i<[ary count]; i++){
        NSManagedObject *s = [ary objectAtIndex:i];
        if( [[ODPTDataAdditional sharedData] isConnectStation:[s valueForKey:@"identifier"] andStation:stationIdent] ){
            NSLog(@"connectStationOfLine : %@ <- %@", [s valueForKey:@"identifier"], stationIdent);
            return [s valueForKey:@"identifier"];
        }
    }
    NSLog(@"connectStationOfLine : nil <- %@", stationIdent);
    return nil;
}

// 時間差を秒で返す。
// 正であれば、 date よりも recordObject記載の時刻の方が未来。
- (NSTimeInterval) timeIntervalOfTimetableRecord:(NSManagedObject *)recordObject SinceDate:(NSDate *)date{
    
    NSAssert([recordObject.entity.name isEqualToString:@"TimetableStationRecord"] ||
             [recordObject.entity.name isEqualToString:@"TimetableVehicleRecord"] ,
              @"timeIntervalOfTimetableRecord: entity type is invalid.");
    
    // NSCalendar を取得
    NSCalendar* calendar = [NSCalendar currentCalendar];
    
    // 取得したい要素を表すフラグをつけて、NSDateComponents を取得。
    NSDateComponents* components = [calendar components:NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond fromDate:date];
    
    NSInteger hour = components.hour;
    NSInteger minute = components.minute;
    NSInteger second = components.second;
    
    if(hour < 4){
        hour += 24;
    }
    
    NSInteger sHour = [[recordObject valueForKey:@"timeHour"] integerValue];
    NSInteger sMinute = [[recordObject valueForKey:@"timeMinute"] integerValue];
    NSInteger sSecond = [[recordObject valueForKey:@"timeSecond"] integerValue];

    
    return (NSTimeInterval) (sHour*3600+sMinute*60+sSecond) - (hour*3600+minute*60+second) ;
    
}


-(NSDictionary *)dictionaryForStationTimetableRecord:(NSManagedObject *)recordObject{
    NSAssert([recordObject.entity.name isEqualToString:@"TimetableStationRecord"], @"dictionaryForStationTimetableRecord: entity type is invalid.");
    
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
    
    NSArray *keys = @[@"index", @"timeHour", @"timeMinute", @"timeSecond", @"destination", @"trainType"];
    for(NSString *key in keys){
        id val = [recordObject valueForKey:key];
        if(val != nil){
            [dict setObject:val forKey:key];
        }
    }
    
    return [dict copy];
}


-(NSDictionary *)dictionaryForTrainTimetable:(NSManagedObject *)vehicleObject{
    NSAssert([vehicleObject.entity.name isEqualToString:@"TimetableVehicle"], @"dictionaryForVehicleTimetable: entity type is invalid.");
    
    NSMutableDictionary *vehicleDict = [[NSMutableDictionary alloc] init];
    
    NSOrderedSet *records = [vehicleObject valueForKey:@"records"];
    
    NSMutableArray *ary = [[NSMutableArray alloc] init];
    for(int i=0; i<[records count]; i++){
        NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
        NSManagedObject *recordObject = [records objectAtIndex:i];
        
        [dict setObject:[recordObject valueForKey:@"index"] forKey:@"index"];
        [dict setObject:[recordObject valueForKey:@"timeHour"] forKey:@"timeHour"];
        [dict setObject:[recordObject valueForKey:@"timeMinute"] forKey:@"timeMinute"];
        [dict setObject:[recordObject valueForKey:@"timeSecond"] forKey:@"timeSecond"];
        [dict setObject:[recordObject valueForKey:@"atStation"] forKey:@"atStation"];
        [dict setObject:[recordObject valueForKey:@"isArrival"] forKey:@"isArrival"];
        [ary addObject:dict];
    }
    

    [vehicleDict setObject:ary forKey:@"records"];
    
    NSArray *keys = @[@"ofLine", @"trainNumber", @"index"];
    for(NSString *key in keys){
        id value = [vehicleObject valueForKey:key];
        if(value != nil){
            [vehicleDict setObject:value forKey:key];
        }
    }
        
    return [vehicleDict copy];
}


- (BOOL)isValidDateOfObject:(NSManagedObject *)object{
    
    if([object.entity.name isEqualToString:@"LineInformation"] ||
       [object.entity.name isEqualToString:@"TrainLocationArray"]){
        
        NSDate *validDate = [object valueForKey:@"validDate"];
        
        //NSLog(@"interval: %f", interval);
        
        if([validDate timeIntervalSinceNow] > 0){
            return YES;
        }
    }else if([object.entity.name isEqualToString:@"TrainType"]){
        
        NSDate *fetchDate = [object valueForKey:@"fetchDate"];
        
        // NSLog(@"trainType valid: %lf", [fetchDate timeIntervalSinceNow]);
        if([fetchDate timeIntervalSinceNow] > -604800){
            return YES;
        }
        
    }else{
        NSAssert(NO, @"isValidDateOfObject: entity type is invalid.");
    }

    return NO;
}

-(NSDictionary *)dictionaryForTrainLocation:(NSManagedObject *)trainLocationObject{
    NSAssert([trainLocationObject.entity.name isEqualToString:@"TrainLocation"], @"dictionaryForTrainLocation: entity type is invalid.");
    
    NSMutableDictionary *trainLocationDict = [[NSMutableDictionary alloc] init];
    
    NSArray *keys = @[@"trainNumber", @"startingStation", @"terminalStation", @"fromStation", @"toStation"];
    for(NSString *key in keys){
        NSString *value = [trainLocationObject valueForKey:key];
        if(value != nil){
            [trainLocationDict setObject:value forKey:key];
        }
    }
    
    NSNumber *delay = [trainLocationObject valueForKey:@"delay"];
    if(delay != nil){
        [trainLocationDict setObject:delay forKey:@"delay"];
    }
    
    return [trainLocationDict copy];
}


- (NSDictionary *)dictionaryForStation:(NSManagedObject *)stationObject{
 
    NSArray *keys = [[[stationObject entity] attributesByName] allKeys];
    NSMutableDictionary *dict = [[stationObject dictionaryWithValuesForKeys:keys] mutableCopy];
    
    // operator レコードはカンマ区切り。
    NSString *operatorString = [stationObject valueForKey:@"operator"];
    if(operatorString  != nil){
        NSArray *f = [operatorString componentsSeparatedByString:@","];
        [dict setObject:f forKey:@"operator"];
    }
    
    return dict;
}


- (NSString *)stationTitleForStationObject:(NSManagedObject *)stationObject{
    
    NSString *title = nil;
    NSString *stitleJA = [stationObject valueForKey:@"title_ja"];
    NSString *stitleEN = [stationObject valueForKey:@"title_en"];
    
    NSAssert(stitleJA != nil || stitleEN != nil, @"stationTitleForStationObject cannot find station title. ident:%@", [stationObject valueForKey:@"identifier"]);
    
    NSString *locale = [[NSLocale preferredLanguages] objectAtIndex:0];
    
    if([locale hasPrefix:@"ja"] == YES){
        if(stitleJA != nil){
            title = stitleJA;
        }
    }else{
        if(stitleEN != nil){
            title = stitleEN;
        }
        
    }
    
    return title;
}


- (NSString *)lineTitleForLineObject:(NSManagedObject *)lineObject{
    

    NSString *stitleJA = [lineObject valueForKey:@"title_ja"];
    NSString *stitleEN = [lineObject valueForKey:@"title_en"];
    
    NSAssert(stitleJA != nil || stitleEN != nil, @"lineTitleForLineObject cannot find line title. ident:%@", [lineObject valueForKey:@"identifier"]);
    
    
    NSString *lineIdentifier = [lineObject valueForKey:@"identifier"];
    NSInteger lineType = [self lineTypeForLineIdentifier:lineIdentifier];
    
    NSString *locale = [[NSLocale preferredLanguages] objectAtIndex:0];
    NSString *lineTitle = nil;
    if([locale hasPrefix:@"ja"] == YES){
        if(stitleJA != nil){
            lineTitle = stitleJA;
        }
    }else{
        if(stitleEN != nil){
            lineTitle = stitleEN;
        }
    }
    
    NSString *operatorIdentifier = [lineObject valueForKey:@"operator"];
    
    NSAssert(operatorIdentifier != nil, @"operatorIdentifier must be not nil!! line:%@", lineIdentifier);
    
    NSString *operatorTitle = nil;
    operatorTitle = [[ODPTDataAdditional sharedData] operatorHeaderForIdentifier:operatorIdentifier];
    
    if([operatorIdentifier isEqualToString:@"odpt.Operator:Toei"]){
        // operator:toei の場合の例外処理
        if(lineType == ODPTDataLineTypeRailway){
            if([lineIdentifier containsString:@"NipporiToneri"]){
                // 日暮里舎人ライナー
                operatorTitle = @"";
            }else if([lineIdentifier containsString:@"Arakawa"]){
                // 都電荒川線
                operatorTitle = @"";
            }else{
                // "都営地下鉄"
                operatorTitle = NSLocalizedString(@"toei_subway", @"");
            }
        }else if(lineType == ODPTDataLineTypeBus){
            operatorTitle = NSLocalizedString(@"toei_bus", @"");
        }
    }else if([operatorIdentifier isEqualToString:@"odpt.Operator:Tobu"]){
        // 特定の路線だけ prefixをつけない
        if([lineIdentifier containsString:@"TobuSkytreeBranch"] ||
           [lineIdentifier containsString:@"TobuSkytree"] ||
           [lineIdentifier containsString:@"TobuUrbanPark"]){
            operatorTitle = @"";
        }
        
    }else if([operatorIdentifier isEqualToString:@"odpt.Operator:Keikyu"]){
        // 京急本線だけは prefixをつけない
        if([lineIdentifier containsString:@"Main"]){
            operatorTitle = @"";
        }

    }else if([operatorIdentifier isEqualToString:@"odpt.Operator:Keisei"]){
        // 京成本線だけは prefixをつけない
        if([lineIdentifier containsString:@"Main"]){
            operatorTitle = @"";
        }
        
    }else if([operatorIdentifier isEqualToString:@"odpt.Operator:Keio"]){
        // 京王本線・京王新線だけはprefixをつけない
        if([lineIdentifier containsString:@"Keio.Keio"]){
            operatorTitle = @"";
        }else if([lineIdentifier containsString:@"Keio.KeioNew"]){
            operatorTitle = @"";
        }
    }
    
    NSString *retStr = @"";
    if([locale hasPrefix:@"ja"] == YES){
        retStr = [operatorTitle stringByAppendingString:lineTitle];
    }else{
        retStr = [NSString stringWithFormat:@"%@ %@", operatorTitle, lineTitle];
    }
    
    return retStr;
    
}

- (NSString *) applicableCalendarIdentifierForDate:(NSDate *)date fromCalendars:(NSArray<NSManagedObject *> *)calendarObjects{
    
    NSAssert(calendarObjects != nil && [calendarObjects count] > 0, @"applicableCalendarForDate calendars is invalid");
    NSAssert(date != nil, @"applicableCalendarForDate date is nil");
    
    // NSLog(@"applicableCalendarIdentifier date:%@", date);
    
    NSCalendar *calendar = [NSCalendar currentCalendar];
    // 時を取得
    NSUInteger flags = NSCalendarUnitHour | NSCalendarUnitWeekday;
    NSDateComponents *comps = [calendar components:flags fromDate:date];
    
    // 曜日を取得
    NSInteger wday = comps.weekday;  // 1が日曜日 7が土曜日
    
    // 今の時刻が午前0時よりあとで、午前4時よりまえの場合は前日の曜日で考える。
    if(comps.hour < 4){
        
        if( --wday <= 0 ){
            wday = 7;
        }
        
        // 1日デクリメント
        NSDateComponents *diffs = [[NSDateComponents alloc] init];
        [diffs setDay:-1];
        
        date = [calendar dateByAddingComponents:diffs toDate:date options:0];
    }
    //NSLog(@"applicableCalendarIdentifier date(modified):%@", date);
    //NSLog(@"applicableCalendarIdentifier date wday:%d", wday);
    
    __block NSString *hitCalendarIdent = nil;
    
    NSMutableArray *cal_l0 = [[NSMutableArray alloc] init];
    NSMutableArray *cal_l1 = [[NSMutableArray alloc] init];
    NSMutableArray *cal_l2 = [[NSMutableArray alloc] init];
    __block NSMutableArray *cal_l3 = [[NSMutableArray alloc] init];
    for(int i=0; i<[calendarObjects count]; i++){
        NSManagedObject *obj = calendarObjects[i];
        NSString *ident = [obj valueForKey:@"identifier"];
        
        if([ident hasPrefix:@"odpt.Calendar:Specific"] == YES){
            [cal_l3 addObject:calendarObjects[i]];
        }else if([ident hasPrefix:@"odpt.Calendar:Weekday"] == YES){
            [cal_l0 addObject:calendarObjects[i]];
        }else if([ident hasPrefix:@"odpt.Calendar:Holiday"] == YES){
            [cal_l1 addObject:calendarObjects[i]];
        }else if([ident hasPrefix:@"odpt.Calendar:SaturdayHoliday"] == YES){
            [cal_l1 addObject:calendarObjects[i]];
        }else{
            [cal_l2 addObject:calendarObjects[i]];
        }
    }
    
    NSMutableArray *cal_p = [[NSMutableArray alloc] init];
    [cal_p addObjectsFromArray:cal_l0];
    [cal_p addObjectsFromArray:cal_l1];
    [cal_p addObjectsFromArray:cal_l2];
    
    NSArray *wdays = @[@"Sunday", @"Monday", @"Tuesday", @"Wednesday", @"Thursday", @"Friday", @"Saturday", @"Weekday", @"Holiday", @"SaturdayHoliday"];
    
    for(int k=0; k<[cal_p count]; k++){
        NSManagedObject *obj = cal_p[k];
        NSString *ident = [obj valueForKey:@"identifier"];
        //NSLog(@"applicableCalendarIdentifier cal_p: %@", ident);
        // __block BOOL (^sub)(NSDate *, NSString *) = ^(NSDate *date, NSString *identDetail) {
        NSArray *f = [ident componentsSeparatedByString:@":"];
        NSString *identDetail = f[1];
        
        BOOL flag = NO;
        
        for(int i=0; i<[wdays count]; i++){
            if([identDetail isEqualToString:wdays[i]] == YES){
                if(i>=0 && i<=6){
                    if(wday == i+1){
                        flag = YES;
                    }
                }else if(i == 7){ // weekday
                    if(wday >= 2 && wday <= 6){
                        flag = YES;
                    }
                    
                }else if(i == 8){ // holiday
                    if([[ODPTDataAdditional sharedData] isHolidayForDate:date]== YES || wday == 1){
                        flag = YES;
                    }
                    
                }else if(i == 9){ // saturday and holiday
                    if([[ODPTDataAdditional sharedData] isHolidayForDate:date]== YES || wday == 7 || wday == 1){
                        flag = YES;
                    }
                    
                }
                break;
            }
        }
        
        if(flag == YES){
            hitCalendarIdent = ident;
        }
    }
    
    
    if([cal_l3 count] == 0){
        return hitCalendarIdent;
        
    }else{
        
        for(int k=0; k<[cal_l3 count]; k++){
                
            NSString *duration = nil;
            NSString *day = nil;
            NSString *ident = nil;
            
            NSManagedObject *obj = cal_l3[k];
            ident = [obj valueForKey:@"identifier"];
            duration = [obj valueForKey:@"duration"];
            day = [obj valueForKey:@"day"];
            
            
            // duration チェック
            BOOL durationValid = YES;
            if(duration != nil){
                durationValid = NO;
                NSArray *d = [duration componentsSeparatedByString:@"/"];
                
                NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
                
                // フォーマットを文字列で指定
                [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm"];
                
                // 文字列からNSDateオブジェクトを生成
                // 開始日の早朝4時
                NSMutableString *startStr = [NSMutableString stringWithFormat:@"%@ 04:00", d[0]];
                NSDate *durationStartDate = [dateFormatter dateFromString:startStr];
                
                // 終了日翌日の深夜2時
                NSMutableString *endStr = [NSMutableString stringWithFormat:@"%@ 02:00", d[1]];
                NSDate *dmyDate = [dateFormatter dateFromString:endStr];
                NSDate *durationEndDate = [dmyDate dateByAddingTimeInterval:3600*24];
                
                if([date timeIntervalSinceDate:durationStartDate] > 0 && [date timeIntervalSinceDate:durationEndDate] < 0){
                    durationValid = YES;
                }
            }
            
            if(durationValid == NO){
                continue;
            }
            
            // day チェック
            BOOL dayValid = YES;
            if(day != nil){
                dayValid = NO;
                NSArray *d = [day componentsSeparatedByString:@","];
                
                // フォーマットを文字列で指定
                NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
                dateFormatter.dateFormat = @"yyyy-MM-dd";
                NSString *dateString = [dateFormatter stringFromDate:date];
                for(int i=0; i<[d count]; i++){
                    if([dateString isEqualToString:d[i]] == YES){
                        dayValid = YES;
                        break;
                    }
                }
            }
            
            if(dayValid == NO){
                continue;
            }
            
            hitCalendarIdent = ident;
            break;
        }
        
        return hitCalendarIdent;                
    }
}

- (NSArray <NSString *> *)directionIdentifierForLineObject:(NSManagedObject *)lineObject{

    NSString *lineIdentifier = [lineObject valueForKey:@"identifier"];
    NSString *directionIdent = [lineObject valueForKey:@"direction"];
    
    
    NSMutableArray *retArray = [[NSMutableArray alloc] init];
    
    if([directionIdent isKindOfClass:[NSString class]] == NO || [directionIdent length] == 0){
     
    }else{
        [retArray addObject:directionIdent];
    }
    
    return [retArray copy];
}

#pragma mark - API Extention Utility 
// 独自拡張
// 独自に拡張した　LineIdentifierを元に戻す。
- (NSString *) removeFooterFromLineIdentifier:(NSString *)LineIdentifier{
    
    
    if([LineIdentifier hasPrefix:@"odpt.Railway:"] == YES){
        
        NSArray *f = [LineIdentifier componentsSeparatedByString:@"."];
        NSAssert([f count] == 5, @"removeFooterFromLineIdentifier format Error. %@", LineIdentifier);
        
        NSMutableString *newStr = [[NSMutableString alloc] init];
        for(int i=0; i<[f count]-2; i++){
            if(i != 0){
                [newStr appendString:@"."];
            }
            [newStr appendString:f[i]];
        }

        return [newStr copy];
    }
    
    return LineIdentifier;
}

- (BOOL)isExtensionLineIdentifier:(NSString *)ident{
    
    if([ident hasPrefix:@"odpt.Railway:"] == YES){
        NSArray *f = [ident componentsSeparatedByString:@"."];
        int fcount = (int)[f count];
        
        if( [f[fcount-1] length] == 1 && [self stringIsDigit:f[fcount-1]]== YES){
            if( [f[fcount-2] length] == 1 && [self stringIsDigit:f[fcount-2]]== YES){
                return YES;
            }else{
                // NSLog(@"XXXX");
                return NO;
            }
        }
        
    }
    
    return YES;
}

- (void) setLineInformationExtentionFor:(NSManagedObject *)object OfIdentifier:(NSString *)lineIdentifier{
    
    // LineColorの処理。 一時的に、ローカルファイルを参照する。

    NSString *shortLineIdentifier = [self removeFooterFromLineIdentifier:lineIdentifier];
    NSString *color = [[ODPTDataAdditional sharedData] colorStringForLine:shortLineIdentifier];
    if(color != nil){
        [object setValue:color forKey:@"color"];
    }
    
    // 循環線の処理
    if([lineIdentifier containsString:@"JR-East.Yamanote"]){
        [object setValue:[NSNumber numberWithBool:YES] forKey:@"circulation"];
    }
    
}

- (NSArray *)adjustStationOrder:(NSArray *)stations ExtentionOfIdentifier:(NSString *)LineIdentifier{
    
    // APIへアクセス可能でなければ、内部データから stationOrder を返す。
    if(! [self isAbleToAccessAPIOfLine:LineIdentifier]){
        return [[ODPTDataAdditional sharedData] stationOrderForOtherLine:LineIdentifier];
    }
    
    /*
    if([LineIdentifier containsString:@"JR-East.UenoTokyo"] == YES){
        
        // 上野東京ライン。
        //   1. 東海道線 - 高崎線  系統    stationOrder index 1 -> 23, 51->55, 104->129
        //   2. 東海道線 - 宇都宮線  系統    stationOrder index 24 -> 50, 23, 51->55, 104->129
        //   3. 東海道線 - 常磐線  系統    stationOrder index 56 -> 88, 98->103, 55, 104->106
        //   4. 東海道線 - 成田線  系統    stationOrder index 89 -> 97, 88, 98->104, 55, 104->106
        if([LineIdentifier containsString:@"JR-East.UenoTokyo.1"] == YES){
            
            NSMutableArray *newStations = [[NSMutableArray alloc] init];
            NSRange range = NSMakeRange(1-1, (23-1)-(1-1) + 1);
            [newStations addObjectsFromArray:[stations subarrayWithRange:range]];
            range = NSMakeRange(51-1, (55-1)-(51-1) + 1);
            [newStations addObjectsFromArray:[stations subarrayWithRange:range]];
            range = NSMakeRange(104-1, (129-1)-(104-1) + 1);
            [newStations addObjectsFromArray:[stations subarrayWithRange:range]];
            
            return [newStations copy];
            
            
        }else if([LineIdentifier containsString:@"JR-East.UenoTokyo.2"] == YES){
            
            NSMutableArray *newStations = [[NSMutableArray alloc] init];
            NSRange range = NSMakeRange(24-1, (50-1)-(24-1) + 1);
            [newStations addObjectsFromArray:[stations subarrayWithRange:range]];
            [newStations addObject:stations[23-1]];
            
            range = NSMakeRange(51-1, (55-1)-(51-1) + 1);
            [newStations addObjectsFromArray:[stations subarrayWithRange:range]];
            range = NSMakeRange(104-1, (129-1)-(104-1) + 1);
            [newStations addObjectsFromArray:[stations subarrayWithRange:range]];
            
            return [newStations copy];
            
        }else if([LineIdentifier containsString:@"JR-East.UenoTokyo.3"] == YES){
            
            NSMutableArray *newStations = [[NSMutableArray alloc] init];
            NSRange range = NSMakeRange(56-1, (88-1)-(56-1) + 1);
            [newStations addObjectsFromArray:[stations subarrayWithRange:range]];
            range = NSMakeRange(98-1, (103-1)-(98-1) + 1);
            [newStations addObjectsFromArray:[stations subarrayWithRange:range]];
            
            [newStations addObject:stations[55-1]];
            
            range = NSMakeRange(104-1, (106-1)-(104-1) + 1);
            [newStations addObjectsFromArray:[stations subarrayWithRange:range]];
            
            return [newStations copy];
        }else if([LineIdentifier containsString:@"JR-East.UenoTokyo.4"] == YES){
            
            NSMutableArray *newStations = [[NSMutableArray alloc] init];
            NSRange range = NSMakeRange(89-1, (97-1)-(89-1) + 1);
            [newStations addObjectsFromArray:[stations subarrayWithRange:range]];
            [newStations addObject:stations[88-1]];
            range = NSMakeRange(98-1, (103-1)-(98-1) + 1);
            [newStations addObjectsFromArray:[stations subarrayWithRange:range]];
            [newStations addObject:stations[55-1]];
            range = NSMakeRange(104-1, (106-1)-(104-1) + 1);
            [newStations addObjectsFromArray:[stations subarrayWithRange:range]];
            
            return [newStations copy];
        }
        return stations;
    }else if([LineIdentifier containsString:@"JR-East.NaritaExpress"] == YES){
        // 成田エクスプレス (成田線より前に）
        if([LineIdentifier containsString:@"JR-East.NaritaExpress.1"] == YES){
            
        }else if([LineIdentifier containsString:@"JR-East.NaritaExpress.2"] == YES){
            
        }else if([LineIdentifier containsString:@"JR-East.NaritaExpress.3"] == YES){
            
        }
        
        return stations;
        
    }else if([LineIdentifier containsString:@"JR-East.Keiyo"] == YES){
        // 京葉線
        //   1. 本線 東京 - 蘇我    1->17
        //   2. 武蔵野線連絡　東京 - 市川塩浜　- 西船橋  1->9, 18
        //   3. 武蔵野線連絡　西船橋 - 南船橋　- 蘇我   18, 11->17
        if([LineIdentifier containsString:@"JR-East.Keiyo.1"] == YES){
            
            NSMutableArray *newStations = [[NSMutableArray alloc] init];
            NSRange range = NSMakeRange(1-1, (17-1)-(1-1) + 1);
            [newStations addObjectsFromArray:[stations subarrayWithRange:range]];
            
            return [newStations copy];
            
        }else if([LineIdentifier containsString:@"JR-East.Keiyo.2"] == YES){
            
            NSMutableArray *newStations = [[NSMutableArray alloc] init];
            NSRange range = NSMakeRange(1-1, (9-1)-(1-1) + 1);
            [newStations addObjectsFromArray:[stations subarrayWithRange:range]];
            [newStations addObject:stations[18-1]];
            
            return [newStations copy];
        }else if([LineIdentifier containsString:@"JR-East.Keiyo.3"] == YES){
            
            NSMutableArray *newStations = [[NSMutableArray alloc] init];
            [newStations addObject:stations[18-1]];
            NSRange range = NSMakeRange(11-1, (17-1)-(11-1) + 1);
            [newStations addObjectsFromArray:[stations subarrayWithRange:range]];
            
            return [newStations copy];
        }
        
        return stations;

    }
     
     */
    if([LineIdentifier containsString:@"JR-East.Chuo"] == YES){
        // 中央本線
        //   1. 本線 高尾 - 塩尻   1->38
        //   2. 辰野支線 岡谷 - 辰野 - 塩尻  36, 39->42, 38
        if([LineIdentifier containsString:@"JR-East.Chuo.1"] == YES){
            
            NSMutableArray *newStations = [[NSMutableArray alloc] init];
            NSRange range = NSMakeRange(1-1, (38-1)-(1-1) + 1);
            [newStations addObjectsFromArray:[stations subarrayWithRange:range]];
            
            return [newStations copy];
        }else if([LineIdentifier containsString:@"JR-East.Chuo.2"] == YES){
                
            NSMutableArray *newStations = [[NSMutableArray alloc] init];
            [newStations addObject:stations[36-1]];
            NSRange range = NSMakeRange(1-1, (42-1)-(39-1) + 1);
            [newStations addObjectsFromArray:[stations subarrayWithRange:range]];
            [newStations addObject:stations[38-1]];
            return [newStations copy];
        }
        
        return stations;
        
    }else if([LineIdentifier containsString:@"JR-East.Keiyo"] == YES){
        // 京葉線
        //   1. 本線 東京 - 蘇我    1->17
        //   2. 武蔵野線支線　市川塩浜　- 西船橋  9, 18
        //   3. 武蔵野線支線　西船橋 - 南船橋   18, 11
        if([LineIdentifier containsString:@"JR-East.Keiyo.1"] == YES){
            
            NSMutableArray *newStations = [[NSMutableArray alloc] init];
            NSRange range = NSMakeRange(1-1, (17-1)-(1-1) + 1);
            [newStations addObjectsFromArray:[stations subarrayWithRange:range]];
            
            return [newStations copy];
            
        }else if([LineIdentifier containsString:@"JR-East.Keiyo.2"] == YES){
            
            NSMutableArray *newStations = [[NSMutableArray alloc] init];
            [newStations addObject:stations[9-1]];
            [newStations addObject:stations[18-1]];
            
            return [newStations copy];
        }else if([LineIdentifier containsString:@"JR-East.Keiyo.3"] == YES){
            
            NSMutableArray *newStations = [[NSMutableArray alloc] init];
            [newStations addObject:stations[18-1]];
            [newStations addObject:stations[11-1]];
            
            return [newStations copy];
        }
        
        return stations;
        
    }else if([LineIdentifier containsString:@"JR-East.Yamanote"] == YES){
        
        NSMutableArray *newStations = [stations mutableCopy];
        [newStations removeLastObject];
        
        return [newStations copy];
        
    }else{
        return stations;
    }
    
}

- (BOOL)isLineIdentifierDownwardExtention:(NSString *)ident{
    
    if([ident hasPrefix:@"odpt.Railway:"] == YES){
        NSArray *f = [ident componentsSeparatedByString:@"."];
        int fcount = (int)[f count];
        
        if( [f[fcount-1] length] == 1 && [self stringIsDigit:f[fcount-1]]== YES){
            if([f[fcount-1] isEqualToString:@"2"] == YES){
                return YES;
            }
        }
    }
    
    return NO;
}


- (BOOL) isAbleToAccessAPIOfLine:(NSString *)LineIdentifier{
    BOOL ret = NO;
    
    NSInteger lineType = [self lineTypeForLineIdentifier:LineIdentifier];
    if(lineType == ODPTDataLineTypeRailway){
        ret = [[ODPTDataAdditional sharedData] isAbleToAccessAPIOfRailway:LineIdentifier];
            
    }else if(lineType == ODPTDataLineTypeBus){
        ret = YES;
    }

    return ret;
}


- (NSArray *)addAllSuffixLineIdentifierExtension:(NSString *)ident{
    
    NSMutableArray *allIdents = [[NSMutableArray alloc] init];
    NSArray *f1 = [self addLevel1SuffixLineIdentifierExtension:ident];
    
    for(NSString *s in f1){
        NSArray *f2 = [self addLevel2SuffixLineIdentifierExtension:s];
        
        for(NSString *r in f2){
            [allIdents addObject:r];
        }
    }

    return [allIdents copy];
}

    
// 独自拡張　LineIdentifier の拡張　　APIにないLineIdentifier を内部的に用いる。adjustStationOrder: と内容を合わせる必要がある。
// 第1階層(路線系統)の追加

- (NSArray *)addLevel1SuffixLineIdentifierExtension:(NSString *)ident{
    
    NSArray *f = [ident componentsSeparatedByString:@"."];
    int fcount = (int)[f count];
    
    NSInteger status = 0;
    if( [f[fcount-1] length] == 1 && [self stringIsDigit:f[fcount-1]]== YES){
        if( [f[fcount-2] length] == 1 && [self stringIsDigit:f[fcount-2]]== YES){
            status = 2;  // Identifier には、Level1/Level2 の小番がつけられている。
        }else{
            status = 1; // Identifier には、Level1 の小番がつけられている。
        }
    }
    
    if(status >= 1){
        return nil;
    }
    
    if([ident hasPrefix:@"odpt.Railway:"] == YES){
        NSArray *p = [ident componentsSeparatedByString:@":"];
        NSString *identShort = p[1];
        
        if([identShort isEqualToString:@"JR-East.Keiyo"] == YES){
            // 京葉線
            //   1. 本線 東京 - 蘇我    1->17
            //   2. 武蔵野線支線　市川塩浜　- 西船橋  9, 18
            //   3. 武蔵野線支線　西船橋 - 南船橋   18, 11
            
            NSMutableArray *retAry = [[NSMutableArray alloc] init];
            NSMutableString *retStr = [[NSMutableString alloc] init];
            [retStr appendString:ident];
            [retStr appendString:@".1"];
            [retAry addObject:retStr];
            
            retStr = [[NSMutableString alloc] init];
            [retStr appendString:ident];
            [retStr appendString:@".2"];
            [retAry addObject:retStr];
            
            retStr = [[NSMutableString alloc] init];
            [retStr appendString:ident];
            [retStr appendString:@".3"];
            [retAry addObject:retStr];
            
            return retAry;
            
        }else if([identShort isEqualToString:@"JR-East.Chuo"] == YES){
         
            //   1. 本線 高尾 - 塩尻   1->38
            //   2. 辰野支線 岡谷 - 辰野 - 塩尻  36, 39->42, 38
            NSMutableArray *retAry = [[NSMutableArray alloc] init];
            NSMutableString *retStr = [[NSMutableString alloc] init];
            [retStr appendString:ident];
            [retStr appendString:@".1"];
            [retAry addObject:retStr];
            
            retStr = [[NSMutableString alloc] init];
            [retStr appendString:ident];
            [retStr appendString:@".2"];
            [retAry addObject:retStr];
            
            return retAry;
            
        }
            /*
        if([identShort isEqualToString:@"JR-East.ShonanShinjuku"] == YES){
            
            // 湘南新宿ライン・上野東京ラインへの対応
            //  湘南新宿ライン　-> 1. 東海道線 - 高崎線  系統　　と 2. 横須賀線 - 宇都宮線 系統　の2つに分けて追加する。
            NSMutableArray *retAry = [[NSMutableArray alloc] init];
            NSMutableString *retStr = [[NSMutableString alloc] init];
            [retStr appendString:ident];
            [retStr appendString:@".1"];
            [retAry addObject:retStr];
            
            retStr = [[NSMutableString alloc] init];
            [retStr appendString:ident];
            [retStr appendString:@".2"];
            [retAry addObject:retStr];
            
            return retAry;
        }else if([identShort isEqualToString:@"JR-East.UenoTokyo"] == YES){
            // 上野東京ライン。
            //   1. 東海道線 - 高崎線  系統
            //   2. 東海道線 - 宇都宮線  系統
            //   3. 東海道線 - 常磐線  系統
            //   4. 東海道線 - 成田線  系統
            NSMutableArray *retAry = [[NSMutableArray alloc] init];
            NSMutableString *retStr = [[NSMutableString alloc] init];
            [retStr appendString:ident];
            [retStr appendString:@".1"];
            [retAry addObject:retStr];
            
            retStr = [[NSMutableString alloc] init];
            [retStr appendString:ident];
            [retStr appendString:@".2"];
            [retAry addObject:retStr];
            
            retStr = [[NSMutableString alloc] init];
            [retStr appendString:ident];
            [retStr appendString:@".3"];
            [retAry addObject:retStr];
            
            retStr = [[NSMutableString alloc] init];
            [retStr appendString:ident];
            [retStr appendString:@".4"];
            [retAry addObject:retStr];
            
            return retAry;
            
        }else if([identShort isEqualToString:@"JR-East.NaritaExpress"] == YES){
            // 成田エクスプレス
            //   1. 横浜方面  大船 -> 成田空港
            //   2. 大宮方面　大宮 -> 成田空港
            //   3. 高尾方面　高尾 -> 成田空港
            
            NSMutableArray *retAry = [[NSMutableArray alloc] init];
            NSMutableString *retStr = [[NSMutableString alloc] init];
            [retStr appendString:ident];
            [retStr appendString:@".1"];
            [retAry addObject:retStr];
            
            retStr = [[NSMutableString alloc] init];
            [retStr appendString:ident];
            [retStr appendString:@".2"];
            [retAry addObject:retStr];
            
            retStr = [[NSMutableString alloc] init];
            [retStr appendString:ident];
            [retStr appendString:@".3"];
            [retAry addObject:retStr];
            
            return retAry;
            
        }else if([identShort isEqualToString:@"JR-East.Chuo"] == YES){
            // 中央本線
            //   1. 高尾 -> 塩尻
            //   2. 辰野支線  岡谷 - 辰野 - 塩尻
            NSMutableArray *retAry = [[NSMutableArray alloc] init];
            NSMutableString *retStr = [[NSMutableString alloc] init];
            [retStr appendString:ident];
            [retStr appendString:@".1"];
            [retAry addObject:retStr];
            
            retStr = [[NSMutableString alloc] init];
            [retStr appendString:ident];
            [retStr appendString:@".2"];
            [retAry addObject:retStr];
            
        }else{
            NSMutableArray *retAry = [[NSMutableArray alloc] init];
            NSMutableString *retStr = [[NSMutableString alloc] init];
            [retStr appendString:ident];
            [retStr appendString:@".1"];
            [retAry addObject:retStr];
            
            return retAry;
        }
        */
        NSMutableArray *retAry = [[NSMutableArray alloc] init];
        NSMutableString *retStr = [[NSMutableString alloc] init];
        [retStr appendString:ident];
        [retStr appendString:@".1"];
        [retAry addObject:retStr];
        
        return retAry;
    }
    return nil;
}



// 第2階層(上り/下り)の追加
- (NSArray *)addLevel2SuffixLineIdentifierExtension:(NSString *)ident{
    
    NSArray *f = [ident componentsSeparatedByString:@"."];
    int fcount = (int)[f count];
    
    NSInteger status = 0;
    if( [f[fcount-1] length] == 1 && [self stringIsDigit:f[fcount-1]]== YES){
        if( [f[fcount-2] length] == 1 && [self stringIsDigit:f[fcount-2]]== YES){
            status = 2;  // Identifier には、Level1/Level2 の小番がつけられている。
        }else{
            status = 1; // Identifier には、Level1 の小番がつけられている。
        }
    }
    
    if(status >= 2){
        return nil;
    }
    
    
    if([ident hasPrefix:@"odpt.Railway:"] == YES){
        NSMutableArray *retAry = [[NSMutableArray alloc] init];
        [ retAry addObject:[ident stringByAppendingString:@".1"] ];
        
        [ retAry addObject:[ident stringByAppendingString:@".2"] ];
        return retAry;
    }
    
    return nil;
}

@end

//
//  ODPTDataAdditional.m
//
//  Copyright (c) 2018 Takehito Ikema
//
//  This software is released under the MIT License.
//  https://opensource.org/licenses/mit-license.php
//
#import "ODPTDataAdditional.h"
#import "ODPTDataLoader.h"

@implementation ODPTDataAdditional{
    
    NSMutableDictionary *colorForLine;
    NSDictionary *directConnectingLineForLine;
    NSMutableDictionary *connectStationDifferentName;
    
    NSMutableDictionary *stationOrderForOtherLine;
    NSMutableDictionary *lineTitleForOtherLine;
    
    NSMutableDictionary *dayTypeForDate;
    
    NSMutableDictionary *stationTitleMetro;
    NSMutableDictionary *stationTitleOther;
    
    NSMutableDictionary *lineInformationLevel;
    NSMutableDictionary *lineInformationStatusEnglish;
    
    NSMutableDictionary *inaccessibleRailways;
    
    NSMutableDictionary *operatorHeaderForIdentifier;
    
    NSMutableDictionary *lineDirectionForLine;
}

static ODPTDataAdditional *_sharedData = nil;

+ (ODPTDataAdditional *)sharedData{
    if(_sharedData == nil){
        _sharedData = [ODPTDataAdditional new];
    }
    
    return _sharedData;
}

- (id)init{

    self = [super init];
    if (self) {
        //Initialization
        [self clear];
    }
    return self;
}

- (void)clear{
    colorForLine = nil;
    directConnectingLineForLine = nil;
    connectStationDifferentName = nil;
    stationOrderForOtherLine = nil;
    
    lineTitleForOtherLine = nil;
    dayTypeForDate = nil;
    stationTitleMetro = nil;
    stationTitleOther = nil;
    
    inaccessibleRailways = nil;
    operatorHeaderForIdentifier = nil;
}

- (void)initColorForLine{
    
    @synchronized(self){
        NSError *err;
        NSString *path;
        NSString *jsonString;
        NSData *jsonData;
        err = nil;
        
        NSBundle *bundle = [NSBundle bundleForClass:[self class]];
        
        path = [bundle pathForResource:@"line_color.json" ofType:nil];
        jsonString = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&err];
        
        if(err){
            NSLog(@"colorJSONFile read error!! %@",path);
        }
        
        jsonData = [jsonString dataUsingEncoding:NSUnicodeStringEncoding];
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:jsonData
                                                             options:NSJSONReadingAllowFragments
                                                               error:&err];
        if(err){
            NSLog(@"colorJSONFile parse error!! %@",err);
        }
        
        colorForLine = [[NSMutableDictionary alloc] init];
        NSArray *keys = [dict allKeys];
        for(int i=0; i<[keys count]; i++){
            NSString *key = [keys objectAtIndex:i];
            NSMutableString *newIdent = [[NSMutableString alloc] init];
            
            [newIdent appendString:key];
            
            [colorForLine setObject:[dict objectForKey:key] forKey:newIdent];
        }
    }
}

- (NSString *)colorStringForLine:(NSString *)lineIdentifier{
    if(colorForLine == nil){
        [self initColorForLine];
    }
    
    NSArray *s_array = [lineIdentifier componentsSeparatedByString:@":"];
    NSAssert(s_array != nil && [s_array count] == 2, @"colorStringForLine  identifier is invalid. %@", lineIdentifier);
    
    NSString *s_name = [s_array lastObject];
    
    return [colorForLine objectForKey:s_name];
}


- (void)initDirectConnectingLine{
    
    @synchronized(self){
        NSError *err;
        NSString *path;
        NSString *jsonString;
        NSData *jsonData;
        err = nil;
        
        NSBundle *bundle = [NSBundle bundleForClass:[self class]];
        
        path = [bundle pathForResource:@"direct_connecting_line.json" ofType:nil];
        jsonString = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&err];
        
        if(err){
            NSLog(@"directConnectingJSONFile read error!! %@",path);
        }
        
        jsonData = [jsonString dataUsingEncoding:NSUnicodeStringEncoding];
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:jsonData
                                                             options:NSJSONReadingAllowFragments
                                                               error:&err];
        if(err){
            NSLog(@"directConnectingJSONFile parse error!! %@",err);
        }
        
        NSMutableDictionary *ret = [dict mutableCopy];
        
        directConnectingLineForLine = [NSDictionary dictionaryWithDictionary:ret];
    }
}

//　路線名と、駅名を与えて、直通する路線のリストを得る。
- (NSArray *)directConnectionLinesForLine:(NSString *)lineIdentifier AtStation:(NSString *)stationIdentifier{
    
    if(directConnectingLineForLine == nil){
        [self initDirectConnectingLine];
    }
    
    NSArray *s_array = [stationIdentifier componentsSeparatedByString:@":"];
    NSAssert(s_array != nil && [s_array count] == 2, @"directConnectionRailwayForStation is invalid. station:%@", stationIdentifier);
    
    NSArray *l_array = [lineIdentifier componentsSeparatedByString:@":"];
    NSAssert(l_array != nil && [l_array count] == 2, @"directConnectionRailwayForStation is invalid. line:%@", lineIdentifier);
    
    NSString *l_name = [l_array lastObject];
    
    
    // ex. l_name = JR-East.Tokaido.1.2
    NSDictionary *cons = [directConnectingLineForLine objectForKey:l_name];
    
    NSMutableArray *sret = [[NSMutableArray alloc] init];
    
    NSArray *cStations = [cons allKeys];      // ex. cStation = @[@"JR-East.Tokaido.Tokyo", @"JR-East.Tokaido.Ofuna"]
    for(int i=0; i<[cStations count]; i++){
        NSString *key = [cStations objectAtIndex:i];
        
        NSString *key_long = [@"odpt.Station:" stringByAppendingString:key];
        if([self isConnectStation:key_long andStation:stationIdentifier]){
            
            NSArray *cLines = [cons objectForKey:key];  // ex. cLines = @[@"JR-East.Takasaki.1.1", @"JR-East.Utsunomiya.1.1"]
            for(int j=0; j<[cLines count]; j++){
                NSString *lineIdent = [@"odpt.Railway:" stringByAppendingString:[cLines objectAtIndex:j]];
                [sret addObject:lineIdent];
            }
            break;
        }
    }
    
    return [sret copy];
}


- (void)initConnectStationDifferentName{
    // 同名以外で接続する駅
    
    @synchronized(self){
        NSError *err;
        NSString *path;
        NSString *jsonString;
        NSData *jsonData;
        err = nil;
        
        NSBundle *bundle = [NSBundle bundleForClass:[self class]];
        
        path = [bundle pathForResource:@"connect_station.json" ofType:nil];
        jsonString = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&err];
        
        if(err){
            NSLog(@"connectStationJSONFile read error!! %@",path);
        }
        
        jsonData = [jsonString dataUsingEncoding:NSUnicodeStringEncoding];
        NSArray *array = [NSJSONSerialization JSONObjectWithData:jsonData
                                                         options:NSJSONReadingAllowFragments
                                                           error:&err];
        if(err){
            NSLog(@"connectStationSONFile parse error!! %@",err);
        }
        
        connectStationDifferentName = [[NSMutableDictionary alloc] init];
        
        for(int i=0; i<[array count]; i++){
            NSArray *sts = [array objectAtIndex:i];
            
            for(int j=0; j<[sts count]; j++){
                NSString *key = sts[j];
                //NSString *newKey = [@"odpt.Station:" stringByAppendingString:key];
                [connectStationDifferentName setObject:sts forKey:key];
            }
        }
    }
}

- (NSArray<NSString *> *)connectStationDifferentNameForStation:(NSString *)stationIdentifier{
    if(connectStationDifferentName == nil){
        [self initConnectStationDifferentName];
    }
    
    NSArray *r_array = [stationIdentifier componentsSeparatedByString:@":"];
    NSAssert(r_array != nil && [r_array count] == 2, @"connectStationForStation identifier is invalid. station %@", stationIdentifier);
    
    NSString *r_name = [r_array lastObject];
    
    NSArray *ret = [connectStationDifferentName objectForKey:r_name];
   
    NSMutableArray *ary = [[NSMutableArray alloc] init];
    for(int i=0; i<[ret count]; i++){
        NSString *sname = [ret objectAtIndex:i];
        [ary addObject:[@"odpt.Station:" stringByAppendingString:sname]];
    }
    
    return [ary copy];
}

// stationAとstationBは接続可能か。
- (BOOL) isConnectStation:(NSString *)stationA andStation:(NSString *)stationB{
    // objectは Stationエンティティ
    // NSAssert([stationA.entity.name isEqualToString:@"Station"], @"isConnectStation is invalid.");
    // NSAssert([stationB.entity.name isEqualToString:@"Station"], @"isConnectStation is invalid.");
    
    // 鉄道のみ有効.
    NSAssert([stationA containsString:@"odpt.Station"] && [stationB containsString:@"odpt.Station"], @"isConnectStation only valid for station(TrainStop). %@, %@", stationA, stationB);
    
    // 駅識別子の最後の項が、一致するか
    NSString *r_ident = stationA;
    NSString *s_ident = stationB;
    
    NSArray *r_array = [r_ident componentsSeparatedByString:@":"];
    NSAssert(r_array != nil && [r_array count] == 2, @"isConnectStation identifier is invalid. stationA %@", r_ident);
    
    NSString *r_name = [r_array lastObject];
    
    NSArray *r_array_short = [r_name componentsSeparatedByString:@"."];
    NSString *r_name_short = [r_array_short lastObject];
    
    NSMutableArray *s_array = [[s_ident componentsSeparatedByString:@":"] mutableCopy];
    NSAssert(s_array != nil && [s_array count] == 2, @"isConnectStation identifier is invalid. stationB ", s_ident);
    
    NSString *s_name = [s_array lastObject];
    
    NSArray *s_array_short = [s_name componentsSeparatedByString:@"."];
    NSString *s_name_short = [s_array_short lastObject];
    
    
    // 別名だが一致するか確認。
    //NSArray *stationsDiff = [[ODPTDataAdditional sharedData] connectStationsDifferentNameForStation:r_ident];
    NSArray *stationsDiff = [self connectStationDifferentNameForStation:r_ident];
    
    if(stationsDiff != nil){
        for(int i=0; i<[stationsDiff count]; i++){
            NSString *s = stationsDiff[i];
            if([s isEqualToString:s_ident]){
                //NSLog(@"isConnectStation %@ %@ -> YES", r_ident, s_ident);
                return YES;
            }
        }
    }
    
    if([r_name_short isEqualToString:s_name_short]){
        //NSLog(@"isConnectStation %@ %@ -> YES", r_ident, s_ident);
        return YES;
    }
    
    // NSLog(@"isConnectStation %@ %@ -> NO", r_ident, s_ident);
    return NO;
}


- (void)initStationOrderForOtherLine{
    // API対象路線以外の始発駅/終着駅
    
    // 逆方向の路線順序並び替えは　LoaderLine 内の機能で実施する。
    
    @synchronized(self){
        NSError *err;
        NSString *path;
        NSString *jsonString;
        NSData *jsonData;
        err = nil;
        
        NSBundle *bundle = [NSBundle bundleForClass:[self class]];
        
        path = [bundle pathForResource:@"station_order_for_line.json" ofType:nil];
        jsonString = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&err];
        
        if(err){
            NSLog(@"StationOrderJSONFile read error!! %@",path);
        }
        
        jsonData = [jsonString dataUsingEncoding:NSUnicodeStringEncoding];
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:jsonData
                                                             options:NSJSONReadingAllowFragments
                                                               error:&err];
        if(err){
            NSLog(@"StationOrderJSONFile parse error!! %@",err);
        }
        
        NSMutableDictionary *dict2 = [NSMutableDictionary dictionaryWithDictionary:dict];
        
        NSArray *array = [dict allKeys];
        for(int i=0; i<[array count]; i++){
            NSString *l = array[i];
            id value = [dict objectForKey:l];
            
            // 逆向きの路線を取得。
            NSString *l_reverse;
            NSRange range = [l rangeOfString:@"." options:NSBackwardsSearch];
            NSString *clb = [l substringToIndex:range.location];
            NSString *clf = [l substringFromIndex:range.location+1];
            if([clf isEqualToString:@"1"]){
                l_reverse = [clb stringByAppendingString:@".2"];
            }else{
                NSAssert(NO, @"initStationOrderForOtherLine data error.");
            }
            
            [dict2 setObject:value forKey:l_reverse];
        }
        
        stationOrderForOtherLine = [dict2 copy];
    }
    
}

- (NSArray *)stationOrderForOtherLine:(NSString *)LineIdentifier{

    // API対象路線以外の終着駅。JSONから。
    if(stationOrderForOtherLine == nil){
        [self initStationOrderForOtherLine];
    }
    
    
    NSMutableArray *newStations = [[NSMutableArray alloc] init];
    //NSString *key = [@"odpt.Railway:" stringByAppendingString:LineIdentifier];
    NSArray *f = [LineIdentifier componentsSeparatedByString:@":"];
    NSArray *stationOrder = [stationOrderForOtherLine objectForKey:f[1]];
    // NSLog(@"adjustStationOrder endStation:%@", stationOrder);
    if(stationOrder != nil){
        for(int i=0; i<[stationOrder count]; i++){
            NSString *stationIdent2 = [@"odpt.Station:" stringByAppendingString:stationOrder[i] ];
            //NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:stationIdent2, @"odpt:station",nil];
            
            NSDictionary *stationTitleDict = [self stationTitleOfOtherLine:stationIdent2];
            NSAssert(stationTitleDict != nil, @"stationOrderForOtherLine stationTitleDict is nil!!");
            
            NSDictionary *dict = @{@"odpt:station":stationIdent2, @"odpt:stationTitle":stationTitleDict};
            
            [newStations addObject:dict];
        }
    }
    
    return [newStations copy];
}



- (void)initLineTitleForOtherLine{
    // 東京メトロ路線以外の路線名
    
    @synchronized(self){
        NSError *err;
        NSString *path;
        NSString *jsonString;
        NSData *jsonData;
        err = nil;
        
        NSBundle *bundle = [NSBundle bundleForClass:[self class]];
        
        path = [bundle pathForResource:@"line_title.json" ofType:nil];
        jsonString = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&err];
        
        if(err){
            NSLog(@"LineTitleJSONFile read error!! %@",path);
        }
        
        jsonData = [jsonString dataUsingEncoding:NSUnicodeStringEncoding];
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:jsonData
                                                             options:NSJSONReadingAllowFragments
                                                               error:&err];
        if(err){
            NSLog(@"LineTitleJSONFile parse error!! %@",err);
        }
        
        NSMutableDictionary *dict2 = [NSMutableDictionary dictionaryWithDictionary:dict];
                
        lineTitleForOtherLine = [dict2 copy];
    }
    
}

- (NSDictionary *)lineTitleForOtherLine:(NSString *)LineIdentifier{
    
    // 東京メトロ以外の路線名。JSONから。
    if(lineTitleForOtherLine == nil){
        [self initLineTitleForOtherLine];
    }

    NSArray *f = [LineIdentifier componentsSeparatedByString:@":"];
    NSArray *g = [f[1] componentsSeparatedByString:@"."];
    NSString *shortLineIdentifier = [NSString stringWithFormat:@"%@.%@",g[0], g[1]];
    
    NSDictionary *lineTitleDict = [lineTitleForOtherLine objectForKey:shortLineIdentifier];
    
    if(lineTitleDict == nil){
        lineTitleDict = @{@"ja":shortLineIdentifier, @"en":shortLineIdentifier};
    }
    return lineTitleDict;
    
}

- (BOOL)isHolidayForDate:(NSDate *)date{
    
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.dateFormat = @"yyyy-MM-dd";
    NSString *dateString = [dateFormatter stringFromDate:date];
    
    // 祝日を取得。
    if(dayTypeForDate == nil){
        [self initHolidays];
    }
    
    NSString *res = [dayTypeForDate objectForKey:dateString];
    
    if(res != nil){
        return YES;
    }
    
    return NO;
}

- (void)initHolidays{
    // 休日・祝日を返す。
    // 日本の法律による、国民の祝日・休日
    // https://www8.cao.go.jp/chosei/shukujitsu/gaiyou.html
    
    @synchronized(self){
        NSError *err;
        NSString *path;
        NSString *jsonString;
        NSData *jsonData;
        err = nil;
        
        NSBundle *bundle = [NSBundle bundleForClass:[self class]];
        
        path = [bundle pathForResource:@"holidays.json" ofType:nil];
        jsonString = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&err];
        
        if(err){
            NSLog(@"HolidaysJSONFile read error!! %@",path);
        }
        
        jsonData = [jsonString dataUsingEncoding:NSUnicodeStringEncoding];
        NSArray *array = [NSJSONSerialization JSONObjectWithData:jsonData
                                                             options:NSJSONReadingAllowFragments
                                                               error:&err];
        if(err){
            NSLog(@"HolidaysJSONFile parse error!! %@",err);
        }
        
        NSMutableDictionary *dict2 = [[NSMutableDictionary alloc] init];
        for(NSString *key in array){
            [dict2 setObject:@"1" forKey:key];
        }
        
        dayTypeForDate = [dict2 copy];
    }
    
}


- (NSDictionary *)stationTitleOfOtherLine:(NSString *)stationIdentifier{
    
    if(stationTitleOther == nil){
        [self initStationTitleOther];
    }
    
    NSArray *f = [stationIdentifier componentsSeparatedByString:@":"];
    NSString *key = f[1];
    
    NSDictionary *retDict = [stationTitleOther objectForKey:key];

    return retDict;
    
}

- (void)initStationTitleOther{
    
    @synchronized(self){
        NSError *err;
        NSString *path;
        NSString *jsonString;
        NSData *jsonData;
        err = nil;
        
        NSBundle *bundle = [NSBundle bundleForClass:[self class]];
        
        NSString *filename = @"other_stationDict.json";
        
        path = [bundle pathForResource:filename ofType:nil];
        jsonString = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&err];
        
        if(err){
            NSLog(@"StationTitleJSONFile read error!! %@",path);
        }
        
        jsonData = [jsonString dataUsingEncoding:NSUnicodeStringEncoding];
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:jsonData
                                                             options:NSJSONReadingAllowFragments
                                                               error:&err];
        if(err){
            NSLog(@"StationTitleJSONFile parse error!! %@",err);
        }
        
        NSMutableDictionary *dict2 = [NSMutableDictionary dictionaryWithDictionary:dict];

        stationTitleOther = [dict2 copy];
    }
}

// lineStatusLevel
// trainInformation で得られる trainInformationStatus(ja)に応じたLevelを返す。

- (NSInteger)lineStatusLevel:(NSString *)str{
    
    NSInteger level = ODPTDataLineStatusLevelNormal;
    
    // NSLog(@"lineStatusLevel str:%@", str);
    if(str == nil || [str length] == 0){
        // 異常なし
        
    }else if([str isKindOfClass:[NSNull class]]){
        // 異常なし
        
    }else{
        // 異常あり
        level = ODPTDataLineStatusLevelDelay;
        
        if(lineInformationLevel == nil){
            [self initLineInformationLevel];
        }

        NSString *levelNumStr = [lineInformationLevel objectForKey:str];
        
        if(levelNumStr != nil){
            level = [levelNumStr integerValue];
        }
        
    }
    
    return level;
}


- (void)initLineInformationLevel{
    
    @synchronized(self){
        NSError *err;
        NSString *path;
        NSString *jsonString;
        NSData *jsonData;
        err = nil;
        
        NSBundle *bundle = [NSBundle bundleForClass:[self class]];
        
        NSString *filename = @"line_information_level.json";
        
        path = [bundle pathForResource:filename ofType:nil];
        jsonString = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&err];
        
        if(err){
            NSLog(@"LineInformationJSONFile read error!! %@",path);
        }
        
        jsonData = [jsonString dataUsingEncoding:NSUnicodeStringEncoding];
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:jsonData
                                                             options:NSJSONReadingAllowFragments
                                                               error:&err];
        if(err){
            NSLog(@"LineInformationJSONFile parse error!! %@",err);
        }
        
        NSMutableDictionary *dict2 = [NSMutableDictionary dictionaryWithDictionary:dict];
        
        lineInformationLevel = [dict2 copy];
    }
    
}

/*
- (NSString *)lineInformationStatus:(NSString *)statusString{
    
    NSString *locale = [[NSLocale preferredLanguages] objectAtIndex:0];

    if([locale hasPrefix:@"ja"] == YES){
        return statusString;
    }else{
        if(lineInformationStatusEnglish == nil){
            [self initLineInformationStatusEnglish];
        }
        
        NSString *en_str = [lineInformationStatusEnglish objectForKey:statusString];
        if(en_str == nil){
            // 知らない文字列の場合は、日本語をそのまま出力
            en_str = statusString;
        }

        return en_str;
    }
}

- (void)initLineInformationStatusEnglish{
    
    @synchronized(self){
        NSError *err;
        NSString *path;
        NSString *jsonString;
        NSData *jsonData;
        err = nil;
        
        NSBundle *bundle = [NSBundle bundleForClass:[self class]];
        
        NSString *filename = @"line_information_status_en.json";
        
        path = [bundle pathForResource:filename ofType:nil];
        jsonString = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&err];
        
        if(err){
            NSLog(@"LineInformationStatusJSONFile read error!! %@",path);
        }
        
        jsonData = [jsonString dataUsingEncoding:NSUnicodeStringEncoding];
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:jsonData
                                                             options:NSJSONReadingAllowFragments
                                                               error:&err];
        if(err){
            NSLog(@"LineInformationStatusJSONFile parse error!! %@",err);
        }
        
        NSMutableDictionary *dict2 = [NSMutableDictionary dictionaryWithDictionary:dict];
        
        lineInformationStatusEnglish = [dict2 copy];
    }
    
}
 */



- (BOOL)isAbleToAccessAPIOfRailway:(NSString *)lineIdentifier{
    
    if(inaccessibleRailways == nil){
        [self initInaccessibleRailway];
    }
    
    NSString *result = [inaccessibleRailways objectForKey:lineIdentifier];
    
    if(result == nil){
        return YES;
    }
    
    return NO;
}



- (void)initInaccessibleRailway{
    // APIにアクセスできない路線
    
    @synchronized(self){
        NSError *err;
        NSString *path;
        NSString *jsonString;
        NSData *jsonData;
        err = nil;
        
        NSBundle *bundle = [NSBundle bundleForClass:[self class]];
        
        path = [bundle pathForResource:@"inaccessible_railway.json" ofType:nil];
        jsonString = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&err];
        
        if(err){
            NSLog(@"inaccessibleRailwayJSONFile read error!! %@",path);
        }
        
        jsonData = [jsonString dataUsingEncoding:NSUnicodeStringEncoding];
        NSArray *array = [NSJSONSerialization JSONObjectWithData:jsonData
                                                         options:NSJSONReadingAllowFragments
                                                           error:&err];
        if(err){
            NSLog(@"inaccessibleRailwayJSONFile parse error!! %@",err);
        }
        
        inaccessibleRailways = [[NSMutableDictionary alloc] init];
        
        for(int i=0; i<[array count]; i++){
            //NSString *newKey = [NSString stringWithFormat:@"odpt.Railway:%@.1.1", array[i] ];
            NSString *newKey = [NSString stringWithFormat:@"odpt.Railway:%@", array[i] ];
            [inaccessibleRailways setObject:@"1" forKey:newKey];
            
        }
    }
}


- (NSString *)operatorHeaderForIdentifier:(NSString *)operatorIdentifier{
    
    // 列車種別名。JSONから。
    if(operatorHeaderForIdentifier == nil){
        [self initOperatorHeader];
    }
    
    NSAssert( [operatorIdentifier hasPrefix:@"odpt.Operator:"], @"operatorHeader invalid identifier ident:%@", operatorIdentifier);
    
    NSArray *r_array = [operatorIdentifier componentsSeparatedByString:@":"];
    NSAssert(r_array != nil && [r_array count] == 2, @"operatorHeader identifier is invalid. station %@", operatorIdentifier);
    
    NSString *r_name = [r_array lastObject];
    
    NSString *operatorHeaderTitle = [operatorHeaderForIdentifier objectForKey:r_name];
    
    if(operatorHeaderTitle == nil){
        operatorHeaderTitle = r_name;
        NSLog(@"operatorHeaderForIdentifier can't find %@", operatorIdentifier);
    }
    return operatorHeaderTitle;
    
}

- (void)initOperatorHeader{
    
    @synchronized(self){
        NSError *err;
        NSString *path;
        NSString *jsonString;
        NSData *jsonData;
        err = nil;
        
        NSBundle *bundle = [NSBundle bundleForClass:[self class]];
        
        NSString *locale = [[NSLocale preferredLanguages] objectAtIndex:0];
        NSString *filename;
        if([locale hasPrefix:@"ja"] == YES){
            filename = @"operator_header_ja.json";
        }else{
            filename = @"operator_header_en.json";
        }
        
        path = [bundle pathForResource:filename ofType:nil];
        jsonString = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&err];
        
        if(err){
            NSLog(@"OperatorHeaderJSONFile read error!! %@",path);
        }
        
        jsonData = [jsonString dataUsingEncoding:NSUnicodeStringEncoding];
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:jsonData
                                                             options:NSJSONReadingAllowFragments
                                                               error:&err];
        if(err){
            NSLog(@"OperatorHeaderJSONFile parse error!! %@",err);
        }
        
        NSMutableDictionary *dict2 = [NSMutableDictionary dictionaryWithDictionary:dict];
        
        operatorHeaderForIdentifier = [dict2 copy];
    }
    
}

@end

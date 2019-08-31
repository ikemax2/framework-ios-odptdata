//
//  ODPTDataLoaderLine.m
//
//  Copyright (c) 2018 Takehito Ikema
//
//  This software is released under the MIT License.
//  https://opensource.org/licenses/mit-license.php
//
#import "ODPTDataLoaderLine.h"
#import "ODPTDataAdditional.h"
#import "ODPTDataLoaderArray.h"

@implementation ODPTDataLoaderLine{
    
    NSManagedObjectID *retID;
    
    BOOL objectCompletionCheck;
    
}

- (id)init{
    
    NSAssert(YES, @"ODPTDataLoaderLine must not use init message.");
    
    return nil;
}


- (id) initWithLine:(NSString *)lineIdentifier Block:(void (^)(NSManagedObjectID *))block{
    
    
    if(self = [super init]){
        self.lineIdentifier = lineIdentifier;
        NSAssert(self.lineIdentifier != nil,  @"ODPTDataLoaderLine lineIdentifier is nil!!");
        NSAssert([self.lineIdentifier length] > 0,  @"ODPTDataLoaderLine lineIdentifier is nil!!");
                 
        self.callback = [block copy]; // IMPORTANT
        objectCompletionCheck = YES;
    }
    
    return self;
    
}

// 内部の再帰呼び出し時のみに適用する
//  チェクフラグを NOとし、オブジェクトが未完成でもLoaderが完了するようにする。
- (id) initWithLine:(NSString *)lineIdentifier withoutCheck:(BOOL)noCheck Block:(void (^)(NSManagedObjectID *))block{
    
    if(self = [super init]){
        self.lineIdentifier = lineIdentifier;
        NSAssert(self.lineIdentifier != nil,  @"ODPTDataLoaderLine lineIdentifier is nil!!");
        NSAssert([self.lineIdentifier length] > 0,  @"ODPTDataLoaderLine lineIdentifier is nil!!");
        
        self.callback = [block copy]; // IMPORTANT
        objectCompletionCheck = NO;
        
    }
    
    return self;
    
}


- (void)removeLineObject{
    
    NSManagedObjectContext *moc = [self.dataManager managedObjectContextForConcurrent];
    [moc performBlockAndWait:^{
        // CoreData DBから書き換えるべき object を受け取る。
        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Line"];
        [request setPredicate:[NSPredicate predicateWithFormat:@"identifier == %@", self.lineIdentifier]];
        
        NSError *error = nil;
        NSArray *results = [moc executeFetchRequest:request error:&error];
        
        if (results == nil) {
            NSLog(@"Error fetching objects: %@\n%@", [error localizedDescription], [error userInfo]);
            abort();
        }
        
        NSManagedObject *lineObj = nil;
        if([results count] == 0){
            NSLog(@"ODPTDataLoaderLine can't find Line Object at remove object %@", self.lineIdentifier);
            return;
        }else{
            // レコードが存在するので、書き換える。
            lineObj = [results objectAtIndex:0];
        }
        
        if(lineObj != nil){
            NSLog(@"ODPTDataLoaderLine removeLineObject delete. ident:%@", self.lineIdentifier);
            [moc deleteObject:lineObj];
        }
        
        // Save the context.
        if (![moc save:&error]) {
            NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
            abort();
        }
        
        //[self.dataManager saveContext]; // 永続保管 非同期で。
        
    }];
    
    
}

- (BOOL)isCompleteObject:(NSManagedObject *)obj{
    // オブジェクトの完全性を確認. // performBlock 内から呼び出すこと
    
    // isValidConnectingLines は ODPTDataConnectingLines によりセットされる
    // TODO: 要見直し. ManagedLoaderの挙動から。
    //    odpt.Railway:TokyoMetro.Tozai.1.1 / odpt.Railway:JR-East.ChuoSobuLocal.1.2 による循環参照時の挙動も。
    //fetchDateがセットされていなければ不完全と考える
    
    if(objectCompletionCheck == NO){
        // チェックフラグがNoであれば、完全性チェックはパス
        return YES;
    }
    
    NSDate *date = [obj valueForKey:@"fetchDate"];
    if(date == nil){
        return NO;
    }
    
    return YES;
    
}


- (void)setStationsToObject:(NSManagedObject *)newLineObject fromData:(NSDictionary *)rec withIdentifier:(NSString *)LineIdentifier withMOC:(NSManagedObjectContext *)moc{
    // performBlock内で呼び出す
    
    NSInteger type = [self lineTypeForLineIdentifier:LineIdentifier];
    
    // stationOrderの処理。
    NSMutableArray *idents_stations = nil;
    if(type == ODPTDataLineTypeRailway){
        idents_stations = [[rec objectForKey:@"odpt:stationOrder"] mutableCopy];
    }else if(type == ODPTDataLineTypeBus){
        idents_stations = [[rec objectForKey:@"odpt:busstopPoleOrder"] mutableCopy];
    }
    
    
    // 独自拡張
    // 特定の路線のみ、APIから取得したstationOrder の内容を変更する。
    NSArray *newIdents = [self adjustStationOrder:idents_stations ExtentionOfIdentifier:LineIdentifier];
    idents_stations = [newIdents mutableCopy];
    
    NSAssert(idents_stations != nil && [idents_stations count] > 0, @"ODPTDataLoaderLine stations is zero. %@", LineIdentifier);
    
    // 駅識別子だけ stationIdents へ格納
    NSMutableArray *stationIdents = [[NSMutableArray alloc] init];
    
    for(int i=0; i<[idents_stations count]; i++){
        NSDictionary *dict = [idents_stations objectAtIndex:i];
        NSString *originalStationIdentifier = nil;
        
        if(type == ODPTDataLineTypeRailway){
            originalStationIdentifier = [dict objectForKey:@"odpt:station"];
        }else if(type == ODPTDataLineTypeBus){
            originalStationIdentifier = [dict objectForKey:@"odpt:busstopPole"];
        }
        
        [stationIdents addObject:originalStationIdentifier];
    }
    
    // 独自拡張
    // 同一識別子の駅が複数存在する場合、区別するために、duplication を設定する。
    // 駅が一つしかない場合は @0 が設定される。
    
    NSMutableArray *duplication = [[NSMutableArray alloc] init];
    for(int i=0; i<[stationIdents count]; i++){
        NSString *sIdent = [stationIdents objectAtIndex:i];
        
        NSInteger d = 0;
        for(int j=0; j<i; j++){
            if([stationIdents[j] isEqualToString:sIdent] == YES){
                d++;
            }
        }
        
        [duplication addObject:[NSNumber numberWithInteger:d]];
    }
    
    
    NSMutableArray *t_stations = [[NSMutableArray alloc] init];
    
    // Station *prev = nil;
    for(int i=0; i<[idents_stations count]; i++){
        NSDictionary *dict = [idents_stations objectAtIndex:i];
        
        // managedObject "Station" を作成し、 CoreDataに追加していく。
        
        // 追加する前にデータベースに存在するか確認
        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Station"];
        
        // stationIdent は事前処理したものを使う。
        NSString *stationIdentifier = stationIdents[i];
            
        [request setPredicate:[NSPredicate predicateWithFormat:@"identifier == %@", stationIdentifier]];
        NSError *error = nil;
        
        NSArray *results = [moc executeFetchRequest:request error:&error];
        
        if (results == nil) {
            NSLog(@"Error fetching objects: %@\n%@", [error localizedDescription], [error userInfo]);
            abort();
        }
        
        
        NSManagedObject *stationObject = nil;
        if( [results count] == 0){
            // 見つからなかった。
            stationObject = [NSEntityDescription insertNewObjectForEntityForName:@"Station" inManagedObjectContext:moc];
            [stationObject setValue:stationIdentifier forKey:@"identifier"];
            // タイトルだけはセットしてしまう
            if(type == ODPTDataLineTypeRailway){
                NSDictionary *titleDict = [dict objectForKey:@"odpt:stationTitle"];
                [stationObject setValue:titleDict[@"ja"] forKey:@"title_ja"];
                [stationObject setValue:titleDict[@"en"] forKey:@"title_en"];
            }else if(type == ODPTDataLineTypeBus){
                // [stationObject setValue:[dict objectForKey:@"dc:title"] forKey:@"title_ja"];
                // このときのデータにtitle_ja は含まれない。のちほど設定する。
                // stationIdentifier からtitle_enを作る
                NSArray *f = [stationIdentifier componentsSeparatedByString:@":"];
                NSArray *g = [f[1] componentsSeparatedByString:@"."];
                [stationObject setValue:g[1] forKey:@"title_en"];
            }
            
            
        }else{
            // 見つかった。
            stationObject = [results objectAtIndex:0];
            
            // For Debug  ここでは、 results count は　1にならなければいけない。さもなければ、同じstationIdentifier を持つ オブジェクトが複数存在する。
            NSAssert([results count] == 1, @"ODPTDataLoaderLine detect multiple result for station identifier.");
        }
        
        // 下の方で　linesObjectに stationsをセットする。この時にlinesの方は同時に設定される(xcdatamodeldにて逆関係を定義）
        //  ので、ここでstationObjectに linesをセットする必要はない。
        
        //ここではタイトルは設定しない。  detailOfStationで設定。
        
        [t_stations addObject:stationObject];
        
    }
    
    // 独自拡張
    if([self isLineIdentifierDownwardExtention:LineIdentifier] == YES){
        //t_stationsを逆順に並び替え。
        // 以下の方法では重複した駅が消されてしまう。
        NSMutableArray *rev_stations = [[NSMutableArray alloc] init];
        for(NSInteger j=[t_stations count]-1; j>=0; j--){
            [rev_stations addObject:t_stations[j] ];
        }
        t_stations = rev_stations;
        
        // duplicationも並び替え
        NSMutableArray *rev_duplication = [[NSMutableArray alloc] init];
        for(NSInteger j=[duplication count]-1; j>=0; j--){
            [rev_duplication addObject:duplication[j] ];
        }
        duplication = rev_duplication;
        
    }
    
    // 方向文字列
    NSString *directionString = nil;
    if(type == ODPTDataLineTypeRailway){
        if([self isLineIdentifierDownwardExtention:LineIdentifier] == YES){
            directionString = [rec objectForKey:@"odpt:descendingRailDirection"];
        }else{
            directionString = [rec objectForKey:@"odpt:ascendingRailDirection"];
        }
        if(directionString == nil){
            NSLog(@"ODPTDataLoaderLine railway not set railDirection!!");
        }
        
    }else if(type == ODPTDataLineTypeBus){
        // 現API仕様では、 BusstopPoleTimetableのみで使用。
        NSManagedObject *endStation = [t_stations lastObject];  // station エンティティオブジェクト
        NSString *endStationIdentifier =  [endStation valueForKey:@"identifier"];
        
        NSArray *f = [endStationIdentifier componentsSeparatedByString:@":"];
        NSArray *g = [f[1] componentsSeparatedByString:@"."];
        
        NSMutableString *mstr = [[NSMutableString alloc] initWithString:@"odpt.BusDirection:"];
        [mstr appendString:g[0]];
        [mstr appendString:@"."];
        [mstr appendString:g[1]];
        
        directionString = [mstr copy];
    }
    
    [newLineObject setValue:directionString forKey:@"direction"];

    
    // NSOrdredSet は重複した要素を保存しない
    NSMutableOrderedSet *orderedSet = [NSMutableOrderedSet orderedSetWithArray:t_stations ];
    
    NSMutableString *orderString = [[NSMutableString alloc] init];
    
    for(int j=0; j<[t_stations count]; j++){
        NSManagedObject *obj = t_stations[j];
        int index = (int)[orderedSet indexOfObject:obj];
        if([orderString length] > 0){
            [orderString appendString:@","];
        }
        
        [orderString appendString:[NSString stringWithFormat:@"%d", index]];
    }
    
    [newLineObject setValue:[orderString copy] forKey:@"stationOrder"];
    [newLineObject setValue:orderedSet forKey:@"stations"];
    
    // duplication 設定用の文字列。すべて0の場合は nil とし、設定しない。
    NSMutableString *duplicationString = [[NSMutableString alloc] init];
    BOOL duplicationFlag = NO;
    for(int i=0; i<[duplication count]; i++){
        if([duplication[i] isEqualToNumber:@0] == NO){
            duplicationFlag = YES;
        }
        if(i!=0){
            [duplicationString appendString:@","];
        }
        [duplicationString appendString:[NSString stringWithFormat:@"%@", duplication[i]]];
    }
    
    if(duplicationFlag == YES){
        [newLineObject setValue:[duplicationString copy] forKey:@"duplication"];
    }

}



- (void)makeObjectOfIdentifier:(NSString *)LineIdentifier ForDictionary:(NSDictionary *)rec Block:(void (^)(NSManagedObjectID *))block{
    
    __block NSMutableArray *cons = [[NSMutableArray alloc] init];
    __block NSMutableString *directConnectingStationNumbers = [[NSMutableString alloc] init];
    
    __block BOOL fetchReverseLineFlag = NO;
    
    __block BOOL failureFlag = NO;
    
    NSInteger lineType = [self lineTypeForLineIdentifier:LineIdentifier];
    
    NSManagedObjectContext *moc = [self.dataManager managedObjectContextForConcurrent];
    [moc performBlockAndWait:^{
        // CoreData DBから書き換えるべき object を受け取る。
        NSManagedObject *newLineObject  = nil;
        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Line"];
        [request setPredicate:[NSPredicate predicateWithFormat:@"identifier == %@", LineIdentifier]];
        
        NSError *error = nil;
        NSArray *results = [moc executeFetchRequest:request error:&error];
        
        if (results == nil) {
            NSLog(@"Error fetching objects: %@\n%@", [error localizedDescription], [error userInfo]);
            abort();
        }
        
        if([results count] > 0){
            // レコードが存在するので、書き換える。
            newLineObject = [results objectAtIndex:0];

            // 路線名
            NSDictionary *titleDict = nil;
            
            if(lineType == ODPTDataLineTypeRailway){
                titleDict = [rec objectForKey:@"odpt:railwayTitle"];
                
                NSArray *f = [LineIdentifier componentsSeparatedByString:@":"];
                NSArray *g = [f[1] componentsSeparatedByString:@"."];
                NSString *familyIdent = [NSString stringWithFormat:@"%@.%@", g[0], g[1]];
                
                // familyIdentifier :  ex. JR-East.Yamanote
                [newLineObject setValue:familyIdent forKey:@"familyIdentifier"];
                
            }else if(lineType == ODPTDataLineTypeBus){
                
                //NSAssert(NO, @"ODPTDataLoaderLine title not support for ODPTDataLineTypeBus");
                NSString *routeTitle_ja =  [rec objectForKey:@"dc:title"];
                NSArray *f = [LineIdentifier componentsSeparatedByString:@":"];
                NSArray *g = [f[1] componentsSeparatedByString:@"."];
                NSString *routeTitle_en = [NSString stringWithFormat:@"%@", g[1]];
                titleDict = @{@"en":routeTitle_en, @"ja":routeTitle_ja};
                // familyIdentifier : busroutePattern における busroute(系統)
                NSString *familyIdent = [rec objectForKey:@"odpt:busroute"];
                NSArray *h = [familyIdent componentsSeparatedByString:@":"];
                [newLineObject setValue:h[1] forKey:@"familyIdentifier"];
                
            }else{
                NSAssert(NO, @"ODPTDataLoader invalid LineType. identifier:%@", LineIdentifier);
            }
            
            [newLineObject setValue:titleDict[@"en"] forKey:@"title_en"];
            [newLineObject setValue:titleDict[@"ja"] forKey:@"title_ja"];
            
            
            // 事業者名
            NSString *operatorIdentifier = [rec objectForKey:@"odpt:operator"];
            if(operatorIdentifier == nil || [operatorIdentifier length] <= 0){
                // operatorが登録されていない場合 は lineIdentifier から作る
                NSArray *f = [LineIdentifier componentsSeparatedByString:@":"];
                NSArray *g = [f[1] componentsSeparatedByString:@"."];
                
                operatorIdentifier = [NSString stringWithFormat:@"odpt.Operator:%@", g[0]];
                
            }
            [newLineObject setValue:operatorIdentifier forKey:@"operator"];
            
            // 独自拡張
            // APIにない路線情報を設定。　LineColor / 循環線
            [self setLineInformationExtentionFor:newLineObject OfIdentifier:LineIdentifier];
            
            // 駅を追加
            [self setStationsToObject:newLineObject fromData:rec withIdentifier:LineIdentifier withMOC:moc];

            //一旦保存。まだ途中だが
            NSError *error = nil;
            // Save the context.
            if (![moc save:&error]) {
                NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
                abort();
            }
            
            
            
            // 逆向き路線を調べる。 鉄道の場合のみ -> cons へ追加
            
            if(lineType == ODPTDataLineTypeRailway){
                // バスの場合、逆方向路線が無条件に存在するとは限らない
                NSString *l_reverse = [self reverseDirectingLineForLineIdentifier:LineIdentifier];
                
                [cons addObject:l_reverse];
                fetchReverseLineFlag = YES;
                
            }else if(lineType == ODPTDataLineTypeBus){
                
            }
            
            // 直通路線を調べる。 -> cons へ追加
            NSOrderedSet *stations = [newLineObject valueForKey:@"stations"];
            
            for(int i=0; i<[stations count]; i++){
                NSManagedObject *obj = [stations objectAtIndex:i];
                
                NSString *stationIdentifier = [obj valueForKey:@"identifier"];
                
                NSArray *t = [[ODPTDataAdditional sharedData] directConnectionLinesForLine:LineIdentifier AtStation:stationIdentifier];
                
                for(int j=0; j<[t count]; j++){
                    if([directConnectingStationNumbers length] != 0){
                        [directConnectingStationNumbers appendString:@","];
                    }
                    [directConnectingStationNumbers appendString:[NSString stringWithFormat:@"%d", i] ];
                }
                
                [cons addObjectsFromArray:t];
            }
        }else{
            // 作ったはずの object (line entity )が存在しない.
            // おそらく キャンセル処理の過程で削除されている  -> アクセス失敗とする
            NSLog(@"ODPTDataLoaderLine can't find Line Object at making object  %@", LineIdentifier);
            failureFlag = YES;
            
        }
    }];
    
    if(failureFlag == YES){
        block(nil);
        return;
    }
    
    __block NSManagedObjectID *retMoID = nil;
    
    // NSLog(@"makeObjectOfIdentifier line:%@ cons:%@", LineIdentifier, cons);
    if([cons count] == 0){
        [moc performBlockAndWait:^{
            // CoreData DBから書き換えるべき object を受け取る。
            NSManagedObject *newLineObject  = nil;
            NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Line"];
            [request setPredicate:[NSPredicate predicateWithFormat:@"identifier == %@", LineIdentifier]];
            
            NSError *error = nil;
            NSArray *results = [moc executeFetchRequest:request error:&error];
            
            if (results == nil) {
                NSLog(@"Error fetching objects: %@\n%@", [error localizedDescription], [error userInfo]);
                abort();
            }
            
            if([results count] > 0){
                // レコードが存在するので、書き換える。
                newLineObject = [results objectAtIndex:0];
                [newLineObject setValue:@"" forKey:@"directConnectingStationNumbers"];
            
                [newLineObject setValue:[NSDate date] forKey:@"fetchDate"];  //読み込み完了を表す
            
                NSError *error = nil;
            
                // Save the context.
                if (![moc save:&error]) {
                    NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
                    abort();
                }
                // 永続保存は,別途
                
        
                retMoID = [newLineObject objectID];
            }else{
                retMoID = nil;
            }
        }];
        
        block(retMoID);
        
        
    }else{
        // 再帰呼び出しになる。 関連する直通路線を全て得るまで。

        NSMutableArray *loaders = [[NSMutableArray alloc] init];
        for(int i=0; i<[cons count]; i++){
            NSString *lineIdent = [cons objectAtIndex:i];
            ODPTDataLoaderLine *l = [[ODPTDataLoaderLine alloc] initWithLine:lineIdent withoutCheck:YES Block:nil];
            
            l.dataProvider = self.dataProvider;
            l.dataManager = self.dataManager;
            [loaders addObject:l];
        }
        
        ODPTDataLoaderArray *job = [[ODPTDataLoaderArray alloc] initWithLoaders:loaders Block:^(NSArray<NSManagedObjectID *> *moIDArray) {

            //NSAssert([cons count] == [moIDArray count], @"ODPTDataLoader lineArray count and return Array count is not same. con:%lu mo:%lu",[cons count], [moIDArray count] );
            if(moIDArray == nil || [cons count] != [moIDArray count]){
                block(nil);
                return;
            }
            
            NSManagedObjectContext *moc = [self.dataManager managedObjectContextForConcurrent];
            [moc performBlockAndWait:^{
                
                // CoreData DBから書き換えるべき object を受け取る。
                NSManagedObject *newLineObject  = nil;
                NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Line"];
                [request setPredicate:[NSPredicate predicateWithFormat:@"identifier == %@", LineIdentifier]];
                
                NSError *error = nil;
                NSArray *results = [moc executeFetchRequest:request error:&error];
                
                if (results == nil) {
                    NSLog(@"Error fetching objects: %@\n%@", [error localizedDescription], [error userInfo]);
                    abort();
                }
                
                NSAssert([results count] > 0, @"ODPTDataLoader can't find object setting DirectConnecting Line.");
                
                if([results count] > 0){
                    // レコードが存在するので、書き換える。
                    newLineObject = [results objectAtIndex:0];
                    int count = 0;
                    if(fetchReverseLineFlag == YES){
                        id moID = [moIDArray objectAtIndex:0];
                        if([moID isKindOfClass:[NSManagedObjectID class]] == YES){
                            NSManagedObject *revLineObj = [moc objectWithID:moID];
                            [newLineObject setValue:revLineObj forKey:@"reverseDirectionLine"];
                        }else{
                            // 多分 NSNull
                            // reverseDirectionLineはセットしない
                        }
                        count++;
                    }
                    
                    // 直通路線を設定
                    NSMutableArray *ary = [[NSMutableArray alloc] init];
                    
                    NSLog(@"ODPTDataLoader setDirectConnecting line:%@", LineIdentifier);
                    for(int i=count; i<[cons count]; i++){
                        id moID = [moIDArray objectAtIndex:i];
                        
                        if([moID isKindOfClass:[NSManagedObjectID class]] == YES){
                            NSManagedObject *conLineObj = [moc objectWithID:moID];
                            [ary addObject:conLineObj];
                            NSLog(@"   set:%@", [conLineObj valueForKey:@"identifier"]);
                        }else{
                            // 多分 NSNull. 取得に失敗
                        }
                    }
                    
                    NSMutableOrderedSet *set = [NSMutableOrderedSet orderedSetWithArray:ary];
                    [newLineObject setValue:set forKey:@"directConnectingToLines"];
                    
                    [newLineObject setValue:directConnectingStationNumbers forKey:@"directConnectingStationNumbers"];
                    
                    [newLineObject setValue:[NSDate date] forKey:@"fetchDate"];  //読み込み完了を表す
                    
                    NSError *error = nil;
                    // Save the context.
                    if (![moc save:&error]) {
                        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
                        abort();
                    }
                    
                    // 永続保存は,別途
                    
                    retMoID = [newLineObject objectID];
                }else{
                    retMoID = nil;
                    NSLog(@"ODPTDataLoader can't find object setting DirectConnecting Line.");
                }
            }];
            
            block(retMoID);
            
        }];
            
        job.dataProvider = self.dataProvider;
        job.dataManager = self.dataManager;
        [job setParent:self];
        
        [[self queue] addLoader:job];
    }
    
}


// APIへアクセスして、データを得て、 CoreDataデータベースに保管。
// type = odpt:Railway  owl:sameAs = [LineIdentifier]
//
- (void)requestBy:(id)owner StationsForLine:(NSString *)LineIdentifier Block:(void (^)(NSManagedObjectID *))block{
    
    NSAssert([self isExtensionLineIdentifier:LineIdentifier], @"ODPTDataLoaderLine not allowed normal Identifier.");
    
    //  CoreData データベースにアクセス。
    
    __block NSManagedObjectID *moID = nil;
    
    NSManagedObjectContext *moc = [self.dataManager managedObjectContextForConcurrent];
    [moc performBlockAndWait:^{
        
        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Line"];
        [request setReturnsObjectsAsFaults:NO];        
        
        [request setPredicate:[NSPredicate predicateWithFormat:@"identifier == %@", LineIdentifier]];
        NSError *error = nil;
        
        NSArray *results = [moc executeFetchRequest:request error:&error];
        
        
        if (results == nil) {
            NSLog(@"Error fetching objects: %@\n%@", [error localizedDescription], [error userInfo]);
            abort();
        }
        
        NSManagedObject *LineObject  = nil;
        if([results count] == 0){
            NSString *entityName = @"Line";
            LineObject = [NSEntityDescription insertNewObjectForEntityForName:entityName inManagedObjectContext:moc];
            [LineObject setValue:LineIdentifier forKey:@"identifier"];
            
            // Save the context.
            if (![moc save:&error]) {
                NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
                abort();
            }
            // 永続保存は,別途
            
        }else{
            LineObject = [results objectAtIndex:0];
            
            if([self isCompleteObject:LineObject] == YES){
                moID = [LineObject objectID];
            }else{
                // 掃除
                NSLog(@"ODPTDataLoaderLine object incompleted. clean up. ident: %@", self.lineIdentifier);
/*
                NSSet *set = [obj valueForKey:@""];
                NSArray *ary = [set allObjects];
                for(NSManagedObject *cl in ary){
                    [moc deleteObject:cl];
                }

                // Save the context.
                if (![moc save:&error]) {
                    NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
                    abort();
                }
                
                [self.dataManager saveContext]; // 永続保管 非同期で。
 */
            }
        }
        
    }];
    
    
    if(moID != nil){
        block(moID);
        return;
    }
    
    // APIへアクセス可能な路線か確認
    if(! [self isAbleToAccessAPIOfLine:LineIdentifier]){
        
        NSInteger type = [self lineTypeForLineIdentifier:LineIdentifier];
        
        // アクセスできない場合は独自データを使う
        NSDictionary *titleDict = [[ODPTDataAdditional sharedData] lineTitleForOtherLine:LineIdentifier];

        NSString *titleKey = nil;
        if(type == ODPTDataLineTypeRailway){
            titleKey = @"odpt:railwayTitle";
        }else if(type == ODPTDataLineTypeBus){
            titleKey = @"odpt:busRoutePattern";
        }
        
        NSDictionary *rec = [NSDictionary dictionaryWithObjectsAndKeys:
                             LineIdentifier, @"owl:sameAs",
                             titleDict, titleKey,
                             nil];
        
        [self makeObjectOfIdentifier:LineIdentifier ForDictionary:rec Block:^(NSManagedObjectID *moID) {
            if(moID != nil){
                block(moID);
                return;
            }
        }];
        return;
    }
    
    
    //  該当する Line の レコードがない。 -> APIへアクセス。
    
    // 独自拡張
    //  odpt.Railway:xxxxx.1.1 を一時的に消して、APIへアクセス。
    NSString *shortLineIdentifier = [self removeFooterFromLineIdentifier:LineIdentifier];
    
    NSDictionary *pred = nil;
    
    NSInteger type = [self lineTypeForLineIdentifier:LineIdentifier];
    if(type == ODPTDataLineTypeRailway){
        
        pred = [NSDictionary dictionaryWithObjectsAndKeys:
                @"odpt:Railway", @"type",
                shortLineIdentifier, @"owl:sameAs",
                nil];
    }else if(type == ODPTDataLineTypeBus){
        
        NSString *routeIdentifier = [self busRouteIdentifierFromBusRoutePatternIdentifier:LineIdentifier];
        // 同一系統路線の駅を続けて得ることが多い. 高速化のため,取得は 同じodpt:busroute でまとめて行う
        pred = [NSDictionary dictionaryWithObjectsAndKeys:
                @"odpt:BusroutePattern", @"type",
                routeIdentifier, @"odpt:busroute",
                nil];
        
    }else{
        NSLog(@"invalid LineType. ident:%@", LineIdentifier);
    }
    
    
    [self.dataProvider requestAccessWithOwner:owner withPredicate:pred block:^(id ary) {
                                        
        if(ary == nil){
            // アクセス失敗/キャンセル
            block(nil);
            return;
        }
        
        if([ary count] == 0){
            // アクセス成功したが、空データ. おそらく identifierが間違っている
            block(nil);
            return;
        }
                                        
        NSDictionary *rec = nil;
        for(int i=0; i<[ary count]; i++){
            rec = [ary objectAtIndex:i];
            if([shortLineIdentifier isEqualToString:[rec objectForKey:@"owl:sameAs"]]){
                break;
            }
        }
        
        if(rec == nil){
            NSLog(@"railway can't find propery record!!!");
            block(nil);
            return;
        }
        
        
        [self makeObjectOfIdentifier:LineIdentifier ForDictionary:rec Block:^(NSManagedObjectID *moID) {
            
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

- (NSString *) query{
    return [@"Line_" stringByAppendingString:self.lineIdentifier];
}


- (void)main{
    
    if([self isCancelled] == YES){

        // [self removeLineObject];
        [self setFailure];
        [self startCallBack];
        [self completeOperation];
        return;
    }
    

    
    [self requestBy:self StationsForLine:self.lineIdentifier Block:^(NSManagedObjectID *moID) {
            
            if(moID == nil || [self isCancelled] == YES){
                NSLog(@"ODPTDataLoaderLine requestStations returns nil or cancelled. ident:%@", self.lineIdentifier);
                // キャンセル時・アクセス失敗時 LineObjectを削除する
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

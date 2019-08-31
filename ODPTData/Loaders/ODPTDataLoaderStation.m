//
//  ODPTDataLoaderStation.m
//
//  Copyright (c) 2018 Takehito Ikema
//
//  This software is released under the MIT License.
//  https://opensource.org/licenses/mit-license.php
//
#import "ODPTDataLoaderStation.h"
#import "ODPTDataAdditional.h"
#import "ODPTDataLoaderLine.h"
#import "ODPTDataLoaderArray.h"

@implementation ODPTDataLoaderStation{
    
    NSManagedObjectID *retID;
    
}

- (id)init{
    
    NSAssert(YES, @"ODPTDataLoaderStation must not use init message.");
    
    return nil;
}


- (id) initWithStation:(NSString *)stationIdentifier Block:(void (^)(NSManagedObjectID *))block{
    
    if(self = [super init]){
        self.stationIdentifier = stationIdentifier;
        NSAssert(self.stationIdentifier != nil,  @"ODPTDataLoaderStation stationIdentifier is nil!!");
        
        self.callback = [block copy]; // IMPORTANT
        
    }
    
    return self;
}



- (BOOL)isCompleteObject:(NSManagedObject *)obj{
    // オブジェクトの完全性を確認. // performBlock 内から呼び出すこと
    
    //fetchDateがセットされていなければ不完全と考える
    NSDate *date = [obj valueForKey:@"fetchDate"];
    if(date == nil){
        return NO;
    }
    
    /*
    NSNumber *lon = [obj valueForKey:@"longitude"];
    if( [lon doubleValue] <= 0  ){
        // CoreData DBにて、 lon/latのデフォルト値は -1に設定。
        // 一度取得しようとして失敗した -> lon/latの値は 0に設定。
        // レコードはあるが、位置情報がDB登録されていない。 -> APIへアクセス
        // NSLog(@"no location. %f, %@", [lon doubleValue], StationIdentifier);
    }else{
        // レコードがあり、位置情報がDB登録されている -> blockを呼び、終了。
        // APIに登録されていない場合は、 lon/latはゼロ値でDB登録
        // NSLog(@"location exist. %f, %@", [lon doubleValue], StationIdentifier);
        // NSManagedObjectは、このブロックより外には渡さない。 -> NSDictionary へ変換。
        // NSDictionary *sdic = [self convertToDictionaryFromStationManagedObject:obj withFullfill:YES];
        // [dic addEntriesFromDictionary:sdic];
        
        
        moID = [obj objectID];
        
    }
    */
    return YES;
    
}

- (void) makeObjectOfIdentifier:(NSString *)StationIdentifier ForDictionary:(NSDictionary *)dict Block:(void (^)(NSManagedObjectID *))block {
    
    NSManagedObjectContext *moc = [self.dataManager managedObjectContextForConcurrent];
    
    __block NSManagedObjectID *moID = nil;

    [moc performBlockAndWait:^{
        NSManagedObject *stationObject = nil;
        
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
        
        if([results count] > 0){
            // レコードが存在するので、書き換える。
            stationObject = [results objectAtIndex:0];
        
        
            // title はすでに設定済み (ODPTDataLoaderLine)
            // [stationObject setValue:[dict objectForKey:@"dc:title"] forKey:@"title"];
            
            // geo:long/geo:lat として入ってくるオブジェクトは
            //   NSString      元のJSONデータで、正しく ""で数値が囲まれている場合。
            //   NSCFNumber    ""で囲まれていない場合は、数値として入ってくる。
            //   NSNull        (null) などと記載されている場合。
            
            id lon = [dict objectForKey:@"geo:long"];
            id lat = [dict objectForKey:@"geo:lat"];
            
            double rlon = [self convertLocationDataString:lon];
            double rlat = [self convertLocationDataString:lat];
            
            [stationObject setValue:[NSNumber numberWithDouble:rlon] forKey:@"longitude"];
            [stationObject setValue:[NSNumber numberWithDouble:rlat] forKey:@"latitude"];
            
            NSInteger stationType = [self stationTypeForStationIdentifier:StationIdentifier];
            if(stationType == ODPTDataStationTypeTrainStop){
                NSString *stationCode = [dict objectForKey:@"odpt:stationCode"];
                if(stationCode != nil && [stationCode isKindOfClass:[NSString class]] == YES){
                    [stationObject setValue:stationCode forKey:@"stationCode"];
                }
                
            }else if(stationType == ODPTDataStationTypeBusStop){
                NSString *title_ja = [dict objectForKey:@"dc:title"];
                if(title_ja != nil && [title_ja isKindOfClass:[NSString class]] == YES){
                    [stationObject setValue:title_ja forKey:@"title_ja"];
                }

                NSString *poleNumberString = [dict objectForKey:@"odpt:busstopPoleNumber"];
                if(poleNumberString != nil && [poleNumberString isKindOfClass:[NSString class]] == YES){
                    [stationObject setValue:poleNumberString forKey:@"busstopPoleNumber"];
                }
            }
            
            
            NSString *noteString = [dict objectForKey:@"odpt:note"];
            if(noteString != nil && [noteString isKindOfClass:[NSString class]] == YES){
                [stationObject setValue:noteString forKey:@"note"];
            }

            id operatorAnswer = [dict objectForKey:@"odpt:operator"];
            if([operatorAnswer isKindOfClass:[NSArray class]] == YES){
                NSArray *operatorArray = operatorAnswer;
                NSMutableString *operatorString = [[NSMutableString alloc] init];
                for(int i=0; i<[operatorArray count]; i++){
                    if(i!=0){
                        [operatorString appendString:@","];
                    }
                    [operatorString appendString:operatorArray[i]];
                }
                [stationObject setValue:operatorString forKey:@"operator"];
            }else if([operatorAnswer isKindOfClass:[NSString class]] == YES){
                NSString *operatorString = operatorAnswer;
                [stationObject setValue:operatorString forKey:@"operator"];
            }

            
            [stationObject setValue:[NSDate date] forKey:@"fetchDate"];  //読み込み完了を表す
            // connectingLines は別.
            
            // Save the context.
            if (![moc save:&error]) {
                // Replace this implementation with code to handle the error appropriately.
                // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
                abort();
            }
            // 永続保存は,別途
            
            moID = [stationObject objectID];
        }else{
            // おそらく LoaderLineがキャンセルされた  継続は不可能
            NSLog(@"ODPTDataLoaderStation can't find station Object %@", StationIdentifier);
            moID = nil;
        }
    }];
    
    block(moID);
    
    
}

    
    
    
// 一つの駅の詳細情報を取得する。
// APIへアクセスして、データを得て、 CoreDataデータベースに保管。
// type = odpt:Station  owl:sameAs = [StationIdentifier]
//
- (void)requestBy:(id)owner DetailOfStaion:(NSString *)StationIdentifier Block:(void (^)(NSManagedObjectID *))block{

    //  CoreData データベースにアクセス。
    __block BOOL objectFound = NO;
    __block NSManagedObjectID *moID = nil;
    __block NSString *lineIdentifierForStation = nil;
    
    NSManagedObjectContext *moc = [self.dataManager managedObjectContextForConcurrent];
    [moc performBlockAndWait:^{
        
        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Station"];
        [request setPredicate:[NSPredicate predicateWithFormat:@"identifier == %@", StationIdentifier]];
        
        NSError *error = nil;
        
        NSArray *results = [moc executeFetchRequest:request error:&error];
        
        if (results == nil) {
            NSLog(@"Error fetching objects: %@\n%@", [error localizedDescription], [error userInfo]);
            abort();
        }
        
        if([results count] == 0){
            //  該当する Station の レコードがない。 -> APIへアクセス。
            objectFound = NO;
            
        }else{
            objectFound = YES;
            
            NSManagedObject *obj = [results objectAtIndex:0];
            if([self isCompleteObject:obj] == YES){
                moID = [obj objectID];
            }else{
                // 掃除
                NSLog(@"ODPTDataLoaderStation object incompleted. clean up. ident: %@", self.stationIdentifier);
             
                NSSet *set = [obj valueForKey:@"nearPoints"];
                NSArray *ary = [set allObjects];
                for(NSManagedObject *p in ary){
                    [moc deleteObject:p];
                }
                
                // Save the context.
                if (![moc save:&error]) {
                    NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
                    abort();
                }
                // 永続保存は,別途
                
                
            }
            
            NSSet *lineSet = [obj valueForKey:@"lines"];
            NSArray *lineArray = [lineSet allObjects];
            if([lineArray count] > 0){
                NSManagedObject *lineObject = lineArray[0];
                lineIdentifierForStation = [lineObject valueForKey:@"identifier"];
            }
        }
        
    }];
    
    if(objectFound == NO){
        // まず stationIdentifier に対応する lineIdentifier を取得。
        
        [self requestLineIdentifierForStationIdentifier:StationIdentifier Block:^(NSString *accessLineIdentifier) {
            
            if(accessLineIdentifier == nil){
                // stationが属するlineを見つけられない.
                // このstation objectは作成できない
                block(nil);
                return;
            };
            
            // Line オブジェクトを作る。
            ODPTDataLoaderLine *job = [[ODPTDataLoaderLine alloc] initWithLine:accessLineIdentifier Block:^(NSManagedObjectID *moID) {
                
                // Station オブジェクトのAPIアクセス
                [self startAccessAPIBy:owner DetailOfStaion:StationIdentifier OfLine:accessLineIdentifier Block:^(NSManagedObjectID *moID) {
                    block(moID);
                }];
                
            }];
            
            job.dataProvider = self.dataProvider;
            job.dataManager = self.dataManager;
            [job setParent:self];
            
            [[self queue] addLoader:job];
        }];
        
        return;
    }else{
        if(moID != nil){
            block(moID);
            return;
        }
    }
    
    // APIへアクセス可能な路線か確認
    /*
    if(! [self isAbleToAccessAPIOfLine:LineIdentifier]){
        // 内部データに駅名があるか、確認
        NSString *stationTitle = [[ODPTDataAdditional sharedData] stationTitleForIdentifier:StationIdentifier];
        if(stationTitle == nil){
            stationTitle = @"";
        }
        
        NSDictionary *rec = [NSDictionary dictionaryWithObjectsAndKeys:
                             StationIdentifier, @"owl:sameAs",
                             stationTitle, @"dc:title",
                             nil];
        
        [self makeObjectOfIdentifier:StationIdentifier ForDictionary:rec Block:^(NSManagedObjectID *moID) {
            if(moID != nil){
                block(moID);
                return;
            }
        }];
        return;
    }
     */
    

    [self startAccessAPIBy:owner DetailOfStaion:StationIdentifier OfLine:lineIdentifierForStation Block:^(NSManagedObjectID *moID) {
        block(moID);
    }];
    
}

// LineIdentifier はnilでも　可。　入れておくとこのLineの全ての駅情報を取得、記録する。(のちのちアクセスが減る)
- (void)startAccessAPIBy:(id)owner DetailOfStaion:(NSString *)StationIdentifier OfLine:(NSString *)LineIdentifier Block:(void (^)(NSManagedObjectID *))block{


    // APIアクセス開始。
    
    NSString *ltype = nil;
    NSInteger type = [self stationTypeForStationIdentifier:StationIdentifier];
    if(type == ODPTDataStationTypeTrainStop){
        ltype = @"odpt:Station";
    }else if(type == ODPTDataStationTypeBusStop){
        ltype = @"odpt:BusstopPole";
    }else{
        NSLog(@"invalid type. line=%@, station=%@", LineIdentifier, StationIdentifier);
    }
    
    NSDictionary *pred;
    
    NSString *originalStationIdentifier = StationIdentifier;
    
    if(LineIdentifier != nil){
        // 路線全ての駅を取得。
        
        // 独自拡張
        //  odpt.Railway:xxxxx.1.1 を一時的に消して、APIへアクセス。
        NSString *shortLineIdentifier = [self removeFooterFromLineIdentifier:LineIdentifier];
        
        NSString *rtype = nil;
        if(type == ODPTDataStationTypeTrainStop){
            rtype = @"odpt:railway";
        }else if(type == ODPTDataStationTypeBusStop){
            rtype = @"odpt:busroutePattern";
        }else{
            NSLog(@"invalid type. line=%@, station=%@", LineIdentifier, StationIdentifier);
        }
        
        pred = [NSDictionary dictionaryWithObjectsAndKeys:
                ltype, @"type",
                shortLineIdentifier, rtype,
                nil];
        
    }else{
        // 単独の駅を取得
        
        pred = [NSDictionary dictionaryWithObjectsAndKeys:
                ltype, @"type",
                originalStationIdentifier, @"owl:sameAs",
                nil];
    }
    
    [self.dataProvider requestAccessWithOwner:owner withPredicate:pred block:^(id ary) {
    
        
                                             if(ary == nil || [ary count] == 0){
                                                 block(nil);
                                                 return;
                                             }
                                             
                                             NSDictionary *rec = nil;
                                             
                                             BOOL flag = NO;
                                             for(int i=0; i<[ary count]; i++){
                                                 rec = [ary objectAtIndex:i];
                                                 if([originalStationIdentifier isEqualToString:[rec objectForKey:@"owl:sameAs"]]){
                                                     flag = YES;
                                                     break;
                                                 }
                                             }
                                             
                                             if(flag == NO){
                                                 NSLog(@"station can't find propery record!!!");
                                                 block(nil);
                                                 return;
                                             }
                                             
                                             [self makeObjectOfIdentifier:StationIdentifier ForDictionary:rec Block:^(NSManagedObjectID *moID) {
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
    return [@"Station_" stringByAppendingString:self.stationIdentifier];
}

- (void)main{
    if([self isCancelled] == YES){
        [self setFailure];
        [self startCallBack];
        [self completeOperation];
        return;
    }

    [self requestBy:self DetailOfStaion:self.stationIdentifier Block:^(NSManagedObjectID *moID){

        if(moID == nil || [self isCancelled] == YES){
            NSLog(@"ODPTDataLoaderStation requestStations returns nil or cancelled. ident:%@", self.stationIdentifier);
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



- (void)requestLineIdentifierForStationIdentifier:(NSString *)StationIdentifier Block:(void (^)(NSString *))block{
    
    // APIアクセス開始。
    
    NSString *ltype = nil;
    NSInteger type = [self stationTypeForStationIdentifier:StationIdentifier];
    if(type == ODPTDataStationTypeTrainStop){
        ltype = @"odpt:Station";
    }else if(type == ODPTDataStationTypeBusStop){
        ltype = @"odpt:BusstopPole";
    }
    NSAssert(ltype != nil, @"lineIdentifierForStationIdentifier invalid stationType. station=%@", StationIdentifier);
    
    // 独自拡張
    NSString *originalStationIdentifier = StationIdentifier;
    
    NSDictionary *pred;
    
    pred = [NSDictionary dictionaryWithObjectsAndKeys:
            ltype, @"type",
            originalStationIdentifier, @"owl:sameAs",
            nil];
    
    [self.dataProvider requestAccessWithOwner:nil withPredicate:pred block:^(id ary) {
        
        if(ary == nil || [ary count] == 0){
            block(nil);
            return;
        }
        
        NSDictionary *rec = nil;
        
        BOOL flag = NO;
        for(int i=0; i<[ary count]; i++){
            rec = [ary objectAtIndex:i];
            if([originalStationIdentifier isEqualToString:[rec objectForKey:@"owl:sameAs"]]){
                flag = YES;
                break;
            }
        }
        
        if(flag == NO){
            NSLog(@"station can't find propery record!!!");
            block(nil);
            return;
        }
        
        NSArray *lineIdentifiers = nil;
        if(type == ODPTDataStationTypeTrainStop){
            NSString *shortLineIdentifier = nil;
            shortLineIdentifier = [rec objectForKey:@"odpt:railway"];
            lineIdentifiers = [self addAllSuffixLineIdentifierExtension:shortLineIdentifier];
        }else if(type == ODPTDataStationTypeBusStop){
            id identObj = [rec objectForKey:@"odpt:busroutePattern"];
            if([identObj isKindOfClass:[NSArray class]] == YES){
                lineIdentifiers = identObj;
            }else if([identObj isKindOfClass:[NSString class]] == YES){
                lineIdentifiers = @[identObj];
            }
        }
        
        if(lineIdentifiers == nil || [lineIdentifiers count] == 0){
            block(nil);
        }else{
            block(lineIdentifiers[0]);
        }
        
    }];
    
}

@end

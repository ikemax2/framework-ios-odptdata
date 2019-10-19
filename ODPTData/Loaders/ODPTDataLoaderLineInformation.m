//
//  ODPTDataLoaderLineInformation.m
//
//  Copyright (c) 2018 Takehito Ikema
//
//  This software is released under the MIT License.
//  https://opensource.org/licenses/mit-license.php
//
#import "ODPTDataLoaderLineInformation.h"

@implementation ODPTDataLoaderLineInformation{
    
    NSManagedObjectID *retID;
}

- (id)init{
    
    NSAssert(YES, @"ODPTDataLoaderLineInformation must not use init message.");
    
    return nil;
}


- (id) initWithLine:(NSString *)lineIdentifier Block:(void (^)(NSManagedObjectID *))block{
    
    if(self = [super init]){
        self.lineIdentifier = lineIdentifier;
        NSAssert(self.lineIdentifier != nil,  @"ODPTDataLoaderLineInformation lineIdentifier is nil!!");
        
        self.callback = [block copy]; // IMPORTANT
        
    }
    
    return self;
}



- (void) makeObjectOfIdentifier:(NSString *)LineIdentifier ForDictionary:(NSDictionary *)dict Block:(void (^)(NSManagedObjectID *))block {
    
    NSManagedObjectContext *moc = [self.dataManager managedObjectContextForConcurrent];
    
    __block NSManagedObjectID *moID = nil;
    [moc performBlockAndWait:^{
        // CoreData DBから書き換えるべき object を受け取る。
        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"LineInformation"];
        [request setPredicate:[NSPredicate predicateWithFormat:@"lineIdentifier == %@", LineIdentifier]];
        
        NSError *error = nil;
        NSArray *results = [moc executeFetchRequest:request error:&error];
        
        if (results == nil) {
            NSLog(@"Error fetching objects: %@\n%@", [error localizedDescription], [error userInfo]);
            abort();
            return;
        }
        
        NSManagedObject *lineInformationObject = nil;
        
        if([results count] == 0){
            NSLog(@"can't find station Object %@", LineIdentifier);
            abort();
        }else{
            // レコードが存在するので、書き換える。
            lineInformationObject = [results objectAtIndex:0];
        }
        
        NSArray *origKeys = @[@"odpt:trainInformationStatus", @"odpt:trainInformationText", @"odpt:trainInformationCause", @"odpt:trainInformationLine"];
        NSArray *dataKeys = @[@"status", @"text", @"cause", @"bound"];
        NSArray *langs = @[@"ja", @"en"];  // 1番目が優先言語。 空の言語がある場合は、その言語の情報をセット。
        
        for(int i=0; i<[origKeys count]; i++){
            NSDictionary *ldict = [dict objectForKey:origKeys[i]];
            
            if([ldict isKindOfClass:[NSNull class]] == YES || ldict == nil || [ldict isKindOfClass:[NSString class]] == YES){
                // null 表記
                ldict = @{@"ja":@"", @"en":@""};
            }
            
            // NSLog(@"ldict: %@", ldict);
            NSString *baseValue = nil;
            for(int j=0; j<[langs count]; j++){
                NSString *dataKey = [NSString stringWithFormat:@"%@_%@", dataKeys[i], langs[j]];
                
                NSString *value = [ldict objectForKey:langs[j]];
                [lineInformationObject setValue:value forKey:dataKey];
                if(baseValue == nil){
                    baseValue = value;
                }
            }
            
            if(baseValue != nil){
                for(int j=0; j<[langs count]; j++){
                    NSString *dataKey = [NSString stringWithFormat:@"%@_%@", dataKeys[i], langs[j]];
                    NSString *value = [lineInformationObject valueForKey:dataKey];
                    if([value isEqualToString:@""] || value == nil){
                        [lineInformationObject setValue:baseValue forKey:dataKey];
                    }
                }
            }
            
        }
        
        
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ssZ"];
        
        NSString *dateString = [dict objectForKey:@"dct:valid"];
        NSDate *d = [formatter dateFromString:dateString];
        [lineInformationObject setValue:d forKey:@"validDate"];

        dateString = [dict objectForKey:@"odpt:timeOfOrigin"];
        d = [formatter dateFromString:dateString];
        [lineInformationObject setValue:d forKey:@"originDate"];
        
        [lineInformationObject setValue:[NSDate date] forKey:@"fetchDate"];
        
        // Save the context.
        if (![moc save:&error]) {
            // Replace this implementation with code to handle the error appropriately.
            // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
            abort();
        }
        // 永続保存は,別途
        
        moID = [lineInformationObject objectID];
        
    }];
    
    block(moID);
    
}

- (void)requestBy:(id)owner lineInformationOf:(NSString *)LineIdentifier Block:(void (^)(NSManagedObjectID *))block{
    
    //  CoreData データベースにアクセス。
    
    __block NSManagedObjectID *moID = nil;
    __block BOOL validFlag = YES;
    
    NSManagedObjectContext *moc = [self.dataManager managedObjectContextForConcurrent];
    [moc performBlockAndWait:^{
        
        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"LineInformation"];
        [request setPredicate:[NSPredicate predicateWithFormat:@"lineIdentifier == %@", LineIdentifier]];
        
        NSError *error = nil;
        
        NSArray *results = [moc executeFetchRequest:request error:&error];
        
        if (results == nil) {
            NSLog(@"Error fetching objects: %@\n%@", [error localizedDescription], [error userInfo]);
            abort();
        }
        
        if([results count] == 0){
            //  該当する LineInformation の レコードがない。 -> APIへアクセス。
            // レコードが存在しないので、新たに作る。
            NSManagedObject *obj = [NSEntityDescription insertNewObjectForEntityForName:@"LineInformation" inManagedObjectContext:moc];
            [obj setValue:LineIdentifier forKey:@"lineIdentifier"];
            
            // Save the context.
            if (![moc save:&error]) {
                NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
                abort();
            }
            // 永続保存は,別途
            
        }else{
            
            NSManagedObject *obj = [results objectAtIndex:0];
            if([self isValidDateOfObject:obj] == NO){
                validFlag = NO;
            }
            moID = [obj objectID];

        }
        
    }];
    
    if(moID != nil){
        // 有効期限内であれば、そのまま返す。
        if(validFlag == YES){
            block(moID);
            return;
        }

    }
    
    
    NSInteger type = [self lineTypeForLineIdentifier:LineIdentifier];
    
    if(type == ODPTDataLineTypeBus){
        // バスは、現時点では informationの配信はない. -> 例外なく正常とする

        NSDictionary *rec = [NSDictionary dictionaryWithObjectsAndKeys:
                             LineIdentifier, @"odpt:busroutePattern",
                             @{@"ja":@"平常運転", @"en":@"Normal Operation"}, @"odpt:trainInformationStatus",
                             @{@"ja":@"平常通り運転しています。", @"en":@"The train is on time."}, @"odpt:trainInformationText",
                             nil];
        
        [self makeObjectOfIdentifier:LineIdentifier ForDictionary:rec Block:^(NSManagedObjectID *moID) {
            if(moID != nil){
                block(moID);
                return;
            }
        }];
        
        return;
    }
    

    // APIへアクセス可能な路線か確認
    if(! [self isAbleToAccessAPIOfLine:LineIdentifier]){
        
        NSDictionary *rec = [NSDictionary dictionaryWithObjectsAndKeys:
                             LineIdentifier, @"odpt:railway",
                             @"", @"odpt:trainInformationStatus",
                             @"", @"odpt:trainInformationText",
                             nil];
        
        [self makeObjectOfIdentifier:LineIdentifier ForDictionary:rec Block:^(NSManagedObjectID *moID) {
            if(moID != nil){
                block(moID);
                return;
            }
        }];
        return;
    }
    
    
    // APIアクセス開始。
    
    // 独自拡張
    //  odpt.Railway:xxxxx.1.1 を一時的に消して、APIへアクセス。
    NSString *shortLineIdentifier = [self removeFooterFromLineIdentifier:LineIdentifier];
    
    // 事業者ごとに取得
    NSString *operator = [self operatorIdentifierForLineIdentifier:LineIdentifier];
    
    NSString *ltype = @"odpt:TrainInformation";
    
    NSDictionary *pred = [NSDictionary dictionaryWithObjectsAndKeys:
                          ltype, @"type",
                          //shortLineIdentifier, @"odpt:railway",
                          operator, @"odpt:operator",
                          nil];
    
    [self.dataProvider requestAccessWithOwner:owner withPredicate:pred block:^(id ary) {
        
        if(ary == nil){
            block(nil);
            return;
        }
        
        NSDictionary *rec = nil;
        
        for(int i=0; i<[ary count]; i++){
            rec = [ary objectAtIndex:i];
            if([shortLineIdentifier isEqualToString:[rec objectForKey:@"odpt:railway"]]){
                break;
            }
        }
        
        if(rec == nil){
            // 異常がない場合、レコードを返さない事業者もある JR-East など
            // レコードがない場合は異常なしと考える
            rec = @{@"odpt:trainInformationStatus":@{@"ja":@"平常運転", @"en":@"Normal Operation"},
                    @"odpt:trainInformationText":@{@"ja":@"平常通り運転しています。", @"en":@"The train is on time."}};
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

- (NSString *)query{
    return [@"LineInformation_" stringByAppendingString:self.lineIdentifier];
}

- (void)main{
    if([self isCancelled] == YES){
        [self setFailure];
        [self startCallBack];
        [self completeOperation];
        return;
    }
    
    
    [self requestBy:self lineInformationOf:self.lineIdentifier Block:^(NSManagedObjectID *moID){
        
        if(moID == nil || [self isCancelled] == YES){
            NSLog(@"requestLineInformation returns nil or cancelled. ident:%@", self.lineIdentifier);
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

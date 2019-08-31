//
//  ODPTDataLoaderTrainLocation.m
//
//  Copyright (c) 2018 Takehito Ikema
//
//  This software is released under the MIT License.
//  https://opensource.org/licenses/mit-license.php
//

#import "ODPTDataLoaderTrainLocation.h"
#import "ODPTDataLoaderLine.h"

@implementation ODPTDataLoaderTrainLocation{
    
    NSManagedObjectID *retID;
}

- (id)init{
    
    NSAssert(YES, @"ODPTDataLoaderTrainLocation must not use init message.");
    
    return nil;
}


- (id) initWithLine:(NSString *)lineIdentifier Block:(void (^)(NSManagedObjectID *))block{
    
    if(self = [super init]){
        self.lineIdentifier = lineIdentifier;
        NSAssert(self.lineIdentifier != nil,  @"ODPTDataLoaderTrainLocation lineIdentifier is nil!!");
        
        self.callback = [block copy]; // IMPORTANT
        
    }
    
    return self;
}

- (void) makeObjectOfLineIdentifier:(NSString *)LineIdentifier ForArray:(NSArray *)ary Block:(void (^)(NSManagedObjectID *))block {
    
    NSManagedObjectContext *moc = [self.dataManager managedObjectContextForConcurrent];
    
    __block NSManagedObjectID *moID = nil;
    
    [moc performBlockAndWait:^{
        
        NSManagedObject *locationArrayObject = nil;
        
        // CoreData DBから書き換えるべき object を受け取る。
        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"TrainLocationArray"];
        [request setPredicate:[NSPredicate predicateWithFormat:@"ofLine == %@", LineIdentifier]];
        
        NSError *error = nil;
        NSArray *results = [moc executeFetchRequest:request error:&error];
        
        if (results == nil) {
            NSLog(@"Error fetching objects: %@\n%@", [error localizedDescription], [error userInfo]);
            abort();
            return;
        }
        
        if([results count] == 0){
            NSLog(@"can't find station Object %@", LineIdentifier);
            abort();
        }
        
        NSInteger type = [self lineTypeForLineIdentifier:self.lineIdentifier];
        
        locationArrayObject = [results objectAtIndex:0];
        
        NSDate *minDate = nil;
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ssZ"];
        
        NSMutableSet *set = [[NSMutableSet alloc] init];
        for(int i=0; i<[ary count]; i++){
                
            NSDictionary *rec = [ary objectAtIndex:i];
                
            // レコードを新たに作る。
            NSManagedObject *recordObject = [NSEntityDescription insertNewObjectForEntityForName:@"TrainLocation" inManagedObjectContext:moc];
            
            if(type == ODPTDataLineTypeRailway){
                NSString *trainNumber = [rec objectForKey:@"odpt:trainNumber"];
                [recordObject setValue:trainNumber forKey:@"trainNumber"];
            
                NSString *startIdent = [rec objectForKey:@"odpt:startingStation"];
                [recordObject setValue:startIdent forKey:@"startingStation"];
            
                NSString *terminalIdent = [rec objectForKey:@"odpt:terminalStation"];
                [recordObject setValue:terminalIdent forKey:@"terminalStation"];

            
                NSString *str = [rec objectForKey:@"odpt:delay"];
                float delay = 0.0f;
                if(str != nil && [str isKindOfClass:[NSNull class]] == NO){
                    delay = [str floatValue];
                }
                [recordObject setValue:[NSNumber numberWithFloat:delay] forKey:@"delay"];
            
            
                NSString *fromIdent = [rec objectForKey:@"odpt:fromStation"];
                [recordObject setValue:fromIdent forKey:@"fromStation"];
            
                NSString *toIdent = [rec objectForKey:@"odpt:toStation"];
                if(toIdent != nil && [toIdent isKindOfClass:[NSNull class]] == NO){
                    [recordObject setValue:toIdent forKey:@"toStation"];
                }else{
                    [recordObject setValue:@"" forKey:@"toStation"];
                }
                
            }else if(type == ODPTDataLineTypeBus){
                NSString *trainNumber = [rec objectForKey:@"odpt:busNumber"];
                if(trainNumber != nil){
                    [recordObject setValue:trainNumber forKey:@"trainNumber"];
                }
                
                NSString *startIdent = [rec objectForKey:@"odpt:startingBusstopPole"];
                if(startIdent != nil){
                    [recordObject setValue:startIdent forKey:@"startingStation"];
                }
                
                NSString *terminalIdent = [rec objectForKey:@"odpt:terminalBusstopPole"];
                if(terminalIdent != nil){
                    [recordObject setValue:terminalIdent forKey:@"terminalStation"];
                }
                
                NSString *fromIdent = [rec objectForKey:@"odpt:fromBusstopPole"];
                [recordObject setValue:fromIdent forKey:@"fromStation"];
                
                NSString *toIdent = [rec objectForKey:@"odpt:toBusstopPole"];
                if(toIdent != nil && [toIdent isKindOfClass:[NSNull class]] == NO){
                    [recordObject setValue:toIdent forKey:@"toStation"];
                }else{
                    [recordObject setValue:@"" forKey:@"toStation"];
                }
                
            }
            
            [set addObject:recordObject];

            // 複数のレコードの中で dc:date が最も早いものを探し、 minDate とする。
            NSDate *d = [formatter dateFromString:[rec objectForKey:@"dc:date"]];
            
            if(minDate == nil){
                minDate = d;
            }else{
                minDate = [minDate earlierDate:d];
            }
        }
            
        [locationArrayObject setValue:set forKey:@"locations"];
        
        // Errata  TrainLocation の ValidDateは有効な時間を指していない。
        // locationArrayObject の有効期間は minDate から　95秒後とする。
        if(minDate == nil){
            minDate = [NSDate date];
        }
        NSDate *validDate = [NSDate dateWithTimeInterval:95.0 sinceDate:minDate];
        
        [locationArrayObject setValue:validDate forKey:@"validDate"];
        
        [locationArrayObject setValue:[NSDate date] forKey:@"fetchDate"];
        
        // Save the context.
        if (![moc save:&error]) {
            // Replace this implementation with code to handle the error appropriately.
            // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
            abort();
        }
        // 永続保存は,別途
        
        moID = [locationArrayObject objectID];
        
    }];
    
    block(moID);
    
}


- (void)requestBy:(id)owner trainLocationOfLine:(NSString *)LineIdentifier Block:(void (^)(NSManagedObjectID *))block{
    
    //  CoreData データベースにアクセス。
    
    __block NSManagedObjectID *moID = nil;
    __block BOOL validFlag = YES;
    
    NSManagedObjectContext *moc = [self.dataManager managedObjectContextForConcurrent];
    [moc performBlockAndWait:^{
        
        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"TrainLocationArray"];
        [request setPredicate:[NSPredicate predicateWithFormat:@"ofLine == %@", LineIdentifier]];
        
        NSError *error = nil;
        
        NSArray *results = [moc executeFetchRequest:request error:&error];
        
        if (results == nil) {
            NSLog(@"Error fetching objects: %@\n%@", [error localizedDescription], [error userInfo]);
            abort();
        }
        
        if([results count] == 0){
            //  該当する TrainLocationArray の レコードがない。 -> APIへアクセス。
            // レコードが存在しないので、新たに作る。
            NSManagedObject *obj = [NSEntityDescription insertNewObjectForEntityForName:@"TrainLocationArray" inManagedObjectContext:moc];
            [obj setValue:LineIdentifier forKey:@"ofLine"];
            
            // Save the context.
            if (![moc save:&error]) {
                NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
                abort();
            }
            
            // 永続保存は,別途
            
        }else{
            
            NSManagedObject *obj = [results objectAtIndex:0];
            if([self isValidDateOfObject:obj] == NO){
                //  該当する TrainLocationArray の 有効期限切れ -> APIへアクセス。
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
    
    // APIへアクセス可能な路線か確認
    if(! [self isAbleToAccessAPIOfLine:LineIdentifier]){
        
        [self makeObjectOfLineIdentifier:LineIdentifier ForArray:@[] Block:^(NSManagedObjectID *moID) {
            
            if(moID != nil){
                block(moID);
                return;
            }
        }];
        return;
    }
    
    
    // APIアクセス開始。
    
    __block ODPTDataLoaderLine *job;
    job = [[ODPTDataLoaderLine alloc] initWithLine:self.lineIdentifier Block:^(NSManagedObjectID *moID) {
        
        if(moID == nil){
            // APIアクセスに失敗。
            NSLog(@"ODPTDataLoaderLine return nil. ident:%@", self.lineIdentifier);

            block(nil);
            return;
        }
        
        NSManagedObjectContext *moc = [self.dataManager managedObjectContextForConcurrent];
        
        __block NSArray *directions;
        
        [moc performBlockAndWait:^{
            NSManagedObject *obj = [moc objectWithID:moID];
            
            directions  = [job directionIdentifierForLineObject:obj];
        }];
        
        
        
        NSMutableArray *preds = [[NSMutableArray alloc] init];
        NSInteger type = [self lineTypeForLineIdentifier:self.lineIdentifier];
        if(type == ODPTDataLineTypeRailway){
            
            // railDirectionは複数帰ってくる場合がある。
            NSArray *railDirections = directions;
            
            NSString *shortLineIdentifier = [job removeFooterFromLineIdentifier:self.lineIdentifier];
            NSMutableArray *lineIdentifiers = [[NSMutableArray alloc] init];
            for(int i=0; i<[railDirections count]; i++){
                [lineIdentifiers addObject:shortLineIdentifier];
            }
            
            for(int i=0; i<[railDirections count]; i++){
                NSDictionary *pred = [NSDictionary dictionaryWithObjectsAndKeys:
                                      @"odpt:Train", @"type",
                                      railDirections[i], @"odpt:railDirection",
                                      lineIdentifiers[i], @"odpt:railway",
                                      nil];
                [preds addObject:pred];
            }
        }else if(type == ODPTDataLineTypeBus){
            
            NSDictionary *pred = [NSDictionary dictionaryWithObjectsAndKeys:
                                  @"odpt:Bus", @"type",
                                  self.lineIdentifier, @"odpt:busroutePattern",
                                  nil];
            [preds addObject:pred];
            
        }
        
        
        
        
        [self.dataProvider requestSequentialAccessWithOwner:owner withPredicates:preds block:^(NSArray<id> *ary) {
            
            NSMutableArray *nextArray = [[NSMutableArray alloc] init];
            for(int i=0; i<[ary count]; i++){
                id obj = [ary objectAtIndex:i];
                
                if([obj isKindOfClass:[NSNull class]] == YES){
                    // いくつかアクセスに失敗した -> アクセス失敗とみなす
                    block(nil);
                    return;
                }
                // NSAssert([obj isKindOfClass:[NSArray class]], @"ODPTDataLoaderTrainLocation return value is abnormal.");
                
                [nextArray addObjectsFromArray:obj];
            }
            
            [self makeObjectOfLineIdentifier:LineIdentifier ForArray:nextArray Block:^(NSManagedObjectID *moID) {
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
    return [@"TrainLocation_" stringByAppendingString:self.lineIdentifier];
}

- (void)main{
    if([self isCancelled] == YES){
        [self setFailure];
        [self startCallBack];
        [self completeOperation];
        return;
    }
    
    [self requestBy:self trainLocationOfLine:self.lineIdentifier Block:^(NSManagedObjectID *moID) {
        
        if(moID == nil || [self isCancelled] == YES){
            NSLog(@"requestTrainLocation returns nil or cancelled. ident:%@", self.lineIdentifier);
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


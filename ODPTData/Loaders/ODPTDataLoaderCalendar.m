//
//  ODPTDataLoaderCalendar.m
//
//  Copyright (c) 2018 Takehito Ikema
//
//  This software is released under the MIT License.
//  https://opensource.org/licenses/mit-license.php
//
#import "ODPTDataLoaderCalendar.h"

@implementation ODPTDataLoaderCalendar{
    
    NSManagedObjectID *retID;
}

- (id)init{
    
    NSAssert(YES, @"ODPTDataLoaderCalendar must not use init message.");
    
    return nil;
}

- (id) initWithCalendar:(NSString *)calendarIdentifier Block:(void (^)(NSManagedObjectID *))block{
    
    if(self = [super init]){
        self.calendarIdentifier = calendarIdentifier;
        NSAssert(self.calendarIdentifier != nil,  @"ODPTDataLoaderCalendar lineIdentifier is nil!!");
        
        self.callback = [block copy]; // IMPORTANT
        
    }
    
    return self;
}


- (void) makeObjectOfIdentifier:(NSString *)identifier ForArray:(NSArray *)ary Block:(void (^)(NSManagedObjectID *))block {
    
    NSManagedObjectContext *moc = [self.dataManager managedObjectContextForConcurrent];
    
    __block NSManagedObjectID *moID = nil;
    
    [moc performBlockAndWait:^{
        
        NSManagedObject *calendarObject = nil;
        
        // CoreData DBから書き換えるべき object を受け取る。
        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Calendar"];
        [request setPredicate:[NSPredicate predicateWithFormat:@"identifier == %@", identifier]];
        
        NSError *error = nil;
        NSArray *results = [moc executeFetchRequest:request error:&error];
        
        if (results == nil) {
            NSLog(@"Error fetching objects: %@\n%@", [error localizedDescription], [error userInfo]);
            abort();
            return;
        }
        
        if([results count] == 0){
            NSLog(@"can't find station Object %@", identifier);
            abort();
        }
        
        calendarObject = [results objectAtIndex:0];
        
        for(int i=0; i<[ary count]; i++){
            
            NSDictionary *rec = [ary objectAtIndex:i];
            
            if([[rec objectForKey:@"owl:sameAs"] isEqualToString:identifier] == NO){
                continue;
            }
            
            NSDictionary *titleDict = [rec objectForKey:@"odpt:calendarTitle"];
            if(titleDict != nil){
                NSArray *langs = @[@"en", @"ja"];
                for(NSString *l in langs){
                    NSString *key = [@"title_" stringByAppendingString:l];
                    NSString *title = [titleDict objectForKey:l];
                    [calendarObject setValue:title forKey:key];
                }
            }else{
                NSArray *f = [identifier componentsSeparatedByString:@":"];
                
                NSString *title_ja = [rec objectForKey:@"dc:title"];
                if([title_ja isKindOfClass:[NSString class]] == YES){
                    [calendarObject setValue:title_ja forKey:@"title_ja"];
                    [calendarObject setValue:f[1] forKey:@"title_en"];
                }else{
                    [calendarObject setValue:f[1] forKey:@"title_ja"];
                    [calendarObject setValue:f[1] forKey:@"title_en"];
                }
            }
            
            NSString *operator = [rec objectForKey:@"odpt:operator"];
            if(operator != nil){
                [calendarObject setValue:operator forKey:@"operator"];
            }
            
            NSString *duration = [rec objectForKey:@"odpt:duration"];
            if(duration != nil){
                [calendarObject setValue:duration forKey:@"duration"];
            }
            
            NSArray *days = [rec objectForKey:@"odpt:day"];
            if(days != nil){
                NSMutableString *daysString = [[NSMutableString alloc] init];
                for(int i=0; i<[days count]; i++){
                    if(i != 0){
                        [daysString appendString:@","];
                    }
                    [daysString appendString:days[i]];
                }
                [calendarObject setValue:[daysString copy] forKey:@"day"];
            }
            
        }
        
        // Save the context.
        if (![moc save:&error]) {
            // Replace this implementation with code to handle the error appropriately.
            // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
            abort();
        }
        // 永続保存は,別途
        
        moID = [calendarObject objectID];

        
    }];
    
    block(moID);
    
}


- (void)requestBy:(id)owner calendarForIdentifier:(NSString *)identifier Block:(void (^)(NSManagedObjectID *))block{
    
    //  CoreData データベースにアクセス。
    
    __block NSManagedObjectID *moID = nil;
    __block BOOL validFlag = YES;
    
    NSManagedObjectContext *moc = [self.dataManager managedObjectContextForConcurrent];
    [moc performBlockAndWait:^{
        
        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Calendar"];
        [request setPredicate:[NSPredicate predicateWithFormat:@"identifier == %@", identifier]];
        
        NSError *error = nil;
        
        NSArray *results = [moc executeFetchRequest:request error:&error];
        
        if (results == nil) {
            NSLog(@"Error fetching objects: %@\n%@", [error localizedDescription], [error userInfo]);
            abort();
        }
        
        if([results count] == 0){
            //  該当する Calendar の レコードがない。 -> APIへアクセス。
            // レコードが存在しないので、新たに作る。
            NSManagedObject *obj = [NSEntityDescription insertNewObjectForEntityForName:@"Calendar" inManagedObjectContext:moc];
            [obj setValue:identifier forKey:@"identifier"];
            
            // Save the context.
            if (![moc save:&error]) {
                NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
                abort();
            }
            
            
        }else{
            
            NSManagedObject *obj = [results objectAtIndex:0];
            
            
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
    
    NSDictionary *pred = [NSDictionary dictionaryWithObjectsAndKeys:
                          @"odpt:Calendar", @"type",
                          nil];
    
    [self.dataProvider requestAccessWithOwner:owner withPredicate:pred block:^(id ary) {
        
        if(ary == nil){
            block(nil);
            return;
        }
        
        if([ary count] == 0){
            block(nil);
            return;
        }
        
        for(int i=0; i<[ary count]; i++){
            id obj = [ary objectAtIndex:i];
            NSAssert([obj isKindOfClass:[NSDictionary class]], @"ODPTDataLoaderCalendar return value is abnormal.");
        }
        
        [self makeObjectOfIdentifier:identifier ForArray:ary Block:^(NSManagedObjectID *moID) {
            block(moID) ;
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
    return [@"Calendar_" stringByAppendingString:self.calendarIdentifier];
}

- (void)main{
    if([self isCancelled] == YES){
        [self setFailure];
        [self startCallBack];
        [self completeOperation];
        return;
    }
    
    NSAssert([self.calendarIdentifier hasPrefix:@"odpt.Calendar:"] == YES, @"ODPTDataLoaderTrainType invalid identifier");
    
    [self requestBy:self calendarForIdentifier:self.calendarIdentifier Block:^(NSManagedObjectID *moID) {
        
        if(moID == nil || [self isCancelled] == YES){
            NSLog(@"requestCalendar returns nil or cancelled. ident:%@", self.calendarIdentifier);
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

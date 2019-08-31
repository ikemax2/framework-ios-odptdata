//
//  ODPTDataLoaderOperator.m
//
//  Copyright (c) 2019 Takehito Ikema
//
//  This software is released under the MIT License.
//  https://opensource.org/licenses/mit-license.php
//
#import "ODPTDataLoaderOperator.h"


@implementation ODPTDataLoaderOperator{
    
    NSManagedObjectID *retID;
}



- (id)init{
    
    NSAssert(YES, @"ODPTDataLoaderOperator must not use init message.");
    
    return nil;
}


- (id) initWithOperator:(NSString *)operatorIdentifier Block:(void (^)(NSManagedObjectID *))block{
    
    if(self = [super init]){
        self.operatorIdentifier = operatorIdentifier;
        NSAssert(self.operatorIdentifier != nil,  @"ODPTDataLoaderOperator lineIdentifier is nil!!");
        
        self.callback = [block copy]; // IMPORTANT
    }
    
    return self;
}


- (void) makeObjectOfIdentifier:(NSString *)identifier ForArray:(NSArray *)ary Block:(void (^)(NSManagedObjectID *))block {
    
    NSManagedObjectContext *moc = [self.dataManager managedObjectContextForConcurrent];
    
    __block NSManagedObjectID *moID = nil;
    
    [moc performBlockAndWait:^{
        
        NSManagedObject *operatorObject = nil;
        
        // CoreData DBから書き換えるべき object を受け取る。
        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Operator"];
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
        
        operatorObject = [results objectAtIndex:0];
        
        for(int i=0; i<[ary count]; i++){
            
            NSDictionary *rec = [ary objectAtIndex:i];
            
            if([[rec objectForKey:@"owl:sameAs"] isEqualToString:identifier] == NO){
                continue;
            }
            
            NSDictionary *titleDict = [rec objectForKey:@"odpt:operatorTitle"];
            
            NSArray *langs = @[@"en", @"ja"];
            for(NSString *l in langs){
                NSString *key = [@"title_" stringByAppendingString:l];
                NSString *title = [titleDict objectForKey:l];
                [operatorObject setValue:title forKey:key];
            }
            
            [operatorObject setValue:[NSDate date] forKey:@"fetchDate"];
            
        }
        
        // Save the context.
        if (![moc save:&error]) {
            // Replace this implementation with code to handle the error appropriately.
            // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
            abort();
        }
        // 永続保存は,別途
        
        moID = [operatorObject objectID];
        
    }];
    
    block(moID);
    
}


- (void)requestBy:(id)owner operatorForIdentifier:(NSString *)identifier Block:(void (^)(NSManagedObjectID *))block{
    
    //  CoreData データベースにアクセス。
    
    __block NSManagedObjectID *moID = nil;
    __block BOOL validFlag = YES;
    
    NSManagedObjectContext *moc = [self.dataManager managedObjectContextForConcurrent];
    [moc performBlockAndWait:^{
        
        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Operator"];
        [request setPredicate:[NSPredicate predicateWithFormat:@"identifier == %@", identifier]];
        
        NSError *error = nil;
        
        NSArray *results = [moc executeFetchRequest:request error:&error];
        
        if (results == nil) {
            NSLog(@"Error fetching objects: %@\n%@", [error localizedDescription], [error userInfo]);
            abort();
        }
        
        if([results count] == 0){
            //  該当する Operator の レコードがない。 -> APIへアクセス。
            // レコードが存在しないので、新たに作る。
            NSManagedObject *obj = [NSEntityDescription insertNewObjectForEntityForName:@"Operator" inManagedObjectContext:moc];
            [obj setValue:identifier forKey:@"identifier"];
            
            // Save the context.
            if (![moc save:&error]) {
                NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
                abort();
            }
            
        }else{
            
            NSManagedObject *obj = [results objectAtIndex:0];
            
            /*
            if([self isValidDateOfObject:obj] == NO){
                //  該当する Operator の 有効期限切れ -> APIへアクセス。
                validFlag = NO;
            }
             */
            validFlag = YES;
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
    
    // APIアクセス開始。
    
    NSDictionary *pred = [NSDictionary dictionaryWithObjectsAndKeys:
                          @"odpt:Operator", @"type",
                          identifier, @"owl:sameAs",
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
            NSAssert([obj isKindOfClass:[NSDictionary class]], @"ODPTDataLoaderOperator return value is abnormal.");
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
    return [@"Operator_" stringByAppendingString:self.operatorIdentifier];
}

- (void)main{
    if([self isCancelled] == YES){
        [self setFailure];
        [self startCallBack];
        [self completeOperation];
        return;
    }
    
    NSAssert([self.operatorIdentifier hasPrefix:@"odpt.Operator:"] == YES, @"ODPTDataLoaderOperator invalid identifier");
    
    [self requestBy:self operatorForIdentifier:self.operatorIdentifier Block:^(NSManagedObjectID *moID) {
        
        if(moID == nil || [self isCancelled] == YES){
            NSLog(@"requestOperator returns nil or cancelled. ident:%@", self.operatorIdentifier);
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

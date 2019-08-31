//
//  ODPTDataController+Place.m
//
//  Copyright (c) 2019 Takehito Ikema
//
//  This software is released under the MIT License.
//  https://opensource.org/licenses/mit-license.php
//
#import "ODPTDataController+Place.h"
#import "ODPTDataController+Common.h"
#import "ODPTDataLoader.h"

@implementation ODPTDataController (Place)

- (CLLocation * _Nullable)originPlacePosition{
    
    __block CLLocation *position = nil;
    NSManagedObjectContext *moc = [self->userDataManager managedObjectContextForConcurrent];
     
    [moc performBlockAndWait:^{
        
        NSManagedObject *object = [self originPlaceObjectOfMOC:moc];
        
        if(object != nil){
            position = [[CLLocation alloc] initWithLatitude:[[object valueForKey:@"latitude"] doubleValue]
                                                  longitude:[[object valueForKey:@"longitude"] doubleValue] ];
        }
        
    }];
    
    return position;
}


- (void)setOriginPlaceToPosition:(CLLocation *)position{
    // 初回起動時のみ、呼ばれる。
    // 指示される位置を TemporaryPlace として登録、 originフラグを立てる。
    
    [self setTemporaryPlaceWithPosition:position];
    [self setOriginToPlaceForIndex:-1];
    
    return;
}

- (void)makePlaceFetchedResultsController:(NSFetchedResultsController * _Nullable * _Nullable)frc{
    
    NSString *entityName = @"Place";
    NSArray *sortKeys = @[@"index"];
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:entityName];
    [request setPredicate:[NSPredicate predicateWithFormat:@"index >= -10"]];
    
    NSMutableArray *descriptors = [[NSMutableArray alloc] init];
    for(int i=0; i<[sortKeys count]; i++){
        NSSortDescriptor *desc = [NSSortDescriptor sortDescriptorWithKey:sortKeys[i] ascending:YES];
        [descriptors addObject:desc];
    }
    
    [request setSortDescriptors:descriptors];
    
    NSManagedObjectContext *moc = [self->userDataManager managedObjectContextForConcurrent];

    
    *frc = [[NSFetchedResultsController alloc] initWithFetchRequest:request managedObjectContext:moc sectionNameKeyPath:nil cacheName:nil];
}


- (void)addNewPlaceWithTitle:(NSString *)title withAddressString:(NSString *)addressString withPosition:(CLLocation *)position{
    
    NSManagedObjectContext *moc = [self->userDataManager managedObjectContextForConcurrent];
    
    [moc performBlockAndWait:^{
        
        NSManagedObject *newObject = [self newPlaceEntityObjectOfMOC:moc];
        
        [newObject setValue:title forKey:@"title"];
        [newObject setValue:addressString forKey:@"address"];
        
        [newObject setValue:[NSNumber numberWithDouble:position.coordinate.latitude] forKey:@"latitude"];
        [newObject setValue:[NSNumber numberWithDouble:position.coordinate.longitude] forKey:@"longitude"];
        
        NSError *error = nil;
        // Save the context.
        if (![moc save:&error]) {
            NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
            abort();
        }
        
        [self->userDataManager persist]; // 永続保管 非同期で。
    }];
}


- (void)deletePlaceForIndex:(NSInteger)index{
    
    NSManagedObjectContext *moc = [self->userDataManager managedObjectContextForConcurrent];
    
    [moc performBlockAndWait:^{
        
        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Place"];
        [request setPredicate:[NSPredicate predicateWithFormat:@"index == %d", index]];
        
        NSArray *results = nil;
        NSError *error = nil;
        results = [moc executeFetchRequest:request error:&error];
        if (results == nil) {
            NSLog(@"Error fetching objects: %@\n%@", [error localizedDescription], [error userInfo]);
            abort();
        }
        
        for(int i=0; i<[results count]; i++){
            NSManagedObject *object = [results objectAtIndex:i];
            [moc deleteObject:object];
        }
        
        // Save the context.
        if (![moc save:&error]) {
            // Replace this implementation with code to handle the error appropriately.
            // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
            abort();
        }
        
        [self->userDataManager persist]; // 永続保管 非同期で。
    }];
    
    
}

- (void)setVisible:(BOOL)visible toPlaceForIndex:(NSInteger)index{
    
    NSManagedObjectContext *moc = [self->userDataManager managedObjectContextForConcurrent];
    
    [moc performBlockAndWait:^{
        
        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Place"];
        [request setPredicate:[NSPredicate predicateWithFormat:@"index == %d", index]];
        
        NSArray *results = nil;
        NSError *error = nil;
        results = [moc executeFetchRequest:request error:&error];
        if (results == nil) {
            NSLog(@"Error fetching objects: %@\n%@", [error localizedDescription], [error userInfo]);
            abort();
        }
        
        for(int i=0; i<[results count]; i++){
            NSManagedObject *object = [results objectAtIndex:i];
            [object setValue:[NSNumber numberWithBool:visible] forKey:@"visible"];
        }
        
        // Save the context.
        if (![moc save:&error]) {
            // Replace this implementation with code to handle the error appropriately.
            // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
            abort();
        }
        [self->userDataManager persist]; // 永続保管 非同期で。
    }];
}

- (void)setTitle:(NSString *)title toPlaceForIndex:(NSInteger)index{
    
    NSManagedObjectContext *moc = [self->userDataManager managedObjectContextForConcurrent];
    
    [moc performBlockAndWait:^{
        
        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Place"];
        [request setPredicate:[NSPredicate predicateWithFormat:@"index == %d", index]];
        
        NSArray *results = nil;
        NSError *error = nil;
        results = [moc executeFetchRequest:request error:&error];
        if (results == nil) {
            NSLog(@"Error fetching objects: %@\n%@", [error localizedDescription], [error userInfo]);
            abort();
        }
        
        if([results count] > 1){
            NSLog(@"setTitle:toPlaceForIndex: detect multiple item for same index.");
        }
        
        for(int i=0; i<[results count]; i++){
            NSManagedObject *object = [results objectAtIndex:i];
            [object setValue:title forKey:@"title"];
        }
        
        // Save the context.
        if (![moc save:&error]) {
            // Replace this implementation with code to handle the error appropriately.
            // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
            abort();
        }
        [self->userDataManager persist]; // 永続保管 非同期で。
    }];
}

- (BOOL)isExistPlaceTitle:(NSString *)title{
    NSManagedObjectContext *moc = [self->userDataManager managedObjectContextForConcurrent];
    
    __block BOOL ret = NO;
    [moc performBlockAndWait:^{
        
        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Place"];
        [request setPredicate:[NSPredicate predicateWithFormat:@"title == %@", title]];
        
        NSArray *results = nil;
        NSError *error = nil;
        results = [moc executeFetchRequest:request error:&error];
        if (results == nil) {
            NSLog(@"Error fetching objects: %@\n%@", [error localizedDescription], [error userInfo]);
            abort();
        }
        
        if([results count] == 0){
            ret = NO;
        }else{
            ret = YES;
        }
    }];
    
    return ret;
}

- (void)setOriginToPlaceForIndex:(NSInteger)index{
    NSManagedObjectContext *moc = [self->userDataManager managedObjectContextForConcurrent];
    
    [moc performBlockAndWait:^{
        // 新たにoriginをセット
        NSFetchRequest *request =  [NSFetchRequest fetchRequestWithEntityName:@"Place"];
        [request setPredicate:[NSPredicate predicateWithFormat:@"index == %d", index]];
        
        NSArray *results = nil;
        NSError *error = nil;
        results = [moc executeFetchRequest:request error:&error];
        if (results == nil) {
            NSLog(@"Error fetching objects: %@\n%@", [error localizedDescription], [error userInfo]);
            abort();
        }
        
        if([results count] > 0){
            
            NSManagedObject *object = [results firstObject];
            
            [self setOriginToPlaceObject:object ofMOC:moc];
            
            // Save the context.
            if (![moc save:&error]) {
                // Replace this implementation with code to handle the error appropriately.
                // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
                abort();
            }
            [self->userDataManager persist]; // 永続保管 非同期で。
        }else{
            NSLog(@"setOriginToPlaceForIndex can't find Place Object index:%d", (int)index);
        }
    }];
    
}

- (CLLocationDistance)distanceFromPoint:(CLLocationCoordinate2D)pointA toPoint:(CLLocationCoordinate2D)pointB{
    
    ODPTDataLoader *loader = [[ODPTDataLoader alloc] init];
    return [loader distanceFromPoint:pointA toPoint:pointB];
    
}

- (NSInteger)placeIndexForOrigin{
    // __block CLLocation *position = nil;
    NSManagedObjectContext *moc = [self->userDataManager managedObjectContextForConcurrent];
    
    __block NSInteger retIndex = NSNotFound;
    [moc performBlockAndWait:^{
        
        NSManagedObject *object = [self originPlaceObjectOfMOC:moc];
        
        if(object != nil){
            NSNumber *index = [object valueForKey:@"index"];
            retIndex =  [index integerValue];
        }
        
    }];
    
    return retIndex;
}


- (NSDictionary * _Nullable)nearestPlaceFromPoint:(CLLocation *)position{
    
    NSManagedObjectContext *moc = [self->userDataManager managedObjectContextForConcurrent];
    
    __block NSMutableDictionary *retDict = nil;
    
    [moc performBlockAndWait:^{
        
        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Place"];
        [request setPredicate:[NSPredicate predicateWithFormat:@"index >= 0", index]];
        
        NSArray *results = nil;
        NSError *error = nil;
        results = [moc executeFetchRequest:request error:&error];
        if (results == nil) {
            NSLog(@"Error fetching objects: %@\n%@", [error localizedDescription], [error userInfo]);
            abort();
        }
        
        if([results count] > 0){
            retDict = [[NSMutableDictionary alloc] init];
            
            CLLocationDistance min_dist = CLLocationDistanceMax;
            NSNumber *index = nil;
            for(int i=0; i<[results count]; i++){
                NSManagedObject *object = [results objectAtIndex:i];
                
                NSNumber *lat = [object valueForKey:@"latitude"];
                NSNumber *lon = [object valueForKey:@"longitude"];
                
                CLLocationCoordinate2D p = CLLocationCoordinate2DMake([lat doubleValue], [lon doubleValue]);
                CLLocationCoordinate2D q = position.coordinate;
                
                CLLocationDistance dist = [self distanceFromPoint:p toPoint:q];
                
                if(min_dist > dist){
                    min_dist = dist;
                    index = [object valueForKey:@"index"];
                }
            }
            
            [retDict setObject:[NSNumber numberWithDouble:min_dist] forKey:@"distance"];
            [retDict setObject:index forKey:@"placeIndex"];
        }
    }];
    
    return retDict;
}


- (void)setTemporaryPlaceWithPosition:(CLLocation *)position{
    // 指定された位置(position)を TemporaryPlace としてDBに保存する。 インデックスは-1でひとつだけ。すでに存在した場合は更新。
    
    NSManagedObjectContext *moc = [self->userDataManager managedObjectContextForConcurrent];
    
    [moc performBlockAndWait:^{
        
        // 新たにOriginを設定する。
        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Place"];
        [request setPredicate:[NSPredicate predicateWithFormat:@"index == -1"]];
        
        NSArray *results = nil;
        NSError *error = nil;
        results = [moc executeFetchRequest:request error:&error];
        if (results == nil) {
            NSLog(@"Error fetching objects: %@\n%@", [error localizedDescription], [error userInfo]);
            abort();
        }
        
        // index=-1 は特殊なPlace. 一時的な地点を表す。
        NSManagedObject *temporaryOriginObject = nil;
        if([results count] == 0){
            temporaryOriginObject = [self newPlaceEntityObjectOfMOC:moc];
            [temporaryOriginObject setValue:@-1 forKey:@"index"];
        }else{
            temporaryOriginObject = [results firstObject];
        }
        
        [temporaryOriginObject setValue:@"TemporaryPlace" forKey:@"title"];
        [temporaryOriginObject setValue:@"" forKey:@"address"];
        [temporaryOriginObject setValue:[NSNumber numberWithDouble:position.coordinate.latitude] forKey:@"latitude"];
        [temporaryOriginObject setValue:[NSNumber numberWithDouble:position.coordinate.longitude] forKey:@"longitude"];
        [self setOriginToPlaceObject:temporaryOriginObject ofMOC:moc];
        
        // Save the context.
        if (![moc save:&error]) {
            // Replace this implementation with code to handle the error appropriately.
            // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
            abort();
        }
        [self->userDataManager persist]; // 永続保管 非同期で。
        
    }];
    
    return;
}


- (void)setCurrentLocationWithTitle:(NSString *)title WithAddressString:(NSString *)addressString WithPosition:(CLLocation *)position{
    // 指定された位置(position)を 現在地 としてDBに保存する。 インデックスは -10でひとつだけ。すでに存在した場合は更新。 表示用。
    
    NSManagedObjectContext *moc = [self->userDataManager managedObjectContextForConcurrent];
    
    [moc performBlockAndWait:^{
        
        // 新たにOriginを設定する。
        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Place"];
        [request setPredicate:[NSPredicate predicateWithFormat:@"index == -10"]];
        
        NSArray *results = nil;
        NSError *error = nil;
        results = [moc executeFetchRequest:request error:&error];
        if (results == nil) {
            NSLog(@"Error fetching objects: %@\n%@", [error localizedDescription], [error userInfo]);
            abort();
        }
        
        // index=-10 は特殊なPlace. 現在地を表す。
        NSManagedObject *currentPlaceObject = nil;
        if([results count] == 0){
            currentPlaceObject = [self newPlaceEntityObjectOfMOC:moc];
            [currentPlaceObject setValue:@-10 forKey:@"index"];
        }else{
            currentPlaceObject = [results firstObject];
        }
        
        if(position != nil){
            [currentPlaceObject setValue:[NSNumber numberWithDouble:position.coordinate.latitude] forKey:@"latitude"];
            [currentPlaceObject setValue:[NSNumber numberWithDouble:position.coordinate.longitude] forKey:@"longitude"];
        }else{
            [currentPlaceObject setValue:[NSNumber numberWithDouble:0.0f] forKey:@"latitude"];
            [currentPlaceObject setValue:[NSNumber numberWithDouble:0.0f] forKey:@"longitude"];
        }
        
        if(title != nil){
            [currentPlaceObject setValue:title forKey:@"title"];
        }
        
        if(addressString != nil){
            [currentPlaceObject setValue:addressString forKey:@"address"];
        }else{
            [currentPlaceObject setValue:@"" forKey:@"address"];
        }
        
        
        // Save the context.
        if (![moc save:&error]) {
            // Replace this implementation with code to handle the error appropriately.
            // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
            abort();
        }
        [self->userDataManager persist]; // 永続保管 非同期で。
        
    }];
    
    return;
}

- (void)requestWithOwner:(id)owner visiblePlaceBlock:(void (^)(NSArray *))block{
    
    // 別スレッドで実行開始。
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        NSManagedObjectContext *moc = [self->userDataManager managedObjectContextForConcurrent];
        
        __block NSMutableArray *retArray = [[NSMutableArray alloc] init];
        [moc performBlockAndWait:^{
            
            NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Place"];
            [request setPredicate:[NSPredicate predicateWithFormat:@"visible == YES"]];
            
            NSArray *results = nil;
            NSError *error = nil;
            results = [moc executeFetchRequest:request error:&error];
            if (results == nil) {
                NSLog(@"Error fetching objects: %@\n%@", [error localizedDescription], [error userInfo]);
                abort();
            }
            
            
            NSArray *keys = @[@"title", @"address", @"latitude", @"longitude"];
            for(int i=0; i<[results count]; i++){
                NSManagedObject *obj = results[i];
                
                // 一時的な出発地は追加しない。
                NSNumber *indexNum = [obj valueForKey:@"index"];
                if([indexNum integerValue] == -1){
                    continue;
                }
                
                NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
                for(NSString *key in keys){
                    id val = [obj valueForKey:key];
                    if(val != nil){
                        [dict setObject:val forKey:key];
                    }
                }
                
                [retArray addObject:dict];
                
            }
        }];
        
        // メインスレッドで実行。
        dispatch_async(
                       dispatch_get_main_queue(),
                       ^{
                           block([retArray copy]);
                       });
    });
    
}

@end

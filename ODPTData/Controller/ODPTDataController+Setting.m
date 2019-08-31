//
//  ODPTDataController+Setting.m
//
//  Copyright (c) 2019 Takehito Ikema
//
//  This software is released under the MIT License.
//  https://opensource.org/licenses/mit-license.php
//

#import "ODPTDataController+Setting.h"
#import "ODPTDataController+Common.h"
#import "CoreDataManager.h"

@implementation ODPTDataController (Setting)

- (BOOL)isValidOfDisplayRailway{
    NSDictionary *dict = [self userSetting];
    return [[dict objectForKey:@"isShowRailway"] boolValue];
}

- (BOOL)isValidOfDisplayBus{
    NSDictionary *dict = [self userSetting];
    return [[dict objectForKey:@"isShowBus"] boolValue];
}


- (void)setValidOfDisplayRailway:(BOOL)sw{
    NSDictionary *dict = @{@"isShowRailway":[NSNumber numberWithBool:sw]};
    [self setUserSetting:dict];
}

- (void)setValidOfDisplayBus:(BOOL)sw{
    NSDictionary *dict = @{@"isShowBus":[NSNumber numberWithBool:sw]};
    [self setUserSetting:dict];
}

- (NSInteger) cacheRefleshStartSeconds{
    NSDictionary *dict = [self userSetting];
    return [[dict objectForKey:@"cacheRefleshStart"] integerValue];
}

- (void)setCacheRefleshStartSeconds:(NSInteger)refleshStartSecond{
    
    NSMutableDictionary *dict = [[self userSetting] mutableCopy];
    
    [dict setObject:[NSNumber numberWithInteger:refleshStartSecond] forKey:@"cacheRefleshStart"];
    
    [self setUserSetting:dict];
}

- (NSNumber * _Nullable)isConnectingLineDeployForStation:(NSString * _Nullable)ridingStationIdentifier atStation:(NSString *)alightingStationIdentifier{
    // alighting: 下車駅 -> 乗り換え -> riding: 乗車駅
    
    NSAssert(alightingStationIdentifier != nil, @"isConnectingLineDeployForStation  alightingStation must not be nil.");
    
    if(ridingStationIdentifier == nil){
        ridingStationIdentifier = @"__EMPTY__";;
    }
    
    NSManagedObjectContext *moc = [self->userDataManager managedObjectContextForConcurrent];
    __block NSNumber *isDeployNumber = nil;
    [moc performBlockAndWait:^{
        
        NSString *entityName = @"ConnectingLineDeploy";
        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:entityName];
        [request setPredicate:[NSPredicate predicateWithFormat:@"ridingStationIdentifier == %@ and alightingStationIdentifier == %@",
                               ridingStationIdentifier, alightingStationIdentifier]];
        
        NSError *error = nil;
        NSArray *results = [moc executeFetchRequest:request error:&error];
        
        if (results == nil) {
            NSLog(@"Error fetching objects: %@\n%@", [error localizedDescription], [error userInfo]);
            abort();
        }
        
        if([results count] >= 1){
            // レコードが存在する。
            NSManagedObject *isDeployObject = [results firstObject];
            isDeployNumber = [isDeployObject valueForKey:@"isDeploy"];
        }
    }];
    
    // NSLog(@"isConnectingLineDeploy %@  ride:%@  alight:%@", isDeployNumber , ridingStationIdentifier, alightingStationIdentifier);
    return isDeployNumber;
}

- (void)setIsConnectingLineDeploy:(BOOL)isDeploy forStation:(NSString * _Nullable)ridingStationIdentifier atStation:(NSString *)alightingStationIdentifier{
    
    // alighting: 下車駅 -> 乗り換え -> riding: 乗車駅
    
    NSAssert(alightingStationIdentifier != nil, @"setIsConnectingLineDeployForStation  alightingStation must not be nil.");
    
    if(ridingStationIdentifier == nil){
        ridingStationIdentifier = @"__EMPTY__";
    }
    
    NSManagedObjectContext *moc = [userDataManager managedObjectContextForConcurrent];
    
    [moc performBlockAndWait:^{
        
        NSString *entityName = @"ConnectingLineDeploy";
        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:entityName];
        [request setPredicate:[NSPredicate predicateWithFormat:@"ridingStationIdentifier == %@ and alightingStationIdentifier == %@",
                               ridingStationIdentifier, alightingStationIdentifier]];
        
        NSError *error = nil;
        NSArray *results = [moc executeFetchRequest:request error:&error];
        
        if (results == nil) {
            NSLog(@"Error fetching objects: %@\n%@", [error localizedDescription], [error userInfo]);
            abort();
        }
        
        NSManagedObject *isDeployObject = nil;
        if([results count] == 0){
            isDeployObject = [NSEntityDescription insertNewObjectForEntityForName:entityName inManagedObjectContext:moc];
            [isDeployObject setValue:ridingStationIdentifier forKey:@"ridingStationIdentifier"];
            [isDeployObject setValue:alightingStationIdentifier forKey:@"alightingStationIdentifier"];
        }else{
            // レコードが存在する。 書き換える。
            isDeployObject = [results objectAtIndex:0];
        }
        
        [isDeployObject setValue:[NSNumber numberWithBool:isDeploy] forKey:@"isDeploy"];
        
        // Save the context.
        if (![moc save:&error]) {
            NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
            abort();
        }
        
        [self->userDataManager persist]; // 永続保管 非同期で。
    }];
    
    // NSLog(@"setIsConnectingLineDeploy %d  ride:%@  alight:%@", isDeploy, ridingStationIdentifier, alightingStationIdentifier);
    
    return;
    
}


- (NSNumber * _Nullable)currentShowMode{
    
    __block NSNumber *showMode = nil;
    NSManagedObjectContext *moc = [userDataManager managedObjectContextForConcurrent];
    [moc performBlockAndWait:^{
        
        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Setting"];
        
        NSError *error = nil;
        NSArray *results = [moc executeFetchRequest:request error:&error];
        
        if (results == nil) {
            NSLog(@"Error fetching objects: %@\n%@", [error localizedDescription], [error userInfo]);
            abort();
        }
        
        if([results count] == 1){
            NSManagedObject *settingObject = [results firstObject];
            showMode = [settingObject valueForKey:@"currentShowMode"];
        }else if([results count] > 1){
            NSAssert(NO, @"currentShowMode detect multiple setting object.");
        }
        
        if([showMode isKindOfClass:[NSNumber class]] == NO){
            showMode = nil;
        }
        
    }];
    
    return showMode;
}

- (void)setCurrentShowMode:(NSInteger)showMode{
    
    NSManagedObjectContext *moc = [userDataManager managedObjectContextForConcurrent];
    [moc performBlockAndWait:^{
        
        NSString *entityName = @"Setting";
        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:entityName];
        
        NSError *error = nil;
        NSArray *results = [moc executeFetchRequest:request error:&error];
        
        if (results == nil) {
            NSLog(@"Error fetching objects: %@\n%@", [error localizedDescription], [error userInfo]);
            abort();
        }
        
        NSAssert([results count] > 0, @"setCurrentShowMode multiple or none result detect.");
        
        
        NSManagedObject *settingObject = nil;
        if([results count] == 0){
            settingObject = [NSEntityDescription insertNewObjectForEntityForName:entityName inManagedObjectContext:moc];
        }else{
            settingObject = [results firstObject];
        }
        
        [settingObject setValue:[NSNumber numberWithInteger:showMode] forKey:@"currentShowMode"];
        
        // Save the context.
        if (![moc save:&error]) {
            NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
            abort();
        }
        
        [self->userDataManager persist]; // 永続保管 非同期で。
        
    }];
    
}

- (void)writeTransferArray:(NSArray <NSDictionary *> *)transferArray forTitle:(NSString *)title asCurrent:(BOOL)currentSwitch{
    
    NSManagedObjectContext *moc = [userDataManager managedObjectContextForConcurrent];
    [moc performBlockAndWait:^{
        
        if(currentSwitch == YES){
            // current の場合は今のcurrentを探して、削除
            
            NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"TransferSet"];
            [request setPredicate:[NSPredicate predicateWithFormat:@"current == %@", [NSNumber numberWithBool:YES]]];
            
            NSError *error = nil;
            NSArray *results = [moc executeFetchRequest:request error:&error];
            
            if (results == nil) {
                NSLog(@"Error fetching objects: %@\n%@", [error localizedDescription], [error userInfo]);
                abort();
            }
            
            for(int i=0; i<[results count]; i++){
                [moc deleteObject:results[i]];
            }
        }
        
        
        NSMutableOrderedSet *transferSet = [[NSMutableOrderedSet alloc] init];
        for(int i=0; i<[transferArray count]; i++){
            NSDictionary *transferDict = transferArray[i];
            
            NSManagedObject *transferObject = nil;
            
            NSString *entityName = @"Transfer";
            transferObject = [NSEntityDescription insertNewObjectForEntityForName:entityName inManagedObjectContext:moc];
            
            [self setTransferObject:transferObject toTransferDictionary:transferDict inManagedObjectContext:moc];
            
            
            [transferSet addObject:transferObject];
        }
        
        NSManagedObject *transferSetObject = [NSEntityDescription insertNewObjectForEntityForName:@"TransferSet" inManagedObjectContext:moc];
        [transferSetObject setValue:transferSet forKey:@"transfers"];
        [transferSetObject setValue:[NSNumber numberWithBool:currentSwitch] forKey:@"current"];
        
        
        NSError *error = nil;
        // Save the context.
        if (![moc save:&error]) {
            NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
            abort();
        }
        
        [self->userDataManager persist]; // 永続保管 非同期で。
        
    }];
    
}

- (NSArray <NSDictionary *> *)readCurrentTransferArray{
    
    NSMutableArray *ret = [[NSMutableArray alloc] init];
    
    NSManagedObjectContext *moc = [userDataManager managedObjectContextForConcurrent];
    [moc performBlockAndWait:^{
        
        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"TransferSet"];
        [request setPredicate:[NSPredicate predicateWithFormat:@"current == %@", [NSNumber numberWithBool:YES]]];
        
        NSError *error = nil;
        NSArray *results = [moc executeFetchRequest:request error:&error];
        
        if (results == nil) {
            NSLog(@"Error fetching objects: %@\n%@", [error localizedDescription], [error userInfo]);
            abort();
        }
        
        if([results count] > 0){
            NSManagedObject *transferSetObject = [results firstObject];
            
            NSOrderedSet *transferSet = [transferSetObject valueForKey:@"transfers"];
            
            for(int i=0; i<[transferSet count]; i++){
                NSManagedObject *transferObject = transferSet[i];
                
                NSDictionary *dict = [self transferDictionaryForTransferObject:transferObject];
                
                [ret addObject:dict];
            }
        }
    }];
    
    return [ret copy];
}

@end

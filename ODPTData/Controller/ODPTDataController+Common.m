//
//  ODPTDataController+Common.m
//
//  Copyright (c) 2019 Takehito Ikema
//
//  This software is released under the MIT License.
//  https://opensource.org/licenses/mit-license.php
//
#import <UIKit/UIKit.h>
#import "ODPTDataController+Common.h"
#import "ODPTDataController.h"
#import "ODPTDataConstant.h"
#import "CoreDataManager.h"

@implementation ODPTDataController (Common)

#pragma mark - Place Entity Object Utility
- (NSManagedObject *)newPlaceEntityObjectOfMOC:(NSManagedObjectContext *)moc{
    // 新たにPlaceエンティティのオブジェクトを作成し、indexプロパティ(通し番号）をセットして、返す。
    // performBlock 内から呼び出すこと
    
    /// fetch requestの生成
    NSFetchRequest *fetchRequest = [NSFetchRequest new];
    
    /// entity descriptionの生成
    NSEntityDescription *entityDescription = [NSEntityDescription entityForName:@"Place" inManagedObjectContext:moc];
    fetchRequest.entity = entityDescription;
    
    /// NSExpressionの生成
    NSExpression *keyPathExpression = [NSExpression expressionForKeyPath:@"index"];
    NSExpression *expression = [NSExpression expressionForFunction:@"max:" arguments:@[keyPathExpression]];
    NSExpressionDescription *expressionDescription = [NSExpressionDescription new];
    expressionDescription.name = @"maxIndex";
    expressionDescription.expression = expression;
    expressionDescription.expressionResultType = NSInteger16AttributeType;
    
    /// 結果のタイプを指定(NSFetchRequestResultType)
    fetchRequest.resultType = NSDictionaryResultType;
    fetchRequest.propertiesToFetch = @[expressionDescription];
    
    NSError *error = nil;
    NSArray *results = [moc executeFetchRequest:fetchRequest error:&error];
    
    if (results == nil) {
        NSLog(@"Error fetching objects: %@\n%@", [error localizedDescription], [error userInfo]);
        abort();
    }
    
    NSNumber *maxIndex  = @0;
    if([results count] > 0){
        maxIndex = [results.firstObject valueForKey:@"maxIndex"];   // エンティティ Place プロパティ index の最大値
        if([maxIndex integerValue] < 0){
            maxIndex = @0;
        }
    }
    
    
    NSString *entityName = @"Place";
    NSManagedObject *newObject = [NSEntityDescription insertNewObjectForEntityForName:entityName inManagedObjectContext:moc];
    [newObject setValue:[NSNumber numberWithInteger:([maxIndex doubleValue] +1)] forKey:@"index"];
    
    return newObject;
}


- (void)setOriginToPlaceObject:(NSManagedObject *)object ofMOC:(NSManagedObjectContext *)moc{
    NSLog(@"setOriginToPlaceObject");
    // originFlagをPlace エンティティのオブジェクトに立てる。
    // originフラグは、すべてのPlaceエンティティオブジェクトを通じて一つのみ YES となる。
    // performBlock の中から呼び出すこと
    
    // すでにoriginがセットされているものを無効にする
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Place"];
    [request setPredicate:[NSPredicate predicateWithFormat:@"isOrigin == %@", [NSNumber numberWithBool:YES]]];
    
    NSArray *results = nil;
    NSError *error = nil;
    results = [moc executeFetchRequest:request error:&error];
    if (results == nil) {
        NSLog(@"Error fetching objects: %@\n%@", [error localizedDescription], [error userInfo]);
        abort();
    }
    
    if([results count] > 1){
        NSLog(@"setOriginToPlaceForIndex: detect multiple origin for same index.");
    }
    
    for(int i=0; i<[results count]; i++){
        NSManagedObject *s = [results objectAtIndex:i];
        [s setValue:[NSNumber numberWithBool:NO] forKey:@"isOrigin"];
    }
    
    [object setValue:[NSNumber numberWithBool:YES] forKey:@"isOrigin"];
    
}

- (NSManagedObject *)originPlaceObjectOfMOC:(NSManagedObjectContext *)moc{
    // originフラグが立っているオブジェクトを返す。
    // performBlock の中から呼び出すこと
    
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Place"];
    [request setPredicate:[NSPredicate predicateWithFormat:@"isOrigin == %@", [NSNumber numberWithBool:YES]]];
    
    NSArray *results = nil;
    NSError *error = nil;
    results = [moc executeFetchRequest:request error:&error];
    if (results == nil) {
        NSLog(@"Error fetching objects: %@\n%@", [error localizedDescription], [error userInfo]);
        abort();
    }
    
    if([results count] == 0){
        return nil;
        
    }else{
        if([results count] > 1){
            NSLog(@"originPlaceObject: detect multiple origin for same index.");
        }
    }
    
    return [results firstObject];
    
}

- (NSDictionary *)placeDictionaryForPlaceObject:(NSManagedObject *)obj{
    NSArray *keys = [[[obj entity] attributesByName] allKeys];
    NSDictionary *dict = [obj dictionaryWithValuesForKeys:keys];
    
    return dict;
    
}


#pragma mark - Branch Entity Object Utility
- (void)setBranchObject:(NSManagedObject *)object toBranchDictionary:(NSDictionary *)dict{
    
    [object setValuesForKeysWithDictionary:dict];
}


- (NSDictionary *)branchDictionaryForBranchObject:(NSManagedObject *)object{
    
    NSArray *keys = [[[object entity] attributesByName] allKeys];
    NSDictionary *dict = [object dictionaryWithValuesForKeys:keys];
    
    return dict;
}

// 現在の分岐（直通路線が複数の方向に分岐する場合に、どの路線を選択するか）を取得する。
//  分岐(Branch)は、所定の駅(atStation), 路線(ofLine) における、分岐先の路線(selectedLine) で表される。
//  実態は、NSDictionary . key として ofLine, atStation, selectedLine を持つ。
//  branchArray がnilの場合, UserData内部, systemDefaultフラグが立っているレコードの中から、所定のatStation,ofLineを持つ分岐レコードを探す。
//  branchArray がnil出ない場合、branchArrayの中から、所定のatStation,ofLineを持つ分岐レコードを探す。

- (NSDictionary *)branchOfLine:(NSString *)lineIdentifier atStation:(NSString *)branchStationIdentifier withBranchArray:(NSArray * _Nullable)branchArray {
    __block NSMutableArray *mBranchArray = [[NSMutableArray alloc] init];
    
    if(branchArray == nil){
        NSMutableDictionary *rd = [[self readBranchForLine:lineIdentifier atStation:branchStationIdentifier] mutableCopy];
        if(rd != nil){
            [mBranchArray addObject:[rd copy] ];
        }
    }else{
        [mBranchArray addObjectsFromArray:branchArray];
    }
    
    NSString *selectedLine = lineIdentifier;
    for(int i=0; i<[mBranchArray count]; i++){
        NSDictionary *dict = mBranchArray[i];
        if([[dict objectForKey:@"ofLine"] isEqualToString:lineIdentifier] &&
           [[dict objectForKey:@"atStation"] isEqualToString:branchStationIdentifier]){
                
            selectedLine = [dict objectForKey:@"selectedLine"];
            if([selectedLine isKindOfClass:[NSString class]] == NO || selectedLine == nil){
                selectedLine = lineIdentifier;
            }
            break;
        }
    }

    NSDictionary *retDict = [NSDictionary dictionaryWithObjects:@[lineIdentifier, branchStationIdentifier, selectedLine] forKeys:@[@"ofLine", @"atStation", @"selectedLine"]];
    
    return retDict;
}


- (NSDictionary * _Nullable)readBranchForLine:(NSString *)lineIdentifier atStation:(NSString *)branchStationIdentifier{
    
    NSManagedObjectContext *moc = [self->userDataManager managedObjectContextForConcurrent];
    __block NSDictionary *rd = nil;
    [moc performBlockAndWait:^{
        
        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Branch"];
        [request setPredicate:[NSPredicate predicateWithFormat:@"ofLine == %@ and atStation == %@ and systemDefault == %@", lineIdentifier, branchStationIdentifier, [NSNumber numberWithBool:YES]]];
        
        NSError *error = nil;
        NSArray *results = [moc executeFetchRequest:request error:&error];
        
        if (results == nil) {
            NSLog(@"Error fetching objects: %@\n%@", [error localizedDescription], [error userInfo]);
            abort();
        }
        
        if([results count] >= 1){
            // レコードが存在する。
            NSManagedObject *selectionObject = [results firstObject];
            rd = [self branchDictionaryForBranchObject:selectionObject];
        }
        
    }];
    
    return rd;
}


- (void)writeBranchForSelectedLine:(NSString *)selectedLine ofLine:(NSString *)lineIdentifier atStation:(NSString *)branchStationIdentifier{
    
    NSDictionary *dict = [NSDictionary dictionaryWithObjects:@[lineIdentifier, branchStationIdentifier, selectedLine] forKeys:@[@"ofLine", @"atStation", @"selectedLine"]];
    
    [self writeBranch:dict];
    
}

// branchデータをUserDataとして記録する。 すでに存在する場合は 書き換える
- (void)writeBranch:(NSDictionary *)branchDict{
    
    NSString *lineIdentifier = [branchDict objectForKey:@"ofLine"];
    NSString *branchStationIdentifier = [branchDict objectForKey:@"atStation"];
    
    NSManagedObjectContext *moc = [userDataManager managedObjectContextForConcurrent];
    
    [moc performBlockAndWait:^{
        
        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Branch"];
        [request setPredicate:[NSPredicate predicateWithFormat:@"ofLine == %@ and atStation == %@ and systemDefault == %@ ", lineIdentifier, branchStationIdentifier, [NSNumber numberWithBool:YES]]];
        
        NSError *error = nil;
        NSArray *results = [moc executeFetchRequest:request error:&error];
        
        if (results == nil) {
            NSLog(@"Error fetching objects: %@\n%@", [error localizedDescription], [error userInfo]);
            abort();
        }
        
        NSManagedObject *selectionObject = nil;
        if([results count] == 0){
            NSString *entityName = @"Branch";
            selectionObject = [NSEntityDescription insertNewObjectForEntityForName:entityName inManagedObjectContext:moc];
            
        }else{
            // レコードが存在する。 書き換える。
            selectionObject = [results objectAtIndex:0];
        }
        
        [self setBranchObject:selectionObject toBranchDictionary:branchDict];
        
        // Save the context.
        if (![moc save:&error]) {
            NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
            abort();
        }
        
        [self->userDataManager persist]; // 永続保管 非同期で。
    }];
    
}

#pragma mark - Transfer Entity Object Utility

- (void)setTransferObject:(NSManagedObject *)transferObject toTransferDictionary:(NSDictionary *)transferDict inManagedObjectContext:(NSManagedObjectContext *)moc{
    
    NSArray *branchData = [transferDict objectForKey:@"branchData"];
    
    // branchData以外を transferObject にセット。
    NSMutableDictionary *d = [transferDict mutableCopy];
    [d removeObjectForKey:@"branchData"];
    [transferObject setValuesForKeysWithDictionary:d];
    
    NSMutableSet *branchSet = [[NSMutableSet alloc] init];
    for(int i=0; i<[branchData count]; i++){
        NSDictionary *branchDict = branchData[i];
        NSManagedObject *branchObject = [NSEntityDescription insertNewObjectForEntityForName:@"Branch" inManagedObjectContext:moc];
        [self setBranchObject:branchObject toBranchDictionary:branchDict];
        [branchObject setValue:[NSNumber numberWithBool:NO] forKey:@"systemDefault"];
        [branchSet addObject:branchObject];
    }
    
    [transferObject setValue:[branchSet copy] forKey:@"branchData"];
    
}

- (NSDictionary *)transferDictionaryForTransferObject:(NSManagedObject *)transferObject{
    
    NSArray *keys = [[[transferObject entity] attributesByName] allKeys];
    // NSLog(@"keys: %@", keys);
    
    NSMutableDictionary *dict = [[transferObject dictionaryWithValuesForKeys:keys] mutableCopy];
    
    NSSet *branchData = [transferObject valueForKey:@"branchData"];
    NSArray *array = [branchData allObjects];
    
    if([array count] > 0){
        NSMutableArray *branchArray = [[NSMutableArray alloc] init];
        for(int j=0; j<[array count]; j++){
            NSManagedObject *branchObject = array[j];
            NSDictionary *bdict = [self branchDictionaryForBranchObject:branchObject];
            [branchArray addObject:bdict];
        }
        [dict setObject:branchArray forKey:@"branchData"];
    }    
    
    return dict;
}

#pragma mark - Setting Entity Object Utility

- (NSDictionary *)userSetting {
    
    NSManagedObjectContext *moc = [self->userDataManager managedObjectContextForConcurrent];
    
    __block NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
    [moc performBlockAndWait:^{
        
        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Setting"];
        
        NSError *error = nil;
        NSArray *results = [moc executeFetchRequest:request error:&error];
        
        if (results == nil) {
            NSLog(@"Error fetching objects: %@\n%@", [error localizedDescription], [error userInfo]);
            abort();
        }
        
        NSManagedObject *settingObject = nil;
        if([results count] >= 1){
            // レコードが存在する。
            settingObject = [results objectAtIndex:0];
            
        }else{
            // 存在しない　レコードを作る
            
            NSString *entityName = @"Setting";
            settingObject = [NSEntityDescription insertNewObjectForEntityForName:entityName inManagedObjectContext:moc];
            
        }
        NSArray *keys = [[[settingObject entity] attributesByName] allKeys];
        dict = [[settingObject dictionaryWithValuesForKeys:keys] mutableCopy];
    }];
    
    return [dict copy];
}

- (void)setUserSetting:(NSDictionary *)dict{
    
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
        
        NSManagedObject *settingObject = nil;
        if([results count] == 0){
            settingObject = [NSEntityDescription insertNewObjectForEntityForName:entityName inManagedObjectContext:moc];
            
        }else{
            // レコードが存在する。 書き換える。
            settingObject = [results objectAtIndex:0];
            
            [settingObject setValuesForKeysWithDictionary:dict];
        }
        
        // Save the context.
        if (![moc save:&error]) {
            NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
            abort();
        }
        
        [self->userDataManager persist]; // 永続保管 非同期で。
        
    }];
    
}

#pragma mark - Other Utility

- (UIColor *)colorFromString:(NSString *)colorStr{
    if([colorStr hasPrefix:@"#"]){
        NSString *str = [colorStr substringFromIndex:1];
        NSScanner *colorScanner = [NSScanner scannerWithString:str];
        unsigned int color;
        if ([colorScanner scanHexInt:&color]){
            
            CGFloat r = ((color & 0xFF0000) >> 16)/255.0f;
            CGFloat g = ((color & 0x00FF00) >> 8) /255.0f;
            CGFloat b =  (color & 0x0000FF) /255.0f;
            
            return [UIColor colorWithRed:r green:g blue:b alpha:1.0f];
        }
    }
    
    return [UIColor colorWithRed:0.4f green:0.4f blue:0.4f alpha:1.0f];
}

- (NSString *)reformStationTitle:(NSString *)orig{
    
    if(orig == nil || [orig isEqualToString:@""] ){
        return @"";
    }
    
    // APIから取得する場合
    NSRange start_range = [orig rangeOfString:@"<"];
    if(start_range.location == NSNotFound){
        return orig;
    }else{
        
        NSRange end_range = [orig rangeOfString:@">"];
        
        NSMutableString *ret = [NSMutableString stringWithString:orig];
        [ret deleteCharactersInRange:NSMakeRange( start_range.location, end_range.location - start_range.location+1 ) ];
        
        return ret;
    }
    
}

- (NSInteger)typeForIdentifier:(NSString *)identifier{
    
    NSInteger type = ODPTDataIdentifierTypeUndefined;
    //路線か駅かを判定。
    NSArray *f = [identifier componentsSeparatedByString:@":"];
    if([ [f objectAtIndex:0] containsString:@"Railway"] == YES ||
       [[f objectAtIndex:0] containsString:@"BusroutePattern"] == YES ){
        // 鉄道orバスの路線
        type = ODPTDataIdentifierTypeLine;
        
    }else if( [[f objectAtIndex:0] containsString:@"Station"] == YES ||
             [[f objectAtIndex:0] containsString:@"Busstop"] == YES  ){
        // 鉄道orバスの駅
        type = ODPTDataIdentifierTypeStation;
        
    }else{
        NSLog(@"ODPTDataModel invalid identifier specified!! %@", identifier);
    }
    
    return type;
}

@end

//
//  ODPTDataController+Dynamic.m
//
//  Copyright (c) 2019 Takehito Ikema
//
//  This software is released under the MIT License.
//  https://opensource.org/licenses/mit-license.php
//

#import "ODPTDataController+Dynamic.h"
#import "ODPTDataLoaderLineInformation.h"
#import "ODPTDataLoaderTrainLocation.h"
#import "ODPTDataAdditional.h"
#import "EfficientLoaderQueue.h"

@implementation ODPTDataController (Dynamic)

- (void)requestWithOwner:(id _Nullable)owner LineInformationForLineIdentifier:(NSString *)LineIdentifier Block:(void (^)(NSDictionary * _Nullable, NSDate * _Nullable))block{
    
    __block ODPTDataLoaderLineInformation *job;
    
    job = [[ODPTDataLoaderLineInformation alloc] initWithLine:LineIdentifier Block:^(NSManagedObjectID *moID) {
        
        if(moID == nil){
            // APIアクセスに失敗。
            NSLog(@"ODPTDataLoaderLineInformation return nil. ident:%@", LineIdentifier);
            // メインスレッドで実行。
            dispatch_async(
                           dispatch_get_main_queue(),
                           ^{
                               block(nil, nil);
                           }
                           );
            return;
        }
        
        NSManagedObjectContext *moc = [self->APIDataManager managedObjectContextForConcurrent];
        
        __block NSMutableDictionary *retDict = [[NSMutableDictionary alloc] init];
        __block NSDate *validDate = nil;
        
        __block NSString *statusKey = nil;
        
        NSString *locale = [[NSLocale preferredLanguages] objectAtIndex:0];
        
        __block NSString *localePrefix = @"en";
        if([locale hasPrefix:@"ja"] == YES){
            localePrefix = @"ja";
        }
        
        __block NSString *statusString = nil;
        __block NSString *detailString = nil;
        __block NSString *causeString = nil;
        
        [moc performBlockAndWait:^{
            NSManagedObject *mo = [moc objectWithID:moID];
            
            statusKey = [mo valueForKey:@"status_ja"];
            
            NSString *key = [@"status_" stringByAppendingString:localePrefix];
            statusString = [mo valueForKey:key];
            
            key = [@"text_" stringByAppendingString:localePrefix];
            detailString = [mo valueForKey:key];
            
            key = [@"cause_" stringByAppendingString:localePrefix];
            causeString = [mo valueForKey:key];
            
            validDate = [mo valueForKey:@"validDate"];
        }];
        
        NSInteger level = [[ODPTDataAdditional sharedData] lineStatusLevel:statusKey];
        [retDict setObject:[NSNumber numberWithInteger:level] forKey:@"level"];
        
        if(detailString == nil){
            detailString = @"";
        }
        
        [retDict setObject:detailString forKey:@"text"];
        
        if(statusString == nil){
            statusString = @"";
        }
        
        NSMutableString *title = [[NSMutableString alloc] init];
        [title appendString:statusString];
        if(causeString != nil && [causeString length] > 0){
            [title appendFormat:@" (%@)", causeString];
        }
        
        [retDict setObject:[title copy] forKey:@"status"];
        
        // メインスレッドで実行。
        dispatch_async(
                       dispatch_get_main_queue(),
                       ^{
                           block(retDict, validDate);
                       }
                       );
        
    }];
    
    job.dataProvider = dataProvider;
    job.dataManager = APIDataManager;
    [job setOwner:owner];
    
    [self->queue addLoader:job];

}



- (void)requestWithOwner:(id _Nullable)owner NowRunningTrainsForLine:(NSString *)lineIdentifier Block:(void (^)(NSArray * _Nullable, NSDate * _Nullable))block{
    
    __block ODPTDataLoaderTrainLocation *job;
    
    job = [[ODPTDataLoaderTrainLocation alloc] initWithLine:lineIdentifier Block:^(NSManagedObjectID *moID) {
        
        if(moID == nil){
            // APIアクセスに失敗。
            NSLog(@"ODPTDataLoaderTrainLocation return nil. ident:%@", lineIdentifier);
            // メインスレッドで実行。
            dispatch_async(
                           dispatch_get_main_queue(),
                           ^{
                               block(nil, nil);
                           }
                           );
            return;
        }
        
        
        // stationIdentifier が lineIdentifier の Line上の駅でない場合は変換。
        NSManagedObjectContext *moc = [self->APIDataManager managedObjectContextForConcurrent];
        
        __block NSMutableArray *retArray = [[NSMutableArray alloc] init];
        __block NSDate *validDate = nil;
        
        [moc performBlockAndWait:^{
            NSManagedObject *mo = [moc objectWithID:moID];
            
            if([mo valueForKey:@"locations"] != nil){
                
                NSSet *set = [mo valueForKey:@"locations"];
                NSArray *locations = [set allObjects];
                
                for(int i=0; i<[locations count]; i++){
                    NSManagedObject *obj = [locations objectAtIndex:i];
                    NSDictionary *dict = [job dictionaryForTrainLocation:obj];
                    
                    [retArray addObject:dict];
                }
                validDate = [mo valueForKey:@"validDate"];
            }
            
            
        }];
        
        // メインスレッドで実行。
        dispatch_async(
                       dispatch_get_main_queue(),
                       ^{
                           block(retArray, validDate);
                       }
                       );
        
    }];
    
    job.dataProvider = dataProvider;
    job.dataManager = APIDataManager;
    [job setOwner:owner];
    
    [self->queue addLoader:job];
}


@end

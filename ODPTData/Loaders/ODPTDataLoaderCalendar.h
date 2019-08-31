//
//  ODPTDataLoaderCalendar.h
//
//  Copyright (c) 2018 Takehito Ikema
//
//  This software is released under the MIT License.
//  https://opensource.org/licenses/mit-license.php
//
#import "ODPTDataLoader.h"

@interface ODPTDataLoaderCalendar : ODPTDataLoader

@property(nonatomic, strong) NSString *calendarIdentifier;

- (id) initWithCalendar:(NSString *)calendarIdentifier Block:(void (^)(NSManagedObjectID *))block;
@end


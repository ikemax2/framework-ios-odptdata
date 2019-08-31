//
//  ODPTDataController+Setting.h
//
//  Copyright (c) 2019 Takehito Ikema
//
//  This software is released under the MIT License.
//  https://opensource.org/licenses/mit-license.php
//

#import "ODPTDataController.h"

NS_ASSUME_NONNULL_BEGIN

@interface ODPTDataController (Setting)
- (BOOL)isValidOfDisplayRailway;
- (BOOL)isValidOfDisplayBus;

- (void)setValidOfDisplayRailway:(BOOL)sw;
- (void)setValidOfDisplayBus:(BOOL)sw;

- (NSInteger) cacheRefleshStartSeconds;
- (void)setCacheRefleshStartSeconds:(NSInteger)refleshStartSecond;

- (NSNumber * _Nullable)isConnectingLineDeployForStation:(NSString * _Nullable)ridingStationIdentifier atStation:(NSString *)alightingStationIdentifier;

- (void)setIsConnectingLineDeploy:(BOOL)isDeploy forStation:(NSString * _Nullable)ridingStationIdentifier atStation:(NSString *)alightingStationIdentifier;

- (NSNumber * _Nullable)currentShowMode;
- (void)setCurrentShowMode:(NSInteger)showMode;

- (void)writeTransferArray:(NSArray <NSDictionary *> *)transferArray forTitle:(NSString *)title asCurrent:(BOOL)currentSwitch;
- (NSArray <NSDictionary *> *)readCurrentTransferArray;

@end

NS_ASSUME_NONNULL_END

//
//  ODPTDataController+Place.h
//
//  Copyright (c) 2019 Takehito Ikema
//
//  This software is released under the MIT License.
//  https://opensource.org/licenses/mit-license.php
//
#import "ODPTDataController.h"
#import <CoreLocation/CoreLocation.h>
#import <CoreData/CoreData.h>

NS_ASSUME_NONNULL_BEGIN

@interface ODPTDataController (Place)

- (void)setOriginPlaceToPosition:(CLLocation *)position;
- (CLLocation * _Nullable)originPlacePosition;
- (void)makePlaceFetchedResultsController:(NSFetchedResultsController *_Nullable *_Nullable)frc;
- (void)addNewPlaceWithTitle:(NSString *)title withAddressString:(NSString *)addressString withPosition:(CLLocation *)position;

- (void)deletePlaceForIndex:(NSInteger)index;
- (void)setVisible:(BOOL)visible toPlaceForIndex:(NSInteger)index;

- (void)setTitle:(NSString *)title toPlaceForIndex:(NSInteger)index;
- (BOOL)isExistPlaceTitle:(NSString *)title;

- (void)setOriginToPlaceForIndex:(NSInteger)index;
- (NSInteger)placeIndexForOrigin;

- (NSDictionary * _Nullable)nearestPlaceFromPoint:(CLLocation *)position;

- (void)setTemporaryPlaceWithPosition:(CLLocation *)position;

- (void)setCurrentLocationWithTitle:(NSString *)title WithAddressString:(NSString *)addressString WithPosition:(CLLocation *)position;

- (void)requestWithOwner:(id)owner visiblePlaceBlock:(void (^)(NSArray *))block;

- (CLLocationDistance)distanceFromPoint:(CLLocationCoordinate2D)pointA toPoint:(CLLocationCoordinate2D)pointB;

@end

NS_ASSUME_NONNULL_END

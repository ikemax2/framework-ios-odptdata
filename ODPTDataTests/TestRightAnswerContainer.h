//
//  TestRightAnswerContainer.h
//
//  Copyright (c) 2019 Takehito Ikema
//
//  This software is released under the MIT License.
//  https://opensource.org/licenses/mit-license.php
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface TestRightAnswerContainer : NSObject
// + (TestRightAnswerContainer *)sharedContainer;

+ (void)setWritingMode:(BOOL)sw;
+ (BOOL)isWritingMode;

- (id)initWithTestCase:(NSString *)caseName;

- (BOOL)judgeAnswer:(id)answer forQuery:(id)query;

//- (BOOL)isExistAnswerForQuery:(id)query;
//- (void)recordAnswer:(id)answer forQuery:(id)query;
//- (BOOL)compareAnswer:(id)answer forQuery:(id)query;

@end

NS_ASSUME_NONNULL_END

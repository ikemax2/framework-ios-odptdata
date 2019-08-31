//
//  ODPTDataTests.h
//
//  Copyright (c) 2019 Takehito Ikema
//
//  This software is released under the MIT License.
//  https://opensource.org/licenses/mit-license.php
//

#import <Foundation/Foundation.h>
#import "CoreDataManager.h"
#import "ODPTDataProvider.h"
#import "EfficientLoaderQueue.h"


@interface ODPTDataTests : XCTestCase{
    @private
    NSOperationQueue *queue;
    CoreDataManager *dataManager;
    ODPTDataProvider *dataProvider;
    EfficientLoaderQueue *eQueue;
    
    NSString *token;
    NSString *endPointURL;
}

- (void)printJobQueue:(NSOperationQueue *)queue;

- (void)prepareForAPIAccessWithReset:(BOOL)sw;

@end


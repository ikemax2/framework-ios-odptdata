//
//  EfficientLoader.h
//
//  Copyright (c) 2018 Takehito Ikema
//
//  This software is released under the MIT License.
//  https://opensource.org/licenses/mit-license.php
//

#import <Foundation/Foundation.h>

@class EfficientLoader;

@protocol EfficientLoaderQueue
@required
- (id)cancelOwner;
- (void)startRelatedCallBackForLoader:(EfficientLoader *)loader;
- (void)addLoader:(EfficientLoader *) loader;
@end

@interface EfficientLoader : NSOperation

// 以下をオーバーライドする
- (NSString *)query;         // query: Loaderがなすべきタスクを返す。
- (void)main;


- (void)completeOperation;

// parent: このLoaderが依存している別のLoaderを返す。 parentが終了するまでこのLoaderは開始しない
- (EfficientLoader *) parent;
- (void)setParent:(EfficientLoader *)p;  // 親子関係を設定

- (void) cancelAction;  // キャンセル時の挙動. subclass はオーバーライドする


// children: このLoaderが依存されている別のLoaderを表す。 このLoaderが完了したら、children となるLoaderが開始される。
- (NSArray<EfficientLoader *> *) children;
- (void)addChild:(EfficientLoader *)c;

// addRelatedLoader: Queueに同一のqueryを持つLoaderが現れた場合、先に実行されるLoaderの結果をコピーする。
- (BOOL)addRelatedLoader:(EfficientLoader *)loader;
- (NSArray *)relatedLoaders;
- (void)clearRelatedLoaders;

// owner: このLoaderによる結果を待っている別のObject（Loaderではない）を表す。
- (id) owner;
- (void)setOwner:(id)owner;

// serialNumber: Loader間で重複しないシリアルナンバーを返す
- (NSInteger)serialNumber;

// isFinishedLoading: Loaderの読み込みが完了した場合は　YESを返す
- (BOOL)isFinishedLoading;

- (void)setFailure;
- (BOOL)isSuccess;

- (void)setQueue:(__weak id<EfficientLoaderQueue>)queue;
- (id<EfficientLoaderQueue>)queue;

- (void)setWaitingRelatedLoader:(BOOL)flag;
- (BOOL)waitingRelatedLoader;

// For Debug
- (void)printInformation;


@end

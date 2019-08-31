//
//  EfficientLoaderQueue.h
//
//  Copyright (c) 2018 Takehito Ikema
//
//  This software is released under the MIT License.
//  https://opensource.org/licenses/mit-license.php
//

#import <Foundation/Foundation.h>
#import "EfficientLoader.h"

// EfficientLoaderQueue
//   EfficientLoader プロトコルを持つオブジェクトを管理する。
//   Loader内部でBlock構文などを使うことで、Loader間には依存関係が生じる。 あるLoaderの実行中に別のLoaderを始動するなど。
//   Loader内部では適切に、この依存関係(parent/child)を設定する必要がある。  parentとなるLoaderは childとなるLoaderの完了を待たないと完了できない。
//   Queue内に、同じQueryを持つLoaderが追加された場合、前のLoaderの結果をコピーする。別途アクセスはしない。
//   Loader中のキャンセルに対応。キャンセル指示を受けると、関連するLoaderの実行を中止させる。


@interface EfficientLoaderQueue: NSObject <EfficientLoaderQueue>

- (void)clear;
- (void)setSuspended:(BOOL)isSuspend;

- (void)cancelAllLoading;
- (void)cancelLoadingForOwner:(id)owner;

- (void)addLoader:(EfficientLoader *) loader;

- (void)printQueueInformation;

- (NSInteger)countLoading;

- (id)cancelOwner; // loader からアクセス　キャンセル処理時に 対象のownerがセットされる。通常はnil.

- (void)startRelatedCallBackForLoader:(EfficientLoader *)loader;
@end

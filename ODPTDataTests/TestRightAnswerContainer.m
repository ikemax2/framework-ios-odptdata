//
//  TestRightAnswerContainer.m
//
//  Copyright (c) 2019 Takehito Ikema
//
//  This software is released under the MIT License.
//  https://opensource.org/licenses/mit-license.php
//

#import "TestRightAnswerContainer.h"

// テストコードに与える入力とその正解を記憶するコンテナクラス。
// データの実体はJSONファイルで保存する。
//  使い方
//  まず、以下のPost Actionを設定。本クラスの書き込みモードで作られた正解ファイルをリソースのフォルダにコピーする内容。
//   ...
//
//  1. 正解データの作成
//     1a. テストコード内で、このクラスのインスタンスを書き込みモードとし、テストケース名と入力(複数も可)を設定。
//     1b. テストを実行して、正解をJSONファイルに保存。PostActionによって、ファイルはリソースフォルダに移動される。
//  2. Xcodeの操作で、作られたJSONファイルをリソースとして、プロジェクトに追加。
//  3. 2回目以降のテスト準備
//     3a. テストコード内で、このクラスのインスタンスを読み込みモードとし、テストケース名を設定。

//static TestRightAnswerContainer *kSharedContainer = nil;
static NSNumber *TestRightAnswerMode = nil;

@implementation TestRightAnswerContainer{
    
    NSString *caseName;
    
    NSMutableArray *queries;
    NSMutableArray *answers;
    
}
/*
+ (TestRightAnswerContainer *)sharedContainer{
    if(kSharedContainer == nil){
        kSharedContainer = [TestRightAnswerContainer new];
    }
    return kSharedContainer;
}
*/

+ (void)setWritingMode:(BOOL)sw{
    TestRightAnswerMode = [NSNumber numberWithBool:sw];
}

+ (BOOL)isWritingMode{
    BOOL ret = NO;
    if(TestRightAnswerMode == nil){
    }else{
        ret = [TestRightAnswerMode boolValue];
    }
    return ret;
}

- (id)initWithTestCase:(NSString *)caseName{
    
    if(self = [super init]){
        self->caseName = caseName;
        
        self->queries = nil;
        self->answers = nil;
    }
    return self;
}


- (BOOL)judgeAnswer:(id)answer forQuery:(id)query{
    
    if([TestRightAnswerContainer isWritingMode] == YES){
        // 正解を記録する。
        [self recordAnswer:answer forQuery:query];
        return YES;
    }else{
        // 正解を確認し、不正解ならassert.
        if([self isExistAnswerForQuery:query] == YES){
            if([self compareAnswer:answer forQuery:query] == NO){
                // XCTAssertFalse(YES, @"answer is wrong. Query:%@ ", query);
                return NO;
            }
        }else{
            // XCTAssertFalse(YES, @"Answer is not found for Query:%@", query);
            return NO;
        }
    }
    
    return YES;    
}

- (BOOL)isExistAnswerForQuery:(id)query{
    
    NSString *path = [self jsonFileReadingPath];
    
    if (! [[NSFileManager defaultManager] fileExistsAtPath:path]){
        return NO;
    }
    
    if(self->queries == nil){
        [self readJSON];
    }
    
    NSUInteger index = [self->queries indexOfObject:query];
    if(index == NSNotFound){
        return NO;
    }
    
    return YES;
}

- (void)recordAnswer:(id)answer forQuery:(id)query{
    
    if(self->queries == nil){
        self->queries = [[NSMutableArray alloc] init];
        self->answers = [[NSMutableArray alloc] init];
    }
    
    [self->queries addObject:query];
    [self->answers addObject:answer];
    
    [self writeJSON];
    
}

- (BOOL)compareAnswer:(id)answer forQuery:(id)query{
    if(self->queries == nil){
        [self readJSON];
    }
    
    NSUInteger index = [self->queries indexOfObject:query];
    if(index == NSNotFound){
        NSLog(@"not found query %@", query);
        return NO;
    }
    
    id rightAnswer = self->answers[index];

    // ハッシュを使った比較。
    BOOL ret = [answer isEqual:rightAnswer];
    
    if(ret == YES){
        NSLog(@"compareAnswer OK. query:%@", query);
    }
    
    return ret;
}


- (NSString *)jsonFileReadingPath{
    
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    
    NSString *fname = [NSString stringWithFormat:@"%@.json", self->caseName];
    NSString *path = [bundle pathForResource:fname ofType:nil];
    
    
    return path;
}

- (NSString *)jsonFileWritingPath{
    
    NSString *userDataDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
    
    if (! [[NSFileManager defaultManager] fileExistsAtPath:userDataDirectory]){
        [[NSFileManager defaultManager] createDirectoryAtPath:userDataDirectory withIntermediateDirectories:YES attributes:nil error:nil];
        NSLog(@"make directory %@", userDataDirectory);
    }
    
    NSString *fname = [NSString stringWithFormat:@"%@.json", self->caseName];
    NSString *path = [userDataDirectory stringByAppendingPathComponent:fname];
    
    return path;
}

- (void)readJSON{
    
    NSError *err;

    NSString *jsonString;
    NSData *jsonData;
    err = nil;

    NSString *path = [self jsonFileReadingPath];
    jsonString = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&err];
    
    if(err){
        NSLog(@"JSONFile read error!! case:%@", self->caseName);
        return;
    }
    
    jsonData = [jsonString dataUsingEncoding:NSUnicodeStringEncoding];
    NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:jsonData
                                                         options:NSJSONReadingAllowFragments
                                                           error:&err];
    
    if(err){
        NSLog(@"JSONFile parse error!! case:%@", self->caseName);
        return;
    }
    
    self->queries = dict[@"queries"];
    self->answers = dict[@"answers"];
}


- (void)writeJSON{
    
    NSError *err = nil;
    
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
    dict[@"queries"] = self->queries;
    dict[@"answers"] = self->answers;
    
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dict
                                                       options:NSJSONWritingPrettyPrinted
                                                         error:&err];
    
    if(err){
        NSLog(@"make JSON data error!! case:%@", self->caseName);
        return;
    }
    
    NSString *path = [self jsonFileWritingPath];
    
    NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];

    [jsonString writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:&err];
    
    if(err){
        NSLog(@"JSONFile write error!! case:%@ path:%@", self->caseName, path);
        return;
    }
    
    NSLog(@"JSON write success. path:%@", path);
    
}

@end

# framework-ios-odptdata 使い方
____

ODPT(Open Data for Public Transpotation) APIへアクセスするiOS フレームワークです。 Objective-C で書かれています。

## 概要

ODPT API は東京周辺の公共交通機関の情報を得られるAPIとして、公開されています。

現時点(2019年8月)で、3種類のODPT API,それに類似したAPIが公開されています。
* 東京メトロ オープンデータ API <https://developer.tokyometroapp.jp/info>
* 公共交通オープンデータ API <https://developer.odpt.org/ja/info>
* 第3回 東京公共交通オープンデータチャレンジ用API <https://tokyochallenge.odpt.org>

3番目のAPIが、最も内容が豊富で、このフレームワークは、このAPIのために開発されています。

ODPT APIは RESTful Web APIです。APIにアクセスするには、アプリは適切な機能を持つ必要があります。さもないと、アプリは十分なユーザーエクスペリエンスを提供できません。

このフレームワークはODPT APIに直接アクセスするiOSアプリのために開発されました。以下の機能があります。
* アクセスレート制限にかからないように、連続的なHTTPリクエスト発行
* 取得したデータをキャッシュ
* 同時かつ、重複したアクセスがある時の効率化
* App側が利用しやすいよう、オリジナルODPTデータ内容を一部調整
* 拡張可能なアーキテクチャ

上記の機能により、アプリ起動時に発生する短期間の大量アクセスや、ユーザーの操作に応じた単発的なアクセスに、破綻なく効率的に、APIにアクセスします。

このフレームワークは、トーキョーラインズ Ver.2.0.4 以降に適用されています。

このフレームワークの開発者は、ODPT APIの管理者とは関係がありません。
このフレームワークを有効に活用するには、別にAPI管理者が定めるAPI使用許諾に同意し、遵守しなければなりません。


## 要件

このフレームワークは、アップルが提供する機能のみに依存しており、他の第三者のライブラリは不要です。

このフレームワークは、Xcode 10.2 にて開発、ビルドされています。

APIにアクセスするために、あなたのアプリ用に、エンドポイントURLおよびトークンを取得する必要があります。
東京公共交通オープンデータチャレンジ用APIについては、以下のURLを参照ください。
<https://tokyochallenge.odpt.org>


## インストール

Git または Xcodeを使って、あなたの環境にファイルをダウンロードしてください。
Xcodeを使う場合は、"Welcome to code"ダイアログにある "Clone an existing project"をクリックしてください。
何かのディレクトリを作成し、その下にファイルを展開することをお勧めします。

## 使い方

### アプリのプロジェクトにフレームワークを追加

一度Xcodeを閉じ、あなたが開発中のプロジェクトを開きます。 フレームワークにある、ODPTData.xcodeproj ファイルを、ソース一覧のアプリのプロジェクトの **下** に、ドラッグ&ドロップします。アプリのプロジェクトと **同列ではありません** 。

ソース一覧で、プロジェクトファイルを選択し、ビルドターゲットを選択します。
"General" - "Embedded Binaries" を選択し、"+"ボタンをクリックし、 "ODPTData.framework"を選択します。

これらの作業によって、あなたのアプリはこのフレームワークに依存するようになります。あなたのアプリをビルドする際は、それに先立ってこのフレームワークがビルドされ、自動的にリンクされます。


## Swift で書かれたアプリへの準備
あなたのアプリがSwiftで書かれている場合、このフレームワークないの関数を呼び出すためには、ブリッジヘッダ(bridge header file)を作成する必要があります。このフレームワークは Objective-Cで書かれているからです。

いつものように新しいヘッダファイル (\*.h)をあなたのプロジェクトに追加します。ファイル名は、 "[XXXXX]-Bridging-Header.h"とするのが望ましいです。[XXXXX]はあなたのアプリ名などで置き換えます。

ソース一覧でプロジェクトファイルを選択し、ビルドターゲットを選択します。
"Build Settings" - "Swift Compilar - General"と選択し、"Objective-C Bridging Header"の項目で、以下のように入力します。

> $(SRCROOT)/$(PROJECT)/[XXXXX]-Bridging-Header.h

このヘッダファイルを開き、以下の一文を追加します。

```Objective-C
@import ODPTData;
```

## フレームワーク内関数の呼び出し

これまでの手順によって、 ODPTData.h や他のヘッダファイルは、あなたのアプリの \*.m や \*.swift といったソースファイルから見えるようになります。
Xcodeのコードスニペット（入力補完）も機能するようになります。

フレームワークを使うには、まず、ODPTDataController クラスをインスタンス化してください。
イニシャライザには、キャッシュ用のデータベースファイル(CoreData)の保存場所や、エンドポイントURL、トークンを設定します。
エンドポイントURL、トークンは、APIの管理者から取得します。
第3回東京公共交通オープンデータチャレンジ用APIの場合、エンドポイントURLは、"https://"ではじまり、"/v4"で終わります。

```Swift
var dataSource = ODPTDataController ( apiCacheDirectory:"zzzz...",  userDataDirectory:"yyyy", endPointURL:"https://xxxxxx", token:"xxxxx" )
```

```Objective-C
ODPTDataController *dataSource = [[ODPTDataController alloc] initWithAPICacheDirectory:[self cacheDirectory]
    withUserDataDirectory:[self userDataDirectory]
    withEndPointURL:endPointURL
    withToken:token];
```

このインスタンスに、prepare メッセージを送信します。

```Swift
 dataSource.prepare()
```

```Objective-C
 [dataSource prepare];
```

ODPTDataControllerクラスの様々なメソッドを呼び出します。

```Swift
dataSource!.request(withOwner: self, stationTitleForIdentifier: ident) { (title: String?) in
     print(ident + " -> " + title!);
  }
```

```Objective-c
[dataSource requestWithOwner:nil StationTitleForIdentifier:StationIdentifier Block:^(NSString \*title) {
    NSLog(@"%@ -> %@", ident, title);
}];
```

非同期なアクセスのため、多くのメソッドはクロージャ（Objective-Cではブロック構文）を使う必要があります。

## 使い方 - テストコード

リポジトリには、このフレームワーク向けのテストコードがいくつか用意されています。このフレームワークを修正したい場合には、このテスコードを走らせてみるのが良いでしょう。

### token.txt / endpoint.txt の作成

API管理者から取得したトークンを記した token.txt を作成します。このファイルはトークンを表す文字列だけを含みます。

API管理者から取得したエンドポイントURL を記した endpoint.txt を作成します。第3回東京公共交通オープンデータチャレンジ用APIの場合、このファイルは、"https://"ではじまり、"/v4"で終わる、エンドポイントURLを表す文字列のみを含みます。

### ODPTDataTests ビルドターゲット向け Run Script の修正

Xcodeを一度閉じ、このフレームワークのプロジェクト "ODPTData.xcodeproj" だけをXcodeで開きます。

Xcodeのビルドターゲット設定で、"ODPTDataTests"を選択します。
ウインドウの上部で、"Build Phases"を選択し、"Run Script"を開きます。
Run Scriptは、テストコードをビルドする前に実行されるシェルスクリプトを表します。

変数 "ODPT_TOKEN_FILE" と "ODPT_ENDPOINT_FILE"に、先ほど作成した"token.txt"と"endpoint.txt"のパスを設定します。

### テストの実行

"ODPTDataTests" ディレクトリ下に、テスト用のソースファイルが置かれています。
例えば、"ODTDataTests+Controller.m"を選択し、"- (void) testRequestLineTitle" を探します。
各メソッド名の左側にひし形のマークがありますので、これをクリックします。
APIからいくつかの路線名を取得するテストだけが実行されます。
テスト結果は、ウインドウ下部のコンソールに表示されます。


## ライセンス

このソフトウェアは、MITライセンスの下で公開されています。

本ソフトウェアを使ってODPT APIにアクセスするには、このソフトウェアライセンスとは別に、API使用許諾に合意し、遵守する必要があります。

あなたの作品に本ソフトウェアが含まれていても、東京公共交通オープンデータチャレンジなどのコンテストに応募することができます。
あなたの作品がコンテストで入賞したとしても、本ソフトウェアの開発者は、入賞に関わる一切の権利を主張することはありません。

## 作者

Takehito Ikema

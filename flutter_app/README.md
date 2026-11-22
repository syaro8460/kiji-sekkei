# flutter_app

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Web版をローカルで動かす

```sh
flutter run -d chrome --web-hostname 127.0.0.1 --web-port 8081
```

ローカル開発版はポート 8081 で開き、「記事設計 Dev」と開発用アイコンが表示されます。通常版をローカルで配信する場合はポート 8080 を使えます。ポートが異なるため、ブラウザ上で両方を開けて、保存データも分かれます。

同じブラウザで同じURL（ポートを含む）を開くと、保存した記事とテンプレートを読み込めます。ブラウザのサイトデータを消すとローカル保存も消えるので、データを持ち出すときはアプリのJSONバックアップを使ってください。

Web版を配信する場合は `flutter build web` で作成する `build/web` を使い、`sqlite3.wasm` を `application/wasm` として配信します。`web/drift_worker.js` と `web/sqlite3.wasm` は [Drift 2.35.4の公式リリース](https://github.com/simolus3/drift/releases/tag/drift-2.35.4) のファイルです。Driftを更新するときは、対応するリリースの2ファイルを同時に更新してください。

## iPhone版をMacで確認する

[Flutter公式のiOS開発環境セットアップ](https://docs.flutter.dev/platform-integration/ios/setup) に沿ってMacとXcodeを準備します。iOSシミュレーターを起動してから `flutter_app` で `flutter devices` を実行し、表示された端末IDを `flutter run -d` に指定します。

シミュレーターでは次を確認します。

- 開発ビルドではホーム画面の表示名が「記事設計 Dev」で、開発用アイコンが表示される。
- 記事を保存後、アプリを終了して開き直しても記事が残る。
- 「ファイル」でJSONバックアップの書き出し・復元と、記事のMarkdown保存ができる。復元にはテスト用データを使う。

実機に入れる場合は、XcodeのRunnerターゲットで開発用の署名を設定します。既存のSwiftUI版と並べて確認する場合は、Flutter版に別のバンドルIDを使います。

## Android・iOSの開発版とリリース版

通常の `flutter run`（Debug）と Profile ビルドは開発用アイコンを使用します。開発版はアプリ識別子の末尾に `.dev` が付き、リリース版と同じ端末にインストールできます。Release ビルドは従来の識別子と正式アイコンを使用します。

両版のローカルデータは独立しています。以前の開発ビルドで保存したデータは従来の識別子側に残ります。新しい開発版に必要なデータは、JSONバックアップで移せます。
## Firebase同期の開発環境

Firebase CLI と Java を用意し、`flutter_app` で以下を実行すると、認証と Firestore のルールをローカルで確認できます。

```sh
firebase emulators:exec --only auth,firestore --project demo-kiji-sekkei "node tool/test_firestore_rules.mjs"
```

検証用のデータは、エミュレーター内に作るテストユーザーのものです。Firestore はユーザーごとに記事とカスタムテンプレートを分け、更新番号を照合します。削除はマーカーで伝えます。通常のアプリは引き続きローカル保存を使用します。

テスト用の記事を端末間で同期する場合は、別のターミナルでローカル環境を起動します。

```sh
firebase emulators:start --only auth,firestore --project demo-kiji-sekkei
```

Flutterの通常の起動先とは別に用意したテスト画面を起動します。

```sh
flutter run -d chrome --web-port 8083 --target lib/firebase_sync_demo.dart
flutter run -d emulator-5554 --target lib/firebase_sync_demo.dart
```

片方でテストアカウントを作成し、もう片方で同じアカウントにログインします。「テスト記事を同期」を押すと、相手の画面のタイトルとメモが更新されます。同期先はログイン方法に依存せず、Firebase AuthenticationのユーザーIDで分かれます。この画面が扱うのはテストアカウントごとに1件のテスト記事です。通常のアプリに戻るには、ターゲットを指定せず `flutter run` します。

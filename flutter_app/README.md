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
flutter run -d chrome --web-port 8080
```

同じブラウザで同じURL（ポートを含む）を開くと、保存した記事とテンプレートを読み込めます。ブラウザのサイトデータを消すとローカル保存も消えるので、データを持ち出すときはアプリのJSONバックアップを使ってください。

Web版を配信する場合は `flutter build web` で作成する `build/web` を使い、`sqlite3.wasm` を `application/wasm` として配信します。`web/drift_worker.js` と `web/sqlite3.wasm` は [Drift 2.35.4の公式リリース](https://github.com/simolus3/drift/releases/tag/drift-2.35.4) のファイルです。Driftを更新するときは、対応するリリースの2ファイルを同時に更新してください。

## iPhone版をMacで確認する

[Flutter公式のiOS開発環境セットアップ](https://docs.flutter.dev/platform-integration/ios/setup) に沿ってMacとXcodeを準備します。iOSシミュレーターを起動してから `flutter_app` で `flutter devices` を実行し、表示された端末IDを `flutter run -d` に指定します。

シミュレーターでは次を確認します。

- ホーム画面の表示名が「記事設計」で、アプリ内の表示が日本語になっている。
- 記事を保存後、アプリを終了して開き直しても記事が残る。
- 「ファイル」でJSONバックアップの書き出し・復元と、記事のMarkdown保存ができる。復元にはテスト用データを使う。

実機に入れる場合は、XcodeのRunnerターゲットで開発用の署名を設定します。既存のSwiftUI版と並べて確認する場合は、Flutter版に別のバンドルIDを使います。

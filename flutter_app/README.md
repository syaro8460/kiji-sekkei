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

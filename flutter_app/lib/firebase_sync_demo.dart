import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import 'models/article_draft.dart';
import 'storage/firestore_draft_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final app = await Firebase.initializeApp(
      name: '[DEFAULT]',
      demoProjectId: 'demo-kiji-sekkei',
    );
    final host = !kIsWeb && defaultTargetPlatform == TargetPlatform.android
        ? '10.0.2.2'
        : '127.0.0.1';
    final auth = FirebaseAuth.instanceFor(app: app);
    await auth.useAuthEmulator(host, 9099, automaticHostMapping: false);
    final firestore = FirebaseFirestore.instanceFor(app: app);
    firestore.useFirestoreEmulator(host, 8082, automaticHostMapping: false);
    runApp(_DemoApp(auth: auth, firestore: firestore));
  } catch (error, stack) {
    if (kDebugMode) {
      debugPrint(error.toString());
      debugPrintStack(stackTrace: stack);
    }
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: Text('Firebaseのローカル検証環境に接続できませんでした。')),
        ),
      ),
    );
  }
}

class _DemoApp extends StatefulWidget {
  const _DemoApp({required this.auth, required this.firestore});

  final FirebaseAuth auth;
  final FirebaseFirestore firestore;

  @override
  State<_DemoApp> createState() => _DemoAppState();
}

class _DemoAppState extends State<_DemoApp> {
  late final _account = widget.auth.authStateChanges();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '記事設計 Dev・同期テスト',
      home: Scaffold(
        appBar: AppBar(title: const Text('Firebase同期テスト')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: StreamBuilder<User?>(
              stream: _account,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Text('アカウントの状態を確認できませんでした。');
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const CircularProgressIndicator();
                }
                final user = snapshot.data;
                if (user == null) return _SignIn(auth: widget.auth);
                return _TestArticle(
                  key: ValueKey(user.uid),
                  onSignOut: widget.auth.signOut,
                  drafts: FirestoreDraftStore(widget.firestore, uid: user.uid),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _SignIn extends StatefulWidget {
  const _SignIn({required this.auth});

  final FirebaseAuth auth;

  @override
  State<_SignIn> createState() => _SignInState();
}

class _SignInState extends State<_SignIn> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _authenticate({required bool create}) async {
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'テスト用のメールアドレスとパスワードを入力してください。');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (create) {
        await widget.auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
      } else {
        await widget.auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      }
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = switch (error.code) {
          'email-already-in-use' => 'そのテストアカウントは作成済みです。ログインしてください。',
          'weak-password' => 'パスワードは6文字以上で入力してください。',
          'network-request-failed' => 'ローカルのFirebaseに接続できませんでした。',
          _ => 'メールアドレスとパスワードを確認してください。',
        };
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text('検証専用です。普段使っているメールアドレスやパスワードは入力しないでください。'),
        TextField(
          controller: _email,
          enabled: !_busy,
          decoration: const InputDecoration(labelText: 'テスト用メールアドレス'),
          keyboardType: TextInputType.emailAddress,
        ),
        TextField(
          controller: _password,
          enabled: !_busy,
          decoration: const InputDecoration(labelText: 'テスト用パスワード'),
          obscureText: true,
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _busy ? null : () => _authenticate(create: false),
          child: const Text('ログイン'),
        ),
        TextButton(
          onPressed: _busy ? null : () => _authenticate(create: true),
          child: const Text('テストアカウントを作成'),
        ),
        if (_error case final error?) Text(error),
      ],
    );
  }
}

class _TestArticle extends StatefulWidget {
  const _TestArticle({
    super.key,
    required this.onSignOut,
    required this.drafts,
  });

  final Future<void> Function() onSignOut;
  final FirestoreDraftStore drafts;

  @override
  State<_TestArticle> createState() => _TestArticleState();
}

class _TestArticleState extends State<_TestArticle> {
  final _title = TextEditingController();
  static const _draftId = '5d35cccd-ff13-4bbe-a4e0-3effabff9b75';
  static const _question = '記事のメモ';
  final _answer = TextEditingController();
  late final _record = widget.drafts.watchDraft(_draftId);
  bool _saving = false;
  String? _message;

  @override
  void dispose() {
    _title.dispose();
    _answer.dispose();
    super.dispose();
  }

  Future<void> _save(int expectedRevision) async {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    setState(() {
      _saving = true;
      _message = null;
    });
    try {
      final answer = _answer.text.trim();
      final saved = await widget.drafts.saveDraft(
        ArticleDraft(
          id: _draftId,
          title: title,
          articleType: '日記',
          questions: const [_question],
          answers: answer.isEmpty ? {} : {_question: answer},
        ),
        expectedRevision: expectedRevision,
      );
      if (!mounted) return;
      setState(() {
        _message = saved ? 'テスト記事を同期しました。' : '別の端末で更新されました。同期済みのタイトルを確認してください。';
      });
    } on FirebaseException {
      if (mounted) setState(() => _message = '同期できませんでした。接続を確認してください。');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SyncedDraft>(
      stream: _record,
      builder: (context, snapshot) {
        final synced = snapshot.data;
        final draft = synced?.draft;
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text('同期済みのタイトル'),
            if (snapshot.hasError)
              const Text('テスト記事を読み込めませんでした。')
            else if (!snapshot.hasData)
              const LinearProgressIndicator()
            else
              Text(draft?.title ?? 'テスト記事はまだありません'),
            if (draft?.answers[_question] case final answer?) Text(answer),
            TextField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'テスト記事のタイトル'),
              maxLength: 100,
            ),
            TextField(
              controller: _answer,
              decoration: const InputDecoration(labelText: 'テスト記事のメモ'),
              maxLength: 300,
            ),
            FilledButton(
              onPressed: _saving || !snapshot.hasData
                  ? null
                  : () => _save(synced!.revision),
              child: const Text('テスト記事を同期'),
            ),
            if (_message case final message?) Text(message),
            TextButton(
              onPressed: _saving ? null : widget.onSignOut,
              child: const Text('ログアウト'),
            ),
          ],
        );
      },
    );
  }
}

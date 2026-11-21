import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/models/article_draft.dart';
import 'package:flutter_app/models/article_template.dart';
import 'package:flutter_app/models/backup_data.dart';
import 'package:flutter_app/models/backup_manager.dart';

void main() {
  group('SwiftUI JSON backup compatibility', () {
    const swiftBackupJson = '''
{
  "schemaVersion": 1,
  "exportedAt": "2025-01-02T03:04:05Z",
  "drafts": [
    {
      "id": "10000000-0000-0000-0000-000000000001",
      "title": "試し書き",
      "articleType": "レビュー",
      "questions": ["何をレビューする？"],
      "answers": {"何をレビューする？": "内容"},
      "tags": ["タグ"],
      "updatedAt": "2025-01-01T10:20:30Z",
      "status": "trashed",
      "deletedAt": "2025-01-01T11:20:30Z"
    }
  ],
  "templates": [
    {
      "id": "20000000-0000-0000-0000-000000000001",
      "name": "自作",
      "questions": ["質問"],
      "iconName": "doc.text",
      "isBuiltIn": false
    }
  ]
}
''';

    test('decodes an existing SwiftUI backup', () {
      final backup = BackupManager().decode(utf8.encode(swiftBackupJson));

      expect(backup.schemaVersion, 1);
      expect(backup.exportedAt, DateTime.utc(2025, 1, 2, 3, 4, 5));

      final draft = backup.drafts.single;
      expect(draft.id, '10000000-0000-0000-0000-000000000001');
      expect(draft.status, DraftStatus.trashed);
      expect(draft.deletedAt, DateTime.utc(2025, 1, 1, 11, 20, 30));
      expect(draft.answers, {'何をレビューする？': '内容'});
      expect(draft.tags, ['タグ']);

      final template = backup.templates.single;
      expect(template.id, '20000000-0000-0000-0000-000000000001');
      expect(template.name, '自作');
      expect(template.iconName, 'doc.text');
      expect(template.isBuiltIn, isFalse);
    });

    test('encodes the SwiftUI schema with UTC ISO-8601 dates', () {
      final backup = BackupData(
        schemaVersion: 1,
        exportedAt: DateTime.utc(2025, 1, 2, 3, 4, 5),
        drafts: [
          ArticleDraft(
            id: '10000000-0000-0000-0000-000000000001',
            title: '下書き',
            articleType: 'レビュー',
            questions: ['質問'],
            updatedAt: DateTime.utc(2025, 1, 1, 10, 20, 30),
          ),
        ],
        templates: [],
      );

      final encoded = BackupManager().encode(backup);
      final json = jsonDecode(utf8.decode(encoded)) as Map<String, dynamic>;
      final draft = (json['drafts'] as List).single as Map<String, dynamic>;

      expect(json['schemaVersion'], 1);
      expect(json['exportedAt'], '2025-01-02T03:04:05Z');
      expect(draft['updatedAt'], '2025-01-01T10:20:30Z');
      expect(draft['status'], 'active');
      expect(draft.containsKey('deletedAt'), isFalse);
      final sortedKeys = draft.keys.toList()..sort();
      expect(draft.keys.toList(), sortedKeys);
    });

    test(
      'applies SwiftUI defaults and question fallback when fields are absent',
      () {
        final beforeDecode = DateTime.now();
        final draft = ArticleDraft.fromJson({
          'id': '10000000-0000-0000-0000-000000000001',
          'title': '旧形式',
          'articleType': 'レビュー',
          'answers': {'回答': '内容'},
        });
        final afterDecode = DateTime.now();

        expect(
          draft.questions,
          ArticleTemplate.builtInTemplates.first.questions,
        );
        expect(draft.answers, {'回答': '内容'});
        expect(draft.tags, isEmpty);
        expect(draft.status, DraftStatus.active);
        expect(draft.deletedAt, isNull);
        expect(
          draft.updatedAt.isBefore(beforeDecode) ||
              draft.updatedAt.isAfter(afterDecode),
          isFalse,
        );

        final unknownTypeDraft = ArticleDraft.fromJson({
          'id': '10000000-0000-0000-0000-000000000002',
          'title': '旧形式',
          'articleType': '自作種類',
          'answers': {'質問B': 'B', '質問A': 'A'},
          'questions': null,
          'tags': null,
          'status': null,
          'updatedAt': null,
          'deletedAt': null,
        });
        expect(unknownTypeDraft.questions, ['質問B', '質問A']);
      },
    );

    test(
      'rejects invalid UUIDs, statuses, and unsupported schema versions',
      () {
        expect(
          () => ArticleDraft.fromJson({
            'id': 'not-a-uuid',
            'title': 'タイトル',
            'articleType': 'レビュー',
          }),
          throwsFormatException,
        );
        expect(
          () => ArticleDraft.fromJson({
            'id': '10000000-0000-0000-0000-000000000001',
            'title': 'タイトル',
            'articleType': 'レビュー',
            'status': 'deleted',
          }),
          throwsFormatException,
        );
        expect(
          () => BackupManager().decode(
            utf8.encode(
              swiftBackupJson.replaceFirst(
                '"schemaVersion": 1',
                '"schemaVersion": 2',
              ),
            ),
          ),
          throwsFormatException,
        );
      },
    );

    test('matches all four built-in template IDs and questions', () {
      final templates = ArticleTemplate.builtInTemplates;

      expect(templates.map((template) => template.id).toList(), [
        '00000000-0000-0000-0000-000000000001',
        '00000000-0000-0000-0000-000000000002',
        '00000000-0000-0000-0000-000000000003',
        '00000000-0000-0000-0000-000000000004',
      ]);
      expect(templates.map((template) => template.name).toList(), [
        'レビュー',
        '比較',
        '体験談',
        '選ばなかった理由',
      ]);
      expect(templates.map((template) => template.questions).toList(), [
        [
          '何をレビューする？',
          '購入・利用した理由は？',
          '使う前に期待していたことは？',
          '実際に良かった点は？',
          '気になった点は？',
          'どんな人におすすめ？',
          '最後に一言でまとめると？',
        ],
        [
          '何と何を比較する？',
          '比較しようと思った理由は？',
          'それぞれの良かった点は？',
          'それぞれの気になった点は？',
          '最終的にどちらを選んだ？',
          'その理由は？',
          'どんな人にはこちらがおすすめ？',
        ],
        [
          '何を体験した？',
          '体験する前はどう思っていた？',
          '実際に体験してどうだった？',
          '印象に残ったことは？',
          '困ったことや失敗したことは？',
          'この体験で学んだことは？',
          '最後に一言でまとめると？',
        ],
        [
          '検討していた商品・サービスは？',
          'なぜ気になっていた？',
          '選ばなかった理由は？',
          '代わりに何を選んだ？',
          '実際に代わりの選択はどうだった？',
          'どんな人なら向いていると思う？',
          '最後に一言でまとめると？',
        ],
      ]);
      expect(templates.every((template) => template.isBuiltIn), isTrue);
    });
  });
}

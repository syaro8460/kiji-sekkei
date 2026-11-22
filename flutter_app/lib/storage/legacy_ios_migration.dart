import 'package:flutter/services.dart';

import '../models/article_draft.dart';
import '../models/article_template.dart';
import 'article_database.dart';

const _channel = MethodChannel('kijisekkei/legacy_ios_migration');

Future<void> migrateLegacyIosData(ArticleDatabase database) async {
  if (await database.hasCompletedLegacyIosMigration()) return;

  final snapshot = await _channel.invokeMapMethod<String, Object?>('read');
  if (snapshot == null) {
    throw const FormatException('Missing legacy migration result.');
  }
  if (snapshot['applicable'] == false) return;

  if (snapshot['applicable'] != true || snapshot['version'] != 1) {
    throw const FormatException('Unknown legacy migration result.');
  }
  final drafts = (snapshot['drafts'] as List).map((item) {
    final fields = Map<String, dynamic>.from(item as Map);
    final updatedAt = fields.remove('updatedAtMicros') as int;
    final deletedAt = fields.remove('deletedAtMicros') as int?;
    fields['updatedAt'] = DateTime.fromMicrosecondsSinceEpoch(
      updatedAt,
      isUtc: true,
    ).toIso8601String();
    fields['deletedAt'] = deletedAt == null
        ? null
        : DateTime.fromMicrosecondsSinceEpoch(
            deletedAt,
            isUtc: true,
          ).toIso8601String();
    return ArticleDraft.fromJson(fields);
  }).toList();
  final templates = (snapshot['templates'] as List)
      .map(
        (item) =>
            ArticleTemplate.fromJson(Map<String, dynamic>.from(item as Map)),
      )
      .toList();
  await database.importLegacyIosData(drafts, templates);
}

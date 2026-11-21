import 'article_draft.dart';
import 'article_template.dart';
import 'json_compat.dart';

class BackupData {
  final int schemaVersion;
  final DateTime exportedAt;
  final List<ArticleDraft> drafts;
  final List<ArticleTemplate> templates;

  const BackupData({
    required this.schemaVersion,
    required this.exportedAt,
    required this.drafts,
    required this.templates,
  });

  factory BackupData.fromJson(Map<String, dynamic> json) {
    final schemaVersion = json['schemaVersion'];
    final drafts = json['drafts'];
    final templates = json['templates'];

    if (schemaVersion is! int) {
      throw const FormatException('schemaVersion must be an integer.');
    }
    if (drafts is! List ||
        !drafts.every((item) => item is Map<String, dynamic>)) {
      throw const FormatException('drafts must be an array of objects.');
    }
    if (templates is! List ||
        !templates.every((item) => item is Map<String, dynamic>)) {
      throw const FormatException('templates must be an array of objects.');
    }

    return BackupData(
      schemaVersion: schemaVersion,
      exportedAt: parseIso8601Date(json['exportedAt'], 'exportedAt'),
      drafts: drafts
          .cast<Map<String, dynamic>>()
          .map(ArticleDraft.fromJson)
          .toList(),
      templates: templates
          .cast<Map<String, dynamic>>()
          .map(ArticleTemplate.fromJson)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'exportedAt': encodeIso8601Date(exportedAt),
    'drafts': drafts.map((draft) => draft.toJson()).toList(),
    'templates': templates.map((template) => template.toJson()).toList(),
  };
}

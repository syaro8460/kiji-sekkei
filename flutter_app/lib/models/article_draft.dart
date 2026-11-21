import 'article_template.dart';
import 'json_compat.dart';

enum DraftStatus { active, trashed }

class ArticleDraft {
  final String id;
  String title;
  String articleType;
  List<String> questions;
  Map<String, String> answers;
  List<String> tags;
  DateTime updatedAt;
  DraftStatus status;
  DateTime? deletedAt;

  ArticleDraft({
    required this.id,
    required this.title,
    required this.articleType,
    required this.questions,
    Map<String, String>? answers,
    List<String>? tags,
    DateTime? updatedAt,
    this.status = DraftStatus.active,
    this.deletedAt,
  }) : answers = answers ?? {},
       tags = tags ?? [],
       updatedAt = updatedAt ?? DateTime.now();

  factory ArticleDraft.fromJson(Map<String, dynamic> json) {
    final articleType = _requiredString(json, 'articleType');
    final answers = _stringMap(json['answers'] ?? const {}, 'answers');
    final savedQuestions = json['questions'];

    final List<String> questions;
    if (savedQuestions == null) {
      final builtInTemplates = ArticleTemplate.builtInTemplates.where(
        (template) => template.name == articleType,
      );
      questions = builtInTemplates.isEmpty
          ? answers.keys.toList()
          : builtInTemplates.first.questions;
    } else {
      questions = _stringList(savedQuestions, 'questions');
    }

    return ArticleDraft(
      id: requireUuid(json['id'], 'id'),
      title: _requiredString(json, 'title'),
      articleType: articleType,
      questions: questions,
      answers: answers,
      tags: json['tags'] == null ? [] : _stringList(json['tags'], 'tags'),
      updatedAt: json['updatedAt'] == null
          ? DateTime.now()
          : parseIso8601Date(json['updatedAt'], 'updatedAt'),
      status: _draftStatus(json['status']),
      deletedAt: json['deletedAt'] == null
          ? null
          : parseIso8601Date(json['deletedAt'], 'deletedAt'),
    );
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'id': requireUuid(id, 'id'),
      'title': title,
      'articleType': articleType,
      'questions': questions,
      'answers': answers,
      'tags': tags,
      'updatedAt': encodeIso8601Date(updatedAt),
      'status': status.name,
    };

    if (deletedAt != null) {
      json['deletedAt'] = encodeIso8601Date(deletedAt!);
    }

    return json;
  }

  int? get remainingTrashDays {
    if (status != DraftStatus.trashed || deletedAt == null) {
      return null;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final deletionDate = deletedAt!.add(const Duration(days: 30));
    final expiryDay = DateTime(
      deletionDate.year,
      deletionDate.month,
      deletionDate.day,
    );

    return expiryDay.difference(today).inDays;
  }

  static DraftStatus _draftStatus(Object? value) {
    if (value == null) {
      return DraftStatus.active;
    }

    if (value is String) {
      return switch (value) {
        'active' => DraftStatus.active,
        'trashed' => DraftStatus.trashed,
        _ => throw FormatException('Invalid draft status: $value'),
      };
    }

    throw const FormatException('Draft status must be a string.');
  }
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String) {
    return value;
  }
  throw FormatException('$key must be a string.');
}

List<String> _stringList(Object? value, String key) {
  if (value is List && value.every((item) => item is String)) {
    return value.cast<String>();
  }
  throw FormatException('$key must be an array of strings.');
}

Map<String, String> _stringMap(Object? value, String key) {
  if (value is Map &&
      value.keys.every((item) => item is String) &&
      value.values.every((item) => item is String)) {
    return value.cast<String, String>();
  }
  throw FormatException('$key must be an object containing string values.');
}

import '../models/article_draft.dart';

String exportArticleStructure(ArticleDraft draft) {
  final structure = StringBuffer(
    '【タイトル】\n${draft.title}\n\n【記事種類】\n${draft.articleType}\n\n\n',
  );

  for (final (index, question) in draft.questions.indexed) {
    final answer = (draft.answers[question] ?? '').trim();
    structure
      ..writeln('【質問${index + 1}】')
      ..writeln(question)
      ..writeln()
      ..writeln('【回答】')
      ..writeln(answer.isEmpty ? '【未入力】' : answer)
      ..writeln();
  }

  return structure.toString().trim();
}

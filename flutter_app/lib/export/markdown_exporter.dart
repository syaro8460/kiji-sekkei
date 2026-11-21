import '../models/article_draft.dart';

String exportMarkdown(ArticleDraft draft) {
  final markdown = StringBuffer('# ${draft.title}\n\n');
  for (final question in draft.questions) {
    markdown
      ..write('## $question\n\n')
      ..write(draft.answers[question] ?? '')
      ..write('\n\n');
  }
  return markdown.toString();
}

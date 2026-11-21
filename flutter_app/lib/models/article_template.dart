import 'json_compat.dart';

class ArticleTemplate {
  final String id;
  String name;
  List<String> questions;
  String iconName;
  bool isBuiltIn;

  ArticleTemplate({
    required this.id,
    required this.name,
    required this.questions,
    this.iconName = 'doc.text',
    this.isBuiltIn = false,
  });

  factory ArticleTemplate.fromJson(Map<String, dynamic> json) {
    final id = requireUuid(json['id'], 'id');
    final name = json['name'];
    final questions = json['questions'];
    final iconName = json['iconName'];
    final isBuiltIn = json['isBuiltIn'];

    if (name is! String) {
      throw const FormatException('name must be a string.');
    }
    if (questions is! List || !questions.every((item) => item is String)) {
      throw const FormatException('questions must be an array of strings.');
    }
    if (iconName is! String) {
      throw const FormatException('iconName must be a string.');
    }
    if (isBuiltIn is! bool) {
      throw const FormatException('isBuiltIn must be a boolean.');
    }

    return ArticleTemplate(
      id: id,
      name: name,
      questions: questions.cast<String>(),
      iconName: iconName,
      isBuiltIn: isBuiltIn,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': requireUuid(id, 'id'),
    'name': name,
    'questions': questions,
    'iconName': iconName,
    'isBuiltIn': isBuiltIn,
  };

  static final List<ArticleTemplate> builtInTemplates = [
    ArticleTemplate(
      id: '00000000-0000-0000-0000-000000000001',
      name: 'レビュー',
      questions: [
        '何をレビューする？',
        '購入・利用した理由は？',
        '使う前に期待していたことは？',
        '実際に良かった点は？',
        '気になった点は？',
        'どんな人におすすめ？',
        '最後に一言でまとめると？',
      ],
      iconName: 'star.bubble',
      isBuiltIn: true,
    ),
    ArticleTemplate(
      id: '00000000-0000-0000-0000-000000000002',
      name: '比較',
      questions: [
        '何と何を比較する？',
        '比較しようと思った理由は？',
        'それぞれの良かった点は？',
        'それぞれの気になった点は？',
        '最終的にどちらを選んだ？',
        'その理由は？',
        'どんな人にはこちらがおすすめ？',
      ],
      iconName: 'arrow.left.arrow.right',
      isBuiltIn: true,
    ),
    ArticleTemplate(
      id: '00000000-0000-0000-0000-000000000003',
      name: '体験談',
      questions: [
        '何を体験した？',
        '体験する前はどう思っていた？',
        '実際に体験してどうだった？',
        '印象に残ったことは？',
        '困ったことや失敗したことは？',
        'この体験で学んだことは？',
        '最後に一言でまとめると？',
      ],
      iconName: 'person.text.rectangle',
      isBuiltIn: true,
    ),
    ArticleTemplate(
      id: '00000000-0000-0000-0000-000000000004',
      name: '選ばなかった理由',
      questions: [
        '検討していた商品・サービスは？',
        'なぜ気になっていた？',
        '選ばなかった理由は？',
        '代わりに何を選んだ？',
        '実際に代わりの選択はどうだった？',
        'どんな人なら向いていると思う？',
        '最後に一言でまとめると？',
      ],
      iconName: 'xmark.circle',
      isBuiltIn: true,
    ),
  ];
}

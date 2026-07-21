import Foundation

struct ArticleTemplate: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var questions: [String]
    var iconName: String
    var isBuiltIn: Bool

    init(
        id: UUID = UUID(),
        name: String,
        questions: [String],
        iconName: String = "doc.text",
        isBuiltIn: Bool = false
    ) {
        self.id = id
        self.name = name
        self.questions = questions
        self.iconName = iconName
        self.isBuiltIn = isBuiltIn
    }

    static let builtInTemplates: [ArticleTemplate] = [
        ArticleTemplate(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            name: "レビュー",
            questions: [
                "何をレビューする？",
                "購入・利用した理由は？",
                "使う前に期待していたことは？",
                "実際に良かった点は？",
                "気になった点は？",
                "どんな人におすすめ？",
                "最後に一言でまとめると？"
            ],
            iconName: "star.bubble",
            isBuiltIn: true
        ),

        ArticleTemplate(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            name: "比較",
            questions: [
                "何と何を比較する？",
                "比較しようと思った理由は？",
                "それぞれの良かった点は？",
                "それぞれの気になった点は？",
                "最終的にどちらを選んだ？",
                "その理由は？",
                "どんな人にはこちらがおすすめ？"
            ],
            iconName: "arrow.left.arrow.right",
            isBuiltIn: true
        ),

        ArticleTemplate(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
            name: "体験談",
            questions: [
                "何を体験した？",
                "体験する前はどう思っていた？",
                "実際に体験してどうだった？",
                "印象に残ったことは？",
                "困ったことや失敗したことは？",
                "この体験で学んだことは？",
                "最後に一言でまとめると？"
            ],
            iconName: "person.text.rectangle",
            isBuiltIn: true
        ),

        ArticleTemplate(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000004")!,
            name: "選ばなかった理由",
            questions: [
                "検討していた商品・サービスは？",
                "なぜ気になっていた？",
                "選ばなかった理由は？",
                "代わりに何を選んだ？",
                "実際に代わりの選択はどうだった？",
                "どんな人なら向いていると思う？",
                "最後に一言でまとめると？"
            ],
            iconName: "xmark.circle",
            isBuiltIn: true
        )
    ]
}

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
                "この記事で紹介する商品・サービスは？",
                "購入・利用した理由は？",
                "良かった点は？",
                "気になった点は？",
                "どんな人におすすめ？",
                "まとめ"
            ],
            iconName: "star.bubble",
            isBuiltIn: true
        ),

        ArticleTemplate(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            name: "比較",
            questions: [
                "比較する商品・サービスは？",
                "比較しようと思った理由は？",
                "それぞれの良かった点は？",
                "それぞれの気になった点は？",
                "結局どちらを選んだ？",
                "どんな人におすすめ？",
                "まとめ"
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
                "実際にやってみてどうだった？",
                "困ったことや失敗したことは？",
                "体験して分かったことは？",
                "まとめ"
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
                "どんな人なら向いている？",
                "まとめ"
            ],
            iconName: "xmark.circle",
            isBuiltIn: true
        )
    ]
}

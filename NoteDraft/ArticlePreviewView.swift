import SwiftUI
import UIKit

struct ArticlePreviewView: View {
    let draft: ArticleDraft

    @State private var showCopiedAlert = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text(draft.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .frame(
                        maxWidth: .infinity,
                        alignment: .leading
                    )

                Text(draft.articleType)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Divider()

                Text(generatedArticle)
                    .textSelection(.enabled)
                    .frame(
                        maxWidth: .infinity,
                        alignment: .leading
                    )

                Button {
                    copyArticle()
                } label: {
                    Label(
                        "記事構成をコピー",
                        systemImage: "doc.on.doc"
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .navigationTitle("記事構成")
        .navigationBarTitleDisplayMode(.inline)
        .alert(
            "コピーしました",
            isPresented: $showCopiedAlert
        ) {
            Button("OK", role: .cancel) {
            }
        } message: {
            Text("ChatGPTやnoteへ貼り付けられます。")
        }
    }

    private var generatedArticle: String {
        switch draft.articleType {
        case "レビュー":
            return generateReviewArticle()

        case "比較":
            return generateComparisonArticle()

        case "選ばなかった理由":
            return generateNotSelectedArticle()

        case "体験談":
            return generateExperienceArticle()

        default:
            return generateBasicArticle()
        }
    }

    private func copyArticle() {
        UIPasteboard.general.string = generatedArticle
        showCopiedAlert = true
    }

    private func generateReviewArticle() -> String {
        generateStructuredArticle(
            questions: [
                "なぜこの商品やサービスを選んだ？",
                "使う前に期待していたことは？",
                "実際に使って良かったところは？",
                "気になったところは？",
                "どんな人におすすめ？",
                "最終的な感想は？"
            ]
        )
    }

    private func generateComparisonArticle() -> String {
        generateStructuredArticle(
            questions: [
                "比較しようと思った理由は？",
                "何と何を比較する？",
                "それぞれの良かったところは？",
                "それぞれの気になったところは？",
                "最終的にどちらを選んだ？",
                "その理由は？"
            ]
        )
    }

    private func generateNotSelectedArticle() -> String {
        generateStructuredArticle(
            questions: [
                "なぜ検討した？",
                "何を期待していた？",
                "なぜ選ばなかった？",
                "迷ったポイントは？",
                "代わりに何を選んだ？",
                "代わりの方法で実際どうだった？",
                "どんな人なら選んでもいいと思う？",
                "今振り返ってどう思う？"
            ]
        )
    }

    private func generateExperienceArticle() -> String {
        generateStructuredArticle(
            questions: [
                "何を体験した？",
                "体験する前はどう思っていた？",
                "実際に起きたことは？",
                "印象に残ったことは？",
                "困ったことや失敗は？",
                "この体験から学んだことは？"
            ]
        )
    }

    private func generateBasicArticle() -> String {
        generateStructuredArticle(
            questions: draft.questions
        )
    }
    
    private func generateStructuredArticle(
        questions: [String]
    ) -> String {
        var result = """
        タイトル：\(draft.title)

        記事種類：\(draft.articleType)

        """

        for (
            index,
            question
        ) in questions.enumerated() {
            result += """
            質問\(index + 1)：\(question)
            回答：\(answer(for: question))

            """
        }

        return result.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
    }

    private func answer(for question: String) -> String {
        let value = draft.answers[question, default: ""]
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        return value.isEmpty ? "【未入力】" : value
    }
}

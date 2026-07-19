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
        """
        # \(draft.title)

        ## はじめに

        \(answer(for: "なぜこの商品やサービスを選んだ？"))

        ## 使う前に期待していたこと

        \(answer(for: "使う前に期待していたことは？"))

        ## 良かったところ

        \(answer(for: "実際に使って良かったところは？"))

        ## 気になったところ

        \(answer(for: "気になったところは？"))

        ## どんな人におすすめか

        \(answer(for: "どんな人におすすめ？"))

        ## まとめ

        \(answer(for: "最終的な感想は？"))
        """
    }

    private func generateComparisonArticle() -> String {
        """
        # \(draft.title)

        ## はじめに

        \(answer(for: "比較しようと思った理由は？"))

        ## 比較するもの

        \(answer(for: "何と何を比較する？"))

        ## それぞれの良かったところ

        \(answer(for: "それぞれの良かったところは？"))

        ## それぞれの気になったところ

        \(answer(for: "それぞれの気になったところは？"))

        ## 最終的に選んだもの

        \(answer(for: "最終的にどちらを選んだ？"))

        ## 選んだ理由

        \(answer(for: "その理由は？"))

        ## まとめ

        比較を通して分かったことをまとめます。
        """
    }

    private func generateNotSelectedArticle() -> String {
        """
        # \(draft.title)

        ## はじめに

        \(answer(for: "なぜ検討した？"))

        ## 期待していたこと

        \(answer(for: "何を期待していた？"))

        ## 選ばなかった理由

        \(answer(for: "なぜ選ばなかった？"))

        ## 迷ったポイント

        \(answer(for: "迷ったポイントは？"))

        ## 代わりに選んだもの・方法

        \(answer(for: "代わりに何を選んだ？"))

        ## 代わりの方法を使ってみた結果

        \(answer(for: "代わりの方法で実際どうだった？"))

        ## 選んでもいいと思う人

        \(answer(for: "どんな人なら選んでもいいと思う？"))

        ## まとめ

        \(answer(for: "今振り返ってどう思う？"))
        """
    }

    private func generateExperienceArticle() -> String {
        """
        # \(draft.title)

        ## はじめに

        \(answer(for: "何を体験した？"))

        ## 体験する前に思っていたこと

        \(answer(for: "体験する前はどう思っていた？"))

        ## 実際に起きたこと

        \(answer(for: "実際に起きたことは？"))

        ## 印象に残ったこと

        \(answer(for: "印象に残ったことは？"))

        ## 困ったこと・失敗したこと

        \(answer(for: "困ったことや失敗は？"))

        ## この体験から学んだこと

        \(answer(for: "この体験から学んだことは？"))

        ## まとめ

        今回の体験を振り返ってまとめます。
        """
    }

    private func generateBasicArticle() -> String {
        let questions = draft.questions

        var result = "# \(draft.title)\n\n"

        for question in questions {
            result += "## \(question)\n\n"
            result += "\(answer(for: question))\n\n"
        }

        return result
    }

    private func answer(for question: String) -> String {
        let value = draft.answers[question, default: ""]
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        return value.isEmpty ? "【未入力】" : value
    }
}

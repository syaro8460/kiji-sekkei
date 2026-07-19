import SwiftUI

struct ArticleEditorView: View {
    @Binding var draft: ArticleDraft

    private var questions: [String] {
        draft.questions
    }

    var body: some View {
        Form {
            Section("記事情報") {
                TextField(
                    "記事タイトル",
                    text: titleBinding
                )

                LabeledContent(
                    "テンプレート",
                    value: draft.articleType
                )
                TextField(
                    "タグ（カンマ区切り）",
                    text: tagsBinding
                )
            }

            ForEach(questions, id: \.self) { question in
                Section(question) {
                    TextEditor(
                        text: answerBinding(for: question)
                    )
                    .frame(minHeight: 110)
                }
            }

            Section {
                NavigationLink {
                    ArticlePreviewView(draft: draft)
                } label: {
                    Label(
                        "記事構成を作成",
                        systemImage: "doc.text.magnifyingglass"
                    )
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .navigationTitle("記事の内容")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var titleBinding: Binding<String> {
        Binding(
            get: {
                draft.title
            },
            set: { newValue in
                draft.title = newValue
                updateDate()
            }
        )
    }

    private var tagsBinding: Binding<String> {
        Binding(
            get: {
                draft.tags.joined(separator: ", ")
            },
            set: { newValue in
                draft.tags = newValue
                    .replacingOccurrences(of: "、", with: ",")
                    .split(separator: ",")
                    .map {
                        $0.trimmingCharacters(in: .whitespaces)
                    }
                    .filter {
                        !$0.isEmpty
                    }

                updateDate()
            }
        )
    }

    private func answerBinding(
        for question: String
    ) -> Binding<String> {
        Binding(
            get: {
                draft.answers[question, default: ""]
            },
            set: { newValue in
                draft.answers[question] = newValue
                updateDate()
            }
        )
    }

    private func updateDate() {
        draft.updatedAt = Date()
    }
}

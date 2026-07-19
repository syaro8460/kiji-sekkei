import SwiftUI

struct ArticleEditorView: View {
    @Binding var draft: ArticleDraft
    
    @State private var newTag = ""
    @FocusState private var isTagFieldFocused: Bool

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

                if !draft.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(draft.tags, id: \.self) { tag in
                                TagChipView(
                                    tag: tag,
                                    onDelete: {
                                        draft.tags.removeAll { $0 == tag }
                                        updateDate()

                                        DispatchQueue.main.async {
                                            isTagFieldFocused = false
                                        }
                                    }
                                )
                            }
                        }
                    }
                }

                TextField(
                    "タグを入力",
                    text: $newTag
                )
                .focused($isTagFieldFocused)
                .onSubmit {
                    let tag = newTag.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )

                    guard !tag.isEmpty else {
                        return
                    }

                    guard !draft.tags.contains(tag) else {
                        newTag = ""
                        return
                    }

                    draft.tags.append(tag)
                    newTag = ""
                    updateDate()
                    isTagFieldFocused = true
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
        .onAppear {
            isTagFieldFocused = false
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

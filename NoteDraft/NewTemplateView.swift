import SwiftUI

struct NewTemplateView: View {
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var templateStore: TemplateStore

    @State private var templateName = ""
    @State private var questions = [""]

    private var canSave: Bool {
        let hasName = !templateName
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            .isEmpty

        let hasQuestion = questions.contains { question in
            !question
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                .isEmpty
        }

        return hasName && hasQuestion
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("テンプレート名") {
                    TextField(
                        "例：長期レビュー",
                        text: $templateName
                    )
                }

                Section {
                    ForEach(
                        questions.indices,
                        id: \.self
                    ) { index in
                        HStack {
                            TextField(
                                "質問項目",
                                text: $questions[index],
                                axis: .vertical
                            )

                            if questions.count > 1 {
                                Button {
                                    questions.remove(
                                        at: index
                                    )
                                } label: {
                                    Image(
                                        systemName: "minus.circle.fill"
                                    )
                                    .foregroundStyle(.red)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    Button {
                        questions.append("")
                    } label: {
                        Label(
                            "質問を追加",
                            systemImage: "plus.circle"
                        )
                    }
                } header: {
                    Text("質問項目")
                } footer: {
                    Text(
                        "記事を書くときに回答する質問を自由に追加できます。"
                    )
                }
            }
            .navigationTitle("テンプレート作成")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(
                    placement: .cancellationAction
                ) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }

                ToolbarItem(
                    placement: .confirmationAction
                ) {
                    Button("保存") {
                        saveTemplate()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private func saveTemplate() {
        templateStore.add(
            name: templateName,
            questions: questions
        )

        dismiss()
    }
}

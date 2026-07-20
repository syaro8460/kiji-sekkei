import SwiftUI

struct NewTemplateView: View {
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var templateStore: TemplateStore
    
    let editingTemplate: ArticleTemplate?

    @State private var templateName = ""
    @State private var questions = [
        QuestionItem(text: "")
    ]
    @State private var showingQuestionReorder = false

    private var canSave: Bool {
        let hasName = !templateName
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            .isEmpty

        let hasQuestion = questions.contains { question in
            !question.text
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
                                text: $questions[index].text,
                                axis: .vertical
                            )

                            if questions.count > 1 {
                                Button {
                                    questions.remove(at: index)
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
                        questions.append(
                            QuestionItem(text: "")
                        )
                    } label: {
                        Label(
                            "質問を追加",
                            systemImage: "plus.circle"
                        )
                    }
                } header: {
                    HStack {
                        Text("質問項目")

                        Spacer()

                        Button {
                            showingQuestionReorder = true
                        } label: {
                            Label(
                                "並び替え",
                                systemImage: "arrow.up.arrow.down"
                            )
                        }
                        .font(.footnote)
                        .labelStyle(.titleAndIcon)
                        .textCase(nil)
                    }
                } footer: {
                    Text(
                        "記事を書くときに回答する質問を自由に追加できます。"
                    )
                }
            }
            .sheet(isPresented: $showingQuestionReorder) {
                QuestionReorderView(
                    questions: $questions
                )
            }
            .navigationTitle(
                editingTemplate == nil
                ? "テンプレート作成"
                : "テンプレート編集"
            )
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
                    Button(
                        editingTemplate == nil
                        ? "保存"
                        : "更新"
                    ) {
                        saveTemplate()
                    }
                    .disabled(!canSave)
                }
            }
        }
        .onAppear {
            guard let editingTemplate else {
                return
            }

            templateName = editingTemplate.name
            questions = editingTemplate.questions.map {
                QuestionItem(text: $0)
            }
        }
    }

    private func saveTemplate() {
        if let editingTemplate {
            templateStore.update(
                id: editingTemplate.id,
                name: templateName,
                questions: questions.map(\.text)
            )
        } else {
            templateStore.add(
                name: templateName,
                questions: questions.map(\.text)
            )
        }

        dismiss()
    }
}

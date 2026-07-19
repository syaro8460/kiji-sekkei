import SwiftUI

struct NewDraftView: View {
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var store: DraftStore
    @ObservedObject var templateStore: TemplateStore

    @Binding var newlyCreatedDraftID: UUID?

    @State private var title = ""
    @State private var selectedTemplateID: UUID?

    private var selectedTemplate: ArticleTemplate? {
        guard let selectedTemplateID else {
            return templateStore.allTemplates.first
        }

        return templateStore.template(
            id: selectedTemplateID
        )
    }

    private var canCreate: Bool {
        !title
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            .isEmpty
            && selectedTemplate != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("記事タイトル") {
                    TextField(
                        "タイトルを入力",
                        text: $title
                    )
                }

                Section("テンプレート") {
                    Picker(
                        "テンプレート",
                        selection: $selectedTemplateID
                    ) {
                        ForEach(
                            templateStore.allTemplates
                        ) { template in
                            Label(
                                template.name,
                                systemImage: template.iconName
                            )
                            .tag(
                                Optional(template.id)
                            )
                        }
                    }
                }

                if let selectedTemplate {
                    Section("質問内容") {
                        ForEach(
                            selectedTemplate.questions,
                            id: \.self
                        ) { question in
                            Label(
                                question,
                                systemImage: "questionmark.circle"
                            )
                        }
                    }
                }
            }
            .navigationTitle("新しい記事")
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
                    Button("作成") {
                        createDraft()
                    }
                    .disabled(!canCreate)
                }
            }
            .onAppear {
                if selectedTemplateID == nil {
                    selectedTemplateID =
                        templateStore
                            .allTemplates
                            .first?
                            .id
                }
            }
        }
    }

    private func createDraft() {
        guard let selectedTemplate else {
            return
        }

        let draft = ArticleDraft(
            title: title.trimmingCharacters(
                in: .whitespacesAndNewlines
            ),
            articleType: selectedTemplate.name,
            questions: selectedTemplate.questions
        )

        store.add(draft)
        newlyCreatedDraftID = draft.id

        dismiss()
    }
}

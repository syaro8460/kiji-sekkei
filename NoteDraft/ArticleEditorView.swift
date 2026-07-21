import SwiftUI
import UniformTypeIdentifiers

struct ArticleEditorView: View {
    @Binding var draft: ArticleDraft
    let templateStore: TemplateStore
    
    @State private var newTag = ""
    @State private var isExportingMarkdown = false
    @State private var markdownDocument = MarkdownDocument()
    @State private var showExportSuccessAlert = false
    @State private var showExportErrorAlert = false
    @State private var exportErrorMessage = ""
    
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

                NavigationLink {
                    TemplateSelectionView(
                        onSelect: { template, mode in
                            let newQuestions = templateStore.allTemplates
                                .first { $0.name == template }?
                                .questions ?? []

                            switch mode {
                            case .reset:
                                draft.articleType = template
                                draft.questions = newQuestions
                                draft.answers = [:]

                            case .keepCommonAnswers:
                                var newAnswers: [String: String] = [:]

                                for question in newQuestions {
                                    if let answer = draft.answers[question] {
                                        newAnswers[question] = answer
                                    }
                                }

                                draft.articleType = template
                                draft.questions = newQuestions
                                draft.answers = newAnswers
                            }

                            updateDate()
                        },
                        templateStore: templateStore
                    )
                } label: {
                    LabeledContent(
                        "テンプレート",
                        value: draft.articleType
                    )
                }
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

            Section("質問と回答") {
                ForEach(questions, id: \.self) { question in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(question)
                            .font(.headline)

                        TextField(
                            "回答を入力",
                            text: answerBinding(for: question),
                            axis: .vertical
                        )
                        .lineLimit(3...8)
                    }
                    .padding(.vertical, 4)
                }
            }

            Section("書き出し") {

                NavigationLink {
                    ArticlePreviewView(draft: draft)
                } label: {
                    Label(
                        "記事構成を作成",
                        systemImage: "doc.text.magnifyingglass"
                    )
                }

                Button {

                    let markdown = MarkdownExporter().export(draft)
                    
                    markdownDocument = MarkdownDocument(
                        text: markdown
                    )

                    isExportingMarkdown = true

                } label: {
                    Label(
                        "記事を書き出す",
                        systemImage: "square.and.arrow.down"
                    )
                }
            }
        }
        .onAppear {
            isTagFieldFocused = false
        }
        .navigationTitle("記事の内容")
        .navigationBarTitleDisplayMode(.inline)
        
        .fileExporter(
            isPresented: $isExportingMarkdown,
            document: markdownDocument,
            contentType: UTType(filenameExtension: "md") ?? .plainText,
            defaultFilename: exportFileName
        ) { result in

            switch result {

            case .success:
                showExportSuccessAlert = true

            case .failure(let error):
                exportErrorMessage = error.localizedDescription
                showExportErrorAlert = true
            }
        }
        
        .alert(
            "書き出し完了",
            isPresented: $showExportSuccessAlert
        ) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("記事を書き出しました。")
        }

        .alert(
            "書き出しに失敗しました",
            isPresented: $showExportErrorAlert
        ) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(exportErrorMessage)
        }
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

    private var exportFileName: String {
        let title = draft.title
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return title.isEmpty ? "Article" : title
    }
    
    private func updateDate() {
        draft.updatedAt = Date()
    }
}

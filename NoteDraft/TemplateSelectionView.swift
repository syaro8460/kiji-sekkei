import SwiftUI

enum TemplateChangeMode {
    case reset
    case keepCommonAnswers
}

struct TemplateSelectionView: View {
    @Environment(\.dismiss) private var dismiss

    let onSelect: (String, TemplateChangeMode) -> Void

    @State private var selectedTemplate: String?
    @State private var isShowingChangeAlert = false

    let templateStore: TemplateStore

    var body: some View {
        List(templateStore.allTemplates) { template in
            Button {
                selectedTemplate = template.name
                isShowingChangeAlert = true
            } label: {
                Text(template.name)
            }
        }
        .navigationTitle("テンプレートを選択")
        .navigationBarTitleDisplayMode(.inline)
        .alert(
            "テンプレートを変更しますか？",
            isPresented: $isShowingChangeAlert
        ) {
            Button(
                "質問と回答をリセット",
                role: .destructive
            ) {
                applyTemplateChange(mode: .reset)
            }

            Button("共通する質問・回答を引き継ぐ") {
                applyTemplateChange(mode: .keepCommonAnswers)
            }

            Button("キャンセル", role: .cancel) {
                selectedTemplate = nil
            }
        } message: {
            Text("変更後の質問と回答の扱いを選んでください。")
        }
    }

    private func applyTemplateChange(
        mode: TemplateChangeMode
    ) {
        guard let selectedTemplate else {
            return
        }

        onSelect(selectedTemplate, mode)
        dismiss()
    }
}

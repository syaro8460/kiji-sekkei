import SwiftUI

struct TemplateListView: View {
    @ObservedObject var templateStore: TemplateStore

    @State private var showingNewTemplate = false
    @State private var pendingDeleteTemplateID: UUID?

    var body: some View {
        List {
            Section("標準テンプレート") {
                ForEach(
                    ArticleTemplate.builtInTemplates
                ) { template in
                    templateRow(template)
                }
            }

            Section("自作テンプレート") {
                if templateStore.customTemplates.isEmpty {
                    ContentUnavailableView(
                        "自作テンプレートはありません",
                        systemImage: "doc.badge.plus",
                        description: Text(
                            "右上の＋からテンプレートを作成できます。"
                        )
                    )
                } else {
                    ForEach(
                        templateStore.customTemplates
                    ) { template in
                        templateRow(template)
                            .swipeActions(
                                edge: .trailing,
                                allowsFullSwipe: false
                            ) {
                                Button(
                                    "削除",
                                    role: .destructive
                                ) {
                                    pendingDeleteTemplateID =
                                        template.id
                                }
                            }
                    }
                }
            }
        }
        .navigationTitle("テンプレート")
        .toolbar {
            ToolbarItem(
                placement: .topBarTrailing
            ) {
                Button {
                    showingNewTemplate = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(
            isPresented: $showingNewTemplate
        ) {
            NewTemplateView(
                templateStore: templateStore
            )
        }
        .alert(
            "テンプレートを削除しますか？",
            isPresented: deleteAlertBinding
        ) {
            Button(
                "削除",
                role: .destructive
            ) {
                confirmDelete()
            }

            Button(
                "キャンセル",
                role: .cancel
            ) {
                pendingDeleteTemplateID = nil
            }
        } message: {
            Text(
                "このテンプレートから作成済みの記事は削除されません。"
            )
        }
    }

    private func templateRow(
        _ template: ArticleTemplate
    ) -> some View {
        HStack(spacing: 12) {
            Image(
                systemName: template.iconName
            )
            .frame(width: 28)
            .foregroundStyle(.tint)

            VStack(
                alignment: .leading,
                spacing: 4
            ) {
                Text(template.name)

                Text(
                    "\(template.questions.count)個の質問"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }

    private var deleteAlertBinding: Binding<Bool> {
        Binding(
            get: {
                pendingDeleteTemplateID != nil
            },
            set: { isPresented in
                if !isPresented {
                    pendingDeleteTemplateID = nil
                }
            }
        )
    }

    private func confirmDelete() {
        guard let templateID =
                pendingDeleteTemplateID
        else {
            return
        }

        templateStore.delete(
            id: templateID
        )

        pendingDeleteTemplateID = nil
    }
}

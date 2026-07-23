import SwiftUI

struct TemplateListView: View {
    @ObservedObject var templateStore: TemplateStore

    @State private var showingNewTemplate = false
    @State private var pendingDeleteTemplateID: UUID?
    @State private var editingTemplate: ArticleTemplate?
    @State private var showingReorder = false

    var body: some View {
        List {
            Section("標準テンプレート") {
                ForEach(
                    ArticleTemplate.builtInTemplates
                ) { template in
                    templateRow(template)
                }
            }

            Section {
                if templateStore.customTemplates.isEmpty {
                    ContentUnavailableView(
                        "自作テンプレートはありません",
                        systemImage: "doc.badge.plus",
                        description: Text(
                            "右上の＋からテンプレートを作成できます。"
                        )
                    )
                } else {
                    ForEach(templateStore.customTemplates) { template in
                        Button {
                            editingTemplate = template
                        } label: {
                            templateRow(template)
                                .frame(
                                    maxWidth: .infinity,
                                    alignment: .leading
                                )
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .swipeActions(
                            edge: .trailing,
                            allowsFullSwipe: false
                        ) {
                            Button(
                                "削除",
                                role: .destructive
                            ) {
                                pendingDeleteTemplateID = template.id
                            }
                        }
                        .swipeActions(
                            edge: .leading,
                            allowsFullSwipe: true
                        ) {
                            Button {
                                templateStore.duplicate(id: template.id)
                            } label: {
                                Label(
                                    "複製",
                                    systemImage: "doc.on.doc"
                                )
                            }
                            .tint(.blue)
                        }
                    }
                }
            } header: {
                HStack {
                    Text("自作テンプレート")

                    Spacer()

                    Button {
                        showingReorder = true
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
        .sheet(isPresented: $showingNewTemplate) {
            NewTemplateView(
                templateStore: templateStore,
                editingTemplate: nil
            )
        }
        .sheet(isPresented: $showingReorder) {
            TemplateReorderView(
                templateStore: templateStore
            )
        }
        .sheet(item: $editingTemplate) { template in
            NewTemplateView(
                templateStore: templateStore,
                editingTemplate: template
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

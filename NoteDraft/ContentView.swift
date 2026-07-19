import SwiftUI

struct ContentView: View {
    @StateObject private var store = DraftStore()
    @StateObject private var templateStore = TemplateStore()
    
    @State private var navigationPath: [UUID] = []
    @State private var showingNewDraft = false
    @State private var newlyCreatedDraftID: UUID?
    @State private var pendingDeleteDraftID: UUID?
    @State private var searchText = ""
    
    private var filteredDrafts: [ArticleDraft] {
        let sortedDrafts = store.drafts.sorted {
            $0.updatedAt > $1.updatedAt
        }

        guard !searchText.isEmpty else {
            return sortedDrafts
        }

        return sortedDrafts.filter {
            $0.title.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if store.drafts.isEmpty {
                    emptyView
                } else {
                    draftList
                }
            }
            .navigationTitle("記事設計")
            .searchable(
                text: $searchText,
                prompt: "検索"
            )
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        TemplateListView(
                            templateStore: templateStore
                        )
                    } label: {
                        Image(
                            systemName: "square.grid.2x2"
                        )
                    }
                    .accessibilityLabel("テンプレートを管理")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingNewDraft = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("新しい記事を作成")
                }
            }
            .navigationDestination(for: UUID.self) { draftID in
                editorDestination(for: draftID)
            }
            .sheet(
                isPresented: $showingNewDraft
            ) {
                NewDraftView(
                    store: store,
                    templateStore: templateStore,
                    newlyCreatedDraftID: $newlyCreatedDraftID
                )
            }
            .onChange(of: showingNewDraft) { _, isShowing in
                openNewDraftWhenSheetCloses(
                    isShowing: isShowing
                )
            }
            .alert(
                "記事を削除しますか？",
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
                    pendingDeleteDraftID = nil
                }
            } message: {
                Text("削除した記事は元に戻せません。")
            }
        }
    }
    
    private var emptyView: some View {
        ContentUnavailableView {
            Label(
                "記事がありません",
                systemImage: "doc.text"
            )
        } description: {
            Text("右上の＋から新しい記事を作成できます。")
        } actions: {
            Button("新しい記事を作成") {
                showingNewDraft = true
            }
            .buttonStyle(.borderedProminent)
        }
    }
    
    private var draftList: some View {
        Group {
            if filteredDrafts.isEmpty {
                ContentUnavailableView {
                    Label(
                        "検索結果がありません",
                        systemImage: "magnifyingglass"
                    )
                } description: {
                    Text("別のキーワードで検索してみてください。")
                }
            } else {
                List {
                    ForEach(filteredDrafts) { draft in
                        NavigationLink(value: draft.id) {
                            DraftRowView(draft: draft)
                        }
                        .swipeActions(
                            edge: .trailing,
                            allowsFullSwipe: false
                        ) {
                            Button(
                                "削除",
                                role: .destructive
                            ) {
                                pendingDeleteDraftID = draft.id
                            }
                        }
                        .swipeActions(
                            edge: .leading,
                            allowsFullSwipe: true
                        ) {
                            Button {
                                duplicateAndOpen(draft.id)
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
            }
        }
    }
    
    @ViewBuilder
    private func editorDestination(
        for draftID: UUID
    ) -> some View {
        if let index = store.drafts.firstIndex(
            where: { $0.id == draftID }
        ) {
            ArticleEditorView(
                draft: $store.drafts[index]
            )
        } else {
            ContentUnavailableView(
                "記事が見つかりません",
                systemImage: "exclamationmark.triangle"
            )
        }
    }
    
    private func draftForID(
        _ draftID: UUID
    ) -> ArticleDraft? {
        store.drafts.first { draft in
            draft.id == draftID
        }
    }
    
    private func openNewDraftWhenSheetCloses(
        isShowing: Bool
    ) {
        guard
            !isShowing,
            let draftID = newlyCreatedDraftID
        else {
            return
        }
        
        newlyCreatedDraftID = nil
        navigationPath.append(draftID)
    }
    
    private func duplicateAndOpen(
        _ draftID: UUID
    ) {
        guard let duplicatedDraft = store.duplicate(
            id: draftID
        ) else {
            return
        }

        navigationPath.append(duplicatedDraft.id)
    }

    private var deleteAlertBinding: Binding<Bool> {
        Binding(
            get: {
                pendingDeleteDraftID != nil
            },
            set: { isPresented in
                if !isPresented {
                    pendingDeleteDraftID = nil
                }
            }
        )
    }

    private func confirmDelete() {
        guard let draftID = pendingDeleteDraftID else {
            return
        }

        store.delete(id: draftID)
        pendingDeleteDraftID = nil
    }
}

#Preview {
    ContentView()
}

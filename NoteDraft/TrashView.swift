import SwiftUI

struct TrashView: View {
    @ObservedObject var store: DraftStore
    
    @State private var pendingDeleteID: UUID?
    @State private var showingDeleteConfirmation = false

    var body: some View {
        Group {
            if store.trashedDrafts.isEmpty {
                ContentUnavailableView {
                    Label(
                        "ゴミ箱は空です",
                        systemImage: "trash"
                    )
                } description: {
                    Text("削除した記事がここに表示されます。")
                }
            } else {
                List {
                    ForEach(store.trashedDrafts) { draft in
                        DraftRowView(
                            draft: draft,
                            showsTrashRemainingDays: true,
                            onTagTap: { _ in }
                        )
                        .swipeActions(
                            edge: .leading,
                            allowsFullSwipe: true
                        ) {
                            Button {
                                store.restore(id: draft.id)
                            } label: {
                                Label(
                                    "復元",
                                    systemImage: "arrow.uturn.backward"
                                )
                            }
                            .tint(.green)
                        }
                        .swipeActions(
                            edge: .trailing,
                            allowsFullSwipe: false
                        ) {
                            Button(role: .destructive) {
                                pendingDeleteID = draft.id
                                showingDeleteConfirmation = true
                            } label: {
                                Label(
                                    "完全削除",
                                    systemImage: "trash.slash"
                                )
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("ゴミ箱")
        
        .alert(
            "記事を完全に削除しますか？",
            isPresented: $showingDeleteConfirmation
        ) {
            Button(
                "キャンセル",
                role: .cancel
            ) {
                pendingDeleteID = nil
            }

            Button(
                "完全削除",
                role: .destructive
            ) {
                guard let id = pendingDeleteID else {
                    return
                }

                store.deletePermanently(id: id)
                pendingDeleteID = nil
            }
        } message: {
            Text("この操作は取り消せません。")
        }
    }
}

#Preview {
    TrashView(
        store: DraftStore()
    )
}

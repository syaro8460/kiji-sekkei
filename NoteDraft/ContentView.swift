import SwiftUI

struct ContentView: View {
    @StateObject private var store = DraftStore()
    @StateObject private var templateStore = TemplateStore()
    
    @State private var navigationPath: [UUID] = []
    @State private var showingNewDraft = false
    @State private var newlyCreatedDraftID: UUID?
    @State private var searchText = ""
    @State private var isSearchPresented = false
    @AppStorage("draftSortOrder")
    private var sortOrder: DraftSortOrder = .updatedNewest
    
    private var filteredDrafts: [ArticleDraft] {
        let sortedDrafts: [ArticleDraft]

        switch sortOrder {
        case .updatedNewest:
            sortedDrafts = store.activeDrafts.sorted {
                $0.updatedAt > $1.updatedAt
            }

        case .updatedOldest:
            sortedDrafts = store.activeDrafts.sorted {
                $0.updatedAt < $1.updatedAt
            }

        case .titleAscending:
            sortedDrafts = store.activeDrafts.sorted {
                $0.title.localizedCompare($1.title)
                    == .orderedAscending
            }

        case .titleDescending:
            sortedDrafts = store.activeDrafts.sorted {
                $0.title.localizedCompare($1.title)
                    == .orderedDescending
            }
        }

        guard !searchText.isEmpty else {
            return sortedDrafts
        }

        return sortedDrafts.filter { draft in
            var targets: [String] = []

            targets.append(draft.title)
            targets.append(draft.articleType)
            targets.append(contentsOf: draft.questions)
            targets.append(contentsOf: draft.answers.values)
            targets.append(contentsOf: draft.tags)

            return targets.contains { target in
                isFuzzyMatch(
                    searchText,
                    target: target
                )
            }
        }
    }

    private func isFuzzyMatch(
        _ query: String,
        target: String
    ) -> Bool {
        let normalizedQuery = normalize(query)
        let normalizedTarget = normalize(target)

        guard !normalizedQuery.isEmpty else {
            return true
        }

        let keywords = normalizedQuery.split {
            $0.isWhitespace
        }.map(String.init)

        return keywords.allSatisfy { keyword in
            // 通常の部分一致
            if normalizedTarget.contains(keyword) {
                return true
            }

            let allowedDistance = max(
                1,
                keyword.count / 3
            )

            return containsFuzzySubstring(
                keyword,
                in: normalizedTarget,
                allowedDistance: allowedDistance
            )
        }
    }

    private func containsFuzzySubstring(
        _ keyword: String,
        in target: String,
        allowedDistance: Int
    ) -> Bool {
        let keywordCharacters = Array(keyword)
        let targetCharacters = Array(target)

        guard !keywordCharacters.isEmpty else {
            return true
        }

        guard !targetCharacters.isEmpty else {
            return false
        }

        let keywordLength = keywordCharacters.count

        let minimumWindowLength = max(
            1,
            keywordLength - allowedDistance
        )

        let maximumWindowLength = min(
            targetCharacters.count,
            keywordLength + allowedDistance
        )

        guard minimumWindowLength <= maximumWindowLength else {
            return false
        }

        for windowLength in minimumWindowLength...maximumWindowLength {
            guard targetCharacters.count >= windowLength else {
                continue
            }

            let lastStartIndex =
                targetCharacters.count - windowLength

            for startIndex in 0...lastStartIndex {
                let endIndex = startIndex + windowLength

                let candidate = String(
                    targetCharacters[startIndex..<endIndex]
                )

                if levenshteinDistance(
                    keyword,
                    candidate
                ) <= allowedDistance {
                    return true
                }
            }
        }

        return false
    }

    private func normalize(
        _ text: String
    ) -> String {
        let foldedText = text.folding(
            options: [
                .caseInsensitive,
                .diacriticInsensitive,
                .widthInsensitive
            ],
            locale: .current
        )

        return foldedText.applyingTransform(
            .hiraganaToKatakana,
            reverse: false
        ) ?? foldedText
    }
    
    private func levenshteinDistance(
        _ lhs: String,
        _ rhs: String
    ) -> Int {
        let lhsCharacters = Array(lhs)
        let rhsCharacters = Array(rhs)

        if lhsCharacters.isEmpty {
            return rhsCharacters.count
        }

        if rhsCharacters.isEmpty {
            return lhsCharacters.count
        }

        var previousRow = Array(
            0...rhsCharacters.count
        )

        for (
            lhsIndex,
            lhsCharacter
        ) in lhsCharacters.enumerated() {
            var currentRow = [
                lhsIndex + 1
            ]

            for (
                rhsIndex,
                rhsCharacter
            ) in rhsCharacters.enumerated() {
                let insertion = currentRow[
                    rhsIndex
                ] + 1

                let deletion = previousRow[
                    rhsIndex + 1
                ] + 1

                let substitution = previousRow[
                    rhsIndex
                ] + (
                    lhsCharacter == rhsCharacter
                    ? 0
                    : 1
                )

                currentRow.append(
                    min(
                        insertion,
                        deletion,
                        substitution
                    )
                )
            }

            previousRow = currentRow
        }

        return previousRow[
            rhsCharacters.count
        ]
    }
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if store.activeDrafts.isEmpty {
                    emptyView
                } else {
                    draftList
                }
            }
            .navigationTitle("記事一覧")
            .searchable(
                text: $searchText,
                isPresented: $isSearchPresented,
                prompt: "検索"
            )
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        NavigationLink {
                            TemplateListView(
                                templateStore: templateStore
                            )
                        } label: {
                            Label(
                                "テンプレート",
                                systemImage: "square.grid.2x2"
                            )
                        }

                        NavigationLink {
                            TrashView(
                                store: store
                            )
                        } label: {
                            Label(
                                "ゴミ箱",
                                systemImage: "trash"
                            )
                        }

                        Divider()

                        NavigationLink {
                            SettingsView(
                                store: store,
                                templateStore: templateStore
                            )
                        } label: {
                            Label(
                                "設定",
                                systemImage: "gearshape"
                            )
                        }

                    } label: {
                        Image(systemName: "line.3.horizontal")
                    }
                    .accessibilityLabel("メニュー")
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
                    Section {
                        ForEach(filteredDrafts) { draft in
                            NavigationLink(value: draft.id) {
                                DraftRowView(
                                    draft: draft,
                                    onTagTap: { tag in
                                        // FIXME:
                                        // タグタップで searchText を更新した場合、
                                        // .searchable のクリアボタン押下時に
                                        // キーボードが表示される。
                                        // dismissSearch() / isPresented では改善せず。
                                        // SwiftUI の挙動と思われるため現状は保留。
                                        searchText = tag
                                        isSearchPresented = false
                                    }
                                )
                            }
                            .swipeActions(
                                edge: .trailing,
                                allowsFullSwipe: false
                            ) {
                                Button(
                                    "削除",
                                    role: .destructive
                                ) {
                                    store.moveToTrash(id: draft.id)
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
                    } header: {
                        Text(
                            searchText.isEmpty
                            ? "記事数：\(filteredDrafts.count)件"
                            : "検索結果：\(filteredDrafts.count)件"
                        )
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
                draft: $store.drafts[index],
                templateStore: templateStore
            )
        } else {
            ContentUnavailableView(
                "記事が見つかりません",
                systemImage: "exclamationmark.triangle"
            )
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
}

#Preview {
    ContentView()
}

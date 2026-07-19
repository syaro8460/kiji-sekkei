import Foundation
import Combine

final class DraftStore: ObservableObject {
    @Published var drafts: [ArticleDraft] = [] {
        didSet {
            save()
        }
    }

    private let storageKey = "articleDrafts"

    init() {
        load()
    }

    var sortedDraftIDs: [UUID] {
        drafts
            .sorted { $0.updatedAt > $1.updatedAt }
            .map(\.id)
    }

    func add(_ draft: ArticleDraft) {
        drafts.append(draft)
    }

    func delete(id: UUID) {
        drafts.removeAll { draft in
            draft.id == id
        }
    }

    func duplicate(id: UUID) -> ArticleDraft? {
        guard let originalDraft = drafts.first(
            where: { $0.id == id }
        ) else {
            return nil
        }

        let duplicatedDraft = ArticleDraft(
            id: UUID(),
            title: "\(originalDraft.title)（コピー）",
            articleType: originalDraft.articleType,
            questions: originalDraft.questions,
            answers: originalDraft.answers,
            updatedAt: Date()
        )

        drafts.append(duplicatedDraft)

        return duplicatedDraft
    }
    
    private func save() {
        guard let data = try? JSONEncoder().encode(drafts) else {
            return
        }

        UserDefaults.standard.set(
            data,
            forKey: storageKey
        )
    }

    private func load() {
        guard
            let data = UserDefaults.standard.data(
                forKey: storageKey
            ),
            let savedDrafts = try? JSONDecoder().decode(
                [ArticleDraft].self,
                from: data
            )
        else {
            return
        }

        drafts = savedDrafts
    }
}

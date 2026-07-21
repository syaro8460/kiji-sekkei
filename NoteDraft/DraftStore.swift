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

    var activeDrafts: [ArticleDraft] {
        drafts.filter {
            $0.status == .active
        }
    }

    var trashedDrafts: [ArticleDraft] {
        drafts
            .filter {
                $0.status == .trashed
            }
            .sorted {
                ($0.deletedAt ?? .distantPast) >
                ($1.deletedAt ?? .distantPast)
            }
    }

    var sortedDraftIDs: [UUID] {
        activeDrafts
            .sorted {
                $0.updatedAt > $1.updatedAt
            }
            .map(\.id)
    }

    var trashedDraftIDs: [UUID] {
        trashedDrafts
            .sorted {
                ($0.deletedAt ?? .distantPast) >
                ($1.deletedAt ?? .distantPast)
            }
            .map(\.id)
    }

    func add(_ draft: ArticleDraft) {
        drafts.append(draft)
    }

    func moveToTrash(id: UUID) {
        guard let index = drafts.firstIndex(
            where: { $0.id == id }
        ) else {
            return
        }
        drafts[index].status = .trashed
        drafts[index].deletedAt = Date()
    }

    func restore(id: UUID) {
        guard let index = drafts.firstIndex(
            where: { $0.id == id }
        ) else {
            return
        }

        drafts[index].status = .active
        drafts[index].deletedAt = nil
        drafts[index].updatedAt = Date()
    }

    func deletePermanently(id: UUID) {
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
    
    func createBackupData(
        templateStore: TemplateStore
    ) -> BackupData {
        BackupData(
            schemaVersion: 1,
            exportedAt: Date(),
            drafts: drafts,
            templates: templateStore.customTemplates
        )
    }
    
    func restore(from backupData: BackupData) {
        drafts = backupData.drafts
        save()
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

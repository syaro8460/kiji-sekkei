import Foundation
import Combine
import SwiftData

final class DraftStore: ObservableObject {
    @Published var drafts: [ArticleDraft] = [] {
        didSet {
            guard !isLoadingFromSwiftData else {
                return
            }

            if isUsingSwiftData {
                do {
                    try saveToSwiftData()
                    lastSavedDrafts = drafts
                    swiftDataSaveError = nil
                } catch {
                    swiftDataSaveError = error.localizedDescription
                    print("SwiftDataの記事保存に失敗: \(error)")
                }
            } else {
                save()
            }
        }
    }

    private let storageKey = "articleDrafts"
    private var modelContainer: ModelContainer?
    private var isUsingSwiftData = false
    private var isLoadingFromSwiftData = false
    @Published private(set) var swiftDataSaveError: String?
    private var lastSavedDrafts: [ArticleDraft] = []
    
    var hasUnsavedSwiftDataChanges: Bool {
        guard isUsingSwiftData else {
            return false
        }

        return drafts != lastSavedDrafts
    }

    func configureSwiftData(
        container: ModelContainer
    ) {
        self.modelContainer = container
    }
    
    func clearSwiftDataSaveError() {
        swiftDataSaveError = nil
    }
    
    func retrySwiftDataSave() {
        guard isUsingSwiftData else {
            return
        }

        do {
            try saveToSwiftData()
            lastSavedDrafts = drafts
            swiftDataSaveError = nil
        } catch {
            swiftDataSaveError = error.localizedDescription
            print("SwiftDataの再保存に失敗: \(error)")
        }
    }

    private func convertToArticleDraft(
        _ stored: StoredArticle
    ) throws -> ArticleDraft {
        let answers = try JSONDecoder().decode(
            [String: String].self,
            from: stored.answersData
        )

        guard let status = ArticleDraft.DraftStatus(
            rawValue: stored.status
        ) else {
            throw SwiftDataConversionError.invalidStatus
        }

        var draft = ArticleDraft(
            id: stored.id,
            title: stored.title,
            articleType: stored.articleType,
            questions: stored.questions,
            answers: answers,
            tags: stored.tags,
            updatedAt: stored.updatedAt
        )

        draft.status = status
        draft.deletedAt = stored.deletedAt

        return draft
    }

    private func convertToStoredArticle(
        _ draft: ArticleDraft
    ) throws -> StoredArticle {
        let answersData = try JSONEncoder().encode(
            draft.answers
        )

        return StoredArticle(
            id: draft.id,
            title: draft.title,
            articleType: draft.articleType,
            questions: draft.questions,
            answersData: answersData,
            tags: draft.tags,
            updatedAt: draft.updatedAt,
            status: draft.status.rawValue,
            deletedAt: draft.deletedAt
        )
    }

    private func saveToSwiftData() throws {
        guard let modelContainer else {
            throw SwiftDataConversionError.missingModelContainer
        }

        let context = ModelContext(modelContainer)
        context.autosaveEnabled = false

        let storedArticles = try context.fetch(
            FetchDescriptor<StoredArticle>()
        )

        let storedByID = Dictionary(
            uniqueKeysWithValues: storedArticles.map {
                ($0.id, $0)
            }
        )

        do {
            for draft in drafts {
                if let stored = storedByID[draft.id] {
                    stored.title = draft.title
                    stored.articleType = draft.articleType
                    stored.questions = draft.questions
                    stored.answersData = try JSONEncoder().encode(
                        draft.answers
                    )
                    stored.tags = draft.tags
                    stored.updatedAt = draft.updatedAt
                    stored.status = draft.status.rawValue
                    stored.deletedAt = draft.deletedAt
                } else {
                    context.insert(
                        try convertToStoredArticle(draft)
                    )
                }
            }

            let draftIDs = Set(drafts.map(\.id))

            for stored in storedArticles {
                if !draftIDs.contains(stored.id) {
                    context.delete(stored)
                }
            }

            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    private func loadFromSwiftData() throws -> [ArticleDraft] {
        guard let modelContainer else {
            return []
        }

        let context = ModelContext(modelContainer)

        let storedArticles = try context.fetch(
            FetchDescriptor<StoredArticle>()
        )

        return try storedArticles.map {
            try convertToArticleDraft($0)
        }
    }

    private func refreshFromSwiftData() throws {
        guard modelContainer != nil else {
            return
        }

        let loadedDrafts = try loadFromSwiftData()

        isLoadingFromSwiftData = true
        defer {
            isLoadingFromSwiftData = false
        }

        drafts = loadedDrafts
        lastSavedDrafts = loadedDrafts
        
        var hasUnsavedSwiftDataChanges: Bool {
            guard isUsingSwiftData else {
                return false
            }

            return drafts != lastSavedDrafts
        }

    }

    init() {
        load()
        removeExpiredTrash()
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

    func removeExpiredTrash() {
        let expirationDate = Calendar.current.date(
            byAdding: .day,
            value: -30,
            to: Date()
        ) ?? Date()

        drafts.removeAll { draft in
            guard
                draft.status == .trashed,
                let deletedAt = draft.deletedAt
            else {
                return false
            }

            return deletedAt < expirationDate
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

    private enum SwiftDataConversionError: Error {
        case invalidStatus
        case missingModelContainer
    }
}

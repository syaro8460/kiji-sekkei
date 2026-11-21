import Foundation
import SwiftData

enum DataMigrationManager {

    private static let migrationCompletedKey =
        "swiftDataArticleMigrationCompleted_v1"

    static func migrateArticles(
        drafts: [ArticleDraft],
        context: ModelContext
    ) throws {

        var migratedCount = 0
        
        do {

            for draft in drafts {

                let descriptor = FetchDescriptor<StoredArticle>(
                    predicate: #Predicate<StoredArticle> {
                        $0.id == draft.id
                    }
                )

                if let existingArticle = try context.fetch(descriptor).first {
                    guard try articleMatches(draft, existingArticle) else {
                        throw MigrationError.articleMismatch
                    }

                    continue
                }

                let storedArticle = try convertArticle(draft)

                guard try articleMatches(draft, storedArticle) else {
                    throw MigrationError.articleMismatch
                }

                context.insert(storedArticle)
                migratedCount += 1

            }

            try context.save()

        } catch {
            context.rollback()
            throw error
        }

        print("SwiftDataへの記事コピー件数: \(migratedCount)")
        print("記事の存在確認が完了しました")

    }
    
    private static func convertArticle(
        _ draft: ArticleDraft
    ) throws -> StoredArticle {

        let answersData = try JSONEncoder().encode(draft.answers)

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
    
    private static func articleMatches(
        _ draft: ArticleDraft,
        _ stored: StoredArticle
    ) throws -> Bool {

        let answers = try JSONDecoder().decode(
            [String: String].self,
            from: stored.answersData
        )

        return draft.id == stored.id
            && draft.title == stored.title
            && draft.articleType == stored.articleType
            && draft.questions == stored.questions
            && draft.answers == answers
            && draft.tags == stored.tags
            && draft.updatedAt == stored.updatedAt
            && draft.status.rawValue == stored.status
            && draft.deletedAt == stored.deletedAt
    }
    
    static func runMigration(
        container: ModelContainer
    ) throws {

        let migrationCompleted = UserDefaults.standard.bool(
            forKey: migrationCompletedKey
        )
        
        guard let sourceData = UserDefaults.standard.data(
            forKey: "articleDrafts"
        ) else {
            print("記事データがないため、移行を保留します")
            return
        }

        let sourceDrafts = try JSONDecoder().decode(
            [ArticleDraft].self,
            from: sourceData
        )

        if migrationCompleted {
            try verifySavedArticles(
                drafts: sourceDrafts,
                container: container
            )

            print("移行済みの記事データを確認しました")
            return
        }

        let migrationContext = ModelContext(container)
        migrationContext.autosaveEnabled = false

        try migrateArticles(
            drafts: sourceDrafts,
            context: migrationContext
        )

        try verifySavedArticles(
            drafts: sourceDrafts,
            container: container
        )
        
        guard UserDefaults.standard.data(
            forKey: "articleDrafts"
        ) == sourceData else {
            throw MigrationError.sourceDataChanged
        }
        
        UserDefaults.standard.set(
            true,
            forKey: migrationCompletedKey
        )

        print("記事のSwiftData移行完了フラグを保存しました")
    }

    private static func verifySavedArticles(
        drafts: [ArticleDraft],
        container: ModelContainer
    ) throws {
        let verificationContext = ModelContext(container)

        let storedArticles = try verificationContext.fetch(
            FetchDescriptor<StoredArticle>()
        )

        let storedByID = Dictionary(
            uniqueKeysWithValues: storedArticles.map {
                ($0.id, $0)
            }
        )

        for draft in drafts {
            guard let stored = storedByID[draft.id] else {
                throw MigrationError.missingArticles
            }

            guard try articleMatches(draft, stored) else {
                throw MigrationError.articleMismatch
            }
        }

        print("保存後の記事データ検証が完了しました")
    }

    enum MigrationError: Error {
        case missingArticles
        case articleMismatch
        case missingSourceData
        case duplicateArticleIDs
        case sourceDataChanged
    }
}

import Foundation
import SwiftData

// Keep the entity name, field types, and constraints identical to the shipped model.
@available(iOS 17.0, *)
@Model
private final class StoredArticle {
    @Attribute(.unique) var id: UUID
    var title: String
    var articleType: String
    var questions: [String]
    var answersData: Data
    var tags: [String]
    var updatedAt: Date
    var status: String
    var deletedAt: Date?

    init(id: UUID, title: String, articleType: String, questions: [String],
         answersData: Data, tags: [String], updatedAt: Date, status: String, deletedAt: Date?) {
        self.id = id
        self.title = title
        self.articleType = articleType
        self.questions = questions
        self.answersData = answersData
        self.tags = tags
        self.updatedAt = updatedAt
        self.status = status
        self.deletedAt = deletedAt
    }
}

enum LegacyIosMigration {
    static let bundleId = "com.syaro8460.kijisekkei"

    enum ReadError: Error {
        case unsupportedSystem
        case invalidData
        case ambiguousSource
    }

    @MainActor
    static func read() throws -> [String: Any] {
        guard #available(iOS 17.0, *) else { throw ReadError.unsupportedSystem }
        let defaults = UserDefaults.standard
        let flag = defaults.object(forKey: "swiftDataArticleMigrationCompleted_v1")
        guard flag == nil || flag is Bool else { throw ReadError.invalidData }
        let completed = flag as? Bool == true
        let legacy = try decodeDefaults([LegacyArticle].self, key: "articleDrafts", from: defaults)
        let templates = try decodeDefaults(
            [LegacyTemplate].self, key: "customArticleTemplates", from: defaults
        ) ?? []

        let stored = try readSwiftData()
        let drafts = try selectArticles(stored: stored, legacy: legacy, completed: completed)
        return [
            "applicable": true,
            "version": 1,
            "drafts": try drafts.map { try $0.bridgeValue() },
            "templates": templates.map { $0.bridgeValue },
        ]
    }

    private static func decodeDefaults<T: Decodable>(
        _ type: T.Type, key: String, from defaults: UserDefaults
    ) throws -> T? {
        guard let value = defaults.object(forKey: key) else { return nil }
        guard let data = value as? Data else { throw ReadError.invalidData }
        return try JSONDecoder().decode(type, from: data)
    }

    @available(iOS 17.0, *)
    @MainActor
    private static func readSwiftData() throws -> [LegacyArticle]? {
        let schema = Schema([StoredArticle.self])
        let url = ModelConfiguration(schema: schema).url
        guard try isExistingRegularFile(url) else {
            // A remaining sidecar makes absence of the primary store ambiguous.
            for suffix in ["-wal", "-shm", "-journal"] {
                if try isExistingRegularFile(URL(fileURLWithPath: url.path + suffix)) {
                    throw ReadError.ambiguousSource
                }
            }
            return nil
        }

        let readOnly = ModelConfiguration(
            schema: schema, url: url, allowsSave: false, cloudKitDatabase: .none
        )
        let container = try ModelContainer(for: schema, configurations: [readOnly])
        let context = ModelContext(container)
        context.autosaveEnabled = false
        return try context.fetch(FetchDescriptor<StoredArticle>()).map { row in
            try LegacyArticle(row: row)
        }
    }

    private static func isExistingRegularFile(_ url: URL) throws -> Bool {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            guard attributes[.type] as? FileAttributeType == .typeRegular else {
                throw ReadError.invalidData
            }
            return true
        } catch let error as NSError
            where error.domain == NSCocoaErrorDomain &&
                (error.code == NSFileNoSuchFileError || error.code == NSFileReadNoSuchFileError) {
            return false
        }
    }

    private static func selectArticles(
        stored: [LegacyArticle]?, legacy: [LegacyArticle]?, completed: Bool
    ) throws -> [LegacyArticle] {
        let legacyById = try index(legacy ?? [])
        guard let stored else {
            if completed { throw ReadError.ambiguousSource }
            return legacy ?? []
        }

        let storedById = try index(stored)
        if completed {
            // Old rows missing from SwiftData may have been intentionally deleted.
            // Newer legacy edits to surviving rows are evidence of a fallback.
            if legacyById.contains(where: { id, old in
                guard let current = storedById[id] else { return false }
                return old.updatedAt > current.updatedAt && old != current
            }) {
                throw ReadError.ambiguousSource
            }
            return stored
        }

        if legacyById.isEmpty || storedById == legacyById { return stored }
        throw ReadError.ambiguousSource
    }

    private static func index(_ articles: [LegacyArticle]) throws -> [UUID: LegacyArticle] {
        var result: [UUID: LegacyArticle] = [:]
        for article in articles {
            if result.updateValue(article, forKey: article.id) != nil {
                throw ReadError.invalidData
            }
        }
        return result
    }
}

private struct LegacyArticle: Decodable, Equatable {
    let id: UUID
    let title: String
    let articleType: String
    let questions: [String]?
    let answers: [String: String]?
    let tags: [String]?
    let updatedAt: Date
    let status: String?
    let deletedAt: Date?

    @available(iOS 17.0, *)
    init(row: StoredArticle) throws {
        id = row.id
        title = row.title
        articleType = row.articleType
        questions = row.questions
        answers = try JSONDecoder().decode([String: String].self, from: row.answersData)
        tags = row.tags
        updatedAt = row.updatedAt
        status = row.status
        deletedAt = row.deletedAt
    }

    func bridgeValue() throws -> [String: Any] {
        let state = status ?? "active"
        guard state == "active" || state == "trashed" else {
            throw LegacyIosMigration.ReadError.invalidData
        }
        var value: [String: Any] = [
            "id": id.uuidString,
            "title": title,
            "articleType": articleType,
            "answers": answers ?? [:],
            "tags": tags ?? [],
            "status": state,
            "updatedAtMicros": try micros(updatedAt),
        ]
        if let questions { value["questions"] = questions }
        if let deletedAt { value["deletedAtMicros"] = try micros(deletedAt) }
        return value
    }

    private func micros(_ date: Date) throws -> Int64 {
        guard let value = Int64(exactly: (date.timeIntervalSince1970 * 1_000_000).rounded()) else {
            throw LegacyIosMigration.ReadError.invalidData
        }
        return value
    }
}

private struct LegacyTemplate: Decodable {
    let id: UUID
    let name: String
    let questions: [String]
    let iconName: String
    let isBuiltIn: Bool

    var bridgeValue: [String: Any] {
        [
            "id": id.uuidString,
            "name": name,
            "questions": questions,
            "iconName": iconName,
            "isBuiltIn": isBuiltIn,
        ]
    }
}

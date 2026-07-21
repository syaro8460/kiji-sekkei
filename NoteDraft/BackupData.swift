import Foundation

struct BackupData: Codable {
    let schemaVersion: Int
    let exportedAt: Date
    let drafts: [ArticleDraft]
    let templates: [ArticleTemplate]
}

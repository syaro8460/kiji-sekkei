
import Foundation
import SwiftData

@Model
final class StoredArticle {
    @Attribute(.unique) var id: UUID
    var title: String
    var articleType: String
    var questions: [String]
    var answersData: Data
    var tags: [String]
    var updatedAt: Date
    var status: String
    var deletedAt: Date?

    init(
        id: UUID = UUID(),
        title: String,
        articleType: String,
        questions: [String],
        answersData: Data = Data(),
        tags: [String] = [],
        updatedAt: Date = Date(),
        status: String = "active",
        deletedAt: Date? = nil
    ) {
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


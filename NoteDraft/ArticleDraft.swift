import Foundation

struct ArticleDraft: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var articleType: String
    var questions: [String]
    var answers: [String: String]
    var tags: [String] = []
    var updatedAt: Date
    
    init(
        id: UUID = UUID(),
        title: String,
        articleType: String,
        questions: [String],
        answers: [String: String] = [:],
        tags: [String] = [],
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.articleType = articleType
        self.questions = questions
        self.answers = answers
        self.tags = tags
        self.updatedAt = updatedAt
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case articleType
        case questions
        case answers
        case tags
        case updatedAt
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(
            keyedBy: CodingKeys.self
        )
        
        let decodedID = try container.decode(
            UUID.self,
            forKey: .id
        )
        
        let decodedTitle = try container.decode(
            String.self,
            forKey: .title
        )
        
        let decodedArticleType = try container.decode(
            String.self,
            forKey: .articleType
        )
        
        let decodedAnswers = try container.decodeIfPresent(
            [String: String].self,
            forKey: .answers
        ) ?? [:]
        
        let decodedTags = try container.decodeIfPresent(
            [String].self,
            forKey: .tags
        ) ?? []
        
        let decodedUpdatedAt = try container.decodeIfPresent(
            Date.self,
            forKey: .updatedAt
        ) ?? Date()
        
        let decodedQuestions: [String]
        
        if let savedQuestions = try container.decodeIfPresent(
            [String].self,
            forKey: .questions
        ) {
            decodedQuestions = savedQuestions
        } else {
            decodedQuestions = ArticleTemplate.builtInTemplates
                .first { template in
                    template.name == decodedArticleType
                }?
                .questions ?? Array(decodedAnswers.keys)
        }
        
        id = decodedID
        title = decodedTitle
        articleType = decodedArticleType
        questions = decodedQuestions
        answers = decodedAnswers
        tags = decodedTags
        updatedAt = decodedUpdatedAt
    }
}

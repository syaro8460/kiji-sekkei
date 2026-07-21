import Foundation
import Combine

final class TemplateStore: ObservableObject {
    @Published private(set) var customTemplates: [ArticleTemplate] = [] {
        didSet {
            save()
        }
    }

    private let saveKey = "customArticleTemplates"

    init() {
        load()
    }

    var allTemplates: [ArticleTemplate] {
        ArticleTemplate.builtInTemplates + customTemplates
    }

    func template(id: UUID) -> ArticleTemplate? {
        allTemplates.first { template in
            template.id == id
        }
    }

    func add(
        name: String,
        questions: [String]
    ) {
        let trimmedName = name.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        let cleanedQuestions = questions
            .map {
                $0.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
            }
            .filter {
                !$0.isEmpty
            }

        guard
            !trimmedName.isEmpty,
            !cleanedQuestions.isEmpty
        else {
            return
        }

        let template = ArticleTemplate(
            name: trimmedName,
            questions: cleanedQuestions,
            iconName: "doc.text",
            isBuiltIn: false
        )

        customTemplates.append(template)
    }

    func delete(id: UUID) {
        customTemplates.removeAll { template in
            template.id == id
        }
    }

    func duplicate(id: UUID) {
        guard let template = customTemplates.first(
            where: { $0.id == id }
        ) else {
            return
        }

        let duplicatedTemplate = ArticleTemplate(
            name: "\(template.name) コピー",
            questions: template.questions,
            iconName: template.iconName,
            isBuiltIn: false
        )

        customTemplates.append(duplicatedTemplate)
    }
    
    func move(
        from source: IndexSet,
        to destination: Int
    ) {
        let movingTemplates = source.map {
            customTemplates[$0]
        }

        customTemplates.removeAll {
            movingTemplates.contains($0)
        }

        var adjustedDestination = destination

        for index in source where index < destination {
            adjustedDestination -= 1
        }

        customTemplates.insert(
            contentsOf: movingTemplates,
            at: adjustedDestination
        )
    }
    
    func update(
        id: UUID,
        name: String,
        questions: [String]
    ) {
        guard let index = customTemplates.firstIndex(
            where: { $0.id == id }
        ) else {
            return
        }

        let trimmedName = name.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        let cleanedQuestions = questions
            .map {
                $0.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
            }
            .filter {
                !$0.isEmpty
            }

        guard
            !trimmedName.isEmpty,
            !cleanedQuestions.isEmpty
        else {
            return
        }

        customTemplates[index] = ArticleTemplate(
            id: id,
            name: trimmedName,
            questions: cleanedQuestions,
            iconName: customTemplates[index].iconName,
            isBuiltIn: false
        )
    }
    
    func restore(from backupData: BackupData) {
        customTemplates = backupData.templates
        save()
    }
    
    private func save() {
        do {
            let data = try JSONEncoder().encode(
                customTemplates
            )

            UserDefaults.standard.set(
                data,
                forKey: saveKey
            )
        } catch {
            print(
                "テンプレートの保存に失敗しました:",
                error
            )
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(
            forKey: saveKey
        ) else {
            return
        }

        do {
            customTemplates = try JSONDecoder().decode(
                [ArticleTemplate].self,
                from: data
            )
        } catch {
            print(
                "テンプレートの読み込みに失敗しました:",
                error
            )
        }
    }
}

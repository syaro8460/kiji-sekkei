import Foundation

struct MarkdownExporter {

    func export(_ draft: ArticleDraft) -> String {

        var markdown = "# \(draft.title)\n\n"

        for question in draft.questions {
            markdown += "## \(question)\n\n"

            let answer = draft.answers[question] ?? ""
            markdown += "\(answer)\n\n"
        }

        return markdown
    }
}

import SwiftUI

struct DraftRowView: View {
    let draft: ArticleDraft

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: iconName)
                .font(.title2)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 7) {
                Text(draft.title)
                    .font(.headline)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    Image(systemName: iconName)
                        .font(.caption)

                    Text(draft.articleType)

                    Spacer()

                    Text(
                        draft.updatedAt.formatted(
                            date: .numeric,
                            time: .shortened
                        )
                    )
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 5)
    }

    private var iconName: String {
        ArticleTemplate.builtInTemplates
            .first { template in
                template.name == draft.articleType
            }?
            .iconName ?? "doc.text"
    }
}

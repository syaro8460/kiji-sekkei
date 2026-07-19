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
                
                if !draft.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(draft.tags, id: \.self) { tag in
                                Text(tag)
                                    .font(.caption2)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(.blue.opacity(0.15))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }

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

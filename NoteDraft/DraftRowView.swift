import SwiftUI

struct DraftRowView: View {
    let draft: ArticleDraft
    var onTagTap: ((String) -> Void)?

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
                    HStack(spacing: 6) {
                        ForEach(draft.tags.prefix(2), id: \.self) { tag in
                            TagChipView(
                                tag: tag,
                                onTap: {
                                    onTagTap?(tag)
                                }
                            )
                        }
                        if draft.tags.count > 2 {
                            Text("+\(draft.tags.count - 2)件")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.thinMaterial)
                                .clipShape(Capsule())
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

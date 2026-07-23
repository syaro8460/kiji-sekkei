import SwiftUI

struct TagChipView: View {
    let tag: String
    var onTap: (() -> Void)?
    var onDelete: (() -> Void)?

    var body: some View {
        HStack(spacing: 4) {
            if let onTap {
                Button {
                    onTap()
                } label: {
                    Label(
                        tag,
                        systemImage: "tag.fill"
                    )
                    .lineLimit(1)
                    .truncationMode(.tail)
                }
                .buttonStyle(TagChipButtonStyle())
            } else {
                Label(
                    tag,
                    systemImage: "tag.fill"
                )
                .lineLimit(1)
                .truncationMode(.tail)
            }

            if let onDelete {
                Button {
                    onDelete()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
            }
        }
        .font(.caption)
        .foregroundStyle(.green)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.green.opacity(0.15))
        .clipShape(Capsule())
    }
}

private struct TagChipButtonStyle: ButtonStyle {
    func makeBody(
        configuration: Configuration
    ) -> some View {
        configuration.label
            .scaleEffect(
                configuration.isPressed
                ? 0.90
                : 1.0
            )
            .opacity(
                configuration.isPressed
                ? 0.75
                : 1.0
            )
            .animation(
                .snappy(duration: 0.18),
                value: configuration.isPressed
            )
    }
}

#Preview {
    HStack {
        TagChipView(tag: "ガジェット")

        TagChipView(
            tag: "note",
            onTap: {}
        )

        TagChipView(
            tag: "スト6",
            onDelete: {}
        )
    }
    .padding()
}

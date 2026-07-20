import SwiftUI

struct TemplateReorderView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var templateStore: TemplateStore

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                Text("ドラッグして並び替えてください")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
                
                List {
                    ForEach(
                        templateStore.customTemplates
                    ) { template in
                        HStack {
                            Image(systemName: "line.3.horizontal")
                                .foregroundStyle(.secondary)
                            
                            Text(template.name)
                        }
                    }
                    .onMove { source, destination in
                        templateStore.move(
                            from: source,
                            to: destination
                        )
                    }
                }
            }
            .navigationTitle("並び替え")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(
                    placement: .topBarTrailing
                ) {
                    Button("完了") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    TemplateReorderView(
        templateStore: TemplateStore()
    )
}

import SwiftUI

struct QuestionReorderView: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var questions: [QuestionItem]

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
                    ForEach(questions) { question in
                        HStack {
                            Image(systemName: "line.3.horizontal")
                                .foregroundStyle(.secondary)

                            Text(question.text)
                        }
                    }
                    .onMove { source, destination in
                        questions.move(
                            fromOffsets: source,
                            toOffset: destination
                        )
                    }
                }
            }
            .navigationTitle("質問を並び替え")
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
    QuestionReorderView(
        questions: .constant([
            QuestionItem(text: "質問1"),
            QuestionItem(text: "質問2"),
            QuestionItem(text: "質問3")
        ])
    )
}

import SwiftUI

struct SettingsView: View {
    
    @AppStorage("draftSortOrder")
    private var sortOrder: DraftSortOrder = .updatedNewest
    
    var body: some View {
        List {
            Section("表示") {
                Picker("並び順", selection: $sortOrder) {
                    ForEach(DraftSortOrder.allCases, id: \.self) { order in
                        Text(order.title)
                            .tag(order)
                    }
                }
            }

            Section("データ") {
                Button("JSONを書き出す") {
                    // TODO: JSONエクスポート
                }

                Button("JSONを読み込む") {
                    // TODO: JSONインポート
                }
            }

            Section("アプリ") {
                LabeledContent("バージョン") {
                    Text(Bundle.main.appVersion)
                }
            }
        }
        .navigationTitle("設定")
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}

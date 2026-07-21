import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject var store: DraftStore
    @ObservedObject var templateStore: TemplateStore

    @AppStorage("draftSortOrder")
    private var sortOrder: DraftSortOrder = .updatedNewest

    @State private var isExporting = false
    @State private var backupDocument = BackupDocument()
    
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
                    do {
                        let backup = store.createBackupData(
                            templateStore: templateStore
                        )

                        let data = try BackupManager().encode(backup)

                        backupDocument = BackupDocument(data: data)
                        isExporting = true

                    } catch {
                        print(error)
                    }
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
        
        .fileExporter(
            isPresented: $isExporting,
            document: backupDocument,
            contentType: .json,
            defaultFilename: "NoteDraft_Backup"
        ) { result in
            switch result {
            case .success:
                print("バックアップを書き出しました")
            case .failure(let error):
                print(error.localizedDescription)
            }
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView(
            store: DraftStore(),
            templateStore: TemplateStore()
        )
    }
}

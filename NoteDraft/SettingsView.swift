import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject var store: DraftStore
    @ObservedObject var templateStore: TemplateStore

    @AppStorage("draftSortOrder")
    private var sortOrder: DraftSortOrder = .updatedNewest

    @State private var isExporting = false
    @State private var backupDocument = BackupDocument()
    @State private var isImporting = false
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var pendingBackupData: BackupData?
    @State private var showRestoreAlert = false
    
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
                Button("バックアップを書き出す") {
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

                Button("バックアップを読み込む") {
                    isImporting = true
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
                alertTitle = "バックアップ完了"
                alertMessage = "バックアップを書き出しました。"
                showAlert = true
            case .failure(let error):
                alertTitle = "エラー"
                alertMessage = error.localizedDescription
                showAlert = true
            }
        }
        
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.json]
        ) { result in
            do {
                let url = try result.get()

                guard url.startAccessingSecurityScopedResource() else {
                    throw CocoaError(.fileReadNoPermission)
                }

                defer {
                    url.stopAccessingSecurityScopedResource()
                }

                let data = try Data(contentsOf: url)
                let backupData = try BackupManager().decode(from: data)
                guard backupData.schemaVersion == 1 else {
                    throw NSError(
                        domain: "Backup",
                        code: 1,
                        userInfo: [
                            NSLocalizedDescriptionKey:
                                "対応していないバックアップファイルです。"
                        ]
                    )
                }

                pendingBackupData = backupData
                showRestoreAlert = true
                
            } catch {
                alertTitle = "エラー"
                alertMessage = error.localizedDescription
                showAlert = true
            }
        }
        
        .alert(alertTitle, isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
        
        .alert("バックアップを復元しますか？", isPresented: $showRestoreAlert) {
            Button("キャンセル", role: .cancel) {
                pendingBackupData = nil
            }

            Button("復元する", role: .destructive) {

                guard let backup = pendingBackupData else {
                    return
                }

                store.restore(from: backup)
                templateStore.restore(from: backup)

                pendingBackupData = nil

                alertTitle = "復元完了"
                alertMessage = "バックアップを読み込みました。"
                showAlert = true
            }

        } message: {
            Text("現在の記事とテンプレートはバックアップの内容で上書きされます。")
        }
    }
}

    private var backupFileName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"

        return "NoteDraft_Backup_\(formatter.string(from: Date()))"
    }

#Preview {
    NavigationStack {
        SettingsView(
            store: DraftStore(),
            templateStore: TemplateStore()
        )
    }
}

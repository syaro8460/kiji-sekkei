import SwiftUI
import SwiftData

@main
struct NoteDraftApp: App {
    @State private var isShowingSplash = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .opacity(isShowingSplash ? 0 : 1)
                    .scaleEffect(isShowingSplash ? 0.98 : 1)

                if isShowingSplash {
                    SplashView()
                        .transition(.opacity)
                }
            }
            .animation(
                .easeOut(duration: 0.4),
                value: isShowingSplash
            )
            .task {
                guard isShowingSplash else {
                    return
                }

                try? await Task.sleep(
                    for: .seconds(1.3)
                )

                isShowingSplash = false
            }
        }
        .modelContainer(for: StoredArticle.self)
    }
}

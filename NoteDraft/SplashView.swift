import SwiftUI

struct SplashView: View {
    var body: some View {
        ZStack {
            Color(.systemGreen)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Image("SplashIcon")
                    .resizable()
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 24))

                Text("記事設計")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
            }
        }
    }
}

#Preview {
    SplashView()
}

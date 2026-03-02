import SwiftUI

struct AppBrandLogoView: View {
    let height: CGFloat

    var body: some View {
        if let _ = UIImage(named: "casamaranalogo") {
            Image("casamaranalogo")
                .resizable()
                .scaledToFit()
                .frame(height: height)
                .accessibilityLabel("Casa Marana Logo")
        } else {
            // Fallback text if image missing
            Text("CASA\nMARANA")
                .font(.system(size: max(18, height * 0.42), weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .frame(height: height)
                .accessibilityLabel("Casa Marana")
        }
    }
}

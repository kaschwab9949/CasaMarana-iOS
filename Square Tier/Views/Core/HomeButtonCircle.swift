import SwiftUI

struct HomeButtonCircle: View {
    let diameter: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            GeometryReader { proxy in
                let w = proxy.size.width
                let h = proxy.size.height
                let dim = min(w, h)
                ZStack {
                    Circle()
                        .fill(Color(uiColor: .systemBackground))
                        .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 3)

                    // Provide a default icon or logo inside the button if image missing
                    if let _ = UIImage(named: "casamaranalogo") {
                        Image("casamaranalogo")
                            .resizable()
                            .scaledToFit()
                            .padding(dim * 0.15)
                            .clipShape(Circle())
                    } else {
                        Text("CM")
                            .font(.system(size: dim * 0.35, weight: .black, design: .rounded))
                            .foregroundStyle(.primary)
                    }
                }
                .frame(width: dim, height: dim)
                .position(x: w / 2, y: h / 2)
            }
            .frame(width: diameter, height: diameter)
        }
        .buttonStyle(.plain)
    }
}

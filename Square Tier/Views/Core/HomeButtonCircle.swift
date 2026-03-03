import SwiftUI

struct HomeButtonCircle: View {
    let diameter: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color(uiColor: .systemBackground))
                    .shadow(color: .black.opacity(0.12), radius: 4, x: 0, y: 2)

                // Keep the entire logo visible inside the circular toolbar button.
                if let _ = UIImage(named: "casamaranalogo") {
                    Image("casamaranalogo")
                        .resizable()
                        .scaledToFit()
                        .padding(diameter * 0.18)
                } else {
                    Text("CM")
                        .font(.system(size: diameter * 0.4, weight: .black, design: .rounded))
                        .foregroundStyle(.primary)
                }
            }
            .frame(width: diameter, height: diameter)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

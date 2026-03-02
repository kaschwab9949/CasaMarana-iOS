import SwiftUI

struct AuthGateView: View {
    @EnvironmentObject var session: AppSession

    var body: some View {
        if !session.isUnlocked {
            if session.hasSetup {
                UnlockView()
            } else {
                CreateAccountView()
            }
        }
    }
}

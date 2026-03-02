import SwiftUI

// MARK: - Rewards Sign In (username/password; no SMS required for repeat logins)

struct RewardsAuthEntryView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 10) {
                SignInView()
            }
        }
        .accessibilityIdentifier("rewards.signInScreen")
    }
}

struct SignInView: View {
    @EnvironmentObject var session: AppSession

    @State private var usernamePhone: String = ""
    @State private var password: String = ""
    @State private var error: String? = nil

    private func normalize10Digits(_ raw: String) -> String {
        let digits = raw.filter { $0.isNumber }
        // keep last 10 digits if user included +1 or formatting
        if digits.count >= 10 { return String(digits.suffix(10)) }
        return digits
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                AppBrandLogoView(height: 70)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 24)

                Text("Sign In")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Sign in to your Casa Marana rewards profile.")
                    .font(.body)
                    .foregroundStyle(.secondary)

                GroupBox {
                    VStack(spacing: 12) {
                        TextField("Phone Number", text: $usernamePhone)
                            .keyboardType(.numberPad)
                            .textContentType(.telephoneNumber)
                            .accessibilityIdentifier("rewards.auth.phoneField")

                        SecureField("Password (PIN)", text: $password)
                            .keyboardType(.numberPad)
                            .accessibilityIdentifier("rewards.auth.pinField")
                    }
                }

                if let error {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("rewards.auth.errorText")
                }

                Button {
                    error = nil

                    let input10 = normalize10Digits(usernamePhone)
                    let pw = password.trimmingCharacters(in: .whitespacesAndNewlines)

                    guard input10.count == 10 else {
                        error = "Please enter a valid 10-digit phone number."
                        return
                    }
                    guard pw.count == 4 else {
                        error = "PIN must be 4 digits. If you don't have one, create an account."
                        return
                    }

                    // In a real app, this makes a network request to authenticate.
                    // For the demo, we assume the user creates an account locally and logs in with it.
                    let demoPhone = "+1\(input10)"
                    let demoPassword = pw

                    let p = UserProfile(
                        fullName: "Member",
                        phoneE164: demoPhone,
                        email: "",
                        birthday: "",
                        isPhoneVerified: true,
                        phoneVerificationToken: "demo_token_123"
                    )

                    // Reuse the existing local PIN storage path to unlock the app.
                    // Using the same 4-digit value for PIN keeps the change minimal.
                    session.createAccount(profile: p, pin: demoPassword)
                } label: {
                    Text("Sign In")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("rewards.auth.signInButton")

                NavigationLink {
                    CreateAccountView()
                } label: {
                    Text("Don't have an account? Create one.")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .padding(.top, 8)
                .accessibilityIdentifier("rewards.auth.createAccountLink")

                Text("Sign in uses your phone number and password. Phone verification is only required when creating an account.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 30)
            }
            .padding()
        }
        .accessibilityIdentifier("rewards.signInScreen")
    }
}

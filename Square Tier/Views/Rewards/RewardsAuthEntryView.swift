import SwiftUI

// MARK: - Rewards Sign In

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

    private var uiTestingSeedsDemoAccount: Bool {
        ProcessInfo.processInfo.arguments.contains("-ui-testing-seed-demo-account")
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

                Text("Sign in to your Casa Marana app login to view your Square loyalty account.")
                    .font(.body)
                    .foregroundStyle(.secondary)

                Text("Loyalty enrollment happens after an in-store transaction. Then create your app login to view your loyalty account.")
                    .font(.footnote)
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

                    let normalizedInput = "+1\(input10)"

                    // UI-test-only fallback to keep tests deterministic on clean simulators.
                    if uiTestingSeedsDemoAccount && !session.hasSetup {
                        let seeded = UserProfile(
                            fullName: "UITest Member",
                            phoneE164: normalizedInput,
                            email: "",
                            birthday: "",
                            isPhoneVerified: true,
                            phoneVerificationToken: "ui_test_seeded_token"
                        )
                        session.createAccount(profile: seeded, pin: pw)
                    }

                    guard session.hasSetup else {
                        error = "No app login found for this device. Tap Create App Login to verify your phone and connect loyalty."
                        return
                    }

                    guard session.unlock(pin: pw) else {
                        error = "Invalid phone number or PIN."
                        return
                    }

                    let storedPhone = normalizePhoneE164(session.profile.phoneE164) ?? session.profile.phoneE164
                    guard !storedPhone.isEmpty else {
                        session.lock()
                        error = "Profile data is incomplete. Please create your app login again."
                        return
                    }

                    guard storedPhone == normalizedInput else {
                        session.lock()
                        error = "This phone number does not match the app login on this device."
                        return
                    }
                } label: {
                    Text("Sign In")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("rewards.auth.signInButton")

                NavigationLink {
                    CreateAccountView()
                } label: {
                    Text("Create app login")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .padding(.top, 8)
                .accessibilityIdentifier("rewards.auth.createAccountLink")

                Text("App login is separate from Square POS. Use a verified phone number to connect and view points.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 30)
            }
            .padding()
        }
        .accessibilityIdentifier("rewards.signInScreen")
    }
}

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

                Text("Sign in with the same phone number and 4-digit PIN from your Casa Marana app login.")
                    .font(.body)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Quick steps")
                        .font(.footnote.weight(.semibold))
                    Text("1. New customer? Tap Create App Login once.")
                    Text("2. Verify your phone by text, then create your 4-digit PIN.")
                    Text("3. Enter that same phone number and PIN here.")
                    Text("4. Tap Sign In to load your Square rewards.")
                }
                .font(.footnote)
                .foregroundStyle(.secondary)

                GroupBox {
                    VStack(spacing: 12) {
                        TextField("Phone Number (10 digits)", text: $usernamePhone)
                            .keyboardType(.numberPad)
                            .textContentType(.telephoneNumber)
                            .accessibilityIdentifier("rewards.auth.phoneField")

                        SecureField("App PIN (4 digits)", text: $password)
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
                        error = "Enter a valid 10-digit US phone number (example: 5205551234)."
                        return
                    }
                    guard pw.count == 4 else {
                        error = "Enter your 4-digit app PIN. New customer? Tap Create App Login first."
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
                        error = "No app login is saved on this device yet. Tap Create App Login."
                        return
                    }

                    guard session.unlock(pin: pw) else {
                        error = "Phone number or PIN is incorrect."
                        return
                    }

                    let storedPhone = normalizePhoneE164(session.profile.phoneE164) ?? session.profile.phoneE164
                    guard !storedPhone.isEmpty else {
                        session.lock()
                        error = "Your saved login is incomplete. Tap Create App Login to set it up again."
                        return
                    }

                    guard storedPhone == normalizedInput else {
                        session.lock()
                        error = "Use the same phone number you used when creating this app login."
                        return
                    }

                    // Older local profiles may not carry the verified flag.
                    // Promote the signed-in phone so rewards can load immediately.
                    session.markSignedInPhoneVerified(normalizedInput)
                } label: {
                    Text("Sign In")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("rewards.auth.signInButton")

                NavigationLink {
                    CreateAccountView()
                } label: {
                    Text("Create App Login")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .padding(.top, 8)
                .accessibilityIdentifier("rewards.auth.createAccountLink")

                Text("App login is separate from in-store checkout. After sign-in, we use your verified phone number to pull Square loyalty points.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Text("Your points, balance, and loyalty status are pulled directly from Square using your verified phone number.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 30)
            }
            .padding()
        }
        .accessibilityIdentifier("rewards.signInScreen")
    }
}

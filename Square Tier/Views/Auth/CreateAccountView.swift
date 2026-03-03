import SwiftUI

struct CreateAccountView: View {
    @EnvironmentObject var session: AppSession
    @Environment(\.dismiss) private var dismiss

    // Force navigation to the Rewards tab after successful account creation.
    @AppStorage("cm.selectedTab") private var selectedTabRaw: String = "home"

    @State private var profile: UserProfile = .empty
    @State private var pin: String = ""
    @State private var confirmPin: String = ""

    // OTP State
    @State private var verificationCodeSent = false
    @State private var verificationRequestId: String? = nil
    @State private var verificationCode: String = ""
    @State private var isSendingCode = false
    @State private var isVerifyingCode = false
    @State private var codeInfo: String? = nil

    @State private var isCreatingAccount = false
    @State private var error: String? = nil
    @State private var hasPIIConsent = false

    private let phoneVerifyAPI = PhoneVerificationAPI()
    private let loyaltyAPI = LoyaltyAPI()

    private func pinIsValid(_ s: String) -> Bool {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.count == 4 && t.allSatisfy { $0.isNumber }
    }

    private func maskedPhone(_ e164: String) -> String {
        let digits = e164.filter(\.isNumber)
        let suffix = String(digits.suffix(4))
        return suffix.isEmpty ? "your phone" : "••• ••• \(suffix)"
    }

    @MainActor
    private func sendVerificationCode() async {
        error = nil
        codeInfo = nil

        let raw = profile.phoneE164
        guard let normalized = normalizePhoneE164(raw) else {
            error = "Please enter a valid 10-digit US phone number."
            return
        }
        profile.phoneE164 = normalized

        isSendingCode = true
        defer { isSendingCode = false }

        do {
            let resp = try await phoneVerifyAPI.start(phoneE164: normalized)
            verificationRequestId = resp.requestId
            verificationCodeSent = true
            verificationCode = ""
            profile.isPhoneVerified = false
            profile.phoneVerificationToken = nil
            codeInfo = "Passcode sent to \(maskedPhone(normalized)). Enter the 6-digit code."
        } catch {
            verificationRequestId = nil
            verificationCodeSent = false
            codeInfo = nil
            self.error = UserFacingError.message(
                for: error,
                context: .auth,
                fallback: "Failed to send passcode. Please check the number and try again."
            )
        }
    }

    private var canFinalizeAccount: Bool {
        let name = profile.fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        let phone = profile.phoneE164.trimmingCharacters(in: .whitespacesAndNewlines)
        let p1 = pin.trimmingCharacters(in: .whitespacesAndNewlines)
        let p2 = confirmPin.trimmingCharacters(in: .whitespacesAndNewlines)

        return !name.isEmpty &&
               name.count <= 300 &&
               profile.isPhoneVerified &&
               !phone.isEmpty &&
               pinIsValid(p1) &&
               p1 == p2 &&
               hasPIIConsent &&
               isValidCustomerEmail(profile.email) &&
               normalizeCustomerBirthday(profile.birthday) != nil
    }

    private func finalizeAccount() async {
        guard !isCreatingAccount else { return }

        let name = profile.fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        let phone = profile.phoneE164.trimmingCharacters(in: .whitespacesAndNewlines)
        let p1 = pin.trimmingCharacters(in: .whitespacesAndNewlines)
        let p2 = confirmPin.trimmingCharacters(in: .whitespacesAndNewlines)

        guard hasPIIConsent else {
            error = "Please confirm permission to store your contact information before creating your app login."
            return
        }

        guard !name.isEmpty, name.count <= 300 else {
            error = "Please enter your full name (up to 300 characters)."
            return
        }

        guard !phone.isEmpty, pinIsValid(p1), p1 == p2, profile.isPhoneVerified else {
            error = "Please complete all fields correctly, confirm your PIN, and verify your phone number."
            return
        }

        guard isValidCustomerEmail(profile.email) else {
            error = "Please enter a valid email address."
            return
        }

        guard let normalizedBirthday = normalizeCustomerBirthday(profile.birthday) else {
            error = "Birthday must use YYYY-MM-DD or MM-DD format."
            return
        }

        profile.fullName = name
        profile.email = normalizeCustomerEmail(profile.email)
        profile.birthday = normalizedBirthday

        isCreatingAccount = true
        defer { isCreatingAccount = false }

        do {
            let status = try await loyaltyAPI.fetchStatus(phoneE164: phone)
            guard status.enrolled else {
                error = "This phone number is not enrolled in Square Loyalty yet. Complete enrollment after an in-store transaction, then sign in to the app."
                return
            }
        } catch {
            self.error = UserFacingError.message(
                for: error,
                context: .auth,
                fallback: "Could not confirm your Square loyalty enrollment. Please try again."
            )
            return
        }

        session.createAccount(profile: profile, pin: p1)

        // If this view is still on the navigation stack, pop it quickly.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            dismiss()
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                AppBrandLogoView(height: 70)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 24)

                Text("Create Your Profile")
                    .font(.title2)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.bottom, 8)

                Text("Create your app login to access your loyalty account. Your phone must already be enrolled in Square Loyalty.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if let error {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.callout)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                        .accessibilityIdentifier("auth.create.errorText")
                }

                GroupBox("Personal Info") {
                    VStack(alignment: .leading, spacing: 10) {
                        TextField("Full Name", text: $profile.fullName)
                            .textContentType(.name)
                            .accessibilityIdentifier("auth.create.fullNameField")
                        TextField("Email Address", text: $profile.email)
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                            .accessibilityIdentifier("auth.create.emailField")
                        TextField("Birthday (optional)", text: $profile.birthday)
                            .accessibilityIdentifier("auth.create.birthdayField")
                    }
                }

                GroupBox("Verify Phone Number") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Tap Send Passcode, then enter the 6-digit code from text message.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        if !verificationCodeSent {
                            TextField("US Phone Number (e.g. 5205551234)", text: $profile.phoneE164)
                                .keyboardType(.phonePad)
                                .textContentType(.telephoneNumber)
                                .accessibilityIdentifier("auth.create.phoneField")

                            Button {
                                Task { await sendVerificationCode() }
                            } label: {
                                HStack {
                                    if isSendingCode { ProgressView() }
                                    Text(isSendingCode ? "Sending…" : "Send Passcode")
                                        .frame(maxWidth: .infinity)
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(isSendingCode || isCreatingAccount)
                            .accessibilityIdentifier("auth.create.sendCodeButton")
                        } else {
                            VStack(alignment: .leading, spacing: 8) {
                                if let info = codeInfo {
                                    Text(info)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }

                                HStack {
                                    Text(profile.phoneE164)
                                        .font(.body.monospacedDigit())
                                    Spacer()
                                    if profile.isPhoneVerified {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                    }
                                }
                                .padding(8)
                                .background(.thinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                                if !profile.isPhoneVerified {
                                    TextField("6-digit code", text: $verificationCode)
                                        .keyboardType(.numberPad)
                                        .textContentType(.oneTimeCode)
                                        .textFieldStyle(.roundedBorder)
                                        .accessibilityIdentifier("auth.create.verificationCodeField")
                                }

                                HStack {
                                    Button {
                                        Task {
                                            error = nil

                                            guard let requestId = verificationRequestId, !requestId.isEmpty else {
                                                await sendVerificationCode()
                                                return
                                            }

                                            let trimmed = verificationCode.trimmingCharacters(in: .whitespacesAndNewlines)
                                            guard !trimmed.isEmpty else {
                                                error = "Please enter the 6-digit passcode."
                                                return
                                            }

                                            isVerifyingCode = true
                                            defer { isVerifyingCode = false }

                                            do {
                                                let resp = try await phoneVerifyAPI.verify(phoneE164: profile.phoneE164, code: trimmed, requestId: requestId)
                                                if resp.verified {
                                                    profile.isPhoneVerified = true
                                                    profile.phoneVerificationToken = resp.token
                                                    codeInfo = "Phone verified successfully."
                                                    error = nil
                                                } else {
                                                    error = "Incorrect passcode. Please try again or resend."
                                                }
                                            } catch let err {
                                                error = UserFacingError.message(
                                                    for: err,
                                                    context: .auth,
                                                    fallback: "Verification failed."
                                                )
                                            }
                                        }
                                    } label: {
                                        HStack {
                                            if isVerifyingCode { ProgressView() }
                                            Text(isVerifyingCode ? "Verifying…" : "Verify Passcode")
                                        }
                                    }
                                    .buttonStyle(.bordered)
                                    .disabled(isSendingCode || isVerifyingCode || isCreatingAccount || profile.isPhoneVerified)
                                    .accessibilityIdentifier("auth.create.verifyCodeButton")

                                    Button {
                                        Task { await sendVerificationCode() }
                                    } label: {
                                        HStack {
                                            if isSendingCode { ProgressView() }
                                            Text(isSendingCode ? "Sending…" : "Resend Passcode")
                                        }
                                    }
                                    .buttonStyle(.bordered)
                                    .disabled(isSendingCode || isVerifyingCode || isCreatingAccount || profile.isPhoneVerified)
                                    .accessibilityIdentifier("auth.create.resendCodeButton")

                                    Button("Edit Number") {
                                        verificationCodeSent = false
                                        verificationRequestId = nil
                                        verificationCode = ""
                                        profile.isPhoneVerified = false
                                        profile.phoneVerificationToken = nil
                                        codeInfo = nil
                                        error = nil
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(isSendingCode || isVerifyingCode || isCreatingAccount || profile.isPhoneVerified)
                                    .accessibilityIdentifier("auth.create.editPhoneButton")
                                }
                            }
                        }
                    }
                }

                GroupBox("Create a Passcode") {
                    VStack(alignment: .leading, spacing: 10) {
                        SecureField("4-digit passcode", text: $pin)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityIdentifier("auth.create.pinField")
                            .onChange(of: pin) { _, newValue in
                                let filtered = newValue.filter { $0.isNumber }
                                if filtered.count > 4 {
                                    pin = String(filtered.prefix(4))
                                } else if filtered != newValue {
                                    pin = filtered
                                }
                            }

                        SecureField("Confirm passcode", text: $confirmPin)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityIdentifier("auth.create.confirmPinField")
                            .onChange(of: confirmPin) { _, newValue in
                                let filtered = newValue.filter { $0.isNumber }
                                if filtered.count > 4 {
                                    confirmPin = String(filtered.prefix(4))
                                } else if filtered != newValue {
                                    confirmPin = filtered
                                }
                            }
                        
                        if !pin.isEmpty && !confirmPin.isEmpty && pin != confirmPin {
                            Text("Passcodes do not match.")
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }
                    }
                }

                GroupBox("Permission") {
                    Toggle(isOn: $hasPIIConsent) {
                        Text("I agree to store my contact information for loyalty account access.")
                            .font(.footnote)
                    }
                }

                Button {
                    Task { await finalizeAccount() }
                } label: {
                    HStack {
                        if isCreatingAccount { ProgressView() }
                        Text(isCreatingAccount ? "Saving…" : "Create App Login")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canFinalizeAccount || isCreatingAccount)
                .accessibilityIdentifier("auth.create.createLoginButton")

                Text("Phone verification confirms this device can access your enrolled loyalty account.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)

                Spacer(minLength: 30)
            }
            .padding()
        }
        .onChange(of: session.isUnlocked) { _, newValue in
            if newValue {
                selectedTabRaw = AppTab.rewards.rawValue
                dismiss()
            }
        }
    }
}

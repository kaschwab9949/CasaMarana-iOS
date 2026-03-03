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
    @State private var rewardsStatusNote: String? = nil
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
                fallback: "We could not send a passcode. Check the phone number and try again."
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

    private func enrollmentFallbackMessage(for error: Error) -> String {
        if let apiError = error as? APIError {
            switch apiError {
            case .rateLimited(let retryAfter):
                let wait = max(15, Int(ceil(retryAfter ?? 60)))
                return "Square rewards enrollment is temporarily busy. Try again in \(wait) seconds after sign-in."
            case .message(let message):
                let lowered = message.lowercased()
                if lowered.contains("route is unavailable")
                    || lowered.contains("not available")
                    || lowered.contains("not supported")
                    || lowered.contains("not allowed")
                    || lowered.contains("cannot be enrolled")
                    || lowered.contains("in-store transaction") {
                    return "Square does not currently allow in-app enrollment for this phone. You can still finish setup and enroll in-store."
                }
            default:
                break
            }
        }

        return "App login created. We could not complete Square rewards enrollment yet; sign in and try again from Rewards."
    }

    private func finalizeAccount() async {
        guard !isCreatingAccount else { return }

        error = nil
        rewardsStatusNote = nil

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

        var postCreateRewardsMessage: String? = nil
        do {
            let status = try await loyaltyAPI.fetchStatus(phoneE164: phone)
            if !status.enrolled {
                do {
                    let enrollment = try await loyaltyAPI.ensureEnrollment(
                        phoneE164: phone,
                        customerID: status.customerID
                    )

                    if enrollment.enrolled || enrollment.created {
                        postCreateRewardsMessage = "Square rewards enrollment is active for this phone."
                    } else {
                        postCreateRewardsMessage = "Square did not allow in-app enrollment for this phone yet. You can still use the app and enroll in-store."
                    }
                } catch let enrollmentError {
                    postCreateRewardsMessage = enrollmentFallbackMessage(for: enrollmentError)
                }
            } else {
                postCreateRewardsMessage = "Square rewards is already linked to this phone."
            }
        } catch {
            postCreateRewardsMessage = "App login created. We could not confirm Square rewards right now; sign in and refresh Rewards."
        }

        session.createAccount(profile: profile, pin: p1)
        rewardsStatusNote = postCreateRewardsMessage

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

                Text("Create your app login with your phone number and a 4-digit PIN.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Text("After setup, sign in to view your points. If your Square program allows in-app enrollment, we will enroll this phone automatically.")
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

                if let rewardsStatusNote {
                    Text(rewardsStatusNote)
                        .foregroundStyle(.secondary)
                        .font(.callout)
                        .padding()
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(8)
                        .accessibilityIdentifier("auth.create.rewardsStatusNote")
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
                        Text("Step 1: Enter your phone number. Step 2: Tap Send Passcode. Step 3: Enter the 6-digit code from text message.")
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

                Text("Phone verification confirms this device can access your phone-based rewards profile.")
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

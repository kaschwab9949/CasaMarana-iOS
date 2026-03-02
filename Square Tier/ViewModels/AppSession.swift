import Foundation
import SwiftUI
import LocalAuthentication
import Combine

@MainActor
final class AppSession: ObservableObject {
    @Published var isUnlocked: Bool = false
    @Published var profile: UserProfile = .empty

    var verifiedPhoneE164: String? {
        guard profile.isPhoneVerified else { return nil }
        return profile.phoneE164.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : profile.phoneE164
    }

    private let pinAccount = "app.localPin"
    private let phoneAccount = "app.verifiedPhone"
    private let profileKey = "cm.userProfile.v1"

    init() {
        if ProcessInfo.processInfo.arguments.contains("-ui-testing-reset-session") {
            eraseProfileData()
            UserDefaults.standard.set("home", forKey: "cm.selectedTab")
        }
        loadProfile()
    }

    var hasSetup: Bool {
        KeychainService.load(account: pinAccount) != nil
    }

    @discardableResult
    func setupAccount(pin: String) -> Bool {
        let ok = KeychainService.save(pin, account: pinAccount)
        if ok {
            isUnlocked = true
        }
        return ok
    }

    /// Combined convenience: save profile + create PIN in one step.
    /// Used by RewardsAuthEntryView sign-in flow.
    func createAccount(profile p: UserProfile, pin: String) {
        updateProfile(p)
        if let phone = normalizePhoneE164(p.phoneE164) {
            KeychainService.save(phone, account: phoneAccount)
        }
        setupAccount(pin: pin)
    }

    /// Fire-and-forget biometric unlock attempt (non-async convenience).
    func attemptBiometricUnlock() {
        guard hasSetup else { return }
        Task { await unlockWithBiometrics() }
    }

    func unlock(pin: String) -> Bool {
        guard let stored = KeychainService.load(account: pinAccount) else { return false }
        let ok = (stored == pin)
        if ok {
            loadProfile()
            isUnlocked = true
        }
        return ok
    }

    func unlockWithBiometrics() async -> Bool {
        // Only allow biometric unlock if a PIN/account exists
        guard hasSetup else { return false }

        let context = LAContext()
        context.localizedCancelTitle = "Cancel"

        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return false
        }

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Unlock Casa Marana to access your rewards"
            )
            if success {
                loadProfile()
                self.isUnlocked = true
            }
            return success
        } catch {
            return false
        }
    }

    func lock() {
        isUnlocked = false
        profile = .empty // clear from memory
    }

    func eraseProfileData() {
        KeychainService.delete(account: pinAccount)
        KeychainService.delete(account: phoneAccount)
        UserDefaults.standard.removeObject(forKey: profileKey)
        profile = .empty
        isUnlocked = false
    }

    func updateProfile(_ updated: UserProfile) {
        var next = updated
        if profile.isPhoneVerified && updated.phoneE164 != profile.phoneE164 {
            // Disallow changing verified phone without re-verification; keep the original phone.
            next.phoneE164 = profile.phoneE164
        }
        guard let data = try? JSONEncoder().encode(next) else { return }
        UserDefaults.standard.set(data, forKey: profileKey)
        profile = next
    }

    private func loadProfile() {
        guard let data = UserDefaults.standard.data(forKey: profileKey),
              let p = try? JSONDecoder().decode(UserProfile.self, from: data) else {
            // Load phone from keychain if it exists but profile doesn't.
            if let phone = KeychainService.load(account: phoneAccount), !phone.isEmpty {
                profile.phoneE164 = phone
            }
            return
        }
        profile = p
        
        // If phone exists in Keychain but profile not set, seed phone.
        if let phone = KeychainService.load(account: phoneAccount), !phone.isEmpty {
            profile.phoneE164 = phone
        }
    }
}

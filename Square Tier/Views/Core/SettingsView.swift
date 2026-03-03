import SwiftUI
import UIKit
import CoreLocation

struct SettingsView: View {
    @EnvironmentObject var session: AppSession
    @EnvironmentObject var location: VenueLocationManager
    @Environment(\.openURL) private var openURL

    @State private var showEraseAlert = false
    @State private var showDeleteAlert = false
    @State private var isDeletingAccount = false
    @State private var deleteError: String? = nil
    @State private var deleteSuccess: String? = nil

    @AppStorage("cm.smartCheckInEnabled") private var smartCheckInEnabled: Bool = false

    // Optional privacy policy URL; set to a real URL to show the link.
    private let privacyPolicyURL = URL(string: "https://www.casamarana.com/privacypolicy")

    // Support links
    private let websiteURL = URL(string: "https://www.casamarana.com")!
    private let supportEmailURL = URL(string: "mailto:casacbw@gmail.com")!
    private let loyaltyAPI = LoyaltyAPI()

    private var normalizedPhoneForDeletion: String? {
        let trimmed = session.profile.phoneE164.trimmingCharacters(in: .whitespacesAndNewlines)
        if let normalized = normalizePhoneE164(trimmed) {
            return normalized
        }
        return trimmed.isEmpty ? nil : trimmed
    }

    private var locationStatusText: String {
        switch location.authorization {
        case .authorizedWhenInUse:
            return "Location access granted while using the app."
        case .authorizedAlways:
            return "Location access is set to Always. The app only uses foreground check-ins."
        case .denied, .restricted:
            return "Location access is disabled."
        case .notDetermined:
            return "Location permission has not been requested yet."
        @unknown default:
            return "Location permission status is unavailable."
        }
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }

    private func deleteAccountFromBackend() async {
        guard !isDeletingAccount else { return }

        guard let phone = normalizedPhoneForDeletion else {
            await MainActor.run {
                deleteError = "No phone number is available for account deletion."
            }
            return
        }

        await MainActor.run {
            isDeletingAccount = true
            deleteError = nil
            deleteSuccess = nil
        }

        do {
            try await loyaltyAPI.deleteAccount(phoneE164: phone)
            await MainActor.run {
                session.eraseProfileData()
                smartCheckInEnabled = false
                location.stop()
                deleteSuccess = "Your account deletion request has been completed."
                isDeletingAccount = false
            }
        } catch {
            await MainActor.run {
                deleteError = UserFacingError.message(
                    for: error,
                    context: .accountDeletion,
                    fallback: "We couldn’t delete your account right now. Please try again or contact support."
                )
                isDeletingAccount = false
            }
        }
    }

    var body: some View {
        List {
            // 1) Privacy
            Section("Privacy") {
                NavigationLink {
                    PrivacyDataUseView()
                } label: {
                    Label("Privacy & Data Use", systemImage: "hand.raised")
                }

                if let pURL = privacyPolicyURL {
                    Link(destination: pURL) {
                        Label("Privacy Policy (Web)", systemImage: "globe")
                    }
                }
            }

            Section("Smart Check-In") {
                Toggle("Enable Smart Check-In", isOn: $smartCheckInEnabled)
                    .accessibilityIdentifier("settings.smartCheckInToggle")
                    .onChange(of: smartCheckInEnabled) { _, enabled in
                        if enabled {
                            location.requestPermission()
                        } else {
                            location.stop()
                        }
                    }

                Text(locationStatusText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Text("Smart Check-In lets us detect when you visit Casa Marana and awards an extra 5 loyalty points for each qualifying visit.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if smartCheckInEnabled && (location.authorization == .denied || location.authorization == .restricted) {
                    Button("Open iOS Settings") {
                        openSystemSettings()
                    }
                    .accessibilityIdentifier("settings.openSystemSettingsButton")
                }
            }

            // 2) Account Operations
            if session.hasSetup {
                Section("Data Management") {
                    if isDeletingAccount {
                        HStack {
                            ProgressView()
                            Text("Deleting account…")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let deleteError {
                        Text(deleteError)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .accessibilityIdentifier("settings.deleteAccountErrorText")
                    }

                    if let deleteSuccess {
                        Text(deleteSuccess)
                            .font(.footnote)
                            .foregroundStyle(.green)
                            .accessibilityIdentifier("settings.deleteAccountSuccessText")
                    }

                    Button(role: .destructive) {
                        showDeleteAlert = true
                    } label: {
                        Label("Delete Account", systemImage: "person.crop.circle.badge.xmark")
                            .foregroundStyle(.red)
                    }
                    .accessibilityIdentifier("settings.deleteAccountButton")
                    .disabled(isDeletingAccount)

                    Button(role: .destructive) {
                        showEraseAlert = true
                    } label: {
                        Label("Erase Local Profile", systemImage: "trash")
                            .foregroundStyle(.red)
                    }
                    .accessibilityIdentifier("settings.eraseLocalProfileButton")
                    .disabled(isDeletingAccount)
                }
            } else {
                Section("Data Management") {
                    Text("No local profile found.")
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("settings.noLocalProfileText")
                }
            }

            // 3) Support
            Section("Support") {
                Link(destination: websiteURL) {
                    Label("Website", systemImage: "safari")
                }
                Link(destination: supportEmailURL) {
                    Label("Email Support", systemImage: "envelope.fill")
                }
            }

            // 4) About
            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text(appVersion)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .listStyle(.insetGrouped)
        .accessibilityIdentifier("settings.list")
        .alert("Delete account?", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
                .accessibilityIdentifier("settings.deleteAccountCancelButton")
            Button("Delete Account", role: .destructive) {
                Task { await deleteAccountFromBackend() }
            }
            .accessibilityIdentifier("settings.deleteAccountConfirmButton")
        } message: {
            Text("This permanently deletes your Casa Marana account data and signs you out on this device.")
        }
        .alert("Erase local profile?", isPresented: $showEraseAlert) {
            Button("Cancel", role: .cancel) {}
                .accessibilityIdentifier("settings.eraseCancelButton")
            Button("Erase", role: .destructive) {
                session.eraseProfileData()
            }
            .accessibilityIdentifier("settings.eraseConfirmButton")
        } message: {
            Text("This removes your PIN and profile from this device.")
        }
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "-"
        return "\(v) (\(b))"
    }
}

struct PrivacyDataUseView: View {
    var body: some View {
        List {
            Section {
                Text("Your profile (name, phone, email, birthday) is stored on this device and protected by your PIN.")
                    .foregroundStyle(.secondary)

                Text("We do not upload your full profile. Phone numbers are securely verified and synced to lookup Square member points.")
                    .foregroundStyle(.secondary)

                Text("If Smart Check-In is enabled and a birthday is on file, birthday may be sent with location samples to support rewards logic.")
                    .foregroundStyle(.secondary)
            }

            Section {
                Text("Verification Requests")
                    .fontWeight(.semibold)

                Text("Verification requests are short-lived and used only to complete phone verification. Verification codes expire quickly and are not stored on your device.")
                    .foregroundStyle(.secondary)
                
                Text("Rewards lookup: when you check Rewards, your phone number is sent to our rewards service to retrieve your points and available rewards.")
                    .foregroundStyle(.secondary)
                
                Text("If you enable Smart Check-In, location samples are sent while using the app to award an extra 5 points per qualifying visit and are not retained as a local history on this device.")
                    .foregroundStyle(.secondary)

                Text("Delete Account removes your account data from our backend and clears your profile from this device.")
                    .foregroundStyle(.secondary)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Privacy & Data Use")
        .navigationBarTitleDisplayMode(.inline)
    }
}

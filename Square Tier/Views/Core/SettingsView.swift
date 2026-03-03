import SwiftUI
import UIKit
import CoreLocation

#if DEBUG
private struct EndpointSelfCheckResult: Identifiable {
    let id = UUID()
    let name: String
    let statusCode: Int?
    let ok: Bool
    let detail: String
}

private enum InternalDebugPanel {
    static let launchArgument = "-cm-show-api-debug"
}
#endif

struct SettingsView: View {
    @EnvironmentObject var session: AppSession
    @EnvironmentObject var location: VenueLocationManager
    @Environment(\.openURL) private var openURL

    @State private var showEraseAlert = false
    @State private var showDeleteAlert = false
    @State private var isDeletingAccount = false
    @State private var deleteError: String? = nil
    @State private var deleteSuccess: String? = nil
#if DEBUG
    @State private var runtimeBackendURL: String = ""
    @State private var runtimeAPIKey: String = ""
    @State private var runtimeAuthMode: AppConfig.AuthHeaderMode = .apiKey
    @State private var runtimeConfigNotice: String? = nil
    @State private var runtimeConfigError: String? = nil
    @State private var isRunningSelfCheck = false
    @State private var endpointSelfCheckResults: [EndpointSelfCheckResult] = []
#endif

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

#if DEBUG
    private var activeAPIKeyStatusText: String {
        let trimmed = AppConfig.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Not configured" : "Configured"
    }

    private var shouldShowInternalAPIDebugSection: Bool {
        ProcessInfo.processInfo.arguments.contains(InternalDebugPanel.launchArgument)
    }

    private func loadRuntimeAPIConfigForm() {
        runtimeBackendURL = AppConfig.runtimeBackendBaseURLOverride ?? ""
        runtimeAPIKey = ""
        runtimeAuthMode = AppConfig.runtimeAuthHeaderModeOverride ?? AppConfig.authHeaderMode
        runtimeConfigNotice = nil
        runtimeConfigError = nil
    }

    private func saveRuntimeAPIConfig() {
        runtimeConfigNotice = nil
        runtimeConfigError = nil

        let trimmedURL = runtimeBackendURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedKey = runtimeAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)

        if !trimmedURL.isEmpty, URL(string: trimmedURL) == nil {
            runtimeConfigError = "Enter a valid backend URL (for example, https://casa-marana-backend.vercel.app)."
            return
        }

        let saved = AppConfig.saveRuntimeOverrides(
            baseURL: trimmedURL.isEmpty ? nil : trimmedURL,
            apiKey: trimmedKey.isEmpty ? nil : trimmedKey,
            authHeaderMode: runtimeAuthMode
        )

        if !saved {
            runtimeConfigError = "Could not securely save the API key."
            return
        }

        runtimeAPIKey = ""
        runtimeConfigNotice = "Saved runtime API settings for this device."
    }

    private func clearRuntimeAPIConfig() {
        AppConfig.clearRuntimeOverrides()
        loadRuntimeAPIConfigForm()
        runtimeConfigNotice = "Cleared runtime API overrides. Build settings are now active."
    }

    private func runEndpointSelfCheck() {
        guard !isRunningSelfCheck else { return }

        isRunningSelfCheck = true
        endpointSelfCheckResults = []
        runtimeConfigError = nil
        runtimeConfigNotice = nil

        Task {
            async let health = performEndpointSelfCheck(
                name: "Health",
                path: BackendRoute.health,
                method: "GET"
            )
            async let menu = performEndpointSelfCheck(
                name: "Menu",
                path: BackendRoute.menuCanonical,
                method: "GET"
            )
            async let location = performEndpointSelfCheck(
                name: "Smart Check-In",
                path: BackendRoute.smartCheckInCanonical,
                method: "POST",
                body: [:]
            )
            async let deletion = performEndpointSelfCheck(
                name: "Delete Account",
                path: BackendRoute.accountDeleteCanonical,
                method: "POST",
                body: [:]
            )
            async let status = performEndpointSelfCheck(
                name: "Loyalty Status",
                path: BackendRoute.loyaltyStatus,
                method: "GET",
                queryItems: [URLQueryItem(name: "phone", value: "+15555551234")]
            )

            let checks = await [health, menu, location, deletion, status]

            await MainActor.run {
                endpointSelfCheckResults = checks
                isRunningSelfCheck = false
            }
        }
    }

    private func performEndpointSelfCheck(
        name: String,
        path: [String],
        method: String,
        body: [String: Any]? = nil,
        queryItems: [URLQueryItem] = []
    ) async -> EndpointSelfCheckResult {
        var url = BackendRoute.url(for: path)
        if !queryItems.isEmpty {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            components?.queryItems = queryItems
            if let composed = components?.url {
                url = composed
            }
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])
        }
        _ = CMHTTP.applyAuthHeaders(&request)

        do {
            let (_, response) = try await CMHTTP.session.data(for: request)
            let statusCode = (response as? HTTPURLResponse)?.statusCode
            let statusValue = statusCode ?? -1
            let exists = statusValue != 404 && statusValue > 0
            let detail = exists ? "Route reachable (\(statusValue))" : "Route not found (404)"
            return EndpointSelfCheckResult(
                name: name,
                statusCode: statusCode,
                ok: exists,
                detail: detail
            )
        } catch {
            return EndpointSelfCheckResult(
                name: name,
                statusCode: nil,
                ok: false,
                detail: "Network error: \(error.localizedDescription)"
            )
        }
    }
#endif

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

                if smartCheckInEnabled && (location.authorization == .denied || location.authorization == .restricted) {
                    Button("Open iOS Settings") {
                        openSystemSettings()
                    }
                    .accessibilityIdentifier("settings.openSystemSettingsButton")
                }
            }

#if DEBUG
            // Extra internal diagnostics are hidden unless explicitly enabled via launch argument.
            if shouldShowInternalAPIDebugSection {
                Section("API Configuration (Debug)") {
                    Text("Active backend: \(AppConfig.backendBaseURL.absoluteString)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Text("Active auth mode: \(AppConfig.authHeaderMode == .bearer ? "Bearer token" : "x-api-key")")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Text("Active key status: \(activeAPIKeyStatusText)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    if AppConfig.hasRuntimeOverrides {
                        Text("Runtime overrides are currently enabled for this device.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    TextField("Runtime backend URL", text: $runtimeBackendURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .keyboardType(.URL)
                        .accessibilityIdentifier("settings.api.runtimeBackendField")

                    SecureField("Runtime API key/token", text: $runtimeAPIKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .accessibilityIdentifier("settings.api.runtimeKeyField")

                    Picker("Header Mode", selection: $runtimeAuthMode) {
                        Text("x-api-key").tag(AppConfig.AuthHeaderMode.apiKey)
                        Text("Bearer").tag(AppConfig.AuthHeaderMode.bearer)
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("settings.api.runtimeModePicker")

                    Button("Save Runtime API Settings") {
                        saveRuntimeAPIConfig()
                    }
                    .accessibilityIdentifier("settings.api.saveButton")

                    Button("Clear Runtime Overrides", role: .destructive) {
                        clearRuntimeAPIConfig()
                    }
                    .accessibilityIdentifier("settings.api.clearButton")

                    if let runtimeConfigError {
                        Text(runtimeConfigError)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .accessibilityIdentifier("settings.api.errorText")
                    }

                    if let runtimeConfigNotice {
                        Text(runtimeConfigNotice)
                            .font(.footnote)
                            .foregroundStyle(.green)
                            .accessibilityIdentifier("settings.api.noticeText")
                    }

                    Divider()

                    Button {
                        runEndpointSelfCheck()
                    } label: {
                        if isRunningSelfCheck {
                            Label("Running endpoint self-check…", systemImage: "hourglass")
                        } else {
                            Label("Run Endpoint Self-Check", systemImage: "checkmark.shield")
                        }
                    }
                    .disabled(isRunningSelfCheck)
                    .accessibilityIdentifier("settings.api.selfCheckButton")

                    if !endpointSelfCheckResults.isEmpty {
                        ForEach(endpointSelfCheckResults) { result in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: result.ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundStyle(result.ok ? .green : .red)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(result.name)
                                        .font(.subheadline.weight(.semibold))
                                    Text(result.detail)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                            .accessibilityIdentifier("settings.api.selfCheck.\(result.name)")
                        }
                    }
                }
            }
#endif

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
        .onAppear {
#if DEBUG
            if shouldShowInternalAPIDebugSection {
                loadRuntimeAPIConfigForm()
            }
#endif
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
            }

            Section {
                Text("Verification Requests")
                    .fontWeight(.semibold)

                Text("Verification requests are short-lived and used only to complete phone verification. Verification codes expire quickly and are not stored on your device.")
                    .foregroundStyle(.secondary)
                
                Text("Rewards lookup: when you check Rewards, your phone number is sent to our rewards service to retrieve your points and available rewards.")
                    .foregroundStyle(.secondary)
                
                Text("If you enable Smart Check-In, location samples are sent while using the app and are not retained as a local history on this device.")
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

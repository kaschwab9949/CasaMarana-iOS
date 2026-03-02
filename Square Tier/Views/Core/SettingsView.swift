import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var session: AppSession
    @State private var showEraseAlert = false

    // Optional privacy policy URL; set to a real URL to show the link.
    private let privacyPolicyURL = URL(string: "https://www.casamarana.com/privacypolicy")

    // Support links
    private let websiteURL = URL(string: "https://www.casamarana.com")!
    private let supportEmailURL = URL(string: "mailto:casacbw@gmail.com")!

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

            // 2) Account Operations
            if session.hasSetup {
                Section("Data Management") {
                    Button(role: .destructive) {
                        showEraseAlert = true
                    } label: {
                        Label("Erase Local Profile", systemImage: "trash")
                            .foregroundStyle(.red)
                    }
                    .accessibilityIdentifier("settings.eraseLocalProfileButton")
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
            }

            Section {
                Text("Verification Requests")
                    .fontWeight(.semibold)

                Text("Verification requests are short-lived and used only to complete phone verification. Verification codes expire quickly and are not stored on your device.")
                    .foregroundStyle(.secondary)
                
                Text("Rewards lookup: when you check Rewards, your phone number is sent to our rewards service to retrieve your points and available rewards.")
                    .foregroundStyle(.secondary)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Privacy & Data Use")
        .navigationBarTitleDisplayMode(.inline)
    }
}

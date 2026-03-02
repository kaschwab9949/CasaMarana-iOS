import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var session: AppSession
    @State private var draft: UserProfile = .empty
    @State private var savedToast: Bool = false
    @State private var phoneError: String? = nil

    var body: some View {
        List {
            Section("Customer") {
                TextField("Full name", text: $draft.fullName)
                if session.profile.isPhoneVerified {
                    HStack {
                        Text("Phone")
                        Spacer()
                        Text(session.profile.phoneE164)
                            .foregroundStyle(.secondary)
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                    }
                } else {
                    TextField("Phone", text: $draft.phoneE164)
                        .keyboardType(.phonePad)
                }
                TextField("Email", text: $draft.email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                TextField("Birthday", text: $draft.birthday)
            }

            Section {
                Button {
                    phoneError = nil

                    // US-only: allow customers to type 10 digits (e.g. 5555555555) and normalize to +1…
                    if !session.profile.isPhoneVerified {
                        let digits = draft.phoneE164.filter { $0.isNumber }
                        if digits.count == 10 {
                            draft.phoneE164 = "+1" + digits
                        } else if digits.count == 11, digits.hasPrefix("1") {
                            draft.phoneE164 = "+" + digits
                        } else if digits.isEmpty {
                            // allowed if not verified
                        } else {
                            phoneError = "Please enter a valid 10-digit US phone number."
                            return
                        }
                    }

                    session.updateProfile(draft)
                    savedToast = true

                    Task {
                        try? await Task.sleep(nanoseconds: 2_000_000_000)
                        savedToast = false
                    }
                } label: {
                    Text("Save Changes")
                        .frame(maxWidth: .infinity)
                }
            }

            if savedToast {
                Section {
                    Text("Saved")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            if let err = phoneError {
                Section {
                    Text(err)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
        }
        .onAppear {
            draft = session.profile
        }
    }
}

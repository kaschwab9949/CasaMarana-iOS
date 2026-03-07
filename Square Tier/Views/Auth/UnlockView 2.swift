import SwiftUI
import LocalAuthentication

struct UnlockView: View {
    @EnvironmentObject var session: AppSession
    @State private var pin: String = ""
    @State private var error: String? = nil

    @State private var isBiometricAvailable: Bool = false
    @State private var biometricSystemImage: String = ""
    @State private var biometricButtonTitle: String = ""

    private let loyaltyAPI = LoyaltyAPI()

    private func checkBiometricsAvailability() {
        let context = LAContext()
        var authError: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &authError) {
            isBiometricAvailable = true
            switch context.biometryType {
            case .faceID:
                biometricSystemImage = "faceid"
                biometricButtonTitle = "Unlock with Face ID"
            case .touchID:
                biometricSystemImage = "touchid"
                biometricButtonTitle = "Unlock with Touch ID"
            case .opticID:
                biometricSystemImage = "opticid"
                biometricButtonTitle = "Unlock with Optic ID"
            default:
                isBiometricAvailable = false
            }
        } else {
            isBiometricAvailable = false
        }
    }

    private func errorForPin(_ s: String) -> String? {
        if s.isEmpty { return nil }
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count == 4, trimmed.allSatisfy({ $0.isNumber }) else {
            return "PIN must be 4 digits"
        }
        return nil
    }

    var body: some View {
        VStack(spacing: 16) {
            AppBrandLogoView(height: 70)

            Text("Enter PIN")
                .font(.title2)
                .fontWeight(.semibold)

            SecureField("4-digit PIN", text: $pin)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.center)
                .frame(width: 150)
                .onChange(of: pin) { _, newValue in
                    let filtered = newValue.filter { $0.isNumber }
                    if filtered.count > 4 {
                        pin = String(filtered.prefix(4))
                    } else if filtered != newValue {
                        pin = filtered
                    }
                }

            if let e = error {
                Text(e)
                    .foregroundStyle(.red)
                    .font(.footnote)
            } else if let e = errorForPin(pin) {
                Text(e)
                    .foregroundStyle(.secondary)
                    .font(.footnote)
            }

            Button {
                if !session.unlock(pin: pin) {
                    error = "Incorrect PIN"
                    pin = ""
                }
            } label: {
                Text("Unlock")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal)

            if isBiometricAvailable {
                Button {
                    Task { _ = await session.unlockWithBiometrics() }
                } label: {
                    Label(biometricButtonTitle, systemImage: biometricSystemImage)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .padding(.horizontal)
            }

            Spacer()

            Text("Notice: Square customer profiles without phone numbers cannot be loaded until verified.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()
        }
        .padding(.top, 40)
        .onAppear {
            checkBiometricsAvailability()
        }
    }
}

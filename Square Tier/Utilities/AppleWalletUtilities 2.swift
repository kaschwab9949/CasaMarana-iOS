import SwiftUI
import PassKit
import UIKit

/// Native "Add to Apple Wallet" badge.
struct AddToWalletButton: UIViewRepresentable {
    let action: () -> Void

    func makeUIView(context: Context) -> PKAddPassButton {
        let button = PKAddPassButton(addPassButtonStyle: .black)
        button.addTarget(context.coordinator, action: #selector(Coordinator.tapped), for: .touchUpInside)
        return button
    }

    func updateUIView(_ uiView: PKAddPassButton, context: Context) {
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(action: action)
    }

    final class Coordinator: NSObject {
        let action: () -> Void
        init(action: @escaping () -> Void) { self.action = action }
        @objc func tapped() { action() }
    }
}

/// Presents the system UI to add a pass to Apple Wallet.
struct AddPassesPresenter: UIViewControllerRepresentable {
    let pass: PKPass
    let onFinish: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onFinish: onFinish)
    }

    func makeUIViewController(context: Context) -> PKAddPassesViewController {
        guard let controller = PKAddPassesViewController(pass: pass) else {
            // Fallback: return an empty controller (should never happen with a valid pass).
            return PKAddPassesViewController()
        }
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: PKAddPassesViewController, context: Context) {}

    final class Coordinator: NSObject, PKAddPassesViewControllerDelegate {
        let onFinish: () -> Void
        init(onFinish: @escaping () -> Void) { self.onFinish = onFinish }

        func addPassesViewControllerDidFinish(_ controller: PKAddPassesViewController) {
            controller.dismiss(animated: true) {
                self.onFinish()
            }
        }
    }
}

/// Optional fallback: if you don't have a backend pass endpoint yet,
/// you can include a signed `.pkpass` in the app bundle and load it.
enum WalletPassBundleFallback {
    static let candidateFilenames: [String] = [
        "casa-marana-loyalty.pkpass",
        "casamarana-loyalty.pkpass",
        "loyalty.pkpass"
    ]

    static func loadBundledPassData() -> Data? {
        for filename in candidateFilenames {
            let url = URL(fileURLWithPath: filename)
            let ext = url.pathExtension
            let name = url.deletingPathExtension().lastPathComponent

            if let path = Bundle.main.path(forResource: name, ofType: ext),
               let data = try? Data(contentsOf: URL(fileURLWithPath: path)) {
                return data
            }
        }
        return nil
    }
}

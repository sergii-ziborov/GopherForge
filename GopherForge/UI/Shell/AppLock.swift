import LocalAuthentication
import SwiftUI

/// Face ID or the device passcode, used only when the owner turns it on.
enum AppLock {
    static let storageKey = "requireFaceID"

    static func authenticate() async -> Bool {
        let context = LAContext()
        var error: NSError?
        let policy: LAPolicy = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
            ? .deviceOwnerAuthenticationWithBiometrics
            : .deviceOwnerAuthentication
        guard context.canEvaluatePolicy(policy, error: &error) else { return false }
        return await withCheckedContinuation { continuation in
            context.evaluatePolicy(policy, localizedReason: "Unlock GopherForge") { success, _ in
                continuation.resume(returning: success)
            }
        }
    }
}

struct AppLockCover: View {
    let unlock: () async -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "faceid")
                    .font(.system(size: 48))
                    .foregroundStyle(.white)
                Text("GopherForge is locked")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                Button("Unlock") { Task { await unlock() } }
                    .buttonStyle(.borderedProminent)
            }
        }
        .accessibilityIdentifier("lock.cover")
    }
}

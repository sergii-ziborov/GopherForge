import UIKit
import SwiftUI

private struct SoftwareKeyboardAccessoryEnabledKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    /// A hardware keyboard does not need the touch-only command strip. Keep
    /// this independent of focus: dismissing the keyboard must not re-enable
    /// an accessory and start a reloadInputViews show/hide cycle.
    var softwareKeyboardAccessoryEnabled: Bool {
        get { self[SoftwareKeyboardAccessoryEnabledKey.self] }
        set { self[SoftwareKeyboardAccessoryEnabledKey.self] = newValue }
    }
}

/// Keep a presentation accessory while the Duo helper row is hosted below
/// the hinge. This follows Crabrix's responder setup without duplicating its
/// visible helper row inside the keyboard.
final class KeyboardPresentationAccessoryView: UIView {
    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: 1)
    }
}

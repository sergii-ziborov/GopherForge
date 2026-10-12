import UIKit

/// Keep a presentation accessory while the Duo helper row is hosted below
/// the hinge. This follows Crabrix's responder setup without duplicating its
/// visible helper row inside the keyboard.
final class KeyboardPresentationAccessoryView: UIView {
    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: 1)
    }
}

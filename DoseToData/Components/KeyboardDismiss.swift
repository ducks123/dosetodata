import SwiftUI

extension View {
    /// Dismisses the keyboard when the user taps anywhere outside a text
    /// field. Child controls (buttons, toggles, fields) still receive their
    /// taps first — only otherwise-unhandled taps resign focus.
    func dismissKeyboardOnTap() -> some View {
        onTapGesture {
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder),
                to: nil, from: nil, for: nil
            )
        }
    }
}

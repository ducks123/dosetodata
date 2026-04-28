import Foundation

/// URLs surfaced in Settings → About. Update these in one place when the
/// hosted documents move.
///
/// NOTE FOR FIRST SUBMISSION: replace the placeholder URLs below with real,
/// publicly accessible pages before archiving for App Review. App Store Connect
/// also requires the privacy policy URL and the support URL in the listing
/// form — use the same URLs there for consistency.
enum LegalLinks {
    /// Public privacy policy. Required by App Review for any app.
    static let privacyPolicy = URL(string: "https://ducks123.github.io/dosetodata/privacy-policy.html")!

    /// Public terms of service. Recommended but not strictly required.
    static let termsOfService = URL(string: "https://ducks123.github.io/dosetodata/terms.html")!

    /// Support/contact page. Required by App Review. Can be a simple one-pager
    /// listing the support email.
    static let support = URL(string: "https://ducks123.github.io/dosetodata/support.html")!

    /// Direct support email, used for the "Email support" row.
    static let supportEmail = "stewartsherpa1@gmail.com"

    /// Builds a mailto: URL with a subject line that includes the app version
    /// so inbound reports are easier to triage.
    static func supportMailtoURL(appVersion: String) -> URL {
        let subject = "DoseToData support (v\(appVersion))"
        let encoded = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? subject
        return URL(string: "mailto:\(supportEmail)?subject=\(encoded)")!
    }
}

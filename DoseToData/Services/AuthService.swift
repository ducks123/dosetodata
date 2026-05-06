import Foundation
import Observation
import Supabase
import Auth
import AuthenticationServices
import CryptoKit

/// Application-facing wrapper around Supabase Auth. Turns the SDK's
/// callback-driven session model into a simple state machine that
/// SwiftUI views can observe.
///
/// Flow:
///   signedOut → [signInWithOTP(email:)] → awaitingOTP(email)
///   awaitingOTP → [verifyOTP(email:,token:)] → signedIn(user)
///   signedIn → [signOut()] → signedOut
///
/// On launch we start in `.checking` while the SDK rehydrates any
/// persisted session from the keychain, then flip to either
/// `.signedIn` or `.signedOut` based on what comes back.
@MainActor
@Observable
final class AuthService {
    enum State: Equatable {
        case checking
        case signedOut
        /// Email was submitted; waiting for the user to paste the 6-digit code.
        case awaitingOTP(email: String)
        case signedIn(user: User)

        static func == (lhs: State, rhs: State) -> Bool {
            switch (lhs, rhs) {
            case (.checking, .checking), (.signedOut, .signedOut):
                return true
            case let (.awaitingOTP(l), .awaitingOTP(r)):
                return l == r
            case let (.signedIn(l), .signedIn(r)):
                return l.id == r.id
            default:
                return false
            }
        }
    }

    /// Published state machine. Views read this to decide what to render.
    private(set) var state: State = .checking

    /// Surface-level error message for the UI to show after a failed call.
    /// Reset to `nil` at the start of every new call so stale errors don't
    /// linger across retries.
    private(set) var errorMessage: String?

    /// `true` while an in-flight network call is running. Views can bind
    /// this to disable the submit button and show a spinner.
    private(set) var isBusy: Bool = false

    private var authListenerTask: Task<Void, Never>?

    init() {
        startListening()
    }

    // No explicit deinit: the listener task captures `self` weakly and
    // will short-circuit once this service is deallocated. `deinit` on a
    // `@MainActor`-isolated class is nonisolated, so it can't touch
    // `authListenerTask` anyway.

    // MARK: - State observation

    /// Subscribes to the SDK's auth-state stream. The first event is always
    /// `.initialSession` — that tells us whether there's a valid keychain
    /// session to rehydrate. Subsequent events keep us in sync if the
    /// session refreshes or expires while the app is running.
    private func startListening() {
        let stream = SupabaseService.client.auth.authStateChanges
        authListenerTask = Task { [weak self] in
            for await (event, session) in stream {
                guard let self else { return }
                self.handle(event: event, session: session)
            }
        }
    }

    private func handle(event: AuthChangeEvent, session: Session?) {
        switch event {
        case .initialSession:
            if let user = session?.user {
                state = .signedIn(user: user)
            } else {
                state = .signedOut
            }
        case .signedIn, .tokenRefreshed, .userUpdated:
            if let user = session?.user {
                state = .signedIn(user: user)
            }
        case .signedOut, .userDeleted:
            state = .signedOut
        case .passwordRecovery, .mfaChallengeVerified:
            // Not used in this app's flow; leave state untouched.
            break
        }
    }

    // MARK: - Public actions

    /// Sends a one-time 6-digit code to the given email. On success the
    /// state advances to `.awaitingOTP` so the view can prompt for the code.
    func signInWithOTP(email: String) async {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "Please enter your email address."
            return
        }

        isBusy = true
        errorMessage = nil
        defer { isBusy = false }

        do {
            try await SupabaseService.client.auth.signInWithOTP(email: trimmed)
            state = .awaitingOTP(email: trimmed)
        } catch {
            errorMessage = friendlyMessage(from: error)
        }
    }

    /// Verifies the 6-digit code the user just received. On success the
    /// auth-state listener flips us to `.signedIn`; we don't set the state
    /// here because the SDK emits `.signedIn` before this call returns.
    func verifyOTP(email: String, token: String) async {
        let trimmedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedToken.isEmpty else {
            errorMessage = "Please enter the 6-digit code from your email."
            return
        }

        isBusy = true
        errorMessage = nil
        defer { isBusy = false }

        do {
            _ = try await SupabaseService.client.auth.verifyOTP(
                email: email,
                token: trimmedToken,
                type: .email
            )
            // The auth listener will move state to `.signedIn` when it gets
            // the `.signedIn` event from the SDK. No explicit assignment here.
        } catch {
            errorMessage = friendlyMessage(from: error)
        }
    }

    /// Jumps back to the email pane if the user mistyped it. Cheap local
    /// state change — doesn't need to call the server.
    func cancelOTP() {
        state = .signedOut
        errorMessage = nil
    }

    /// Signs out on this device only. Other devices with the same account
    /// remain signed in.
    func signOut() async {
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }

        do {
            try await SupabaseService.client.auth.signOut(scope: .local)
            // Auth listener will flip state to `.signedOut`.
        } catch {
            errorMessage = friendlyMessage(from: error)
        }
    }

    /// Permanently deletes the current user's account via the
    /// `public.delete_current_user()` RPC. That function runs with
    /// `security definer` so it can reach into `auth.users` and remove
    /// the row; we sign out locally afterward.
    func deleteAccount() async {
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }

        do {
            try await SupabaseService.client.rpc("delete_current_user").execute()
            // The server-side row is gone; also clear the local session so
            // the keychain doesn't hold onto a dead refresh token.
            try? await SupabaseService.client.auth.signOut(scope: .local)
            state = .signedOut
        } catch {
            errorMessage = friendlyMessage(from: error)
        }
    }

    // MARK: - Sign in with Apple

    /// Nonce stashed between "start the SIWA request" and "got the
    /// credential back." Apple signs the nonce into the identity token
    /// so Supabase can verify the token really came from us — which
    /// means we need the raw (unhashed) value at exchange time.
    private var currentAppleNonce: String?

    /// Produces a fresh nonce and returns the SHA-256 hash of it for the
    /// ASAuthorizationAppleIDRequest. We keep the raw value on `self` so
    /// `completeSignInWithApple(authorization:)` can hand it to Supabase.
    func prepareAppleSignInRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = Self.randomNonceString()
        currentAppleNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce)
    }

    /// Exchanges the Apple identity token for a Supabase session. Called
    /// from the `SignInWithAppleButton` completion handler in `AuthSheet`.
    func completeSignInWithApple(result: Result<ASAuthorization, Error>) async {
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }

        switch result {
        case .failure(let error):
            // User-cancelled shows up as ASAuthorizationError.canceled —
            // no error surface needed, they just tapped Cancel.
            if let asError = error as? ASAuthorizationError, asError.code == .canceled {
                return
            }
            errorMessage = friendlyMessage(from: error)

        case .success(let authorization):
            guard
                let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                let tokenData = credential.identityToken,
                let idToken = String(data: tokenData, encoding: .utf8),
                let nonce = currentAppleNonce
            else {
                errorMessage = "Apple sign-in didn't return a usable token. Try again."
                return
            }

            do {
                _ = try await SupabaseService.client.auth.signInWithIdToken(
                    credentials: .init(provider: .apple, idToken: idToken, nonce: nonce)
                )
                // Auth listener will flip state to .signedIn.
            } catch {
                errorMessage = friendlyMessage(from: error)
            }
            currentAppleNonce = nil
        }
    }

    // MARK: - Sign in with Google

    /// Kicks off the Google OAuth flow via ASWebAuthenticationSession.
    /// Supabase builds the authorization URL and redirects back to our
    /// `dosetodata://auth-callback` scheme when Google is done. The SDK
    /// then exchanges the code for a session on our behalf.
    func signInWithGoogle() async {
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }

        do {
            try await SupabaseService.client.auth.signInWithOAuth(
                provider: .google,
                redirectTo: URL(string: "dosetodata://auth-callback")
            )
            // On success the SDK handles the callback URL internally and
            // the auth listener flips us to .signedIn.
        } catch {
            // Cancelling the ASWebAuthenticationSession throws; swallow
            // that so we don't show a scary error for "user tapped X."
            if (error as NSError).code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                return
            }
            errorMessage = friendlyMessage(from: error)
        }
    }

    /// Handles incoming OAuth redirect URLs from SFSafariViewController /
    /// ASWebAuthenticationSession when the app is backgrounded mid-flow.
    /// Called from `DoseToDataApp`'s `.onOpenURL`.
    func handleOpenURL(_ url: URL) {
        Task {
            do {
                try await SupabaseService.client.auth.session(from: url)
            } catch {
                errorMessage = friendlyMessage(from: error)
            }
        }
    }

    // MARK: - Nonce helpers

    /// Cryptographically random 32-char alphanumeric string. Used as the
    /// nonce seed for SIWA — Apple signs a SHA-256 of this into the ID
    /// token so Supabase can confirm the token was minted for this request.
    private static func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length
        while remaining > 0 {
            var randoms = [UInt8](repeating: 0, count: 16)
            let status = SecRandomCopyBytes(kSecRandomDefault, randoms.count, &randoms)
            if status != errSecSuccess {
                // Fall back to arc4random if SecRandom is unavailable;
                // highly unlikely in practice but avoids a crash.
                randoms = (0..<16).map { _ in UInt8.random(in: 0...255) }
            }
            for random in randoms where remaining > 0 {
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remaining -= 1
                }
            }
        }
        return result
    }

    private static func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let hashed = SHA256.hash(data: data)
        return hashed.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Error shaping

    /// Turns SDK errors into something safe to show the user. Supabase's
    /// `localizedDescription` is usually fine, but network errors can leak
    /// URLs or technical jargon — we prefer a short generic message in
    /// those cases.
    private func friendlyMessage(from error: Error) -> String {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            return "Network problem. Check your connection and try again."
        }
        return error.localizedDescription
    }
}

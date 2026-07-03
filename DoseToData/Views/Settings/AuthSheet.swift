import SwiftUI
import Auth
import AuthenticationServices

/// Sheet that walks the user through the passwordless email-OTP flow:
///
///   1. Enter email, tap Send code → Supabase emails a 6-digit code.
///   2. Enter the 6-digit code → on success, the sheet shows a "You're in"
///      confirmation and auto-dismisses after a beat.
///
/// The sheet never shows a signed-in landing state for longer than a
/// moment; long-lived account management lives in SettingsView.
struct AuthSheet: View {
    @Environment(AuthService.self) private var auth
    @Environment(\.dismiss) private var dismiss

    @State private var emailDraft: String = ""
    @State private var codeDraft: String = ""
    @FocusState private var focusedField: Field?

    private enum Field {
        case email
        case code
    }

    var body: some View {
        NavigationStack {
            Group {
                switch auth.state {
                case .checking, .signedOut:
                    emailPane
                case .awaitingOTP(let email):
                    codePane(email: email)
                case .signedIn:
                    signedInPane
                }
            }
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .onChange(of: auth.state) { _, newState in
            // When the listener flips us to signedIn, give the user a
            // moment to see the confirmation, then close the sheet.
            if case .signedIn = newState {
                Task {
                    try? await Task.sleep(nanoseconds: 1_200_000_000)
                    dismiss()
                }
            }
        }
    }

    // MARK: - Panes

    /// Step 1 — collect the email address.
    private var emailPane: some View {
        Form {
            Section {
                VStack(spacing: 12) {
                    // Apple is required per App Store Guideline 4.8 whenever
                    // any third-party sign-in is offered. It renders with
                    // native styling — we don't wrap it in PrimaryButtonStyle.
                    SignInWithAppleButton(.continue) { request in
                        auth.prepareAppleSignInRequest(request)
                    } onCompletion: { result in
                        Task { await auth.completeSignInWithApple(result: result) }
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .disabled(auth.isBusy)

                    Button {
                        Task { await auth.signInWithGoogle() }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "globe")
                            Text("Continue with Google")
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 50)
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(UIColor.separator), lineWidth: 0.5)
                        )
                    }
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .disabled(auth.isBusy)
                }
                .padding(.vertical, 8)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            Section {
                HStack {
                    VStack { Divider() }
                    Text("or continue with email")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Palette.textSecondary)
                    VStack { Divider() }
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            Section {
                TextField("you@example.com", text: $emailDraft)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .email)
                    .submitLabel(.send)
                    .onSubmit { Task { await sendCode() } }
            } header: {
                Text("Your email")
            } footer: {
                Text("We'll email you a 6-digit code. No password to remember.")
            }

            if let message = auth.errorMessage {
                Section {
                    Text(message)
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Palette.negative)
                }
            }

            Section {
                Button {
                    Task { await sendCode() }
                } label: {
                    HStack {
                        if auth.isBusy {
                            ProgressView().controlSize(.small)
                        }
                        Text(auth.isBusy ? "Sending…" : "Send code")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(auth.isBusy || emailDraft.trimmingCharacters(in: .whitespaces).isEmpty)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Label("About your account", systemImage: "person.circle")
                        .font(Theme.Font.bodyEmphasis)
                    Text("Signing in links your account to this device. Your data is stored locally — deleting the app will erase your history.")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Palette.textSecondary)
                    Text("You can delete your account any time from Settings.")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Palette.textSecondary)
                }
                .padding(.vertical, 4)
            }
        }
    }

    /// Step 2 — collect the 6-digit code.
    private func codePane(email: String) -> some View {
        Form {
            Section {
                TextField("123456", text: $codeDraft)
                    .textContentType(.oneTimeCode)
                    .keyboardType(.numberPad)
                    .focused($focusedField, equals: .code)
                    .onChange(of: codeDraft) { _, new in
                        // Keep to digits only; auto-submit when we hit 6.
                        let digits = new.filter(\.isNumber)
                        if digits != new { codeDraft = digits }
                        if digits.count == 6 {
                            Task { await verifyCode(email: email) }
                        }
                    }
            } header: {
                Text("Enter the 6-digit code")
            } footer: {
                Text("Sent to \(email). Check your spam folder if it doesn't arrive within a minute.")
            }

            if let message = auth.errorMessage {
                Section {
                    Text(message)
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Palette.negative)
                }
            }

            Section {
                Button {
                    Task { await verifyCode(email: email) }
                } label: {
                    HStack {
                        if auth.isBusy {
                            ProgressView().controlSize(.small)
                        }
                        Text(auth.isBusy ? "Verifying…" : "Verify")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(auth.isBusy || codeDraft.count < 6)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)

                Button("Use a different email") {
                    auth.cancelOTP()
                    codeDraft = ""
                }
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Palette.textSecondary)

                Button {
                    Task { await auth.signInWithOTP(email: email) }
                } label: {
                    Text("Resend code")
                        .font(Theme.Font.caption)
                }
                .disabled(auth.isBusy)
            }
        }
        .onAppear { focusedField = .code }
    }

    /// Success state that auto-dismisses after a short delay.
    private var signedInPane: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(Theme.Palette.success)
            Text("You're signed in")
                .font(Theme.Font.sectionTitle)
            Text("Your account is linked to this device. Your check-ins and medications stay on your phone.")
                .font(Theme.Font.body)
                .foregroundStyle(Theme.Palette.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Palette.background)
    }

    // MARK: - Actions

    private func sendCode() async {
        focusedField = nil
        await auth.signInWithOTP(email: emailDraft)
    }

    private func verifyCode(email: String) async {
        focusedField = nil
        await auth.verifyOTP(email: email, token: codeDraft)
    }
}

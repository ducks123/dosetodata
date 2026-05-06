import SwiftUI
import RevenueCat

struct SettingsView: View {
    @Environment(AuthService.self) private var auth
    @Environment(SubscriptionService.self) private var sub
    @Environment(\.dismiss) private var dismiss

    @State private var showAuthSheet = false
    @State private var showSignOutConfirm = false
    @State private var showDeleteConfirm = false
    @State private var showPaywall = false
    @State private var wasSignedIn = false

    var body: some View {
        NavigationStack {
            List {
                // MARK: - Account
                Section("Account") {
                    switch auth.state {
                    case .checking:
                        HStack(spacing: 8) {
                            ProgressView().controlSize(.small)
                            Text("Checking sign-in…")
                                .foregroundStyle(Theme.Palette.textSecondary)
                        }
                    case .signedOut, .awaitingOTP:
                        Button("Sign in") {
                            showAuthSheet = true
                        }
                    case .signedIn(let user):
                        LabeledContent("Email") {
                            Text(user.email ?? "—")
                                .foregroundStyle(Theme.Palette.textSecondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                }

                // MARK: - Sign out / Delete (only when signed in)
                if case .signedIn = auth.state {
                    Section {
                        Button("Sign out") {
                            showSignOutConfirm = true
                        }
                        Button("Delete account", role: .destructive) {
                            showDeleteConfirm = true
                        }
                    }
                }

                // MARK: - Subscription
                Section("Subscription") {
                    HStack {
                        Text("Status")
                        Spacer()
                        Text(subscriptionStatusLabel)
                            .foregroundStyle(subscriptionStatusColor)
                            .font(.system(size: 14, weight: .medium))
                    }

                    switch sub.status {
                    case .expired:
                        Button("Upgrade to Premium") {
                            showPaywall = true
                        }
                        .foregroundStyle(Theme.Palette.primary)
                    case .trial, .loading:
                        Button("View Plans") {
                            showPaywall = true
                        }
                        .foregroundStyle(Theme.Palette.primary)
                    case .active:
                        EmptyView()
                    }

                    Button("Restore purchases") {
                        Task { try? await sub.restorePurchases() }
                    }
                    .foregroundStyle(Theme.Palette.textSecondary)
                }

                // MARK: - About
                Section("About") {
                    LabeledContent("Version", value: appVersion)
                    Link(destination: LegalLinks.supportMailtoURL(appVersion: appVersion)) {
                        Label("Email support", systemImage: "envelope")
                    }
                    Link(destination: LegalLinks.support) {
                        Label("Support page", systemImage: "questionmark.circle")
                    }
                    Link(destination: LegalLinks.privacyPolicy) {
                        Label("Privacy policy", systemImage: "hand.raised")
                    }
                    Link(destination: LegalLinks.termsOfService) {
                        Label("Terms of service", systemImage: "doc.text")
                    }
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showAuthSheet) {
                AuthSheet()
            }
            .confirmationDialog(
                "Sign out of this device?",
                isPresented: $showSignOutConfirm,
                titleVisibility: .visible
            ) {
                Button("Sign out", role: .destructive) {
                    Task { await auth.signOut() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Your data stays on this device. You can sign back in any time.")
            }
            .confirmationDialog(
                "Delete your account?",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete account", role: .destructive) {
                    Task { await auth.deleteAccount() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently deletes your account and all synced data from our servers. Data on this device is not removed.")
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
                    .environment(sub)
            }
            .onAppear {
                if case .signedIn = auth.state { wasSignedIn = true }
                Task { await sub.refresh() }
            }
            .onChange(of: auth.state) { _, newState in
                if wasSignedIn, case .signedOut = newState {
                    showAuthSheet = true
                    wasSignedIn = false
                }
                if case .signedIn = newState { wasSignedIn = true }
            }
        }
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(v) (\(b))"
    }

    private var subscriptionStatusLabel: String {
        switch sub.status {
        case .loading:  return "Checking…"
        case .active:   return "Active"
        case .expired:  return "Trial ended"
        case .trial(let days):
            return days == 1 ? "Trial — 1 day left" : "Trial — \(days) days left"
        }
    }

    private var subscriptionStatusColor: Color {
        switch sub.status {
        case .loading:  return Theme.Palette.textSecondary
        case .active:   return Theme.Palette.success
        case .expired:  return Theme.Palette.negative
        case .trial:    return Theme.Palette.attention
        }
    }
}

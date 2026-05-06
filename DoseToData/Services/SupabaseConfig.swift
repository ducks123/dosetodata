import Foundation

/// Project credentials for the Supabase backend that powers optional
/// account sync. The URL and publishable key are safe to ship in the
/// binary — both are designed to be client-visible. Row-level security
/// on the Postgres side is what actually protects user data, not this key.
enum SupabaseConfig {
    static let url = URL(string: "https://rgnazoaeoyhezhkezmpx.supabase.co")!
    static let publishableKey = "sb_publishable_gx36Z-nZ7sc5U2xLNPHeDA_jlKC7fAb"
}

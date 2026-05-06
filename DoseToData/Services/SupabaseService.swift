import Foundation
import Supabase

/// Process-wide singleton for the Supabase client. The SDK expects you to
/// hold a single client for the lifetime of the app; new instances would
/// each spin up their own realtime socket and auth refresh loop.
///
/// The client is lazily constructed on first access, so launching the app
/// without ever opening the sync sheet is essentially free.
enum SupabaseService {
    static let client: SupabaseClient = {
        SupabaseClient(
            supabaseURL: SupabaseConfig.url,
            supabaseKey: SupabaseConfig.publishableKey,
            options: SupabaseClientOptions(
                auth: SupabaseClientOptions.AuthOptions(
                    storage: KeychainLocalStorage(),
                    autoRefreshToken: true
                )
            )
        )
    }()
}

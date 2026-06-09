import SwiftUI
import SwiftData
import UserNotifications
import RevenueCat

@main
struct DoseToDataApp: App {
    @State private var appState = AppState()
    @State private var userPreferences = UserPreferences()
    @State private var auth = AuthService()
    @State private var subscriptionService = SubscriptionService()

    let sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Medication.self,
            UserMedication.self,
            MedEvent.self,
            MoodEntry.self,
            SideEffectEntry.self,
            Test.self,
            ScaleResponse.self,
            DailyCheckIn.self,
            CustomCheckInQuestion.self,
            MedAdherenceLog.self,
            MedChangeEvent.self,
            MedAction.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            // Migration failure — wipe every possible SwiftData store location and
            // try again. SwiftData can place the store in Application Support or
            // Documents depending on the iOS version; we sweep both. SQLite WAL/SHM
            // journal files use a hyphen suffix (default.store-wal, default.store-shm),
            // NOT a dotted extension, so we match by prefix.
            let fm = FileManager.default
            let searchDirs: [URL] = [
                fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first,
                fm.urls(for: .documentDirectory, in: .userDomainMask).first,
            ].compactMap { $0 }

            for dir in searchDirs {
                guard let contents = try? fm.contentsOfDirectory(
                    at: dir, includingPropertiesForKeys: nil
                ) else { continue }
                for url in contents where
                    url.lastPathComponent.hasPrefix("default.store") ||
                    url.lastPathComponent.hasSuffix(".sqlite") ||
                    url.lastPathComponent.hasSuffix(".sqlite-wal") ||
                    url.lastPathComponent.hasSuffix(".sqlite-shm") {
                    try? fm.removeItem(at: url)
                }
            }

            // Retry persistent store after cleanup.
            if let container = try? ModelContainer(for: schema, configurations: [config]) {
                return container
            }
            // Last resort: in-memory store so the app always opens.
            // Data won't persist this session but there's no crash.
            let memConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            if let memContainer = try? ModelContainer(for: schema, configurations: [memConfig]) {
                return memContainer
            }
            fatalError("Could not create any ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .environment(userPreferences)
                .environment(auth)
                .environment(subscriptionService)
                .task {
                    await subscriptionService.refresh()
                    MedicationSeeder.seedIfNeeded(context: sharedModelContainer.mainContext)
                    // One-shot migration to retire the legacy Test feature:
                    // any test still marked active gets ended as of today.
                    // Guarded by a UserDefaults flag so it only runs once
                    // ever per device. Test records and history are kept —
                    // they still render as historical chart markers on
                    // Insights — but they no longer count as "active."
                    TestRetirementMigration.runIfNeeded(
                        context: sharedModelContainer.mainContext
                    )
                    // Register notification quick-action category and set the delegate
                    // so "Took it" / "Skip today" actions are handled immediately.
                    NotificationDelegate.shared.modelContainer = sharedModelContainer
                    UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
                    ReminderManager.shared.setupNotificationCategories()
                }
                // Google OAuth returns via the `dosetodata://` scheme. We
                // hand the URL to AuthService which passes it to the
                // Supabase SDK to exchange the code for a session.
                .onOpenURL { url in
                    auth.handleOpenURL(url)
                }
        }
        .modelContainer(sharedModelContainer)
    }
}

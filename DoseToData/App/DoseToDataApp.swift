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
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            // Migration failure — wipe the store and start fresh rather than crashing.
            // This is acceptable during beta; user data for this session is lost but
            // the app no longer hard-crashes on schema changes.
            let storeURL = URL.applicationSupportDirectory.appending(path: "default.store")
            for ext in ["", ".wal", "-wal", ".shm", "-shm"] {
                let url = storeURL.appendingPathExtension(ext.isEmpty ? "" : ext).standardized
                try? FileManager.default.removeItem(at: url)
            }
            // Also try without extension in case the filename is different
            try? FileManager.default.removeItem(at: storeURL)
            do {
                return try ModelContainer(for: schema, configurations: [config])
            } catch {
                fatalError("Could not create ModelContainer even after reset: \(error)")
            }
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

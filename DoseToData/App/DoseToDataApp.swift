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
            // Store failed to open (migration bug, transient FS error, locked
            // file, partial restore, SwiftData regression, …). The on-disk
            // store is the user's ONLY copy of their health data, so we must
            // NOT delete it. Instead QUARANTINE it: move the store files aside
            // into a timestamped backup folder so they remain recoverable,
            // then retry with a fresh store so the app still launches. (The
            // earlier implementation hard-deleted the store, which could
            // silently and permanently erase years of history — see C1.)
            //
            // SwiftData can place the store in Application Support or Documents
            // depending on the iOS version; we check both.
            let fm = FileManager.default
            let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            let documents = fm.urls(for: .documentDirectory, in: .userDomainMask).first
            let searchDirs: [URL] = [appSupport, documents].compactMap { $0 }
            let quarantineRoot = appSupport
                ?? documents
                ?? fm.temporaryDirectory
            let now = Date()

            let quarantined = SwiftDataStoreRecovery.quarantineStoreFiles(
                in: searchDirs,
                quarantineRoot: quarantineRoot,
                timestamp: now
            )
            SwiftDataStoreRecovery.recordQuarantine(quarantined, timestamp: now)

            // Retry persistent store after quarantine (fresh, empty store).
            if let container = try? ModelContainer(for: schema, configurations: [config]) {
                return container
            }
            // Last resort: in-memory store so the app always opens. Data won't
            // persist this session, but the quarantined store on disk is
            // untouched and recoverable.
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

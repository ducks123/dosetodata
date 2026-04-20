import SwiftUI
import SwiftData

@main
struct DoseToDataApp: App {
    @State private var appState = AppState()

    let sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Medication.self,
            UserMedication.self,
            MedEvent.self,
            MoodEntry.self,
            SideEffectEntry.self,
            Test.self,
            ScaleResponse.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .task {
                    MedicationSeeder.seedIfNeeded(context: sharedModelContainer.mainContext)
                }
        }
        .modelContainer(sharedModelContainer)
    }
}

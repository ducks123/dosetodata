import Foundation
import SwiftData

/// One-shot migration that retires the legacy `Test` feature when the user
/// updates to the medication-change build (1.0.2 / Build 81).
///
/// What it does:
/// - Finds every `Test` record with `actualEndDate == nil` (i.e. still
///   marked as an active in-progress test).
/// - Sets `actualEndDate` to "now" so the test reads as ended.
/// - Leaves all other Test fields (start date, watching-for note, scale
///   responses) untouched — the data is preserved for historical chart
///   markers on Insights.
/// - Records a `UserDefaults` flag so the migration only runs once per
///   device, even across app launches.
///
/// What it does NOT do:
/// - Delete any Test data.
/// - Convert tests into MedChangeEvents (the data model is too different
///   to migrate cleanly, and old tests are still useful as raw markers).
enum TestRetirementMigration {
    /// UserDefaults key. Versioned so future cutovers can re-use the
    /// pattern without colliding.
    private static let didRunKey = "dosetodata.migration.testRetirement.v1"

    static func runIfNeeded(context: ModelContext) {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: didRunKey) else { return }

        do {
            let descriptor = FetchDescriptor<Test>(
                predicate: #Predicate { $0.actualEndDate == nil }
            )
            let activeTests = try context.fetch(descriptor)
            let now = Date()
            for test in activeTests {
                test.actualEndDate = now
            }
            try context.save()
        } catch {
            // If the migration fails (e.g. SwiftData hiccup), don't flip the
            // flag — we'll retry on the next launch. Best-effort but safe.
            return
        }

        defaults.set(true, forKey: didRunKey)
    }
}

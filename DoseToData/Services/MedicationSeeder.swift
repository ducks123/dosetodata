import Foundation
import SwiftData

enum MedicationSeeder {
    /// Legacy one-shot flag from the original v1 seeding.
    private static let seededFlagKey = "dosetodata.medLibrary.seeded.v1"
    /// Version-based additive seeding. Bump `currentSeedVersion` whenever
    /// MedicationLibrary.json gains entries: on next launch, any library med
    /// not already present (matched by brandName, case-insensitive) is
    /// inserted. Existing meds, user edits, and custom medications are never
    /// touched.
    private static let seedVersionKey = "dosetodata.medLibrary.seedVersion"
    private static let currentSeedVersion = 2

    struct LibraryEntry: Decodable {
        let brandName: String
        let genericName: String
        let medClass: String
        let category: String
        let commonDoses: [String]
        let commonSideEffects: [String]
        let isExtendedRelease: Bool
    }

    static func seedIfNeeded(context: ModelContext) {
        let defaults = UserDefaults.standard
        var storedVersion = defaults.integer(forKey: seedVersionKey)
        // Migrate the legacy boolean flag to version 1.
        if storedVersion == 0, defaults.bool(forKey: seededFlagKey) {
            storedVersion = 1
        }
        guard storedVersion < currentSeedVersion else { return }

        guard let url = Bundle.main.url(forResource: "MedicationLibrary", withExtension: "json") else {
            assertionFailure("MedicationLibrary.json missing from bundle")
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let entries = try JSONDecoder().decode([LibraryEntry].self, from: data)
            let existingMeds = (try? context.fetch(FetchDescriptor<Medication>())) ?? []
            let existingBrands = Set(existingMeds.map { $0.brandName.lowercased() })

            var inserted = 0
            for entry in entries where !existingBrands.contains(entry.brandName.lowercased()) {
                let category = MedCategory(rawValue: entry.category) ?? .other
                let med = Medication(
                    brandName: entry.brandName,
                    genericName: entry.genericName,
                    medClass: entry.medClass,
                    commonDoses: entry.commonDoses,
                    commonSideEffects: entry.commonSideEffects,
                    isExtendedRelease: entry.isExtendedRelease,
                    category: category
                )
                context.insert(med)
                inserted += 1
            }
            try context.save()
            defaults.set(currentSeedVersion, forKey: seedVersionKey)
            #if DEBUG
            print("[MedicationSeeder] Seed v\(currentSeedVersion): inserted \(inserted) medications.")
            #endif
        } catch {
            assertionFailure("Failed to seed medication library: \(error)")
        }
    }
}

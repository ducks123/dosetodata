import Foundation
import SwiftData

enum MedicationSeeder {
    private static let seededFlagKey = "dosetodata.medLibrary.seeded.v1"

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
        if UserDefaults.standard.bool(forKey: seededFlagKey) {
            return
        }

        let existing = (try? context.fetchCount(FetchDescriptor<Medication>())) ?? 0
        if existing > 0 {
            UserDefaults.standard.set(true, forKey: seededFlagKey)
            return
        }

        guard let url = Bundle.main.url(forResource: "MedicationLibrary", withExtension: "json") else {
            assertionFailure("MedicationLibrary.json missing from bundle")
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let entries = try JSONDecoder().decode([LibraryEntry].self, from: data)
            for entry in entries {
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
            }
            try context.save()
            UserDefaults.standard.set(true, forKey: seededFlagKey)
            print("[MedicationSeeder] Seeded \(entries.count) medications.")
        } catch {
            assertionFailure("Failed to seed medication library: \(error)")
        }
    }
}

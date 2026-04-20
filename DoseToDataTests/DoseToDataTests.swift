import XCTest
@testable import DoseToData

final class DoseToDataTests: XCTestCase {
    func testMedicationLibraryJSONDecodes() throws {
        let bundle = Bundle(for: Self.self)
        let appBundle = Bundle.allBundles.first { $0.url(forResource: "MedicationLibrary", withExtension: "json") != nil } ?? bundle
        guard let url = appBundle.url(forResource: "MedicationLibrary", withExtension: "json") else {
            XCTFail("MedicationLibrary.json not found in any loaded bundle")
            return
        }
        let data = try Data(contentsOf: url)
        let entries = try JSONDecoder().decode([MedicationSeeder.LibraryEntry].self, from: data)
        XCTAssertGreaterThanOrEqual(entries.count, 80, "Expected 80+ medication entries")
    }
}

import Foundation
import SwiftData

@Model
final class Medication {
    @Attribute(.unique) var id: UUID
    var brandName: String
    var genericName: String
    var medClass: String
    var commonDoses: [String]
    var commonSideEffects: [String]
    var isExtendedRelease: Bool
    var category: MedCategory

    init(
        id: UUID = UUID(),
        brandName: String,
        genericName: String,
        medClass: String,
        commonDoses: [String],
        commonSideEffects: [String],
        isExtendedRelease: Bool,
        category: MedCategory
    ) {
        self.id = id
        self.brandName = brandName
        self.genericName = genericName
        self.medClass = medClass
        self.commonDoses = commonDoses
        self.commonSideEffects = commonSideEffects
        self.isExtendedRelease = isExtendedRelease
        self.category = category
    }
}

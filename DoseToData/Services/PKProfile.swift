import Foundation

/// Pharmacokinetic profile for a medication — typical onset, peak window, and duration.
/// Times are in minutes from the dose.
///
/// Values are **population averages** pulled from FDA labels and common PK literature.
/// Individual response varies widely based on metabolism, food, tolerance, etc.
/// These are meant as a visual aid, not a prediction.
struct PKProfile {
    /// Minutes from dose until any noticeable effect begins.
    let onsetMin: Int
    /// Minutes from dose when the peak window begins.
    let peakStartMin: Int
    /// Minutes from dose when the peak window ends.
    let peakEndMin: Int
    /// Minutes from dose when the effect is fully worn off.
    let durationMin: Int

    /// Look up a profile by the medication's brand name.
    static func profile(for medication: Medication) -> PKProfile? {
        byBrand[medication.brandName]
    }

    /// Short humanized description, e.g. "Kicks in ~30 min · Peaks 2–4 hr · Wears off by 6 hr"
    var summary: String {
        "Kicks in ~\(minutesShort(onsetMin)) · Peaks \(minutesShort(peakStartMin))–\(minutesShort(peakEndMin)) · Wears off by \(minutesShort(durationMin))"
    }

    private func minutesShort(_ m: Int) -> String {
        if m < 60 { return "\(m) min" }
        let h = Double(m) / 60.0
        if h == h.rounded() {
            return "\(Int(h)) hr"
        }
        return String(format: "%.1f hr", h)
    }

    // MARK: Seed library

    private static let byBrand: [String: PKProfile] = [
        // Amphetamines
        "Adderall IR":          .init(onsetMin: 30,  peakStartMin: 120, peakEndMin: 240, durationMin: 360),  // 4–6 hr
        "Adderall XR":          .init(onsetMin: 30,  peakStartMin: 180, peakEndMin: 480, durationMin: 720),  // biphasic, 10–12 hr
        "Vyvanse":              .init(onsetMin: 90,  peakStartMin: 180, peakEndMin: 420, durationMin: 780),  // 10–14 hr
        "Mydayis":              .init(onsetMin: 60,  peakStartMin: 420, peakEndMin: 720, durationMin: 960),  // 14–16 hr triphasic
        "Dexedrine IR":         .init(onsetMin: 30,  peakStartMin: 120, peakEndMin: 240, durationMin: 360),
        "Dexedrine Spansule":   .init(onsetMin: 60,  peakStartMin: 180, peakEndMin: 420, durationMin: 600),  // 8–10 hr

        // Methylphenidates
        "Ritalin IR":           .init(onsetMin: 30,  peakStartMin: 60,  peakEndMin: 150, durationMin: 240),  // 3–4 hr
        "Ritalin LA":           .init(onsetMin: 30,  peakStartMin: 90,  peakEndMin: 420, durationMin: 480),  // 8 hr biphasic
        "Concerta":             .init(onsetMin: 60,  peakStartMin: 360, peakEndMin: 540, durationMin: 720),  // OROS ascending, 10–12 hr
        "Focalin IR":           .init(onsetMin: 30,  peakStartMin: 60,  peakEndMin: 150, durationMin: 240),
        "Focalin XR":           .init(onsetMin: 30,  peakStartMin: 90,  peakEndMin: 540, durationMin: 720),
        "Jornay PM":            .init(onsetMin: 600, peakStartMin: 780, peakEndMin: 1020, durationMin: 1200), // delayed-release evening dosing
        "Azstarys":             .init(onsetMin: 60,  peakStartMin: 180, peakEndMin: 600, durationMin: 780),
        "Daytrana":             .init(onsetMin: 120, peakStartMin: 420, peakEndMin: 660, durationMin: 720),

        // Non-stimulant ADHD (very rough — these are continuous steady-state, showing daily window)
        "Strattera":            .init(onsetMin: 60,  peakStartMin: 60,  peakEndMin: 240, durationMin: 1440),
        "Qelbree":              .init(onsetMin: 60,  peakStartMin: 60,  peakEndMin: 240, durationMin: 1440),
        "Intuniv":              .init(onsetMin: 60,  peakStartMin: 120, peakEndMin: 600, durationMin: 1440),
        "Kapvay":               .init(onsetMin: 60,  peakStartMin: 120, peakEndMin: 420, durationMin: 720),

        // Anxiety
        "Xanax":                .init(onsetMin: 15,  peakStartMin: 60,  peakEndMin: 120, durationMin: 360),
        "Klonopin":             .init(onsetMin: 30,  peakStartMin: 60,  peakEndMin: 240, durationMin: 720),
        "Ativan":               .init(onsetMin: 20,  peakStartMin: 60,  peakEndMin: 180, durationMin: 480),
        "Valium":               .init(onsetMin: 15,  peakStartMin: 60,  peakEndMin: 180, durationMin: 720),
        "Buspar":               .init(onsetMin: 60,  peakStartMin: 60,  peakEndMin: 120, durationMin: 360),
        "Vistaril":             .init(onsetMin: 30,  peakStartMin: 120, peakEndMin: 240, durationMin: 360),
        "Propranolol":          .init(onsetMin: 30,  peakStartMin: 60,  peakEndMin: 180, durationMin: 360),

        // Sleep
        "Ambien":               .init(onsetMin: 15,  peakStartMin: 60,  peakEndMin: 180, durationMin: 420),
        "Lunesta":              .init(onsetMin: 30,  peakStartMin: 60,  peakEndMin: 240, durationMin: 480),
        "Trazodone":            .init(onsetMin: 30,  peakStartMin: 60,  peakEndMin: 180, durationMin: 420),
        "Melatonin":            .init(onsetMin: 30,  peakStartMin: 60,  peakEndMin: 180, durationMin: 360),
        "Belsomra":             .init(onsetMin: 30,  peakStartMin: 120, peakEndMin: 360, durationMin: 540),
        "Sonata":               .init(onsetMin: 15,  peakStartMin: 30,  peakEndMin: 90,  durationMin: 240),
        "Rozerem":              .init(onsetMin: 30,  peakStartMin: 45,  peakEndMin: 120, durationMin: 300),
        "Quviviq":              .init(onsetMin: 30,  peakStartMin: 60,  peakEndMin: 300, durationMin: 540),
    ]
}

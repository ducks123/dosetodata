import SwiftUI
import SwiftData

struct ScheduleView: View {
    @Query(sort: \UserMedication.startDate, order: .forward) private var userMedications: [UserMedication]

    @State private var showingEditMeds = false

    private let calendar = Calendar.current

    private var activeMeds: [UserMedication] {
        userMedications.filter { $0.endDate == nil }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerSection
                    TimelineStrip(medications: activeMeds)
                    medListSection
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .background(Theme.Palette.background.ignoresSafeArea())
            .navigationTitle("Schedule")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingEditMeds) {
                EditMedicationsSheet()
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Today")
                .font(Theme.Font.heroLabel)
                .foregroundStyle(Theme.Palette.textSecondary)
            Text(Date().formatted(.dateTime.weekday(.wide).month().day()))
                .font(Theme.Font.sectionTitle)
        }
        .padding(.top, 4)
    }

    private var medListSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Your medications")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Palette.textSecondary)
                Spacer()
                if !activeMeds.isEmpty {
                    editListButton
                }
            }
            .padding(.top, 4)
            .padding(.horizontal, 4)

            if activeMeds.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Nothing scheduled yet")
                        .font(Theme.Font.bodyEmphasis)
                    Text("Tap Add medication below to get started.")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .cardStyle()
            } else {
                ForEach(activeMeds) { userMed in
                    NavigationLink(value: userMed.id) {
                        MedScheduleRow(userMed: userMed)
                    }
                    .buttonStyle(.plain)
                }
            }

            addMedicationCard
        }
        .navigationDestination(for: UUID.self) { userMedID in
            if let userMed = activeMeds.first(where: { $0.id == userMedID }) {
                MedScheduleEditorView(userMed: userMed)
            }
        }
    }

    /// Prominent pill-shaped "Edit list" button next to the section header.
    private var editListButton: some View {
        Button {
            showingEditMeds = true
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "pencil")
                    .font(.system(size: 12, weight: .semibold))
                Text("Edit list")
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(Theme.Palette.primary)
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .background(Theme.Palette.primary.opacity(0.12))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    /// Dashed call-to-action card below the med list — the primary path for adding a new med.
    private var addMedicationCard: some View {
        Button {
            showingEditMeds = true
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Theme.Palette.primary.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Theme.Palette.primary)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Add medication")
                        .font(Theme.Font.bodyEmphasis)
                        .foregroundStyle(Theme.Palette.textPrimary)
                    Text("Pick from the library or enter your own.")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Palette.textSecondary)
                }
                Spacer()
            }
            .padding(14)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .strokeBorder(
                        Theme.Palette.primary.opacity(0.45),
                        style: StrokeStyle(lineWidth: 1.25, dash: [5, 4])
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

private struct MedScheduleRow: View {
    let userMed: UserMedication

    private var sortedTimes: [String] {
        userMed.scheduledTimes.sorted()
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(userMed.scheduleColor)
                    .frame(width: 44, height: 44)
                Image(systemName: userMed.medication.category.iconSystemName)
                    .foregroundStyle(Theme.Palette.primary)
                    .font(.system(size: 18, weight: .semibold))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(userMed.medication.brandName)
                    .font(Theme.Font.bodyEmphasis)
                    .foregroundStyle(Theme.Palette.textPrimary)
                Text("\(userMed.currentDose) · \(scheduleSummary)")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .lineLimit(1)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(Theme.Palette.textSecondary)
        }
        .cardStyle()
    }

    private var scheduleSummary: String {
        if sortedTimes.isEmpty {
            return "Tap to set times"
        }
        let times = sortedTimes.map { ScheduleTime.displayString(from: $0) }.joined(separator: ", ")
        let days = userMed.scheduledDays.isEmpty ? [1,2,3,4,5,6,7] : userMed.scheduledDays
        if days.count == 7 { return times }
        let dayLabel = daysSummary(Set(days))
        return "\(times) · \(dayLabel)"
    }

    private func daysSummary(_ days: Set<Int>) -> String {
        if days == [2,3,4,5,6] { return "Weekdays" }
        if days == [1,7]        { return "Weekends" }
        let ordered: [(Int, String)] = [(2,"Mon"),(3,"Tue"),(4,"Wed"),(5,"Thu"),(6,"Fri"),(7,"Sat"),(1,"Sun")]
        return ordered.filter { days.contains($0.0) }.map(\.1).joined(separator: ", ")
    }
}

struct TimelineStrip: View {
    let medications: [UserMedication]

    private let hourWidth: CGFloat = 110
    private let laneHeight: CGFloat = 48
    private let laneSpacing: CGFloat = 8
    private let topPaddingForHours: CGFloat = 28

    /// Timeline starts at the earliest scheduled dose, falls back to 6 am.
    private var startHour: Int {
        medications
            .flatMap { $0.scheduledTimes }
            .compactMap { parseHour(from: $0) }
            .min() ?? 6
    }

    private func parseHour(from timeString: String) -> Int? {
        guard let first = timeString.split(separator: ":").first else { return nil }
        return Int(first)
    }

    /// Full 24 hours starting from the first dose, wrapping midnight.
    private var hours: [Int] { (0..<24).map { (startHour + $0) % 24 } }
    private var totalWidth: CGFloat { CGFloat(23) * hourWidth + 40 }

    /// Each medication gets its own dedicated lane so nothing overlaps.
    private var medLaneIndex: [UUID: Int] {
        Dictionary(uniqueKeysWithValues: medications.enumerated().map { ($1.id, $0) })
    }

    private var lanesCount: Int { max(1, medications.count) }

    private var contentHeight: CGFloat {
        topPaddingForHours + CGFloat(lanesCount) * (laneHeight + laneSpacing) + 8
    }

    private struct PlacedEvent: Identifiable {
        let id = UUID()
        let userMed: UserMedication
        let minutesFromStart: Int
        let timeString: String
    }

    private var events: [PlacedEvent] {
        medications.flatMap { userMed in
            userMed.scheduledTimes.compactMap { timeString -> PlacedEvent? in
                guard let minutes = ScheduleTime.minutesFromStart(timeString, startHour: startHour) else { return nil }
                return PlacedEvent(userMed: userMed, minutesFromStart: minutes, timeString: timeString)
            }
        }
        .sorted { $0.minutesFromStart < $1.minutesFromStart }
    }

    private var nowOffset: CGFloat? {
        let cal = Calendar.current
        let hour = cal.component(.hour, from: Date())
        let minute = cal.component(.minute, from: Date())
        // Always place now — it's always somewhere in a 24-hour view.
        var minutesFromStart = (hour - startHour) * 60 + minute
        if minutesFromStart < 0 { minutesFromStart += 24 * 60 }
        guard minutesFromStart < 24 * 60 else { return nil }
        return CGFloat(minutesFromStart) / 60 * hourWidth + 20
    }

    private static let nowAnchorID = "timelineNowAnchor"

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Today at a glance")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Palette.textSecondary)
                Spacer()
                if !events.isEmpty {
                    Text("\(events.count) dose\(events.count == 1 ? "" : "s")")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Palette.textSecondary)
                }
            }
            .padding(.leading, 4)

            ScrollViewReader { proxy in
                // Horizontal-only scroll — vertical is handled by the outer page ScrollView,
                // which gives clean single-axis scrolling with no diagonal drift.
                ScrollView(.horizontal, showsIndicators: false) {
                    ZStack(alignment: .topLeading) {
                        hourGrid
                        if let nowOffset {
                            nowIndicator(x: nowOffset)
                            Color.clear
                                .frame(width: 1, height: 1)
                                .offset(x: nowOffset, y: contentHeight / 2)
                                .id(Self.nowAnchorID)
                        }
                        ForEach(events) { event in
                            let x = 20 + CGFloat(event.minutesFromStart) / 60 * hourWidth
                            let lane = medLaneIndex[event.userMed.id] ?? 0
                            let y = topPaddingForHours + CGFloat(lane) * (laneHeight + laneSpacing)
                            if let profile = PKProfile.profile(for: event.userMed.medication) {
                                EffectBandView(
                                    userMed: event.userMed,
                                    timeString: event.timeString,
                                    profile: profile,
                                    hourWidth: hourWidth,
                                    laneHeight: laneHeight
                                )
                                .offset(x: x, y: y)
                            } else {
                                EventPill(userMed: event.userMed, timeString: event.timeString, width: hourWidth)
                                    .offset(x: x, y: y)
                            }
                        }
                    }
                    .frame(width: totalWidth, height: contentHeight)
                    .padding(.vertical, 4)
                }
                .onAppear {
                    // Small delay lets the scroll view finish laying out before we scroll.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        if nowOffset != nil {
                            withAnimation { proxy.scrollTo(Self.nowAnchorID, anchor: .center) }
                        }
                    }
                }
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
            .shadow(
                color: Theme.cardShadow.color,
                radius: Theme.cardShadow.radius,
                x: Theme.cardShadow.x,
                y: Theme.cardShadow.y
            )
        }
    }

    private var hourGrid: some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(hours.enumerated()), id: \.offset) { index, hour in
                let x = CGFloat(index) * hourWidth + 20
                Path { path in
                    path.move(to: CGPoint(x: x, y: topPaddingForHours - 4))
                    path.addLine(to: CGPoint(x: x, y: contentHeight - 8))
                }
                .stroke(Theme.Palette.divider.opacity(0.7), lineWidth: 1)

                Text(hourLabel(for: hour))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .position(x: x, y: 12)
            }
        }
    }

    private func nowIndicator(x: CGFloat) -> some View {
        ZStack(alignment: .top) {
            Path { path in
                path.move(to: CGPoint(x: x, y: topPaddingForHours - 4))
                path.addLine(to: CGPoint(x: x, y: contentHeight - 8))
            }
            .stroke(Theme.Palette.primary, lineWidth: 2)

            Circle()
                .fill(Theme.Palette.primary)
                .frame(width: 8, height: 8)
                .position(x: x, y: topPaddingForHours - 4)
        }
    }

    private func hourLabel(for hour: Int) -> String {
        let suffix = hour < 12 ? "am" : "pm"
        let displayHour = hour == 0 ? 12 : (hour <= 12 ? hour : hour - 12)
        return "\(displayHour)\(suffix)"
    }
}

private struct EventPill: View {
    let userMed: UserMedication
    let timeString: String
    let width: CGFloat

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: userMed.medication.category.iconSystemName)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.Palette.primary)
            VStack(alignment: .leading, spacing: 1) {
                Text(userMed.medication.brandName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Text(ScheduleTime.displayString(from: timeString))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(width: width, height: 44, alignment: .leading)
        .background(userMed.scheduleColor)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Theme.Palette.primary.opacity(0.25), lineWidth: 1)
        )
    }
}

// MARK: - Pharmacokinetic effect band

/// Trapezoidal "mountain" that visualizes a dose's effect curve over time.
/// Baseline at both ends (no effect) rising through onset to a peak plateau,
/// then falling back to baseline when the dose wears off.
private struct EffectBand: Shape {
    /// Fraction of total width where onset ends and the rise begins (0...1).
    let onsetFraction: CGFloat
    /// Fraction where the peak plateau begins (0...1).
    let peakStartFraction: CGFloat
    /// Fraction where the peak plateau ends (0...1).
    let peakEndFraction: CGFloat

    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        let baselineY = h - 1       // sit just above the bottom so stroke is visible
        let peakY: CGFloat = 4      // how high the peak reaches
        let onsetX = max(0, min(w, onsetFraction * w))
        let peakStartX = max(onsetX, min(w, peakStartFraction * w))
        let peakEndX = max(peakStartX, min(w, peakEndFraction * w))

        return Path { p in
            p.move(to: CGPoint(x: 0, y: baselineY))
            // flat baseline during the initial onset delay
            p.addLine(to: CGPoint(x: onsetX, y: baselineY))
            // smooth ramp up to peak
            let riseSpan = peakStartX - onsetX
            p.addCurve(
                to: CGPoint(x: peakStartX, y: peakY),
                control1: CGPoint(x: onsetX + riseSpan * 0.55, y: baselineY),
                control2: CGPoint(x: peakStartX - riseSpan * 0.35, y: peakY)
            )
            // peak plateau
            p.addLine(to: CGPoint(x: peakEndX, y: peakY))
            // smooth ramp down to baseline
            let fallSpan = w - peakEndX
            p.addCurve(
                to: CGPoint(x: w, y: baselineY),
                control1: CGPoint(x: peakEndX + fallSpan * 0.35, y: peakY),
                control2: CGPoint(x: w - fallSpan * 0.55, y: baselineY)
            )
            p.closeSubpath()
        }
    }
}

/// Renders an EffectBand for a scheduled dose, with a compact label at the start
/// showing the medication name and time.
private struct EffectBandView: View {
    let userMed: UserMedication
    let timeString: String
    let profile: PKProfile
    let hourWidth: CGFloat
    let laneHeight: CGFloat

    private var bandWidth: CGFloat {
        CGFloat(profile.durationMin) / 60 * hourWidth
    }

    private var onsetFraction: CGFloat {
        CGFloat(profile.onsetMin) / CGFloat(max(1, profile.durationMin))
    }

    private var peakStartFraction: CGFloat {
        CGFloat(profile.peakStartMin) / CGFloat(max(1, profile.durationMin))
    }

    private var peakEndFraction: CGFloat {
        CGFloat(profile.peakEndMin) / CGFloat(max(1, profile.durationMin))
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // The effect curve — filled with a gradient that brightens through the peak window.
            EffectBand(
                onsetFraction: onsetFraction,
                peakStartFraction: peakStartFraction,
                peakEndFraction: peakEndFraction
            )
            .fill(
                LinearGradient(
                    stops: [
                        .init(color: userMed.scheduleColor.opacity(0.25), location: 0.0),
                        .init(color: userMed.scheduleColor.opacity(0.55), location: max(0.01, peakStartFraction)),
                        .init(color: userMed.scheduleColor.opacity(0.70), location: min(0.99, peakEndFraction)),
                        .init(color: userMed.scheduleColor.opacity(0.25), location: 1.0)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .overlay(
                EffectBand(
                    onsetFraction: onsetFraction,
                    peakStartFraction: peakStartFraction,
                    peakEndFraction: peakEndFraction
                )
                .stroke(userMed.scheduleColor.opacity(0.9), lineWidth: 1)
            )
            .frame(width: bandWidth, height: laneHeight)

            // Small "Peak" marker anchored at the middle of the peak plateau.
            Text("Peak")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Theme.Palette.textSecondary)
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(
                    Capsule().fill(Color.white.opacity(0.85))
                )
                .offset(
                    x: (peakStartFraction + peakEndFraction) / 2 * bandWidth - 14,
                    y: -6
                )

            // Start label: brand name + dose time.
            HStack(spacing: 5) {
                Image(systemName: userMed.medication.category.iconSystemName)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Theme.Palette.primary)
                Text(userMed.medication.brandName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .lineLimit(1)
                Text(ScheduleTime.displayString(from: timeString))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule().fill(Color.white.opacity(0.95))
            )
            .overlay(
                Capsule().stroke(userMed.scheduleColor.opacity(0.9), lineWidth: 1)
            )
            .offset(x: 4, y: laneHeight - 26)
        }
        .frame(width: bandWidth, height: laneHeight, alignment: .topLeading)
    }
}

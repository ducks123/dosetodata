import SwiftUI
import SwiftData

struct ScheduleView: View {
    @Query(sort: \UserMedication.startDate, order: .reverse) private var userMedications: [UserMedication]

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
            .navigationBarTitleDisplayMode(.large)
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
            Text("Your medications")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Palette.textSecondary)
                .padding(.top, 4)
                .padding(.leading, 4)

            if activeMeds.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Nothing scheduled yet")
                        .font(Theme.Font.bodyEmphasis)
                    Text("Add medications under Settings → My Medications, then set times here.")
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
        }
        .navigationDestination(for: UUID.self) { userMedID in
            if let userMed = activeMeds.first(where: { $0.id == userMedID }) {
                MedScheduleEditorView(userMed: userMed)
            }
        }
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
                    .fill(userMed.medication.category.pastelColor)
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
        let formatted = sortedTimes.map { ScheduleTime.displayString(from: $0) }
        return formatted.joined(separator: ", ")
    }
}

struct TimelineStrip: View {
    let medications: [UserMedication]

    private let hourWidth: CGFloat = 60
    private let startHour: Int = 5
    private let endHour: Int = 23
    private let laneHeight: CGFloat = 44
    private let laneSpacing: CGFloat = 8
    private let topPaddingForHours: CGFloat = 28

    private var hours: [Int] { Array(startHour...endHour) }
    private var totalWidth: CGFloat { CGFloat(hours.count - 1) * hourWidth + 40 }

    private struct PlacedEvent: Identifiable {
        let id = UUID()
        let userMed: UserMedication
        let minutesFromStart: Int
        let timeString: String
    }

    private var events: [PlacedEvent] {
        var out: [PlacedEvent] = []
        for userMed in medications {
            for timeString in userMed.scheduledTimes {
                guard let minutes = ScheduleTime.minutesFromStart(timeString, startHour: startHour) else { continue }
                out.append(PlacedEvent(
                    userMed: userMed,
                    minutesFromStart: minutes,
                    timeString: timeString
                ))
            }
        }
        return out.sorted { $0.minutesFromStart < $1.minutesFromStart }
    }

    private var nowOffset: CGFloat? {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: Date())
        let minute = calendar.component(.minute, from: Date())
        guard hour >= startHour, hour <= endHour else { return nil }
        let minutesFromStart = (hour - startHour) * 60 + minute
        return CGFloat(minutesFromStart) / 60 * hourWidth + 20
    }

    private var lanesCount: Int {
        max(1, min(medications.count, 4))
    }

    private var timelineHeight: CGFloat {
        topPaddingForHours + CGFloat(lanesCount) * (laneHeight + laneSpacing) + 8
    }

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
                ScrollView(.horizontal, showsIndicators: false) {
                    ZStack(alignment: .topLeading) {
                        hourGrid
                        if let nowOffset {
                            nowIndicator(x: nowOffset)
                        }
                        ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                            EventPill(userMed: event.userMed, timeString: event.timeString)
                                .position(
                                    x: 20 + CGFloat(event.minutesFromStart) / 60 * hourWidth,
                                    y: topPaddingForHours + CGFloat(index % lanesCount) * (laneHeight + laneSpacing) + laneHeight / 2
                                )
                        }
                    }
                    .frame(width: totalWidth, height: timelineHeight)
                    .padding(.vertical, 4)
                    .id("timelineRoot")
                }
                .onAppear {
                    if nowOffset != nil {
                        withAnimation {
                            proxy.scrollTo("timelineRoot", anchor: .center)
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
            ForEach(hours, id: \.self) { hour in
                let x = CGFloat(hour - startHour) * hourWidth + 20
                Path { path in
                    path.move(to: CGPoint(x: x, y: topPaddingForHours - 4))
                    path.addLine(to: CGPoint(x: x, y: timelineHeight - 8))
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
                path.addLine(to: CGPoint(x: x, y: timelineHeight - 8))
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

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: userMed.medication.category.iconSystemName)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Theme.Palette.primary)
            VStack(alignment: .leading, spacing: 0) {
                Text(userMed.medication.brandName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .lineLimit(1)
                Text(ScheduleTime.displayString(from: timeString))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Theme.Palette.textSecondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(userMed.medication.category.pastelColor)
        .clipShape(Capsule())
        .overlay(
            Capsule().stroke(Theme.Palette.primary.opacity(0.3), lineWidth: 1)
        )
    }
}

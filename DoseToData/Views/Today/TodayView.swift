import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(UserPreferences.self) private var prefs

    @Query(sort: \DailyCheckIn.date, order: .reverse) private var checkIns: [DailyCheckIn]
    @Query(sort: \Test.startDate, order: .reverse) private var tests: [Test]
    @Query(sort: \UserMedication.startDate, order: .reverse) private var userMedications: [UserMedication]

    @State private var showingCheckIn = false
    @State private var showingCreateTest = false

    private let calendar = Calendar.current

    private var todaysCheckIn: DailyCheckIn? {
        checkIns.first { calendar.isDateInToday($0.date) }
    }

    private var completedDates: Set<Date> {
        Set(checkIns.map { calendar.startOfDay(for: $0.date) })
    }

    private var activeTest: Test? {
        tests.first { $0.actualEndDate == nil && $0.startEvent != nil }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                WeekStrip(completedDates: completedDates, today: Date())
                    .padding(.horizontal, 4)
                checkInCard
                if let activeTest, let startEvent = activeTest.startEvent {
                    activeTestCard(test: activeTest, startEvent: startEvent)
                }
                changesSection
            }
            .padding(20)
        }
        .background(Theme.Palette.background.ignoresSafeArea())
        .sheet(isPresented: $showingCheckIn) {
            DailyCheckInSheet()
        }
        .sheet(isPresented: $showingCreateTest) {
            CreateTestSheet()
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(greeting)
                .font(Theme.Font.heroLabel)
                .foregroundStyle(Theme.Palette.textSecondary)
            Text(Date().formatted(.dateTime.weekday(.wide).month().day()))
                .font(Theme.Font.sectionTitle)
        }
        .padding(.top, 8)
    }

    private var greeting: String {
        let hour = calendar.component(.hour, from: Date())
        let base: String = switch hour {
        case 5..<12: "Good morning"
        case 12..<17: "Good afternoon"
        case 17..<22: "Good evening"
        default: "Late night"
        }
        let name = prefs.displayName.trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? base : "\(base), \(name)"
    }

    private var isTodayCompleted: Bool {
        todaysCheckIn != nil
    }

    private var answerCountLabel: String {
        guard let ci = todaysCheckIn else { return "" }
        let n = ci.answers.count
        return "\(n) question\(n == 1 ? "" : "s") logged"
    }

    private var checkInCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Today's check-in")
                        .font(Theme.Font.heroLabel)
                        .foregroundStyle(Theme.Palette.textSecondary)
                    Text(isTodayCompleted ? "You're logged for today" : "How are you today?")
                        .font(Theme.Font.hero)
                        .foregroundStyle(Theme.Palette.textPrimary)
                }
                Spacer(minLength: 0)
                if isTodayCompleted {
                    ZStack {
                        Circle()
                            .fill(Theme.Palette.success)
                            .frame(width: 40, height: 40)
                        Image(systemName: "checkmark")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
            }

            Text(isTodayCompleted
                 ? "\(answerCountLabel). You can update anytime before midnight."
                 : "Quick panel: anxiety, happiness, focus, irritability, social, plus anything you add.")
                .font(Theme.Font.body)
                .foregroundStyle(Theme.Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if let ci = todaysCheckIn, !ci.answers.isEmpty {
                summaryChips(for: ci)
            }

            Button {
                showingCheckIn = true
            } label: {
                HStack(spacing: 8) {
                    if isTodayCompleted {
                        Image(systemName: "checkmark.circle.fill")
                    }
                    Text(isTodayCompleted ? "Completed — tap to update" : "Complete today's check-in")
                }
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Palette.heroAccent)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
    }

    private func summaryChips(for ci: DailyCheckIn) -> some View {
        FlowLayout(spacing: 6) {
            ForEach(ci.answers, id: \.self) { answer in
                if let level = answer.checkInLevel {
                    HStack(spacing: 4) {
                        Text(shortLabel(for: answer.questionKey))
                            .font(.system(size: 11, weight: .semibold))
                        Text(level.displayName.lowercased())
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(Theme.Palette.textSecondary)
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(Color.white)
                    .clipShape(Capsule())
                }
            }
        }
    }

    private func shortLabel(for key: String) -> String {
        if let std = StandardCheckInQuestion(rawValue: key) {
            return std.shortLabel
        }
        return "Custom"
    }

    private func activeTestCard(test: Test, startEvent: MedEvent) -> some View {
        let daysSinceStart = calendar.dateComponents([.day], from: test.startDate, to: Date()).day ?? 0
        let plannedDays: Int? = test.plannedEndDate.map {
            calendar.dateComponents([.day], from: test.startDate, to: $0).day ?? 0
        }
        let medName = startEvent.userMedication?.medication.brandName ?? "Active test"
        let dayLabel = plannedDays.map { "Day \(daysSinceStart + 1) of \($0)" } ?? "Day \(daysSinceStart + 1)"

        return HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Theme.Palette.attention.opacity(0.25))
                    .frame(width: 48, height: 48)
                Image(systemName: "flame.fill")
                    .foregroundStyle(Theme.Palette.attention)
                    .font(.system(size: 20, weight: .semibold))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(dayLabel)
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Palette.textSecondary)
                Text(medName)
                    .font(Theme.Font.bodyEmphasis)
                if !test.watchingFor.isEmpty {
                    Text("Watching: \(test.watchingFor)")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Palette.textSecondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(Theme.Palette.textSecondary)
        }
        .cardStyle()
    }

    private var changesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Medication changes")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Palette.textSecondary)
                .padding(.leading, 4)

            ActionRow(
                icon: "flask.fill",
                iconColor: Theme.Palette.primary,
                title: "Create a test",
                subtitle: "Add or change a med for a set period, then compare that window to your baseline."
            ) {
                showingCreateTest = true
            }
        }
    }
}

private struct ActionRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.18))
                        .frame(width: 40, height: 40)
                    Image(systemName: icon)
                        .foregroundStyle(iconColor)
                        .font(.system(size: 16, weight: .semibold))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Theme.Font.bodyEmphasis)
                        .foregroundStyle(Theme.Palette.textPrimary)
                    Text(subtitle)
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Palette.textSecondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(Theme.Palette.textSecondary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
            .shadow(
                color: Theme.cardShadow.color,
                radius: Theme.cardShadow.radius,
                x: Theme.cardShadow.x,
                y: Theme.cardShadow.y
            )
        }
        .buttonStyle(.plain)
    }
}

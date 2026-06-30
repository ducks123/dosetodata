import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(UserPreferences.self) private var prefs
    @Environment(AppState.self) private var appState
    @Environment(SubscriptionService.self) private var sub

    @Query(sort: \DailyCheckIn.date, order: .reverse) private var checkIns: [DailyCheckIn]
    @Query(sort: \UserMedication.startDate, order: .reverse) private var userMedications: [UserMedication]
    @Query private var adherenceLogs: [MedAdherenceLog]

    @State private var showingCheckIn = false
    @State private var showingLogMedChange = false
    /// When set, presents the MedChangeMarkerDetailSheet for that event so
    /// the user can edit or delete from the Today screen.
    @State private var selectedRecentChange: MedChangeEvent? = nil
    @Query(sort: \MedChangeEvent.date, order: .reverse) private var medChangeEvents: [MedChangeEvent]
    @State private var showingEditMeds = false
    @State private var showingCheckInSetup = false
    @State private var showingSettings = false
    @State private var showingPaywall = false
    @State private var editingPastDate: Date? = nil
    @State private var viewingCheckIn: DailyCheckIn? = nil
    @State private var selectedDate: Date = Calendar.current.startOfDay(for: Date())

    private struct EditableDate: Identifiable {
        let date: Date
        var id: TimeInterval { date.timeIntervalSince1970 }
    }

    private let calendar = AppCalendar.current

    private func consumePendingTodayDate() {
        guard let date = appState.pendingTodayDate else { return }
        selectedDate = calendar.startOfDay(for: date)
        appState.pendingTodayDate = nil
    }

    // MARK: - Earliest data date (drives how far back the strip reaches)

    private var earliestDataDate: Date? {
        let cal = AppCalendar.current
        let checkInDates  = checkIns.map  { cal.startOfDay(for: $0.date) }
        let adherenceDates = adherenceLogs.map { cal.startOfDay(for: $0.date) }
        return (checkInDates + adherenceDates).min()
    }

    // MARK: - Day states (for all dates shown in the scroll strip)

    private var allDayStates: [Date: WeekDayState] {
        let cal = AppCalendar.current
        let today = cal.startOfDay(for: Date())
        let daysBack: Int
        if let earliest = earliestDataDate {
            let computed = cal.dateComponents([.day], from: earliest, to: today).day ?? 180
            daysBack = max(computed, 0)
        } else {
            daysBack = 180
        }
        guard let startDate = cal.date(byAdding: .day, value: -daysBack, to: today) else { return [:] }
        // Include any future-dated check-ins so the user can simulate ahead
        // and still see green checkmarks on those days in the date strip.
        let latestCheckIn = checkIns.map { cal.startOfDay(for: $0.date) }.max() ?? today
        let endDate = max(today, latestCheckIn)
        var result: [Date: WeekDayState] = [:]
        var current = startDate
        while current <= endDate {
            result[current] = dayState(for: current, using: cal)
            current = cal.date(byAdding: .day, value: 1, to: current) ?? endDate
        }
        return result
    }

    private func dayState(for date: Date, using cal: Calendar) -> WeekDayState {
        let isCheckedIn = checkIns.contains { cal.isDate($0.date, inSameDayAs: date) }

        let weekday = cal.component(.weekday, from: date)
        let scheduledIDs = Set(
            userMedications.filter { med in
                let startOK = cal.startOfDay(for: med.startDate) <= date
                let endOK   = med.endDate.map { cal.startOfDay(for: $0) >= date } ?? true
                guard startOK && endOK else { return false }
                let days = med.scheduledDays.isEmpty ? [1,2,3,4,5,6,7] : med.scheduledDays
                return days.contains(weekday)
            }.map(\.id)
        )

        if scheduledIDs.isEmpty {
            return isCheckedIn ? .complete : .empty
        }

        let log = adherenceLogs.first { cal.isDate($0.date, inSameDayAs: date) }
        let anySkipped = log?.anySkipped(scheduledIDs: scheduledIDs) ?? false
        let allTaken   = log?.allTaken(scheduledIDs: scheduledIDs) ?? false

        if isCheckedIn {
            return anySkipped ? .medsMissed : .complete
        } else if allTaken {
            return .medsTaken
        } else {
            return .empty
        }
    }


    /// Returns false and triggers the paywall when the user can't write.
    private func requireSubscription() -> Bool {
        guard sub.canWrite else {
            showingPaywall = true
            return false
        }
        return true
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Subscription banners sit above everything else
                TrialBanner()
                ExpiredBanner()
                headerSection
                DateScrollStrip(
                    dayStates: allDayStates,
                    today: Date(),
                    selectedDate: selectedDate,
                    earliestDate: earliestDataDate
                ) { date in
                    selectedDate = date
                }
                DateStripLegend()
                checkInCard(for: selectedDate)
                // Legacy "Current tests" section removed in Build 81 as part
                // of the cutover to MedChangeEvent. Existing Test records are
                // auto-ended via TestRetirementMigration on first launch of
                // this build (see DoseToDataApp.swift), so no active tests
                // exist to render after that point. The records themselves
                // are preserved for historical chart markers on Insights.
                changesSection
            }
            .padding(20)
        }
        .background(Theme.Palette.background.ignoresSafeArea())
        .onAppear { consumePendingTodayDate() }
        .onChange(of: appState.pendingTodayDate) { _, _ in consumePendingTodayDate() }
        .overlay(alignment: .top) {
            ConfettiBurst(trigger: appState.confettiTrigger)
        }
        .sheet(isPresented: $showingCheckIn) {
            DailyCheckInSheet()
        }
        .sheet(item: $selectedRecentChange) { event in
            MedChangeMarkerDetailSheet(event: event)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showingLogMedChange) {
            LogMedChangeSheet()
        }
        .sheet(isPresented: $showingEditMeds) {
            EditMedicationsSheet()
        }
        .sheet(isPresented: $showingCheckInSetup) {
            CheckInReminderSheet()
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .sheet(item: Binding(
            get: { editingPastDate.map { EditableDate(date: $0) } },
            set: { editingPastDate = $0?.date }
        )) { wrapper in
            DailyCheckInSheet(targetDate: wrapper.date)
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallView()
                .environment(sub)
        }
        .sheet(item: $viewingCheckIn) { ci in
            CheckInDetailView(checkIn: ci) {
                // Edit callback: open the edit sheet for this day
                if calendar.isDateInToday(ci.date) {
                    showingCheckIn = true
                } else {
                    editingPastDate = ci.date
                }
            }
        }
    }

    private var headerRelativeLabel: String {
        if calendar.isDateInToday(selectedDate)     { return "Today" }
        if calendar.isDateInYesterday(selectedDate)  { return "Yesterday" }
        if calendar.isDateInTomorrow(selectedDate)   { return "Tomorrow" }
        return ""
    }

    private var headerSection: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                if !headerRelativeLabel.isEmpty {
                    Text(headerRelativeLabel)
                        .font(Theme.Font.heroLabel)
                        .foregroundStyle(Theme.Palette.textSecondary)
                }
                Text(selectedDate.formatted(.dateTime.weekday(.wide).month().day().year()))
                    .font(Theme.Font.sectionTitle)
            }
            Spacer()
            Button {
                showingSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 20))
                    .foregroundStyle(Theme.Palette.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 8)
    }

    // MARK: - Today-only stats (for streak / 7-day delta)

    private var todaysCheckIn: DailyCheckIn? {
        checkIns.first { calendar.isDateInToday($0.date) }
    }

    private var currentStreak: Int {
        AppState.currentStreak(from: checkIns.map { $0.date }, calendar: calendar)
    }

    private var todayAverageScore: Double? {
        averageScore(for: todaysCheckIn)
    }

    private var sevenDayAverageScore: Double? {
        let cal = calendar
        let sevenDaysAgo = cal.date(byAdding: .day, value: -7, to: cal.startOfDay(for: Date())) ?? Date()
        let pastCheckIns = checkIns.filter { ci in
            !cal.isDateInToday(ci.date) && ci.date >= sevenDaysAgo
        }
        let scores = pastCheckIns.flatMap { ci in
            ci.answers.compactMap { $0.checkInLevel?.numericValue }.map(Double.init)
        }
        guard !scores.isEmpty else { return nil }
        return scores.reduce(0, +) / Double(scores.count)
    }

    private var sevenDayPercentDelta: Double? {
        guard let today = todayAverageScore, let week = sevenDayAverageScore, week > 0 else { return nil }
        return ((today - week) / week) * 100
    }

    private func averageScore(for ci: DailyCheckIn?) -> Double? {
        guard let ci else { return nil }
        let scores = ci.answers.compactMap { $0.checkInLevel?.numericValue }.map(Double.init)
        guard !scores.isEmpty else { return nil }
        return scores.reduce(0, +) / Double(scores.count)
    }

    // MARK: - Check-in card

    private func checkInCard(for date: Date) -> some View {
        let checkIn = checkIns.first { calendar.isDate($0.date, inSameDayAs: date) }
        let hasEntry = checkIn != nil
        let isToday = calendar.isDateInToday(date)

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(isToday ? "Today's check-in" : "Check-in")
                        .font(Theme.Font.heroLabel)
                        .foregroundStyle(Theme.Palette.textSecondary)
                    Text(cardHeadline(hasEntry: hasEntry, isToday: isToday))
                        .font(Theme.Font.hero)
                        .foregroundStyle(Theme.Palette.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Button {
                    showingCheckInSetup = true
                } label: {
                    Image(systemName: "bell.badge")
                        .font(.system(size: 18))
                        .foregroundStyle(Theme.Palette.textSecondary)
                }
                .buttonStyle(.plain)
            }

            // Streak — only on today's card
            if isToday && currentStreak > 0 {
                HStack(spacing: 5) {
                    Text("🔥")
                        .font(.system(size: 14))
                    Text("\(currentStreak)-day streak")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.Palette.textSecondary)
                }
            }

            if let ci = checkIn, !ci.answers.isEmpty {
                summaryChips(for: ci)
            }

            if let avg = averageScore(for: checkIn) {
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(String(format: "%.1f", avg))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.Palette.textPrimary)
                    Text("/ 5 today")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Palette.textSecondary)
                    if isToday, let delta = sevenDayPercentDelta {
                        Spacer()
                        let isUp = delta >= 0
                        let symbol = isUp ? "↑" : "↓"
                        let color: Color = isUp ? Theme.Palette.success : Theme.Palette.negative
                        Text("\(symbol) \(String(format: "%.1f", abs(delta)))% vs 7d")
                            .font(Theme.Font.caption)
                            .foregroundStyle(color)
                    }
                }
            }

            if hasEntry {
                Button {
                    appState.shouldNavigateToInsights = true
                } label: {
                    Text("View your progress")
                }
                .buttonStyle(PrimaryButtonStyle())

                Button {
                    viewingCheckIn = checkIn
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "doc.text")
                        Text("View check-in")
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.Palette.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Theme.Palette.primary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous))
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    guard requireSubscription() else { return }
                    if isToday {
                        showingCheckIn = true
                    } else {
                        editingPastDate = date
                    }
                } label: {
                    Text(isToday ? "Complete today's check-in" : "Log for this day")
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .strokeBorder(
                    AngularGradient(
                        colors: [.red, .orange, .yellow, .green, .cyan, .blue, .purple, .pink, .red],
                        center: .center
                    ),
                    lineWidth: 2
                )
                .opacity(hasEntry ? 1 : 0)
                .animation(.easeInOut(duration: 0.4), value: hasEntry)
        )
        .shadow(
            color: Theme.cardShadow.color,
            radius: Theme.cardShadow.radius,
            x: Theme.cardShadow.x,
            y: Theme.cardShadow.y
        )
        .animation(.easeInOut(duration: 0.4), value: hasEntry)
    }

    private func cardHeadline(hasEntry: Bool, isToday: Bool) -> String {
        if isToday {
            return hasEntry ? "You're logged for today" : "How are you today?"
        } else {
            return hasEntry ? "You're logged for this day" : "No entry for this day"
        }
    }

    private func summaryChips(for ci: DailyCheckIn) -> some View {
        FlowLayout(spacing: 6) {
            ForEach(ci.answers, id: \.self) { answer in
                if let level = answer.checkInLevel {
                    HStack(spacing: 4) {
                        Text(shortLabel(for: answer.questionKey))
                            .font(.system(size: 11, weight: .semibold))
                        Text("\(level.displayName)/5")
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

    private var changesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent changes")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Palette.textSecondary)
                .padding(.leading, 4)

            // Latest 2 medication change events inline. Tapping a row will
            // jump to the marker detail (Insights chart marker) in a later
            // build; for now it just opens an empty placeholder via a
            // pending-todo (no-op) so users see their history.
            if medChangeEvents.isEmpty {
                emptyRecentChangesCard
            } else {
                ForEach(medChangeEvents.prefix(2)) { event in
                    recentChangeRow(event)
                }
            }

            Button {
                guard requireSubscription() else { return }
                showingLogMedChange = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                    Text("Log a medication change")
                }
            }
            .buttonStyle(PrimaryButtonStyle())

            // Note: the previous "Edit medications" secondary link was removed
            // here per product feedback. Medication management is still
            // reachable from inside LogMedChangeSheet (the med picker) and
            // from Settings if we ever surface it there. The Today screen
            // stays focused on the single "Log a medication change" action.
        }
    }

    private var emptyRecentChangesCard: some View {
        Text("Log your first medication change so your chart shows what's affecting your trends.")
            .font(Theme.Font.caption)
            .foregroundStyle(Theme.Palette.textSecondary)
            .multilineTextAlignment(.leading)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
    }

    private func recentChangeRow(_ event: MedChangeEvent) -> some View {
        Button {
            selectedRecentChange = event
        } label: {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(event.date.formatted(date: .abbreviated, time: .omitted))
                            .font(Theme.Font.bodyEmphasis)
                            .foregroundStyle(Theme.Palette.textPrimary)
                        Text("·")
                            .foregroundStyle(Theme.Palette.textSecondary)
                        Text("\(event.actions.count) change\(event.actions.count == 1 ? "" : "s")")
                            .font(Theme.Font.caption)
                            .foregroundStyle(Theme.Palette.textSecondary)
                        Spacer()
                    }
                    ForEach(event.actions) { action in
                        Text(action.summaryLine)
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.Palette.textPrimary)
                    }
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .padding(.top, 2)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
        }
        .buttonStyle(.plain)
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

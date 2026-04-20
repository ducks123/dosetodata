import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(UserPreferences.self) private var prefs

    @Query(sort: \MoodEntry.date, order: .reverse) private var moodEntries: [MoodEntry]
    @Query(sort: \Test.startDate, order: .reverse) private var tests: [Test]
    @Query(sort: \UserMedication.startDate, order: .reverse) private var userMedications: [UserMedication]

    @State private var showingCheckIn = false
    @State private var showingSideEffectSheet = false
    @State private var showingAddMedFlow = false

    private let calendar = Calendar.current

    private var todaysMood: MoodEntry? {
        moodEntries.first { calendar.isDateInToday($0.date) }
    }

    private var completedDates: Set<Date> {
        Set(moodEntries.map { calendar.startOfDay(for: $0.date) })
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
                quickActions
            }
            .padding(20)
        }
        .background(Theme.Palette.background.ignoresSafeArea())
        .sheet(isPresented: $showingCheckIn) {
            DailyCheckInSheet(existingMood: todaysMood)
        }
        .sheet(isPresented: $showingSideEffectSheet) {
            SideEffectQuickAddSheet()
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showingAddMedFlow) {
            MedEventPlaceholderSheet()
                .presentationDetents([.medium])
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
        todaysMood != nil
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
                 ? "Mood: \(todaysMood?.moodScore ?? 0)/10. You can update it anytime before midnight."
                 : "A quick three-step check-in: mood, side effects, optional note.")
                .font(Theme.Font.body)
                .foregroundStyle(Theme.Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

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

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick log")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Palette.textSecondary)
                .padding(.leading, 4)
            QuickActionRow(
                icon: "exclamationmark.triangle.fill",
                iconColor: Theme.Palette.negative,
                title: "Add a side effect",
                subtitle: "Headache, appetite loss, anything you've noticed"
            ) {
                showingSideEffectSheet = true
            }
            QuickActionRow(
                icon: "pill.fill",
                iconColor: Theme.Palette.primary,
                title: "Log a medication change",
                subtitle: userMedications.isEmpty ? "Started something new? Add it here" : "Started, stopped, or changed a dose"
            ) {
                showingAddMedFlow = true
            }
        }
    }
}

private struct QuickActionRow: View {
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
                        .lineLimit(1)
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

private struct MedEventPlaceholderSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                Text("Medication changes")
                    .font(Theme.Font.sectionTitle)
                Text("Phase 2 lands the full \"started / stopped / changed dose / missed\" flow plus the optional test toggle. For now you can add your current medications under Settings → My Medications.")
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Text("Got it")
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .padding(24)
            .background(Theme.Palette.background)
            .navigationTitle("Coming soon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

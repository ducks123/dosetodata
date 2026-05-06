import SwiftUI
import SwiftData

struct MedScheduleEditorView: View {
    @Bindable var userMed: UserMedication
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var showingTimePicker = false
    @State private var pendingTime: Date = defaultPendingTime()

    private static func defaultPendingTime() -> Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = 8
        components.minute = 0
        return Calendar.current.date(from: components) ?? Date()
    }

    private var sortedTimes: [String] {
        userMed.scheduledTimes.sorted()
    }

    /// Weekdays displayed Mon→Sun. weekday values follow Calendar.weekday (1=Sun … 7=Sat).
    private let orderedDays: [(weekday: Int, label: String)] = [
        (2, "M"), (3, "Tu"), (4, "W"), (5, "Th"), (6, "F"), (7, "Sa"), (1, "Su")
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerCard
                reminderToggleCard
                timesSection
                frequencySection
                quickPresetsSection
            }
            .padding(20)
        }
        .background(Theme.Palette.background.ignoresSafeArea())
        .navigationTitle("Schedule")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingTimePicker) {
            NavigationStack {
                VStack(spacing: 0) {
                    DatePicker("Time", selection: $pendingTime, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .padding()
                    Button {
                        addTime(from: pendingTime)
                        showingTimePicker = false
                    } label: {
                        Text("Add time")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(20)
                }
                .background(Theme.Palette.background)
                .navigationTitle("Pick a time")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel") { showingTimePicker = false }
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }

    private var reminderToggleCard: some View {
        Toggle(isOn: Binding(
            get: { userMed.remindersEnabled },
            set: { newValue in
                userMed.remindersEnabled = newValue
                try? modelContext.save()
                Task {
                    if newValue {
                        await ReminderManager.shared.scheduleReminders(for: userMed)
                    } else {
                        await ReminderManager.shared.clearReminders(for: userMed.id)
                    }
                }
            }
        )) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Reminders")
                    .font(Theme.Font.bodyEmphasis)
                Text(userMed.scheduledTimes.isEmpty
                     ? "Set at least one time below to receive reminders."
                     : "Daily notifications at your scheduled times.")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .tint(Theme.Palette.primary)
        .disabled(userMed.scheduledTimes.isEmpty)
        .padding(14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
        .shadow(
            color: Theme.cardShadow.color,
            radius: Theme.cardShadow.radius,
            x: Theme.cardShadow.x,
            y: Theme.cardShadow.y
        )
        .onChange(of: userMed.scheduledTimes) { _, _ in
            if userMed.remindersEnabled {
                Task {
                    await ReminderManager.shared.scheduleReminders(for: userMed)
                }
            }
        }
    }

    private var headerCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(userMed.medication.category.pastelColor)
                    .frame(width: 52, height: 52)
                Image(systemName: userMed.medication.category.iconSystemName)
                    .foregroundStyle(Theme.Palette.primary)
                    .font(.system(size: 20, weight: .semibold))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(userMed.medication.brandName)
                    .font(Theme.Font.sectionTitle)
                Text("\(userMed.currentDose) · \(userMed.medication.genericName)")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Palette.textSecondary)
            }
            Spacer()
        }
        .cardStyle()
    }

    private var timesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Scheduled times")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Palette.textSecondary)
                .padding(.horizontal, 4)

            if sortedTimes.isEmpty {
                Text("No times set. Add one below or pick a preset.")
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .cardStyle()
            } else {
                ForEach(sortedTimes, id: \.self) { timeString in
                    HStack {
                        Image(systemName: "clock")
                            .foregroundStyle(Theme.Palette.primary)
                        Text(ScheduleTime.displayString(from: timeString))
                            .font(Theme.Font.bodyEmphasis)
                        Spacer()
                        Button {
                            removeTime(timeString)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(Theme.Palette.textSecondary)
                        }
                    }
                    .padding(16)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
                    .shadow(
                        color: Theme.cardShadow.color,
                        radius: Theme.cardShadow.radius,
                        x: Theme.cardShadow.x,
                        y: Theme.cardShadow.y
                    )
                }
            }
        }
    }

    private var frequencySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Frequency")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Palette.textSecondary)
                Spacer()
                let allSelected = activeDays.count == 7
                Text(allSelected ? "Every day" : daysSummary(activeDays))
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Palette.primary)
            }
            .padding(.horizontal, 4)

            HStack(spacing: 6) {
                ForEach(orderedDays, id: \.weekday) { item in
                    let isOn = activeDays.contains(item.weekday)
                    Button {
                        toggleDay(item.weekday)
                    } label: {
                        Text(item.label)
                            .font(.system(size: 13, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(isOn ? Theme.Palette.primary : Color.white)
                            .foregroundStyle(isOn ? Color.white : Theme.Palette.textSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(
                                        isOn ? Theme.Palette.primary : Theme.Palette.divider,
                                        lineWidth: 1
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(14)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
            .shadow(
                color: Theme.cardShadow.color,
                radius: Theme.cardShadow.radius,
                x: Theme.cardShadow.x,
                y: Theme.cardShadow.y
            )
        }
    }

    /// Falls back to all-days if the field is empty (pre-migration records).
    private var activeDays: [Int] {
        userMed.scheduledDays.isEmpty ? [1, 2, 3, 4, 5, 6, 7] : userMed.scheduledDays
    }

    private func toggleDay(_ weekday: Int) {
        var days = activeDays
        if days.contains(weekday) {
            guard days.count > 1 else { return }   // always keep at least one day
            days.removeAll { $0 == weekday }
        } else {
            days.append(weekday)
        }
        userMed.scheduledDays = days
        try? modelContext.save()
        if userMed.remindersEnabled {
            Task { await ReminderManager.shared.scheduleReminders(for: userMed) }
        }
    }

    /// Human-readable summary of selected weekdays, e.g. "Mon, Wed, Fri".
    private func daysSummary(_ days: [Int]) -> String {
        let names: [Int: String] = [1: "Sun", 2: "Mon", 3: "Tue", 4: "Wed", 5: "Thu", 6: "Fri", 7: "Sat"]
        let weekdays = Set(days)
        if weekdays == [2, 3, 4, 5, 6] { return "Weekdays" }
        if weekdays == [1, 7]           { return "Weekends" }
        // Order Mon→Sun for display
        return orderedDays
            .filter { weekdays.contains($0.weekday) }
            .compactMap { names[$0.weekday] }
            .joined(separator: ", ")
    }

    private var quickPresetsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Quick presets")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Palette.textSecondary)
                .padding(.horizontal, 4)

            VStack(spacing: 8) {
                presetButton(title: "Once daily · 8am", times: ["08:00"])
                presetButton(title: "Twice daily · 8am, 8pm", times: ["08:00", "20:00"])
                presetButton(title: "With meals · 8am, 12pm, 6pm", times: ["08:00", "12:00", "18:00"])
                presetButton(title: "Morning + booster · 8am, 2pm", times: ["08:00", "14:00"])
                presetButton(title: "At bedtime · 10pm", times: ["22:00"])
                addTimePresetButton
            }
        }
    }

    private var addTimePresetButton: some View {
        Button {
            pendingTime = Self.defaultPendingTime()
            showingTimePicker = true
        } label: {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(Theme.Palette.primary)
                    Text("Add a custom time")
                        .font(Theme.Font.body)
                        .foregroundStyle(Theme.Palette.textPrimary)
                }
                Spacer()
                Image(systemName: "clock")
                    .foregroundStyle(Theme.Palette.textSecondary)
            }
            .padding(14)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous)
                    .strokeBorder(
                        Theme.Palette.primary.opacity(0.4),
                        style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func presetButton(title: String, times: [String]) -> some View {
        Button {
            userMed.scheduledTimes = times
            try? modelContext.save()
        } label: {
            HStack {
                Text(title)
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.Palette.textPrimary)
                Spacer()
                if Set(userMed.scheduledTimes) == Set(times) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Theme.Palette.primary)
                } else {
                    Image(systemName: "arrow.right")
                        .foregroundStyle(Theme.Palette.textSecondary)
                }
            }
            .padding(14)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous)
                    .stroke(Theme.Palette.divider, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func addTime(from date: Date) {
        let timeString = ScheduleTime.string(from: date)
        var times = userMed.scheduledTimes
        if !times.contains(timeString) {
            times.append(timeString)
            userMed.scheduledTimes = times.sorted()
            try? modelContext.save()
        }
    }

    private func removeTime(_ timeString: String) {
        userMed.scheduledTimes.removeAll { $0 == timeString }
        try? modelContext.save()
    }
}

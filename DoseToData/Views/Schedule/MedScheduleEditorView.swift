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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerCard
                timesSection
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
            HStack {
                Text("Scheduled times")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Palette.textSecondary)
                Spacer()
                Button {
                    pendingTime = Self.defaultPendingTime()
                    showingTimePicker = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                        Text("Add time")
                    }
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Palette.primary)
                }
            }
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
            }
        }
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

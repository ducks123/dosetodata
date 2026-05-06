import SwiftUI

/// Sheet for configuring when the user gets check-in reminders.
/// Accessible via the bell icon on the Today card.
/// Supports preset options (morning, afternoon, evening) plus custom times.
struct CheckInReminderSheet: View {
    @Environment(UserPreferences.self) private var prefs
    @Environment(\.dismiss) private var dismiss

    // Local draft — committed on Done
    @State private var selectedTimes: Set<String> = []
    @State private var showCustomPicker = false
    @State private var customTime = Date()

    private let presets: [(label: String, icon: String, time: String)] = [
        ("Morning",   "sunrise.fill",  "08:00"),
        ("Afternoon", "sun.max.fill",  "12:00"),
        ("Evening",   "moon.fill",     "17:00"),
    ]

    /// Any selected times that aren't one of the three presets.
    private var customSelectedTimes: [String] {
        let presetSet = Set(presets.map(\.time))
        return selectedTimes.filter { !presetSet.contains($0) }.sorted()
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 24) {

                Text("Get a gentle nudge at the times you choose. You can pick more than one.")
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .padding(.horizontal, 20)
                    .padding(.top, 4)

                VStack(spacing: 0) {
                    // Preset rows
                    ForEach(presets, id: \.time) { preset in
                        let isOn = selectedTimes.contains(preset.time)
                        Button {
                            toggle(preset.time)
                        } label: {
                            HStack(spacing: 14) {
                                ZStack {
                                    Circle()
                                        .fill(isOn ? Theme.Palette.primary : Theme.Palette.primary.opacity(0.10))
                                        .frame(width: 36, height: 36)
                                    Image(systemName: preset.icon)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(isOn ? .white : Theme.Palette.primary)
                                }
                                Text(preset.label)
                                    .font(Theme.Font.bodyEmphasis)
                                    .foregroundStyle(Theme.Palette.textPrimary)
                                Spacer()
                                Text(formattedTime(preset.time))
                                    .font(Theme.Font.caption)
                                    .foregroundStyle(Theme.Palette.textSecondary)
                                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(isOn ? Theme.Palette.primary : Theme.Palette.divider)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 14)
                            .background(Color.white)
                        }
                        .buttonStyle(.plain)
                        Divider().padding(.leading, 70)
                    }

                    // Already-added custom times
                    ForEach(customSelectedTimes, id: \.self) { timeString in
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(Theme.Palette.primary)
                                    .frame(width: 36, height: 36)
                                Image(systemName: "clock.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                            Text(formattedTime(timeString))
                                .font(Theme.Font.bodyEmphasis)
                                .foregroundStyle(Theme.Palette.textPrimary)
                            Spacer()
                            Button {
                                selectedTimes.remove(timeString)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(Theme.Palette.negative)
                                    .font(.system(size: 20))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                        .background(Color.white)
                        Divider().padding(.leading, 70)
                    }

                    // Custom time expand row
                    Button {
                        showCustomPicker.toggle()
                    } label: {
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(Theme.Palette.primary.opacity(0.10))
                                    .frame(width: 36, height: 36)
                                Image(systemName: showCustomPicker ? "minus" : "plus")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Theme.Palette.primary)
                            }
                            Text("Add custom time")
                                .font(Theme.Font.bodyEmphasis)
                                .foregroundStyle(Theme.Palette.textPrimary)
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                        .background(Color.white)
                    }
                    .buttonStyle(.plain)

                    if showCustomPicker {
                        VStack(spacing: 10) {
                            DatePicker("", selection: $customTime, displayedComponents: .hourAndMinute)
                                .datePickerStyle(.wheel)
                                .labelsHidden()

                            Button("Add this time") {
                                let comps = Calendar.current.dateComponents([.hour, .minute], from: customTime)
                                let h = comps.hour ?? 17
                                let m = comps.minute ?? 0
                                let timeString = String(format: "%02d:%02d", h, m)
                                selectedTimes.insert(timeString)
                                showCustomPicker = false
                            }
                            .buttonStyle(PrimaryButtonStyle())
                            .padding(.horizontal, 20)
                            .padding(.bottom, 12)
                        }
                        .background(Color.white)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card).stroke(Theme.Palette.divider, lineWidth: 1))
                .padding(.horizontal, 20)

                // "No reminders" option
                Button {
                    selectedTimes.removeAll()
                } label: {
                    HStack {
                        Text("No reminders")
                            .font(Theme.Font.body)
                            .foregroundStyle(selectedTimes.isEmpty ? Theme.Palette.negative : Theme.Palette.textSecondary)
                        Spacer()
                        if selectedTimes.isEmpty {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Theme.Palette.negative)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
                    .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card).stroke(Theme.Palette.divider, lineWidth: 1))
                    .padding(.horizontal, 20)
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .background(Theme.Palette.background.ignoresSafeArea())
            .navigationTitle("Check-in reminders")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        save()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                selectedTimes = Set(prefs.checkInReminderTimes)
            }
        }
    }

    private func toggle(_ time: String) {
        if selectedTimes.contains(time) {
            selectedTimes.remove(time)
        } else {
            selectedTimes.insert(time)
        }
    }

    private func save() {
        // If the custom picker is still open, auto-commit the displayed time
        if showCustomPicker {
            let comps = Calendar.current.dateComponents([.hour, .minute], from: customTime)
            let h = comps.hour ?? 17
            let m = comps.minute ?? 0
            selectedTimes.insert(String(format: "%02d:%02d", h, m))
        }
        let times = Array(selectedTimes).sorted()
        prefs.checkInReminderTimes = times
        Task {
            await ReminderManager.shared.scheduleCheckInReminders(times: times)
        }
    }

    private func formattedTime(_ timeString: String) -> String {
        ScheduleTime.displayString(from: timeString)
    }
}

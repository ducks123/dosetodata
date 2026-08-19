import SwiftUI
import SwiftData

struct EditMedicationsSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \UserMedication.startDate, order: .reverse) private var userMedications: [UserMedication]

    @State private var showingAdd = false
    @State private var medToStop: UserMedication? = nil

    private var activeMeds: [UserMedication] {
        userMedications.filter { $0.endDate == nil }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    intro

                    currentMedsSection

                    Button {
                        showingAdd = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                            Text("Add a medication")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
                .padding(20)
            }
            .background(Theme.Palette.background)
            .navigationTitle("Edit medications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .sheet(isPresented: $showingAdd) {
            AddMedicationFlow { userMed in
                modelContext.insert(userMed)
                modelContext.saveChanges("edit medications")
            }
        }
        .confirmationDialog(
            "Stop this medication?",
            isPresented: .init(
                get: { medToStop != nil },
                set: { if !$0 { medToStop = nil } }
            ),
            presenting: medToStop
        ) { med in
            Button("Stop \(med.medication.brandName)", role: .destructive) {
                stop(med)
            }
            Button("Cancel", role: .cancel) { medToStop = nil }
        } message: { med in
            Text("This marks \(med.medication.brandName) as stopped today. It stays in your history for trends.")
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Your schedule")
                .font(Theme.Font.heroLabel)
                .foregroundStyle(Theme.Palette.textSecondary)
            Text("Add or remove meds")
                .font(Theme.Font.hero)
        }
    }

    private var currentMedsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Current")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Palette.textSecondary)
                .padding(.leading, 4)

            if activeMeds.isEmpty {
                Text("Nothing on your schedule yet. Tap 'Add a medication' below.")
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .cardStyle()
            } else {
                ForEach(activeMeds) { userMed in
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(userMed.medication.category.pastelColor)
                                .frame(width: 40, height: 40)
                            Image(systemName: userMed.medication.category.iconSystemName)
                                .foregroundStyle(Theme.Palette.primary)
                                .font(.system(size: 16, weight: .semibold))
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(userMed.medication.brandName)
                                .font(Theme.Font.bodyEmphasis)
                            Text(scheduleSummary(for: userMed))
                                .font(Theme.Font.caption)
                                .foregroundStyle(Theme.Palette.textSecondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Button(role: .destructive) {
                            medToStop = userMed
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(Theme.Palette.negative)
                        }
                        .buttonStyle(.plain)
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
        }
    }

    private func scheduleSummary(for userMed: UserMedication) -> String {
        let times = userMed.scheduledTimes.sorted()
        if times.isEmpty {
            return "\(userMed.currentDose) · no times set"
        }
        let formatted = times.map { ScheduleTime.displayString(from: $0) }
        return "\(userMed.currentDose) · \(formatted.joined(separator: ", "))"
    }

    private func stop(_ userMed: UserMedication) {
        userMed.endDate = Date()
        let event = MedEvent(
            userMedication: userMed,
            type: .stopped,
            date: Date(),
            previousDose: userMed.currentDose,
            newDose: nil
        )
        modelContext.insert(event)
        modelContext.saveChanges("edit medications")
        // A stopped medication must stop reminding (H2). Clear its pending
        // notifications after the save commits.
        let stoppedID = userMed.id
        Task { await ReminderManager.shared.clearReminders(for: stoppedID) }
        medToStop = nil
    }
}

struct AddMedicationFlow: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Medication.brandName) private var libraryMeds: [Medication]

    @State private var searchText: String = ""
    @State private var selectedMed: Medication? = nil
    @State private var dose: String = ""
    @State private var addToSchedule: Bool = true
    @State private var scheduledTimes: [String] = []
    @State private var scheduledDays: [Int] = [1, 2, 3, 4, 5, 6, 7]
    @State private var showingTimePicker = false
    @State private var pendingTime: Date = Self.defaultTime()
    @State private var showingCustomForm = false

    let onCommit: (UserMedication) -> Void

    private static func defaultTime() -> Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = 8
        components.minute = 0
        return Calendar.current.date(from: components) ?? Date()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if selectedMed == nil {
                        librarySection
                    } else {
                        medDetailsSection

                        // The CTA lives at the END of the form, not pinned
                        // over it — users pass dose, times, and days before
                        // reaching it, so nobody commits before configuring
                        // reminders.
                        Button {
                            commit()
                        } label: {
                            Text("Add to my medications")
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(dose.isEmpty)
                        .opacity(dose.isEmpty ? 0.5 : 1)
                        .padding(.top, 8)
                    }
                }
                .padding(20)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.immediately)
            .dismissKeyboardOnTap()
            .background(Theme.Palette.background)
            .navigationTitle("Add medication")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .sheet(isPresented: $showingTimePicker) {
            TimePickerSheet(initialTime: pendingTime) { time in
                let timeString = ScheduleTime.string(from: time)
                if !scheduledTimes.contains(timeString) {
                    scheduledTimes.append(timeString)
                    scheduledTimes.sort()
                }
            }
        }
        .sheet(isPresented: $showingCustomForm) {
            CustomMedicationForm { newMed, dose, addToSchedule, scheduledTimes, scheduledDays in
                // Custom form now captures dose + schedule itself, so commit
                // the UserMedication directly — no second detail screen.
                // Mirrors the library-med commit() path: insert the new
                // Medication here, build the UserMedication, and let the
                // parent's onCommit do the insert + save.
                modelContext.insert(newMed)
                let userMed = UserMedication(
                    medication: newMed,
                    currentDose: dose,
                    startDate: Date()
                )
                if addToSchedule {
                    userMed.scheduledTimes = scheduledTimes
                    userMed.scheduledDays = scheduledDays
                }
                onCommit(userMed)
                if userMed.remindersEnabled && !userMed.scheduledTimes.isEmpty {
                    Task { await ReminderManager.shared.scheduleReminders(for: userMed) }
                }
                dismiss()
            }
        }
    }

    private var librarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Theme.Palette.textSecondary)
                TextField("Search medications", text: $searchText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.button))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.button).stroke(Theme.Palette.divider, lineWidth: 1))

            // No match for the search: Add-custom leads so the escape hatch
            // is the first thing under the field, not buried below.
            if !searchText.isEmpty && filteredLibrary.isEmpty {
                customMedRow
            }

            ForEach(filteredLibrary.prefix(searchText.isEmpty ? 8 : 20)) { med in
                Button {
                    selectedMed = med
                    dose = ""  // user types their prescribed dose (Apple 1.4.2)
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(med.category.pastelColor)
                                .frame(width: 40, height: 40)
                            Image(systemName: med.category.iconSystemName)
                                .foregroundStyle(Theme.Palette.primary)
                                .font(.system(size: 16, weight: .semibold))
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(med.brandName)
                                .font(Theme.Font.bodyEmphasis)
                            Text("\(med.genericName) · \(med.medClass)")
                                .font(Theme.Font.caption)
                                .foregroundStyle(Theme.Palette.textSecondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Image(systemName: "plus.circle")
                            .foregroundStyle(Theme.Palette.textSecondary)
                    }
                    .padding(12)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
                }
                .buttonStyle(.plain)
            }

            if searchText.isEmpty || !filteredLibrary.isEmpty {
                customMedRow
            }
        }
    }

    private var customMedRow: some View {
        Button {
            showingCustomForm = true
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(MedCategory.other.pastelColor)
                        .frame(width: 40, height: 40)
                    Image(systemName: "plus")
                        .foregroundStyle(Theme.Palette.primary)
                        .font(.system(size: 16, weight: .semibold))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Can't find it?")
                        .font(Theme.Font.bodyEmphasis)
                    Text("Add a custom medication")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Palette.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(Theme.Palette.textSecondary)
            }
            .padding(12)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.card)
                    .strokeBorder(
                        Theme.Palette.primary.opacity(0.4),
                        style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var medDetailsSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            if let med = selectedMed {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(med.category.pastelColor)
                            .frame(width: 44, height: 44)
                        Image(systemName: med.category.iconSystemName)
                            .foregroundStyle(Theme.Palette.primary)
                            .font(.system(size: 18, weight: .semibold))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(med.brandName)
                            .font(Theme.Font.sectionTitle)
                        Text(med.genericName)
                            .font(Theme.Font.caption)
                            .foregroundStyle(Theme.Palette.textSecondary)
                    }
                    Spacer()
                    Button("Change") { selectedMed = nil }
                        .font(Theme.Font.caption)
                }
                .cardStyle()

                MedDoseAndTimesPicker(
                    commonDoses: med.commonDoses,
                    dose: $dose,
                    addToSchedule: $addToSchedule,
                    scheduledTimes: $scheduledTimes,
                    scheduledDays: $scheduledDays,
                    onAddTime: {
                        pendingTime = Self.defaultTime()
                        showingTimePicker = true
                    }
                )
            }
        }
    }

    private var filteredLibrary: [Medication] {
        guard !searchText.isEmpty else { return libraryMeds }
        let q = searchText.lowercased()
        return libraryMeds.filter {
            $0.brandName.lowercased().contains(q) ||
            $0.genericName.lowercased().contains(q) ||
            $0.medClass.lowercased().contains(q)
        }
    }

    private func commit() {
        guard let med = selectedMed else { return }
        let userMed = UserMedication(
            medication: med,
            currentDose: dose,
            startDate: Date()
        )
        // Reminders are ON by default (UserMedication defaults `remindersEnabled = true`).
        // That holds for both library and custom meds. If the user adds times now, we
        // schedule them immediately below; if they add times later from the Schedule
        // editor, the editor's onChange(of: scheduledTimes) picks it up automatically.
        if addToSchedule {
            userMed.scheduledTimes = scheduledTimes
            userMed.scheduledDays = scheduledDays.isEmpty ? [1, 2, 3, 4, 5, 6, 7] : scheduledDays
        }
        onCommit(userMed)
        if userMed.remindersEnabled && !userMed.scheduledTimes.isEmpty {
            Task {
                await ReminderManager.shared.scheduleReminders(for: userMed)
            }
        }
        dismiss()
    }
}

struct MedDoseAndTimesPicker: View {
    let commonDoses: [String]
    @Binding var dose: String
    @Binding var addToSchedule: Bool
    @Binding var scheduledTimes: [String]
    /// Weekdays the med is taken (Calendar.weekday convention: 1=Sun … 7=Sat).
    @Binding var scheduledDays: [Int]
    let onAddTime: () -> Void

    /// Mon-first display order for the weekday picker.
    private let orderedDays: [(weekday: Int, label: String)] = [
        (2, "M"), (3, "Tu"), (4, "W"), (5, "Th"), (6, "F"), (7, "Sa"), (1, "Su")
    ]

    private var activeDays: [Int] {
        scheduledDays.isEmpty ? [1, 2, 3, 4, 5, 6, 7] : scheduledDays
    }

    private func toggleDay(_ weekday: Int) {
        var days = Set(activeDays)
        if days.contains(weekday) {
            // Don't allow removing the last day — a med taken zero days
            // makes no sense; keep at least one selected.
            if days.count > 1 { days.remove(weekday) }
        } else {
            days.insert(weekday)
        }
        scheduledDays = days.sorted()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                // Dose label + required indicator. Real user feedback from a
                // brother of Stewart's: when adding a medication without a
                // dose, the Add button stays disabled with no explanation,
                // and it wasn't obvious WHICH field was the blocker. The
                // red "Required" pill makes it unmissable.
                HStack(spacing: 6) {
                    Text("Dose")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Palette.textSecondary)
                    Text("Required")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Theme.Palette.negative)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Theme.Palette.negative.opacity(0.12))
                        .clipShape(Capsule())
                }
                // Preset dose chips were removed to comply with App Store
                // Guideline 1.4.2 — Apple reads suggested doses as a "dosage
                // calculator," which is restricted to manufacturer / hospital
                // accounts. Users type whatever their prescriber has them on.
                // `commonDoses` stays on the Medication model for future use.
                TextField("Enter your prescribed dose (e.g. 10mg, 1 tablet)", text: $dose)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.button))
                    .overlay(RoundedRectangle(cornerRadius: Theme.Radius.button).stroke(
                        dose.trimmingCharacters(in: .whitespaces).isEmpty
                            ? Theme.Palette.negative.opacity(0.5)
                            : Theme.Palette.divider,
                        lineWidth: 1
                    ))
                if dose.trimmingCharacters(in: .whitespaces).isEmpty {
                    Text("Enter a dose to enable Add.")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.Palette.negative)
                        .padding(.leading, 4)
                }
            }

            Toggle(isOn: $addToSchedule) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Add it to my medication schedule")
                        .font(Theme.Font.bodyEmphasis)
                    Text("Pick times to see doses on the schedule and get reminders.")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .tint(Theme.Palette.primary)
            .padding(14)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))

            if addToSchedule {
                VStack(alignment: .leading, spacing: 10) {
                    Text("How often")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Palette.textSecondary)
                        .padding(.horizontal, 4)

                    presetRow(title: "Once daily · 8am", times: ["08:00"])
                    presetRow(title: "Twice daily · 8am, 8pm", times: ["08:00", "20:00"])
                    presetRow(title: "With meals · 8am, 12pm, 6pm", times: ["08:00", "12:00", "18:00"])
                    presetRow(title: "At bedtime · 10pm", times: ["22:00"])
                    addCustomTimeRow

                    // Which days of the week the med is taken. Defaults to
                    // every day; the user can deselect days here at add time
                    // instead of having to open the Schedule editor later.
                    HStack {
                        Text("Which days")
                            .font(Theme.Font.caption)
                            .foregroundStyle(Theme.Palette.textSecondary)
                        Spacer()
                        Text(activeDays.count == 7 ? "Every day" : "\(activeDays.count) days/week")
                            .font(Theme.Font.caption)
                            .foregroundStyle(Theme.Palette.primary)
                    }
                    .padding(.horizontal, 4)
                    .padding(.top, 4)

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
                                            .stroke(isOn ? Theme.Palette.primary : Theme.Palette.divider, lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if !scheduledTimes.isEmpty {
                        Divider().padding(.vertical, 4)
                        ForEach(scheduledTimes, id: \.self) { timeString in
                            HStack {
                                Image(systemName: "clock")
                                    .foregroundStyle(Theme.Palette.primary)
                                Text(ScheduleTime.displayString(from: timeString))
                                    .font(Theme.Font.bodyEmphasis)
                                Spacer()
                                Button {
                                    scheduledTimes.removeAll { $0 == timeString }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(Theme.Palette.textSecondary)
                                }
                            }
                            .padding(.horizontal, 4)
                        }

                        // Reminders are automatically enabled for scheduled meds.
                        // Turn them off per-med from Schedule → tap the med → Reminders toggle.
                        Text("We'll send a reminder at each time. Turn off from the medication's schedule if you don't want it.")
                            .font(Theme.Font.caption)
                            .foregroundStyle(Theme.Palette.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 4)
                    }
                }
            }
        }
    }

    private var addCustomTimeRow: some View {
        Button {
            onAddTime()
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
            .padding(12)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.button))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.button)
                    .strokeBorder(
                        Theme.Palette.primary.opacity(0.4),
                        style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func presetRow(title: String, times: [String]) -> some View {
        Button {
            scheduledTimes = times
        } label: {
            HStack {
                Text(title)
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.Palette.textPrimary)
                Spacer()
                if Set(scheduledTimes) == Set(times) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Theme.Palette.primary)
                } else {
                    Image(systemName: "arrow.right")
                        .foregroundStyle(Theme.Palette.textSecondary)
                }
            }
            .padding(12)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.button))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.button)
                    .stroke(Theme.Palette.divider, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct CustomMedicationForm: View {
    @Environment(\.dismiss) private var dismiss

    @State private var brandName: String = ""
    @State private var genericName: String = ""
    @State private var category: MedCategory = .other
    // Dose + schedule are now captured HERE so the custom-med flow is a
    // single screen — previously the user filled this form, then got a
    // SECOND "Add medication" screen re-asking for dose + how-often. Now
    // it's all one step.
    @State private var dose: String = ""
    @State private var addToSchedule: Bool = true
    @State private var scheduledTimes: [String] = []
    @State private var scheduledDays: [Int] = [1, 2, 3, 4, 5, 6, 7]
    @State private var showingTimePicker = false
    @State private var pendingTime: Date = Self.defaultTime()

    /// Delivers the fully-specified custom medication AND its dose/schedule
    /// in one shot so the caller can create the UserMedication directly with
    /// no follow-up sheet.
    let onSave: (_ medication: Medication, _ dose: String, _ addToSchedule: Bool, _ scheduledTimes: [String], _ scheduledDays: [Int]) -> Void

    private static func defaultTime() -> Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = 8
        components.minute = 0
        return Calendar.current.date(from: components) ?? Date()
    }

    private var canSave: Bool {
        !brandName.trimmingCharacters(in: .whitespaces).isEmpty
            && !dose.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("New medication")
                            .font(Theme.Font.heroLabel)
                            .foregroundStyle(Theme.Palette.textSecondary)
                        Text("Add your own")
                            .font(Theme.Font.hero)
                    }

                    field(title: "Name", placeholder: "e.g. Adderall, Lexapro", text: $brandName)
                    field(title: "Generic name (optional)", placeholder: "e.g. amphetamine", text: $genericName)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Category")
                            .font(Theme.Font.caption)
                            .foregroundStyle(Theme.Palette.textSecondary)
                            .padding(.leading, 4)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(MedCategory.allCases) { cat in
                                    Button {
                                        category = cat
                                    } label: {
                                        Text(cat.displayName)
                                            .font(Theme.Font.bodyEmphasis)
                                            .padding(.vertical, 8)
                                            .padding(.horizontal, 14)
                                            .background(category == cat ? Theme.Palette.primary : Color.white)
                                            .foregroundStyle(category == cat ? Color.white : Theme.Palette.textPrimary)
                                            .clipShape(Capsule())
                                            .overlay(Capsule().stroke(Theme.Palette.divider, lineWidth: category == cat ? 0 : 1))
                                    }
                                }
                            }
                        }
                    }

                    // Same dose + schedule UI used by the library-med flow,
                    // so a custom med is fully set up on this one screen.
                    MedDoseAndTimesPicker(
                        commonDoses: [],
                        dose: $dose,
                        addToSchedule: $addToSchedule,
                        scheduledTimes: $scheduledTimes,
                        scheduledDays: $scheduledDays,
                        onAddTime: { showingTimePicker = true }
                    )

                    // The CTA lives at the END of the form, not pinned over
                    // it — users pass dose, times, and days before reaching
                    // it, so nobody commits before configuring reminders.
                    Button {
                        save()
                    } label: {
                        Text("Add to my medications")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(!canSave)
                    .opacity(canSave ? 1 : 0.5)
                    .padding(.top, 8)
                }
                .padding(20)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.immediately)
            .dismissKeyboardOnTap()
            .background(Theme.Palette.background)
            .navigationTitle("Custom medication")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showingTimePicker) {
                TimePickerSheet(initialTime: pendingTime) { time in
                    let timeString = ScheduleTime.string(from: time)
                    if !scheduledTimes.contains(timeString) {
                        scheduledTimes.append(timeString)
                        scheduledTimes.sort()
                    }
                }
            }
        }
    }

    private func field(title: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Palette.textSecondary)
                .padding(.leading, 4)
            TextField(placeholder, text: text)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.button))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.button).stroke(Theme.Palette.divider, lineWidth: 1))
        }
    }

    private func save() {
        let trimmedBrand = brandName.trimmingCharacters(in: .whitespaces)
        let trimmedGeneric = genericName.trimmingCharacters(in: .whitespaces)
        let med = Medication(
            brandName: trimmedBrand,
            genericName: trimmedGeneric.isEmpty ? trimmedBrand : trimmedGeneric,
            medClass: "Custom",
            commonDoses: [],
            commonSideEffects: [],
            isExtendedRelease: false,
            category: category
        )
        onSave(
            med,
            dose.trimmingCharacters(in: .whitespaces),
            addToSchedule,
            addToSchedule ? scheduledTimes : [],
            addToSchedule ? (scheduledDays.isEmpty ? [1, 2, 3, 4, 5, 6, 7] : scheduledDays) : [1, 2, 3, 4, 5, 6, 7]
        )
        dismiss()
    }
}

struct TimePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var time: Date

    let onAdd: (Date) -> Void

    init(initialTime: Date, onAdd: @escaping (Date) -> Void) {
        _time = State(initialValue: initialTime)
        self.onAdd = onAdd
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .padding()
                Button {
                    onAdd(time)
                    dismiss()
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
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

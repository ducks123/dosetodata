import SwiftUI
import SwiftData

struct MedicationsOnboardingStepView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Medication.brandName) private var libraryMeds: [Medication]
    @Query(sort: \UserMedication.startDate, order: .reverse) private var userMedications: [UserMedication]

    @State private var searchText: String = ""
    @State private var pendingMed: Medication? = nil   // shown in dose/time sheet
    @State private var showingCustomForm = false

    let onContinue: () -> Void
    let onSkip: () -> Void

    private var filteredLibrary: [Medication] {
        let alreadyAddedIDs = Set(userMedications.map { $0.medication.id })
        let pool = libraryMeds.filter { !alreadyAddedIDs.contains($0.id) }
        guard !searchText.isEmpty else { return pool }
        let q = searchText.lowercased()
        return pool.filter {
            $0.brandName.lowercased().contains(q) ||
            $0.genericName.lowercased().contains(q) ||
            $0.medClass.lowercased().contains(q)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Step 2 of 4")
                    .font(Theme.Font.heroLabel)
                    .foregroundStyle(Theme.Palette.textSecondary)
                Text("Any medications\nyou're taking now?")
                    .font(Theme.Font.hero)
                    .foregroundStyle(Theme.Palette.textPrimary)
                Text("Tap one to set a dose, time, and reminders.")
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .padding(.top, 2)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)

            searchField
                .padding(.horizontal, 24)
                .padding(.top, 16)

            ScrollView {
                VStack(spacing: 10) {
                    if !userMedications.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Added")
                                .font(Theme.Font.caption)
                                .foregroundStyle(Theme.Palette.textSecondary)
                            ForEach(userMedications) { userMed in
                                AddedMedRow(userMed: userMed) {
                                    modelContext.delete(userMed)
                                    try? modelContext.save()
                                }
                            }
                        }
                        .padding(.top, 16)
                    }

                    if !filteredLibrary.isEmpty {
                        ForEach(filteredLibrary.prefix(searchText.isEmpty ? 30 : 50)) { med in
                            MedLibraryRow(med: med) {
                                pendingMed = med
                            }
                        }
                    }

                    CantFindItRow {
                        showingCustomForm = true
                    }
                    .padding(.top, 6)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
            }

            VStack(spacing: 10) {
                Button {
                    onContinue()
                } label: {
                    Text(userMedications.isEmpty ? "Continue without adding" : "Continue")
                }
                .buttonStyle(PrimaryButtonStyle())

                Button("I'll add later") {
                    onSkip()
                }
                .font(Theme.Font.body)
                .foregroundStyle(Theme.Palette.textSecondary)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
        }
        .sheet(item: $pendingMed) { med in
            OnboardingMedDetailsSheet(medication: med) { dose, addToSchedule, scheduledTimes in
                let userMed = UserMedication(
                    medication: med,
                    currentDose: dose,
                    startDate: Date()
                )
                if addToSchedule { userMed.scheduledTimes = scheduledTimes }
                modelContext.insert(userMed)
                try? modelContext.save()
                if userMed.remindersEnabled && !userMed.scheduledTimes.isEmpty {
                    Task { await ReminderManager.shared.scheduleReminders(for: userMed) }
                }
            }
        }
        .sheet(isPresented: $showingCustomForm) {
            CustomMedicationForm { newMed in
                modelContext.insert(newMed)
                try? modelContext.save()
                // Chain straight into dose/time setup for the new custom med.
                pendingMed = newMed
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Theme.Palette.textSecondary)
            TextField("Search medications", text: $searchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Theme.Palette.textSecondary)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous)
                .stroke(Theme.Palette.divider, lineWidth: 1)
        )
    }
}

// MARK: - Library row

private struct MedLibraryRow: View {
    let med: Medication
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
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
                        .foregroundStyle(Theme.Palette.textPrimary)
                    Text("\(med.genericName) · \(med.medClass)")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Palette.textSecondary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "plus.circle")
                    .font(.system(size: 22))
                    .foregroundStyle(Theme.Palette.textSecondary)
            }
            .padding(12)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Custom-medication row (dashed)

private struct CantFindItRow: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
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
                        .foregroundStyle(Theme.Palette.textPrimary)
                    Text("Add a custom medication")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Palette.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.Palette.textSecondary)
            }
            .padding(12)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .strokeBorder(
                        Theme.Palette.primary.opacity(0.4),
                        style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Already-added row

private struct AddedMedRow: View {
    let userMed: UserMedication
    let onRemove: () -> Void

    var body: some View {
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
                Text(detailLine)
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .lineLimit(2)
            }
            Spacer()
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(Theme.Palette.textSecondary)
            }
        }
        .padding(12)
        .background(Theme.Palette.heroAccent)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
    }

    private var detailLine: String {
        var parts: [String] = [userMed.currentDose]
        if !userMed.scheduledTimes.isEmpty {
            let first = userMed.scheduledTimes.first ?? ""
            let extra = userMed.scheduledTimes.count - 1
            parts.append(extra > 0
                         ? "\(ScheduleTime.displayString(from: first)) +\(extra)"
                         : ScheduleTime.displayString(from: first))
        }
        return parts.joined(separator: " · ")
    }
}

// MARK: - Dose / time / reminders sheet (presented when a library row is tapped)

private struct OnboardingMedDetailsSheet: View {
    let medication: Medication
    let onCommit: (_ dose: String, _ addToSchedule: Bool, _ scheduledTimes: [String]) -> Void

    @State private var dose: String
    @State private var addToSchedule: Bool = true
    @State private var scheduledTimes: [String] = []
    @State private var showingTimePicker = false
    @State private var pendingTime: Date = OnboardingMedDetailsSheet.defaultTime()

    @Environment(\.dismiss) private var dismiss

    init(medication: Medication,
         onCommit: @escaping (_ dose: String, _ addToSchedule: Bool, _ scheduledTimes: [String]) -> Void) {
        self.medication = medication
        self.onCommit = onCommit
        // Start with an empty dose so the user types in their prescribed dose
        // themselves. Pre-filling from `commonDoses` looked like a dose
        // recommendation to Apple's review (Guideline 1.4.2).
        _dose = State(initialValue: "")
    }

    private static func defaultTime() -> Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = 8
        components.minute = 0
        return Calendar.current.date(from: components) ?? Date()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(medication.category.pastelColor)
                                .frame(width: 44, height: 44)
                            Image(systemName: medication.category.iconSystemName)
                                .foregroundStyle(Theme.Palette.primary)
                                .font(.system(size: 18, weight: .semibold))
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(medication.brandName)
                                .font(Theme.Font.sectionTitle)
                            Text("\(medication.genericName) · \(medication.medClass)")
                                .font(Theme.Font.caption)
                                .foregroundStyle(Theme.Palette.textSecondary)
                        }
                        Spacer()
                    }
                    .padding(14)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))

                    MedDoseAndTimesPicker(
                        commonDoses: medication.commonDoses,
                        dose: $dose,
                        addToSchedule: $addToSchedule,
                        scheduledTimes: $scheduledTimes,
                        onAddTime: {
                            pendingTime = OnboardingMedDetailsSheet.defaultTime()
                            showingTimePicker = true
                        }
                    )
                }
                .padding(20)
                .padding(.bottom, 80)
            }
            .background(Theme.Palette.background)
            .navigationTitle("Add medication")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    onCommit(dose, addToSchedule, scheduledTimes)
                    dismiss()
                } label: {
                    Text("Add to my medications")
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Theme.Palette.background.opacity(0.96))
                .disabled(dose.trimmingCharacters(in: .whitespaces).isEmpty)
                .opacity(dose.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
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

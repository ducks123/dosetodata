import SwiftUI
import SwiftData

struct MedicationsOnboardingStepView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Medication.brandName) private var medications: [Medication]
    @Query(sort: \UserMedication.startDate, order: .reverse) private var userMedications: [UserMedication]

    @State private var searchText: String = ""
    @State private var showingAddSheet: Medication?

    let onContinue: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Step 2 of 3")
                    .font(Theme.Font.heroLabel)
                    .foregroundStyle(Theme.Palette.textSecondary)
                Text("Any medications\nyou're taking now?")
                    .font(Theme.Font.hero)
                    .foregroundStyle(Theme.Palette.textPrimary)
                Text("Add what you're on. Search by brand or generic name.")
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 24)
            .padding(.top, 32)

            searchField
                .padding(.horizontal, 24)
                .padding(.top, 24)

            ScrollView {
                VStack(spacing: 12) {
                    if !userMedications.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
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
                        .padding(.top, 8)
                    }

                    if !filtered.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(searchText.isEmpty ? "Popular" : "Matches")
                                .font(Theme.Font.caption)
                                .foregroundStyle(Theme.Palette.textSecondary)
                            ForEach(filtered.prefix(searchText.isEmpty ? 8 : 20)) { med in
                                MedLibraryRow(med: med) {
                                    showingAddSheet = med
                                }
                            }
                        }
                        .padding(.top, 12)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
            }

            VStack(spacing: 12) {
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
            .padding(.bottom, 32)
        }
        .sheet(item: $showingAddSheet) { med in
            AddMedicationSheet(medication: med) { dose, startDate in
                let userMed = UserMedication(
                    medication: med,
                    currentDose: dose,
                    startDate: startDate
                )
                modelContext.insert(userMed)
                try? modelContext.save()
                showingAddSheet = nil
            }
            .presentationDetents([.medium])
        }
    }

    private var filtered: [Medication] {
        let alreadyAddedIDs = Set(userMedications.map { $0.medication.id })
        let pool = medications.filter { !alreadyAddedIDs.contains($0.id) }
        guard !searchText.isEmpty else { return pool }
        let q = searchText.lowercased()
        return pool.filter {
            $0.brandName.lowercased().contains(q) ||
            $0.genericName.lowercased().contains(q) ||
            $0.medClass.lowercased().contains(q)
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

private struct MedLibraryRow: View {
    let med: Medication
    let onAdd: () -> Void

    var body: some View {
        Button(action: onAdd) {
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
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Theme.Palette.primary)
            }
            .padding(12)
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
                Text("\(userMed.currentDose) · started \(userMed.startDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Palette.textSecondary)
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
}

struct AddMedicationSheet: View {
    let medication: Medication
    let onAdd: (_ dose: String, _ startDate: Date) -> Void

    @State private var selectedDose: String
    @State private var startDate: Date = Date()
    @Environment(\.dismiss) private var dismiss

    init(medication: Medication, onAdd: @escaping (_ dose: String, _ startDate: Date) -> Void) {
        self.medication = medication
        self.onAdd = onAdd
        _selectedDose = State(initialValue: medication.commonDoses.first ?? "")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(medication.category.pastelColor)
                                .frame(width: 52, height: 52)
                            Image(systemName: medication.category.iconSystemName)
                                .foregroundStyle(Theme.Palette.primary)
                                .font(.system(size: 20, weight: .semibold))
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(medication.brandName)
                                .font(Theme.Font.sectionTitle)
                            Text("\(medication.genericName) · \(medication.medClass)")
                                .font(Theme.Font.caption)
                                .foregroundStyle(Theme.Palette.textSecondary)
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Dose")
                            .font(Theme.Font.caption)
                            .foregroundStyle(Theme.Palette.textSecondary)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(medication.commonDoses, id: \.self) { dose in
                                    Button {
                                        selectedDose = dose
                                    } label: {
                                        Text(dose)
                                            .font(Theme.Font.bodyEmphasis)
                                            .padding(.vertical, 8)
                                            .padding(.horizontal, 14)
                                            .background(selectedDose == dose ? Theme.Palette.primary : Color.white)
                                            .foregroundStyle(selectedDose == dose ? Color.white : Theme.Palette.textPrimary)
                                            .clipShape(Capsule())
                                            .overlay(
                                                Capsule().stroke(Theme.Palette.divider, lineWidth: selectedDose == dose ? 0 : 1)
                                            )
                                    }
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("When did you start?")
                            .font(Theme.Font.caption)
                            .foregroundStyle(Theme.Palette.textSecondary)
                        DatePicker("Start date", selection: $startDate, in: ...Date(), displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                    }

                    Button {
                        onAdd(selectedDose, startDate)
                        dismiss()
                    } label: {
                        Text("Add")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(selectedDose.isEmpty)
                    .padding(.top, 8)
                }
                .padding(24)
            }
            .background(Theme.Palette.background)
            .navigationTitle("Add medication")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

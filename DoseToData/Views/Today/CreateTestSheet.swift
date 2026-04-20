import SwiftUI
import SwiftData

struct CreateTestSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Medication.brandName) private var libraryMeds: [Medication]
    @Query(sort: \UserMedication.startDate, order: .reverse) private var userMedications: [UserMedication]

    enum ChangeType: String, CaseIterable, Identifiable {
        case started
        case stopped
        case doseChanged

        var id: String { rawValue }

        var title: String {
            switch self {
            case .started: return "Started a new medication"
            case .stopped: return "Stopped a medication"
            case .doseChanged: return "Changed a dose"
            }
        }

        var icon: String {
            switch self {
            case .started: return "plus.circle.fill"
            case .stopped: return "minus.circle.fill"
            case .doseChanged: return "arrow.left.arrow.right.circle.fill"
            }
        }

        var medEventType: MedEventType {
            switch self {
            case .started: return .started
            case .stopped: return .stopped
            case .doseChanged: return .doseChanged
            }
        }
    }

    @State private var step: Int = 0

    // Step 1
    @State private var changeType: ChangeType? = nil

    // Step 2 — picker state
    @State private var searchText: String = ""
    @State private var selectedLibraryMed: Medication? = nil
    @State private var selectedUserMed: UserMedication? = nil
    @State private var selectedDose: String = ""
    @State private var startDate: Date = Date()

    // Step 3 — test window + watching
    @State private var durationWeeks: Int = 4
    @State private var customDays: String = ""
    @State private var useCustomDuration: Bool = false
    @State private var watchingFor: String = ""

    private let durationPresets = [2, 4, 6, 8]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                progressBar
                ScrollView {
                    Group {
                        switch step {
                        case 0: changeTypeStep
                        case 1: medPickerStep
                        default: detailsStep
                        }
                    }
                    .padding(24)
                    .padding(.bottom, 40)
                }
                footer
            }
            .background(Theme.Palette.background)
            .navigationTitle("Create a test")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    // MARK: Progress

    private var progressBar: some View {
        HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { idx in
                Capsule()
                    .fill(idx <= step ? Theme.Palette.primary : Theme.Palette.divider)
                    .frame(height: 4)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 16)
    }

    // MARK: Step 1

    private var changeTypeStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("What's changing?")
                .font(Theme.Font.hero)
            Text("Pick the change you want to test. We'll help you scope a time window around it.")
                .font(Theme.Font.body)
                .foregroundStyle(Theme.Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 10) {
                ForEach(ChangeType.allCases) { type in
                    Button {
                        changeType = type
                        if type != .started {
                            selectedLibraryMed = nil
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: type.icon)
                                .font(.system(size: 22))
                                .foregroundStyle(Theme.Palette.primary)
                            Text(type.title)
                                .font(Theme.Font.bodyEmphasis)
                            Spacer()
                            Image(systemName: changeType == type ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(changeType == type ? Theme.Palette.primary : Theme.Palette.divider)
                        }
                        .padding(16)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.card)
                                .stroke(changeType == type ? Theme.Palette.primary : Color.clear, lineWidth: 2)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: Step 2

    private var medPickerStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(step2Title)
                .font(Theme.Font.hero)

            switch changeType {
            case .started:
                startedMedPicker
            case .stopped, .doseChanged:
                currentMedPicker
            case .none:
                EmptyView()
            }

            if (changeType == .started && selectedLibraryMed != nil) ||
                (changeType == .doseChanged && selectedUserMed != nil) {
                doseAndDatePicker
            }

            if changeType == .stopped && selectedUserMed != nil {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Stopped on")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Palette.textSecondary)
                    DatePicker("Stop date", selection: $startDate, in: ...Date(), displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                }
            }
        }
    }

    private var step2Title: String {
        switch changeType {
        case .started: return "Which medication?"
        case .stopped: return "Which one did you stop?"
        case .doseChanged: return "Which dose are you changing?"
        case .none: return ""
        }
    }

    private var startedMedPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
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

            ForEach(filteredLibrary.prefix(searchText.isEmpty ? 6 : 15)) { med in
                Button {
                    selectedLibraryMed = med
                    selectedDose = med.commonDoses.first ?? ""
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
                        Image(systemName: selectedLibraryMed?.id == med.id ? "checkmark.circle.fill" : "plus.circle")
                            .foregroundStyle(selectedLibraryMed?.id == med.id ? Theme.Palette.primary : Theme.Palette.textSecondary)
                    }
                    .padding(12)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.card)
                            .stroke(selectedLibraryMed?.id == med.id ? Theme.Palette.primary : Color.clear, lineWidth: 2)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var currentMedPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            if userMedications.isEmpty {
                Text("You haven't added any current medications yet. Head to Settings → My Medications to add one, then come back.")
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .cardStyle()
            } else {
                ForEach(userMedications.filter { $0.endDate == nil }) { userMed in
                    Button {
                        selectedUserMed = userMed
                        selectedDose = userMed.currentDose
                    } label: {
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
                                    .lineLimit(1)
                            }
                            Spacer()
                            Image(systemName: selectedUserMed?.id == userMed.id ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(selectedUserMed?.id == userMed.id ? Theme.Palette.primary : Theme.Palette.textSecondary)
                        }
                        .padding(12)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.card)
                                .stroke(selectedUserMed?.id == userMed.id ? Theme.Palette.primary : Color.clear, lineWidth: 2)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var doseAndDatePicker: some View {
        let doses: [String] = {
            if let m = selectedLibraryMed { return m.commonDoses }
            if let m = selectedUserMed { return m.medication.commonDoses }
            return []
        }()

        let dateLabel: String = changeType == .started ? "Started on" : "New dose starts"

        return VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text(changeType == .doseChanged ? "New dose" : "Dose")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Palette.textSecondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(doses, id: \.self) { dose in
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
                                    .overlay(Capsule().stroke(Theme.Palette.divider, lineWidth: selectedDose == dose ? 0 : 1))
                            }
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(dateLabel)
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Palette.textSecondary)
                DatePicker("Start date", selection: $startDate, in: ...Date(), displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .labelsHidden()
            }
        }
    }

    // MARK: Step 3

    private var detailsStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Test window")
                .font(Theme.Font.hero)
            Text("How long do you want to watch this change? Pick a window to make before/after comparisons meaningful.")
                .font(Theme.Font.body)
                .foregroundStyle(Theme.Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                ForEach(durationPresets, id: \.self) { weeks in
                    Button {
                        useCustomDuration = false
                        durationWeeks = weeks
                    } label: {
                        Text("\(weeks) wk")
                            .font(Theme.Font.bodyEmphasis)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background((!useCustomDuration && durationWeeks == weeks) ? Theme.Palette.primary : Color.white)
                            .foregroundStyle((!useCustomDuration && durationWeeks == weeks) ? Color.white : Theme.Palette.textPrimary)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.button))
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.Radius.button)
                                    .stroke(Theme.Palette.divider, lineWidth: (!useCustomDuration && durationWeeks == weeks) ? 0 : 1)
                            )
                    }
                }
            }

            HStack {
                Text("Or custom days:")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Palette.textSecondary)
                TextField("e.g. 30", text: $customDays)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 100)
                    .onChange(of: customDays) { _, newValue in
                        useCustomDuration = !newValue.isEmpty
                    }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("What are you watching for? (optional)")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Palette.textSecondary)
                TextField("e.g. Better focus at work", text: $watchingFor, axis: .vertical)
                    .lineLimit(1...3)
                    .textFieldStyle(.roundedBorder)
            }

            summaryCard
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Summary")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Palette.textSecondary)
            Text(summaryText)
                .font(Theme.Font.body)
                .foregroundStyle(Theme.Palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Palette.heroAccent)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
    }

    private var summaryText: String {
        let medName = selectedLibraryMed?.brandName ?? selectedUserMed?.medication.brandName ?? "a medication"
        let verb: String = switch changeType {
        case .started: "Started"
        case .stopped: "Stopped"
        case .doseChanged: "Changed dose to"
        case .none: ""
        }
        let dose = changeType == .stopped ? "" : " (\(selectedDose))"
        let days = totalDays
        return "\(verb) \(medName)\(dose) on \(startDate.formatted(date: .abbreviated, time: .omitted)), tracking for \(days) days."
    }

    // MARK: Footer

    private var footer: some View {
        HStack(spacing: 12) {
            if step > 0 {
                Button {
                    step -= 1
                } label: { Text("Back") }
                .buttonStyle(SecondaryButtonStyle())
            }

            Button {
                if step < 2 {
                    step += 1
                } else {
                    commit()
                }
            } label: {
                Text(step < 2 ? "Next" : "Create test")
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(nextDisabled)
            .opacity(nextDisabled ? 0.5 : 1)
        }
        .padding(20)
        .background(Theme.Palette.background)
    }

    private var nextDisabled: Bool {
        switch step {
        case 0: return changeType == nil
        case 1:
            switch changeType {
            case .started:
                return selectedLibraryMed == nil || selectedDose.isEmpty
            case .stopped:
                return selectedUserMed == nil
            case .doseChanged:
                return selectedUserMed == nil || selectedDose.isEmpty
            case .none:
                return true
            }
        default:
            return false
        }
    }

    // MARK: Data

    private var filteredLibrary: [Medication] {
        guard !searchText.isEmpty else { return libraryMeds }
        let q = searchText.lowercased()
        return libraryMeds.filter {
            $0.brandName.lowercased().contains(q) ||
            $0.genericName.lowercased().contains(q) ||
            $0.medClass.lowercased().contains(q)
        }
    }

    private var totalDays: Int {
        if useCustomDuration, let n = Int(customDays), n > 0 {
            return n
        }
        return durationWeeks * 7
    }

    private func commit() {
        guard let changeType else { return }

        let userMed: UserMedication = {
            switch changeType {
            case .started:
                guard let lib = selectedLibraryMed else { fatalError("med missing") }
                let um = UserMedication(
                    medication: lib,
                    currentDose: selectedDose,
                    startDate: startDate
                )
                modelContext.insert(um)
                return um
            case .stopped, .doseChanged:
                guard let um = selectedUserMed else { fatalError("user med missing") }
                return um
            }
        }()

        if changeType == .stopped {
            userMed.endDate = startDate
        }

        let previousDose: String? = (changeType == .doseChanged) ? userMed.currentDose : nil
        if changeType == .doseChanged {
            userMed.currentDose = selectedDose
        }

        let event = MedEvent(
            userMedication: userMed,
            type: changeType.medEventType,
            date: startDate,
            previousDose: previousDose,
            newDose: changeType == .stopped ? nil : selectedDose
        )
        modelContext.insert(event)

        let plannedEnd = Calendar.current.date(byAdding: .day, value: totalDays, to: startDate)
        let test = Test(
            startEvent: event,
            startDate: startDate,
            plannedEndDate: plannedEnd,
            watchingFor: watchingFor
        )
        modelContext.insert(test)
        event.test = test

        try? modelContext.save()
        dismiss()
    }
}

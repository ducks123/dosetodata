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
    @State private var testName: String = ""
    @State private var testNameEdited: Bool = false

    // Step 4 — custom questions scoped to this test
    @State private var customQuestionPrompts: [String] = []
    @State private var pendingQuestionText: String = ""

    // For .started: add to schedule + times
    @State private var addToSchedule: Bool = false
    @State private var scheduledTimes: [String] = []
    @State private var showingTimePicker = false
    @State private var pendingTime: Date = defaultTime()

    private static func defaultTime() -> Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = 8
        components.minute = 0
        return Calendar.current.date(from: components) ?? Date()
    }

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
                        case 2: detailsStep
                        default: customQuestionsStep
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

    // MARK: Progress

    private var progressBar: some View {
        HStack(spacing: 8) {
            ForEach(0..<4, id: \.self) { idx in
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
                Text("You haven't added any current medications yet. Tap 'Edit medications' on the home screen to add one, then come back.")
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

            if changeType == .started {
                scheduleSection
            }
        }
    }

    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: $addToSchedule) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Add it to my medication schedule")
                        .font(Theme.Font.bodyEmphasis)
                    Text("Adds this med to your daily schedule so you can track doses and reminders.")
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

                    scheduleChip(title: "Once daily · 8am", times: ["08:00"])
                    scheduleChip(title: "Twice daily · 8am, 8pm", times: ["08:00", "20:00"])
                    scheduleChip(title: "With meals · 8am, 12pm, 6pm", times: ["08:00", "12:00", "18:00"])
                    scheduleChip(title: "At bedtime · 10pm", times: ["22:00"])
                    addCustomTimeChip

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
                    }
                }
            }
        }
    }

    private var addCustomTimeChip: some View {
        Button {
            pendingTime = Self.defaultTime()
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

    private func scheduleChip(title: String, times: [String]) -> some View {
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

    // MARK: Step 3

    private var detailsStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Test window")
                .font(Theme.Font.hero)
            Text("How long do you want to watch this change? Pick a window to make before/after comparisons meaningful.")
                .font(Theme.Font.body)
                .foregroundStyle(Theme.Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 8) {
                Text("Test name")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Palette.textSecondary)
                TextField("Name this test", text: $testName)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: testName) { _, _ in testNameEdited = true }
                    .onAppear {
                        if !testNameEdited {
                            testName = defaultTestName
                        }
                    }
            }

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

    // MARK: Step 4 — custom questions

    private var customQuestionsStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Daily questions")
                .font(Theme.Font.hero)
            Text("Add questions or symptoms you want to track just during this test. They'll appear in your daily check-in while the test is running.")
                .font(Theme.Font.body)
                .foregroundStyle(Theme.Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(suggestedTestQuestions, id: \.self) { suggestion in
                    Button {
                        if !customQuestionPrompts.contains(suggestion) {
                            customQuestionPrompts.append(suggestion)
                        }
                    } label: {
                        HStack {
                            Text(suggestion)
                                .font(Theme.Font.body)
                                .foregroundStyle(Theme.Palette.textPrimary)
                            Spacer()
                            Image(systemName: customQuestionPrompts.contains(suggestion) ? "checkmark.circle.fill" : "plus.circle")
                                .foregroundStyle(customQuestionPrompts.contains(suggestion) ? Theme.Palette.primary : Theme.Palette.textSecondary)
                        }
                        .padding(12)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.button))
                        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.button).stroke(Theme.Palette.divider, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Add your own")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .padding(.leading, 4)
                HStack(spacing: 8) {
                    TextField("e.g. How was your appetite?", text: $pendingQuestionText)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.button))
                        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.button).stroke(Theme.Palette.divider, lineWidth: 1))
                    Button {
                        addPendingQuestion()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 26))
                            .foregroundStyle(pendingQuestionText.trimmingCharacters(in: .whitespaces).isEmpty ? Theme.Palette.divider : Theme.Palette.primary)
                    }
                    .disabled(pendingQuestionText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }

            if !customQuestionPrompts.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your questions for this test")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Palette.textSecondary)
                        .padding(.leading, 4)
                    ForEach(customQuestionPrompts, id: \.self) { prompt in
                        HStack {
                            Text(prompt)
                                .font(Theme.Font.body)
                            Spacer()
                            Button {
                                customQuestionPrompts.removeAll { $0 == prompt }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(Theme.Palette.textSecondary)
                            }
                        }
                        .padding(12)
                        .background(Theme.Palette.heroAccent)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.button))
                    }
                }
            }
        }
    }

    private var suggestedTestQuestions: [String] {
        switch changeType {
        case .started, .doseChanged:
            return [
                "How was your focus today?",
                "How was your appetite today?",
                "How well did you sleep last night?",
                "Any side effects today?"
            ]
        case .stopped:
            return [
                "How was your mood today?",
                "How was your sleep?",
                "Any withdrawal feelings today?"
            ]
        case .none:
            return []
        }
    }

    private func addPendingQuestion() {
        let trimmed = pendingQuestionText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if !customQuestionPrompts.contains(trimmed) {
            customQuestionPrompts.append(trimmed)
        }
        pendingQuestionText = ""
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
                if step < 3 {
                    step += 1
                } else {
                    commit()
                }
            } label: {
                Text(step < 3 ? "Next" : "Create test")
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

    private var defaultTestName: String {
        let medName = selectedLibraryMed?.brandName ?? selectedUserMed?.medication.brandName ?? "medication"
        switch changeType {
        case .started: return "Starting \(medName)"
        case .stopped: return "Stopping \(medName)"
        case .doseChanged: return "\(medName) \(selectedDose)"
        case .none: return ""
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
                if addToSchedule {
                    um.scheduledTimes = scheduledTimes
                }
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
        let trimmedName = testName.trimmingCharacters(in: .whitespaces)
        let finalName = trimmedName.isEmpty ? defaultTestName : trimmedName
        let test = Test(
            name: finalName,
            startEvent: event,
            startDate: startDate,
            plannedEndDate: plannedEnd,
            watchingFor: watchingFor
        )
        modelContext.insert(test)
        event.test = test

        for prompt in customQuestionPrompts {
            let q = CustomCheckInQuestion(prompt: prompt, testID: test.id)
            modelContext.insert(q)
        }

        try? modelContext.save()
        dismiss()
    }
}

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(UserPreferences.self) private var prefs
    @Environment(\.modelContext) private var modelContext
    @Query private var medications: [Medication]
    @Query(sort: \UserMedication.startDate, order: .reverse) private var userMedications: [UserMedication]
    @Query private var moodEntries: [MoodEntry]

    var body: some View {
        NavigationStack {
            List {
                Section("Profile") {
                    @Bindable var prefs = prefs
                    TextField("Your name (optional)", text: $prefs.displayName)
                }

                Section("My medications") {
                    if userMedications.isEmpty {
                        Text("Nothing added yet.")
                            .foregroundStyle(Theme.Palette.textSecondary)
                    } else {
                        ForEach(userMedications) { userMed in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(userMed.medication.brandName)
                                    .font(Theme.Font.bodyEmphasis)
                                Text("\(userMed.currentDose) · started \(userMed.startDate.formatted(date: .abbreviated, time: .omitted))")
                                    .font(Theme.Font.caption)
                                    .foregroundStyle(Theme.Palette.textSecondary)
                            }
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                modelContext.delete(userMedications[index])
                            }
                            try? modelContext.save()
                        }
                    }
                }

                Section("Library") {
                    LabeledContent("Medications available", value: "\(medications.count)")
                    LabeledContent("Moods logged", value: "\(moodEntries.count)")
                }

                Section("About") {
                    LabeledContent("Version", value: appVersion)
                    Link("Contact support", destination: URL(string: "mailto:stewartsherpa1@gmail.com")!)
                }

                Section {
                    Button("Reset onboarding", role: .destructive) {
                        prefs.hasCompletedOnboarding = false
                        prefs.disclaimerAccepted = false
                        prefs.trackingGoals = []
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(v) (\(b))"
    }
}

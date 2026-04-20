import SwiftUI
import SwiftData

struct RootView: View {
    @Query private var medications: [Medication]

    var body: some View {
        VStack(spacing: 16) {
            Text("DoseToData")
                .font(.system(size: 32, weight: .bold))
            Text("Phase 0 — project skeleton")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("\(medications.count) medications seeded")
                .font(.body)
                .padding(.top, 8)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.968, green: 0.972, blue: 0.984))
    }
}

#Preview {
    RootView()
        .modelContainer(for: Medication.self, inMemory: true)
}

import SwiftUI
import SwiftData
import Charts

/// The celebration step right after the first check-in: confetti, the user's
/// real first data point, and a clearly-labeled example of what two weeks of
/// tracking looks like.
///
/// Compliance note (Guideline 1.4.2): the grey line is generic EXAMPLE data,
/// visually distinct (dashed, muted) and labeled as an example in two places.
/// It must never be styled or captioned as a forecast of the user's own
/// trajectory, and it is deliberately not anchored to the user's real value.
struct Day1ChartStepView: View {
    @Environment(AppState.self) private var appState
    @Query(sort: \DailyCheckIn.date, order: .reverse) private var allCheckIns: [DailyCheckIn]

    let onContinue: () -> Void

    /// Average of today's scale answers (1–5, higher = better day), or nil
    /// if the user saved a check-in with no scale answers (note-only, etc.).
    private var todayScore: Double? {
        let calendar = Calendar.current
        guard let checkIn = allCheckIns.first(where: { calendar.isDateInToday($0.date) }) else { return nil }
        let values = checkIn.answers.compactMap { $0.checkInLevel?.numericValue }
        guard !values.isEmpty else { return nil }
        return Double(values.reduce(0, +)) / Double(values.count)
    }

    /// Generic example series (day 1...13). Deliberately starts away from any
    /// real value and meanders — it should read as "a chart like this," not
    /// "your future."
    private let exampleSeries: [(day: Int, value: Double)] = [
        (1, 2.6), (2, 2.9), (3, 2.7), (4, 3.1), (5, 3.3), (6, 3.0),
        (7, 3.4), (8, 3.2), (9, 3.6), (10, 3.8), (11, 3.5), (12, 3.9), (13, 4.0)
    ]

    /// The example med-change marker sits mid-window, echoing the real
    /// Insights feature (dashed vertical rule at a change date).
    private let exampleChangeDay = 7

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Day 1")
                    .font(Theme.Font.heroLabel)
                    .foregroundStyle(Theme.Palette.textSecondary)
                Text(todayScore != nil
                     ? "Your first point\nis on the chart."
                     : "Day 1 is logged.")
                    .font(Theme.Font.hero)
                    .foregroundStyle(Theme.Palette.textPrimary)
                Text("Check in each day and your trend takes shape. When a medication changes, it's marked — so you can see what happened next.")
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .padding(.top, 4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 24)
            .padding(.top, 32)

            chartCard
                .padding(.horizontal, 24)
                .padding(.top, 24)

            Spacer()

            Button {
                onContinue()
            } label: {
                Text("Continue")
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
        }
        .overlay {
            ConfettiBurst(trigger: appState.confettiTrigger)
                .allowsHitTesting(false)
        }
        .onAppear {
            // Re-fire so the burst plays over THIS screen (the sheet's own
            // trigger fired before this view existed; TodayView isn't around
            // during onboarding to render it).
            appState.confettiTrigger = UUID()
        }
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Chart {
                // Example trend — dashed, muted, generic.
                ForEach(exampleSeries, id: \.day) { point in
                    LineMark(
                        x: .value("Day", point.day),
                        y: .value("Score", point.value),
                        series: .value("Series", "example")
                    )
                    .foregroundStyle(Theme.Palette.textSecondary.opacity(0.35))
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 4]))
                    .interpolationMethod(.catmullRom)
                }

                // Example med-change marker, echoing Insights.
                RuleMark(x: .value("Day", exampleChangeDay))
                    .foregroundStyle(Theme.Palette.textSecondary.opacity(0.3))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .annotation(position: .top, alignment: .center) {
                        Text("Med change")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(Theme.Palette.textSecondary.opacity(0.7))
                    }

                // The user's real Day-1 point.
                if let score = todayScore {
                    PointMark(
                        x: .value("Day", 0),
                        y: .value("Score", score)
                    )
                    .foregroundStyle(Theme.Palette.primary)
                    .symbolSize(220)
                    .annotation(position: .topTrailing, alignment: .leading) {
                        Text("You, today")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Theme.Palette.primary)
                    }
                }
            }
            .chartYScale(domain: 0.5...5.5)
            .chartXScale(domain: -0.5...13.5)
            .chartYAxis {
                AxisMarks(values: [1, 3, 5]) {
                    AxisGridLine()
                    AxisValueLabel()
                }
            }
            .chartXAxis {
                AxisMarks(values: [0, 13]) { value in
                    AxisValueLabel {
                        if let day = value.as(Int.self) {
                            Text(day == 0 ? "Today" : "2 weeks")
                                .font(.system(size: 11))
                        }
                    }
                }
            }
            .frame(height: 200)

            Label("Grey line is example data — your real trend builds one check-in at a time.",
                  systemImage: "info.circle")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
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

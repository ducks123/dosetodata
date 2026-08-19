import SwiftUI
import Charts

/// UI pieces for the post-onboarding guided tour that runs inside the real
/// app (MainTabView owns the stage machine; see `UserPreferences.onboardingTourStage`).

// MARK: - Stage 1 banner (Today)

/// Nudge shown above the tab bar until the user saves their first check-in.
/// Bounces and points upward at the check-in card's button, matching the
/// tab tooltips so all tour prompts read as one family.
struct TourGuideBanner: View {
    let text: String

    @State private var bounce = false

    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: "arrowtriangle.up.fill")
                .font(.system(size: 18))
                .foregroundStyle(Theme.Palette.primary)
                .offset(y: 3)
            HStack(spacing: 10) {
                Image(systemName: "hand.point.up.left.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                Text(text)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(Theme.Palette.primary)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
            .shadow(color: Theme.Palette.primary.opacity(0.4), radius: 12, y: 4)
        }
        .padding(.horizontal, 20)
        .offset(y: bounce ? -7 : 2)
        .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: bounce)
        .onAppear { bounce = true }
    }
}

// MARK: - Tab tooltip (stages 2 and 3)

/// Bouncing tooltip above the tab bar whose arrow lines up with the tab it
/// points at.
struct TourTabTooltip: View {
    let text: String
    /// Horizontal position of the target tab's center, as a fraction of
    /// screen width (Schedule ≈ 0.5, Insights ≈ 0.71).
    let arrowFraction: CGFloat

    @State private var bounce = false

    var body: some View {
        VStack(spacing: 0) {
            Text(text)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 13)
                .background(Theme.Palette.primary)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(color: Theme.Palette.primary.opacity(0.45), radius: 10, y: 4)

            Image(systemName: "arrowtriangle.down.fill")
                .font(.system(size: 18))
                .foregroundStyle(Theme.Palette.primary)
                .offset(y: -3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, UIScreen.main.bounds.width * arrowFraction - 9)
        }
        .offset(y: bounce ? -7 : 2)
        .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: bounce)
        .onAppear { bounce = true }
    }
}

// MARK: - Insights example card (stage 4, shown over a dimmed scrim)

/// Modal card over the real Insights tab: the user's actual first data point
/// plus a clearly-labeled example of what two weeks of tracking looks like.
/// The scrim behind it (owned by MainTabView) makes Continue the only action.
///
/// Compliance note (Guideline 1.4.2): the grey line is generic EXAMPLE data,
/// dashed and muted, labeled as an example in the caption. It is deliberately
/// not anchored to the user's real value and must never be framed as a
/// forecast of their own trajectory.
struct TourInsightsCard: View {
    /// Average of today's scale answers (1 to 5), nil if the first check-in
    /// had no scale answers.
    let todayScore: Double?
    let onContinue: () -> Void

    private let exampleSeries: [(day: Int, value: Double)] = [
        (1, 2.6), (2, 2.9), (3, 2.7), (4, 3.1), (5, 3.3), (6, 3.0),
        (7, 3.4), (8, 3.2), (9, 3.6), (10, 3.8), (11, 3.5), (12, 3.9), (13, 4.0)
    ]
    private let exampleChangeDay = 7

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your trends build here")
                .font(Theme.Font.sectionTitle)
            Text("Every check-in adds a point. When a medication changes, it gets marked on the chart so you can see what happened next.")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            chart
                .frame(height: 150)

            Label("The grey line is example data. Your real trend builds one check-in at a time.",
                  systemImage: "info.circle")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: onContinue) {
                Text("Continue")
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding(18)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .shadow(color: .black.opacity(0.25), radius: 24, y: 8)
        .padding(.horizontal, 24)
    }

    private var chart: some View {
        Chart {
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

            RuleMark(x: .value("Day", exampleChangeDay))
                .foregroundStyle(Theme.Palette.textSecondary.opacity(0.3))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                .annotation(position: .top, alignment: .center) {
                    Text("Med change")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Theme.Palette.textSecondary.opacity(0.7))
                }

            if let score = todayScore {
                PointMark(
                    x: .value("Day", 0),
                    y: .value("Score", score)
                )
                .foregroundStyle(Theme.Palette.primary)
                .symbolSize(180)
                .annotation(position: .topTrailing, alignment: .leading) {
                    Text("You, today")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.Palette.primary)
                }
            }
        }
        .chartYScale(domain: 0.5...5.5)
        .chartXScale(domain: -0.5...14.5)
        .chartYAxis {
            AxisMarks(values: [1, 3, 5]) {
                AxisGridLine()
                AxisValueLabel()
            }
        }
        .chartXAxis {
            AxisMarks(values: [0, 13]) { value in
                AxisValueLabel(anchor: value.as(Int.self) == 13 ? .topTrailing : .topLeading) {
                    if let day = value.as(Int.self) {
                        Text(day == 0 ? "Today" : "2 weeks")
                            .font(.system(size: 11))
                    }
                }
            }
        }
    }
}

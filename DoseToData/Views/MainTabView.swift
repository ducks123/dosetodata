import SwiftUI
import SwiftData

struct MainTabView: View {
    @Environment(AppState.self) private var appState
    @Environment(UserPreferences.self) private var prefs
    @Environment(SubscriptionService.self) private var sub
    @Query(sort: \DailyCheckIn.date, order: .reverse) private var allCheckIns: [DailyCheckIn]

    @State private var selectedTab: Tab = .today
    @State private var showTourPaywall = false
    @State private var tourShowsPrimer = false

    enum Tab: Hashable {
        case today, schedule, insights
    }

    /// True while the post-onboarding guided tour is running. Stages are
    /// documented on `UserPreferences.onboardingTourStage`.
    private var inTour: Bool {
        !prefs.hasCompletedOnboarding && prefs.onboardingTourStage > 0
    }

    private var hasCheckInToday: Bool {
        let calendar = Calendar.current
        return allCheckIns.contains { calendar.isDateInToday($0.date) }
    }

    /// Average of today's scale answers for the tour's example chart.
    private var todayScore: Double? {
        let calendar = Calendar.current
        guard let checkIn = allCheckIns.first(where: { calendar.isDateInToday($0.date) }) else { return nil }
        let values = checkIn.answers.compactMap { $0.checkInLevel?.numericValue }
        guard !values.isEmpty else { return nil }
        return Double(values.reduce(0, +)) / Double(values.count)
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            TodayView()
                .tabItem {
                    Label("Today", systemImage: "sun.max.fill")
                }
                .tag(Tab.today)

            ScheduleView()
                .tabItem {
                    Label("Schedule", systemImage: "calendar")
                }
                .tag(Tab.schedule)

            InsightsView()
                .tabItem {
                    Label("Insights", systemImage: "chart.xyaxis.line")
                }
                .tag(Tab.insights)
        }
        .tint(Theme.Palette.primary)
        .onChange(of: appState.pendingInsightsTestID) { _, newValue in
            if newValue != nil {
                selectedTab = .insights
            }
        }
        .onChange(of: appState.shouldNavigateToInsights) { _, newValue in
            if newValue {
                selectedTab = .insights
                appState.shouldNavigateToInsights = false
            }
        }
        .onChange(of: appState.pendingTodayDate) { _, newValue in
            if newValue != nil {
                selectedTab = .today
            }
        }
        // ── Guided tour ─────────────────────────────────────────────────
        .overlay {
            if inTour {
                tourLayer
            }
        }
        .animation(.easeInOut(duration: 0.25), value: prefs.onboardingTourStage)
        .onChange(of: hasCheckInToday) { _, checkedIn in
            if inTour, prefs.onboardingTourStage == 1, checkedIn {
                prefs.onboardingTourStage = 2
            }
        }
        .onChange(of: selectedTab) { _, tab in
            guard inTour else { return }
            if prefs.onboardingTourStage == 2, tab == .schedule {
                prefs.onboardingTourStage = 3
            } else if prefs.onboardingTourStage == 3, tab == .insights {
                prefs.onboardingTourStage = 4
            }
        }
        .onAppear {
            guard inTour else { return }
            // Resume after a relaunch mid-tour.
            if prefs.onboardingTourStage == 1, hasCheckInToday {
                prefs.onboardingTourStage = 2
            }
            if prefs.onboardingTourStage >= 5 {
                showTourPaywall = true
            }
        }
        .fullScreenCover(isPresented: $showTourPaywall) {
            if tourShowsPrimer {
                ReminderPrimerStepView(onDone: finishTour)
                    .background(Theme.Palette.background.ignoresSafeArea())
            } else {
                PaywallView(
                    isDismissible: false,
                    dayOneLogged: hasCheckInToday,
                    onComplete: { tourShowsPrimer = true }
                )
                .environment(sub)
            }
        }
    }

    @ViewBuilder
    private var tourLayer: some View {
        switch prefs.onboardingTourStage {
        case 1:
            if selectedTab == .today && !hasCheckInToday {
                bottomAligned(
                    TourGuideBanner(text: "Complete today's check-in to put your first point on the chart.")
                )
            }
        case 2:
            bottomAligned(
                TourTabTooltip(text: "Your meds are on the Schedule tab", arrowFraction: 0.5)
            )
        case 3:
            bottomAligned(
                TourTabTooltip(text: "Now see your trends in Insights", arrowFraction: 0.71)
            )
        case 4:
            if selectedTab == .insights {
                // Modal moment: dim everything so Continue is the only
                // action, per tester feedback (a half-interactive state read
                // as broken/fake).
                ZStack {
                    Color.black.opacity(0.45)
                        .ignoresSafeArea()
                        .onTapGesture {}  // absorb taps behind the card
                    TourInsightsCard(todayScore: todayScore) {
                        prefs.onboardingTourStage = 5
                        showTourPaywall = true
                    }
                }
                .transition(.opacity)
            }
        default:
            EmptyView()
        }
    }

    /// Pins tour banners/tooltips just above the floating tab bar.
    private func bottomAligned<Content: View>(_ content: Content) -> some View {
        VStack {
            Spacer()
            content
                .padding(.bottom, 74)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func finishTour() {
        prefs.hasCompletedOnboarding = true
        prefs.onboardingTourStage = 0
        showTourPaywall = false
    }
}

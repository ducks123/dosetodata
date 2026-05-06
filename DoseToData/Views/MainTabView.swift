import SwiftUI

struct MainTabView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedTab: Tab = .today

    enum Tab: Hashable {
        case today, schedule, insights
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
    }
}


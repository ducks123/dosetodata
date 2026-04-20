import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: Tab = .today

    enum Tab: Hashable {
        case today, timeline, history, settings
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            TodayView()
                .tabItem {
                    Label("Today", systemImage: "sun.max.fill")
                }
                .tag(Tab.today)

            TimelinePlaceholderView()
                .tabItem {
                    Label("Timeline", systemImage: "chart.xyaxis.line")
                }
                .tag(Tab.timeline)

            HistoryPlaceholderView()
                .tabItem {
                    Label("History", systemImage: "clock.arrow.circlepath")
                }
                .tag(Tab.history)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(Tab.settings)
        }
        .tint(Theme.Palette.primary)
    }
}

struct TimelinePlaceholderView: View {
    var body: some View {
        PlaceholderContent(
            title: "Timeline",
            subtitle: "Phase 3 unlocks the mood chart with medication event markers and before/after panels."
        )
    }
}

struct HistoryPlaceholderView: View {
    var body: some View {
        PlaceholderContent(
            title: "History",
            subtitle: "Completed tests and exports will live here once Phases 4–5 ship."
        )
    }
}

private struct PlaceholderContent: View {
    let title: String
    let subtitle: String

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                Text(title)
                    .font(Theme.Font.hero)
                Text(subtitle)
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.Palette.background.ignoresSafeArea())
        }
    }
}

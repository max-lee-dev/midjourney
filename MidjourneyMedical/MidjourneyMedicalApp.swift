import SwiftUI

@main
struct MidjourneyMedicalApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
        }
    }
}

struct RootView: View {
    @State private var selectedTab: Tab = Tab.initial
    @State private var showMainApp = RootView.shouldStartInMainApp

    private static let lastSeenScanKey = "lastSeenScanToken"

    /// Decide once, synchronously, whether to skip the post-scan experience —
    /// avoids a flash of the loading screen on returning launches.
    private static var shouldStartInMainApp: Bool {
        let environment = ProcessInfo.processInfo.environment
        if environment["SKIP_LOADING"] == "1" { return true }
        if environment["FORCE_NEW_SCAN"] == "1" { return false }
        guard MockData.hasNewScan else { return true }
        return UserDefaults.standard.string(forKey: lastSeenScanKey) == MockData.latestScanToken
    }

    private func markScanSeen() {
        UserDefaults.standard.set(MockData.latestScanToken, forKey: Self.lastSeenScanKey)
    }

    enum Tab: Hashable {
        case body, scan, timeline, compare, insights, baseline

        /// Allows the launch environment to choose the starting tab (used for snapshots).
        static var initial: Tab {
            switch ProcessInfo.processInfo.environment["START_TAB"] {
            case "scan": return .scan
            case "timeline": return .timeline
            case "compare": return .compare
            case "insights": return .insights
            case "baseline": return .baseline
            default: return .body
            }
        }
    }

    var body: some View {
        ZStack {
            if showMainApp {
                mainTabs
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else {
                ScanExperienceFlow {
                    markScanSeen()
                    withAnimation(.easeInOut(duration: 0.6)) {
                        showMainApp = true
                    }
                }
                .transition(.opacity)
            }
        }
    }

    private var mainTabs: some View {
        Group {
            switch selectedTab {
            case .body: BodyView()
            case .scan: ScanTabView()
            case .timeline: TimelineView()
            case .compare: CompareView()
            case .insights: InsightsView()
            case .baseline: BaselineView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            CustomTabBar(selectedTab: $selectedTab)
        }
    }
}

/// Custom HUD bottom bar — Scan lives in the center as the emphasized, raised primary action.
struct CustomTabBar: View {
    @Binding var selectedTab: RootView.Tab

    private struct Item: Identifiable {
        let tab: RootView.Tab
        let title: String
        let icon: String
        var id: RootView.Tab { tab }
    }

    private let leftItems: [Item] = [
        Item(tab: .body, title: "Body", icon: "figure.stand"),
        Item(tab: .timeline, title: "Timeline", icon: "chart.xyaxis.line"),
    ]

    private let rightItems: [Item] = [
        Item(tab: .compare, title: "Compare", icon: "arrow.left.arrow.right"),
        Item(tab: .baseline, title: "Baseline", icon: "person.2"),
    ]

    private let barHeight: CGFloat = 54
    private let scanButtonSize: CGFloat = 48

    private func handleSelect(_ tab: RootView.Tab) {
        withAnimation(.easeOut(duration: 0.2)) {
            selectedTab = tab
        }
    }

    private func tabButton(_ item: Item) -> some View {
        let isSelected = selectedTab == item.tab
        return Button {
            handleSelect(item.tab)
        } label: {
            VStack(spacing: 4) {
                Image(systemName: item.icon)
                    .font(.system(size: 18, weight: .semibold))
                Text(item.title)
                    .hudCaptionStyle()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(isSelected ? Theme.accent : Theme.textSecondary)
            .frame(maxWidth: .infinity)
            .frame(height: barHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.title)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private var scanButton: some View {
        let isSelected = selectedTab == .scan
        return Button {
            handleSelect(.scan)
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Theme.accent : Theme.accent.opacity(0.16))
                    Image(systemName: "viewfinder")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(isSelected ? Color.black : Theme.accent)
                }
                .frame(width: scanButtonSize, height: scanButtonSize)
                .overlay(Circle().strokeBorder(Theme.background, lineWidth: 3))
                .overlay(Circle().strokeBorder(Theme.accent.opacity(isSelected ? 0 : 0.5), lineWidth: 1))
                .shadow(color: Theme.accent.opacity(isSelected ? 0.4 : 0), radius: 8)

                Text("Scan")
                    .hudCaptionStyle()
                    .foregroundStyle(isSelected ? Theme.accent : Theme.textSecondary)
            }
        }
        .buttonStyle(.plain)
        .offset(y: -10)
        .accessibilityLabel("Scan")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                HStack(spacing: 0) {
                    ForEach(leftItems, content: tabButton)
                }
                .frame(maxWidth: .infinity)

                Color.clear
                    .frame(width: scanButtonSize + 10)

                HStack(spacing: 0) {
                    ForEach(rightItems, content: tabButton)
                }
                .frame(maxWidth: .infinity)
            }
            .frame(height: barHeight)

            scanButton
        }
        .padding(.horizontal, 6)
        .background(
            Theme.background
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Theme.stroke)
                        .frame(height: 1)
                }
                .ignoresSafeArea(edges: .bottom)
        )
    }
}

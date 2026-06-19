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
    @State private var timelineEntranceFromScan = false

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
                    .transition(
                        .asymmetric(
                            insertion: .opacity
                                .combined(with: .scale(scale: 0.97))
                                .combined(with: .offset(y: 12)),
                            removal: .opacity
                        )
                    )
            } else {
                ScanExperienceFlow(onComplete: enterMainApp)
                    .transition(.opacity.combined(with: .scale(scale: 1.02)))
            }
        }
        .animation(.easeInOut(duration: 0.65), value: showMainApp)
    }

    private func enterMainApp(landingTab: Tab) {
        markScanSeen()
        timelineEntranceFromScan = landingTab == .timeline
        withAnimation(.easeInOut(duration: 0.65)) {
            selectedTab = landingTab
            showMainApp = true
        }
        if landingTab == .timeline {
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1.2))
                timelineEntranceFromScan = false
            }
        }
    }

    private var mainTabs: some View {
        Group {
            switch selectedTab {
            case .body: BodyView()
            case .scan: ScanTabView(
                selectedTab: $selectedTab,
                timelineEntranceFromScan: $timelineEntranceFromScan
            )
            case .timeline: TimelineView(animateEntrance: timelineEntranceFromScan)
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

    private let barHeight: CGFloat = 58
    private let scanButtonSize: CGFloat = 52

    private func handleSelect(_ tab: RootView.Tab) {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
            selectedTab = tab
        }
    }

    private func tabButton(_ item: Item) -> some View {
        let isSelected = selectedTab == item.tab
        return Button {
            handleSelect(item.tab)
        } label: {
            VStack(spacing: 5) {
                Image(systemName: item.icon)
                    .font(.system(size: 19, weight: isSelected ? .bold : .regular))
                    .frame(height: 22)
                    .scaleEffect(isSelected ? 1.05 : 1)

                Text(item.title)
                    .hudCaptionStyle()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(isSelected ? Theme.accent : Theme.textSecondary)
            .frame(maxWidth: .infinity)
            .frame(height: barHeight)
            // Active-channel tick — a glowing gold marker on the top rail.
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Theme.accent)
                    .frame(width: 22, height: 2)
                    .shadow(color: Theme.accent.opacity(0.9), radius: 5)
                    .opacity(isSelected ? 1 : 0)
                    .scaleEffect(x: isSelected ? 1 : 0.3, anchor: .center)
            }
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
            VStack(spacing: 5) {
                ZStack {
                    // Outer concentric HUD ring.
                    Circle()
                        .strokeBorder(Theme.accent.opacity(isSelected ? 0.6 : 0.28), lineWidth: 1)
                        .frame(width: scanButtonSize + 10, height: scanButtonSize + 10)

                    Circle()
                        .fill(
                            isSelected
                                ? LinearGradient(
                                    colors: [Theme.accent, Theme.accentDeep],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                                : LinearGradient(
                                    colors: [Theme.accent.opacity(0.16), Theme.accent.opacity(0.06)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                        )
                        .frame(width: scanButtonSize, height: scanButtonSize)
                        .overlay(Circle().strokeBorder(Theme.accent.opacity(isSelected ? 0 : 0.55), lineWidth: 1))
                        // Mask a clean cut-out where the button meets the bar.
                        .overlay(Circle().strokeBorder(Theme.background, lineWidth: 4))

                    Image(systemName: "viewfinder")
                        .font(.system(size: 21, weight: .bold))
                        .foregroundStyle(isSelected ? Color.black : Theme.accent)
                }
                .shadow(color: Theme.accent.opacity(isSelected ? 0.5 : 0.18), radius: isSelected ? 12 : 6)

                Text("Scan")
                    .hudCaptionStyle()
                    .foregroundStyle(isSelected ? Theme.accent : Theme.textSecondary)
            }
        }
        .buttonStyle(.plain)
        .offset(y: -14)
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
                    .frame(width: scanButtonSize + 14)

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
            LinearGradient(
                colors: [Theme.surfaceElevated, Theme.background],
                startPoint: .top,
                endPoint: .bottom
            )
            .background(Theme.background)
            // Gold hairline that glows toward the center, fading at the edges.
            .overlay(alignment: .top) {
                LinearGradient(
                    colors: [.clear, Theme.accent.opacity(0.5), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(height: 1)
            }
            .ignoresSafeArea(edges: .bottom)
        )
    }
}

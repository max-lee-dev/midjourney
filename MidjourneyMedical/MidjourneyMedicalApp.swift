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
        case scan, timeline

        /// Allows the launch environment to choose the starting screen (used for snapshots).
        static var initial: Tab {
            ProcessInfo.processInfo.environment["START_TAB"] == "scan" ? .scan : .timeline
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

    private func handleSelect(_ tab: Tab) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            selectedTab = tab
        }
    }

    private var mainTabs: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch selectedTab {
                case .scan:
                    ScanTabView(
                        selectedTab: $selectedTab,
                        timelineEntranceFromScan: $timelineEntranceFromScan
                    )
                case .timeline:
                    TimelineView(animateEntrance: timelineEntranceFromScan)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if selectedTab == .timeline {
                FloatingScanButton { handleSelect(.scan) }
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .overlay(alignment: .topLeading) {
            if selectedTab == .scan {
                BackToTimelineButton { handleSelect(.timeline) }
                    .transition(.opacity)
            }
        }
    }
}

/// Always-available primary action on the Timeline — drops the user straight
/// into the scan ritual. Hidden while the scan experience is on screen.
struct FloatingScanButton: View {
    var action: () -> Void

    private let size: CGFloat = 62

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .strokeBorder(Theme.accent.opacity(0.35), lineWidth: 1)
                        .frame(width: size + 12, height: size + 12)

                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Theme.accent, Theme.accentDeep],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: size, height: size)
                        .overlay(Circle().strokeBorder(Theme.background, lineWidth: 4))

                    Image(systemName: "viewfinder")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(Theme.background)
                }
                .shadow(color: Theme.accent.opacity(0.45), radius: 16, y: 4)

                Text("SCAN")
                    .font(Theme.hudCaption(size: 9))
                    .tracking(1.4)
                    .foregroundStyle(Theme.accent)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Begin a new scan")
    }
}

/// Lightweight chevron affordance shown on the Scan screen to return to the Timeline.
struct BackToTimelineButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.leading, 4)
        .padding(.top, 8)
        .accessibilityLabel("Back to timeline")
    }
}

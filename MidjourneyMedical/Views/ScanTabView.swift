import SwiftUI

/// Scan tab — opens straight to the clean scan-ready screen. The preflight runs
/// inline (tap "Begin your scan" → device code → step in → countdown), then the
/// immersive body sweep + reveal takes over full-screen.
struct ScanTabView: View {
    @Binding var selectedTab: RootView.Tab
    @Binding var timelineEntranceFromScan: Bool
    @State private var presentingScan = false
    @State private var scanSession = 0

    var body: some View {
        ScanPreflightView { presentingScan = true }
            .id(scanSession)
            .fullScreenCover(isPresented: $presentingScan) {
                FullScanFlow { landingTab in
                    withAnimation(.easeInOut(duration: 0.65)) {
                        presentingScan = false
                        selectedTab = landingTab
                    }
                    timelineEntranceFromScan = landingTab == .timeline
                    scanSession += 1
                    if landingTab == .timeline {
                        Task { @MainActor in
                            try? await Task.sleep(for: .seconds(1.2))
                            timelineEntranceFromScan = false
                        }
                    }
                }
            }
    }
}

#Preview {
    ScanTabView(selectedTab: .constant(.scan), timelineEntranceFromScan: .constant(false))
        .preferredColorScheme(.dark)
}

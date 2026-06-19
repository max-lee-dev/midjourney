import SwiftUI

/// Scan tab — opens straight to the clean scan-ready screen. The preflight runs
/// inline (tap "Begin your scan" → device code → step in → countdown), then the
/// immersive body sweep + reveal takes over full-screen.
struct ScanTabView: View {
    @State private var presentingScan = false
    @State private var scanSession = 0

    var body: some View {
        ScanPreflightView { presentingScan = true }
            .id(scanSession)
            .fullScreenCover(isPresented: $presentingScan) {
                FullScanFlow {
                    presentingScan = false
                    scanSession += 1
                }
            }
    }
}

#Preview {
    ScanTabView()
        .preferredColorScheme(.dark)
}

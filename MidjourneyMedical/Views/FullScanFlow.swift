import SwiftUI

/// Coordinates the immersive half of a full scan: the live body sweep hands off
/// to the slice-stacking + analyze + Wrapped reveal, then signals completion so
/// the host can dismiss back to the Scan tab. (The preflight now runs inline on
/// the Scan tab before this is presented.)
struct FullScanFlow: View {
    var onComplete: (RootView.Tab) -> Void

    enum FullScanStage { case sweep, process }

    @State private var stage: FullScanStage = .sweep

    var body: some View {
        ZStack {
            switch stage {
            case .sweep:
                BodyScanSweepView {
                    withAnimation(.easeInOut(duration: 0.6)) { stage = .process }
                }
                .transition(.opacity)
            case .process:
                ScanExperienceFlow(onComplete: onComplete)
                    .transition(.opacity)
            }
        }
    }
}

#Preview {
    FullScanFlow(onComplete: { _ in })
        .preferredColorScheme(.dark)
}

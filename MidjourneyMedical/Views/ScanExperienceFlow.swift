import SwiftUI

/// Coordinates the post-scan experience: Act 1 (slice loading + stacking) hands
/// off to Act 2 (the organ "Wrapped" reveal), then signals completion so the
/// host can enter the main app.
struct ScanExperienceFlow: View {
    var onComplete: () -> Void

    @State private var showWrapped = false

    var body: some View {
        ZStack {
            if showWrapped {
                OrganWrappedView(results: MockData.organResults(), onComplete: onComplete)
                    .transition(.opacity)
            } else {
                ScanLoadingView {
                    withAnimation(.easeInOut(duration: 0.6)) { showWrapped = true }
                }
                .transition(.opacity)
            }
        }
    }
}

#Preview {
    ScanExperienceFlow(onComplete: {})
        .preferredColorScheme(.dark)
}

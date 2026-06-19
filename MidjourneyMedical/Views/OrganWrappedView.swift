import SwiftUI

/// Act 2 — a Spotify Wrapped-style reveal of each organ's standing in the
/// user's age cohort, with how it moved since the last visit. The camera pans
/// down the 3D body (head → feet) as cards auto-advance; a final summary hands
/// off to the main app.
struct OrganWrappedView: View {
    let results: [OrganScanResult]
    var onComplete: (RootView.Tab) -> Void

    @State private var index = 0
    @State private var navigationDirection: NavigationDirection = .forward
    @State private var showFullSummary = false
    /// Starts false so the body enters at the same full-body framing as the
    /// reveal view (no size jump on the crossfade), then glides to the first
    /// organ once the hand-off has settled.
    @State private var hasEntered = false

    /// Per-card dwell time before auto-advancing.
    private let cardDuration: Double = 3.8
    private let swipeThreshold: CGFloat = 44

    private enum NavigationDirection {
        case forward, backward
    }

    private var isSummary: Bool { index >= results.count }

    private var currentTint: Color {
        guard index < results.count else { return Theme.accent }
        return Theme.color(for: results[index].status)
    }

    private var statusMap: [BodyRegion: HealthStatus] {
        Dictionary(uniqueKeysWithValues: results.map { ($0.region, $0.status) })
    }

    private var focusedRegion: BodyRegion? {
        guard hasEntered else { return nil }
        if index < results.count { return results[index].region }
        return results.last?.region
    }

    var body: some View {
        ZStack {
            background

            WrappedBodyFocusView(statuses: statusMap, focusedRegion: focusedRegion, ambient: false)
                .ignoresSafeArea()

            bottomScrim

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                Spacer(minLength: 0)

                if !isSummary {
                    HStack(spacing: 0) {
                        bodyProgressRail
                            .padding(.leading, 20)

                        Spacer(minLength: 0)
                    }
                    .transition(.opacity)

                    Spacer(minLength: 0)
                }

                Group {
                    if index < results.count {
                        OrganWrappedCard(result: results[index])
                            .id(index)
                    } else {
                        WrappedSummaryCard(results: results, onViewSummary: {
                            withAnimation(.easeInOut(duration: 0.45)) { showFullSummary = true }
                        })
                            .id("summary")
                    }
                }
                .transition(.asymmetric(
                    insertion: navigationDirection == .forward
                        ? .move(edge: .bottom).combined(with: .opacity)
                        : .move(edge: .top).combined(with: .opacity),
                    removal: navigationDirection == .forward
                        ? .move(edge: .top).combined(with: .opacity)
                        : .move(edge: .bottom).combined(with: .opacity)
                ))
            }

            if showFullSummary {
                ScanSummaryView(results: results, onComplete: handleViewHistory)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(1)
            }
        }
        .contentShape(Rectangle())
        .gesture(verticalSwipeGesture)
        .onTapGesture { if !isSummary { advance() } }
        .onAppear {
            guard !hasEntered else { return }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(500))
                hasEntered = true
            }
        }
        .task(id: index) {
            guard index < results.count else { return }
            try? await Task.sleep(for: .seconds(cardDuration))
            guard !Task.isCancelled else { return }
            advance()
        }
    }

    private func handleViewHistory() {
        onComplete(.timeline)
    }

    private func advance() {
        guard index < results.count else { return }
        navigationDirection = .forward
        withAnimation(.easeInOut(duration: 0.55)) {
            index += 1
        }
    }

    private func retreat() {
        guard index > 0 else { return }
        navigationDirection = .backward
        withAnimation(.easeInOut(duration: 0.55)) {
            index -= 1
        }
    }

    private var verticalSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 20, coordinateSpace: .local)
            .onEnded { value in
                let dx = value.translation.width
                let dy = value.translation.height
                guard abs(dy) > abs(dx), abs(dy) >= swipeThreshold else { return }

                if dy > 0 {
                    advance()
                } else {
                    retreat()
                }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
    }

    // MARK: - Backdrop

    private var background: some View {
        Theme.background.ignoresSafeArea()
    }

    private var bottomScrim: some View {
        VStack {
            Spacer()
            LinearGradient(
                colors: isSummary
                    ? [.clear, Theme.background.opacity(0.12), Theme.background.opacity(0.5)]
                    : [.clear, Theme.background.opacity(0.55), Theme.background.opacity(0.92)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: isSummary ? 200 : 340)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .animation(.easeInOut(duration: 0.5), value: isSummary)
    }

    /// Vertical rail — mirrors head-to-feet progression through the body.
    private var bodyProgressRail: some View {
        SwiftUI.TimelineView(.periodic(from: .now, by: 1.0 / 30.0)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            VStack(spacing: 7) {
                ForEach(Array(results.enumerated()), id: \.offset) { i, result in
                    progressRailSegment(at: i, result: result, time: time)
                }
            }
        }
    }

    private func progressRailSegment(at i: Int, result: OrganScanResult, time: Double) -> some View {
        let isCurrent = i == index
        let isPast = i < index
        let count = max(results.count - 1, 1)

        // Staggered wave top → bottom; active step breathes 1.5× stronger.
        let stagger = Double(i) / Double(count) * .pi * 1.4
        let wave = sin(time * 2.2 + stagger)
        let strength = isCurrent ? 1.5 : 0.85
        let opacityWobble = 0.18 * strength * wave
        let scaleWobble = 1 + 0.11 * strength * wave

        let fill: Color = {
            if isCurrent { return Theme.color(for: result.status) }
            if isPast { return Theme.color(for: result.status).opacity(0.45) }
            return Theme.accent.opacity(0.18)
        }()

        let baseOpacity = isCurrent ? 1.0 : (isPast ? 0.45 : 0.18)
        let height: CGFloat = isCurrent ? 22 : 14
        let width: CGFloat = isCurrent ? 3 : 2

        return Rectangle()
            .fill(fill)
            .frame(width: width, height: height)
            .scaleEffect(x: 1, y: scaleWobble, anchor: .center)
            .opacity(min(1, max(0.08, baseOpacity + opacityWobble)))
            .animation(.easeInOut(duration: 0.35), value: index)
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(spacing: 12) {
            Text("\(min(index + 1, results.count)) / \(results.count)")
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(Theme.textSecondary)

            Spacer()

            if index < results.count {
                Text(results[index].cohortLabel.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(currentTint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            } else {
                Text("COMPLETE")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(Theme.accent)
            }

            Spacer()

            Button { onComplete(.timeline) } label: {
                Text("SKIP")
                    .font(Theme.hudLabel(size: 12))
                    .tracking(0.8)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }
}

// MARK: - Organ card

private struct OrganWrappedCard: View {
    let result: OrganScanResult

    @State private var counter = 0
    @State private var showDetails = false

    private var tint: Color { Theme.color(for: result.status) }
    private var targetDelta: Int { abs(result.standingPointsDelta) }

    private var percentileCaption: String {
        "\(result.percentileLabel) percentile \u{00B7} \(result.cohortLabel)"
    }

    private var baselineDescriptor: String {
        let label = result.lastScanDate.shortLabel.uppercased()
        let pts = result.standingPointsDelta
        if pts > 0 { return "AHEAD OF \(label)" }
        if pts < 0 { return "BEHIND \(label)" }
        return "EVEN WITH \(label)"
    }

    private var deltaColor: Color {
        let pts = result.standingPointsDelta
        if pts > 0 { return Theme.normal }
        if pts < 0 { return result.status == .alert ? Theme.alert : Theme.watch }
        return Theme.textSecondary
    }

    private var deltaArrow: String {
        let pts = result.standingPointsDelta
        if pts > 0 { return "arrow.up.right" }
        if pts < 0 { return "arrow.down.right" }
        return "arrow.right"
    }

    private var valueChange: String {
        let metric = result.metric
        return "\(metric.shortName) \(metric.format(result.previousValue)) \u{2192} \(metric.format(result.currentValue)) \(metric.unit)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(result.region.displayName.uppercased())
                .font(Theme.hudTitle(size: 24))
                .foregroundStyle(Theme.textPrimary)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Image(systemName: deltaArrow)
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(deltaColor)
                Text("\(counter)")
                    .font(Theme.hudData(size: 56))
                    .foregroundStyle(deltaColor)
                    .contentTransition(.numericText())
                Text("PTS")
                    .font(Theme.hudData(size: 24))
                    .foregroundStyle(deltaColor)
            }
            .padding(.top, 6)

            Text(baselineDescriptor)
                .font(Theme.hudLabel(size: 12))
                .tracking(1.2)
                .foregroundStyle(deltaColor)
                .padding(.top, 2)

            Text(percentileCaption)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
                .padding(.top, 6)

            Text(result.metric.higherIsBetter ? "Higher is better" : "Lower is better")
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(Theme.textTertiary)
                .padding(.top, 2)

            DistributionBar(
                percentile: result.percentile,
                tint: tint,
                animatedFrom: result.previousPercentile
            )
            .padding(.top, 18)

            Text(valueChange)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(Theme.textSecondary)
                .padding(.top, 14)
                .opacity(showDetails ? 1 : 0)
                .offset(y: showDetails ? 0 : 10)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.top, 22)
        .padding(.bottom, 36)
        .background {
            Rectangle()
                .fill(Theme.surfaceElevated)
                .overlay(Rectangle().strokeBorder(Theme.stroke, lineWidth: 1))
                .ignoresSafeArea(edges: .bottom)
        }
        .onAppear { animateIn() }
    }

    private func animateIn() {
        withAnimation(.easeOut(duration: 0.45).delay(0.35)) {
            showDetails = true
        }

        Task { @MainActor in
            let target = targetDelta
            guard target > 0 else { counter = 0; return }
            let frames = target
            let perFrame = 1.0 / Double(frames)
            for i in 0...frames {
                counter = Int((Double(target) * Double(i) / Double(frames)).rounded())
                try? await Task.sleep(for: .seconds(perFrame))
            }
            counter = target
        }
    }
}

// MARK: - Summary card

private struct WrappedSummaryCard: View {
    let results: [OrganScanResult]
    var onViewSummary: () -> Void

    @State private var appeared = false

    var body: some View {
        Button(action: onViewSummary) {
            Text("VIEW SUMMARY")
                .font(Theme.hudLabel(size: 14))
                .tracking(0.8)
                .foregroundStyle(Theme.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Theme.accent.opacity(0.12))
                .overlay(Rectangle().strokeBorder(Theme.accent, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 28)
        .padding(.top, 8)
        .padding(.bottom, 44)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
        .onAppear {
            withAnimation(.spring(response: 0.65, dampingFraction: 0.78)) { appeared = true }
        }
    }
}

#Preview {
    OrganWrappedView(results: MockData.organResults(), onComplete: { _ in })
        .preferredColorScheme(.dark)
}

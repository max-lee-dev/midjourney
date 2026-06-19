import SwiftUI

/// Full scan summary — holistic body view plus every region from the Wrapped reveal.
struct ScanSummaryView: View {
    let results: [OrganScanResult]
    var onComplete: () -> Void

    @State private var appeared = false

    private var statusMap: [BodyRegion: HealthStatus] {
        Dictionary(uniqueKeysWithValues: results.map { ($0.region, $0.status) })
    }

    private var improved: Int {
        results.filter { $0.isImproved && $0.status == .normal }.count
    }
    private var toWatch: Int {
        results.filter { $0.status != .normal }.count
    }
    private var steady: Int {
        results.filter { !$0.isImproved && $0.status == .normal }.count
    }

    private var headline: String {
        if improved >= results.count / 2 { return "Mostly moving forward" }
        if toWatch >= 3 { return "A few areas to watch" }
        return "Holding steady overall"
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                heroBody
                scrollContent
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) { appeared = true }
        }
    }

    // MARK: - Hero

    private var heroBody: some View {
        ZStack(alignment: .bottom) {
            WrappedBodyFocusView(statuses: statusMap, focusedRegion: nil, spin: true, colorful: true)
                .frame(maxWidth: .infinity)
                .frame(height: 340)
                .mask(
                    LinearGradient(
                        colors: [.white, .white, .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            LinearGradient(
                colors: [.clear, Theme.background.opacity(0.85), Theme.background],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 120)
            .allowsHitTesting(false)
        }
        .frame(height: 340)
    }

    // MARK: - Scroll

    private var scrollContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 28) {
                headerBlock
                statsRow
                regionsSection
                viewHistoryButton
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }

    private var headerBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Scan summary")
                .hudEyebrowStyle()
                .foregroundStyle(Theme.accent)
            Text(headline)
                .font(Theme.hudTitle(size: 26))
                .foregroundStyle(Theme.textPrimary)
            Text("\(results.count) regions compared to \(results.first?.cohortLabel ?? "your cohort")")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
    }

    private var statsRow: some View {
        HStack(spacing: 0) {
            summaryChip(value: improved, label: "Improved", tint: Theme.normal)
            chipDivider
            summaryChip(value: toWatch, label: "To watch", tint: Theme.watch)
            chipDivider
            summaryChip(value: steady, label: "Steady", tint: Theme.textSecondary)
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 16)
        .animation(.easeOut(duration: 0.45).delay(0.08), value: appeared)
    }

    private var chipDivider: some View {
        Rectangle()
            .fill(Theme.textSecondary.opacity(0.2))
            .frame(width: 1, height: 36)
    }

    private func summaryChip(value: Int, label: String, tint: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(Theme.hudData(size: 32))
                .foregroundStyle(tint)
            Text(label.uppercased())
                .font(Theme.hudCaption(size: 9))
                .tracking(0.6)
                .foregroundStyle(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private var regionsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("By region")
                .font(Theme.hudLabel(size: 12))
                .tracking(1.0)
                .foregroundStyle(Theme.textSecondary)
                .padding(.bottom, 8)

            ForEach(Array(results.enumerated()), id: \.element.id) { index, result in
                SummaryRegionRow(result: result)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 10)
                    .animation(
                        .easeOut(duration: 0.4).delay(0.12 + Double(index) * 0.04),
                        value: appeared
                    )
            }
        }
    }

    private var viewHistoryButton: some View {
        Button(action: onComplete) {
            HStack(spacing: 8) {
                Text("VIEW HISTORY")
                    .font(Theme.hudLabel(size: 14))
                    .tracking(0.8)
                Image(systemName: "chart.xyaxis.line")
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(Theme.accent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Theme.accent.opacity(0.12))
            .overlay(Rectangle().strokeBorder(Theme.accent, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .padding(.top, 8)
        .opacity(appeared ? 1 : 0)
        .animation(.easeOut(duration: 0.4).delay(0.35), value: appeared)
        .accessibilityLabel("View history")
    }
}

// MARK: - Region row

private struct SummaryRegionRow: View {
    let result: OrganScanResult

    private var tint: Color { Theme.color(for: result.status) }
    private var percentile: Int { Int((result.percentile * 100).rounded()) }

    private var deltaLabel: String {
        let pts = result.standingPointsDelta
        let label = result.lastScanDate.shortLabel
        if pts == 0 { return "Even with \(label)" }
        let arrow = pts > 0 ? "\u{2191}" : "\u{2193}"
        let direction = pts > 0 ? "ahead of" : "behind"
        return "\(arrow) \(abs(pts)) pts \(direction) \(label)"
    }

    private var deltaColor: Color {
        let pts = result.standingPointsDelta
        if pts > 0 { return Theme.normal }
        if pts < 0 { return result.status == .alert ? Theme.alert : Theme.watch }
        return Theme.textSecondary
    }

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            RegionIcon(region: result.region, size: 26, color: tint)
                .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 3) {
                Text(result.region.displayName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text(deltaLabel)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(deltaColor)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                Text(result.percentileLabel)
                    .font(Theme.hudData(size: 20))
                    .foregroundStyle(tint)
                Text("percentile")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(0.5)
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .padding(.vertical, 14)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Theme.textSecondary.opacity(0.12))
                .frame(height: 1)
        }
    }
}

#Preview {
    ScanSummaryView(results: MockData.organResults(), onComplete: {})
        .preferredColorScheme(.dark)
}

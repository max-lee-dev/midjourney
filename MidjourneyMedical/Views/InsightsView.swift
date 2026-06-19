import SwiftUI

/// Screen 4 — AI-surfaced findings ranked by significance.
struct InsightsView: View {
    @State private var selectedInsight: Insight?

    private var insights: [Insight] {
        MockData.insights.sorted { $0.significance > $1.significance }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                ScreenTitle(eyebrow: "AI analysis", title: "Insights")

                headerCard

                VStack(spacing: 12) {
                    ForEach(insights) { insight in
                        Button {
                            selectedInsight = insight
                        } label: {
                            InsightCard(insight: insight)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(20)
        }
        .screenBackground()
        .sheet(item: $selectedInsight) { insight in
            InsightDetailSheet(insight: insight)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(0)
        }
    }

    private var headerCard: some View {
        let alerts = insights.filter { $0.severity == .alert }.count
        let watches = insights.filter { $0.severity == .watch }.count
        return HStack(spacing: 14) {
            Image(systemName: "sparkles")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 48, height: 48)
                .overlay(Rectangle().strokeBorder(Theme.accent.opacity(0.45), lineWidth: 1))
            VStack(alignment: .leading, spacing: 3) {
                Text("\(insights.count) FINDINGS FROM YOUR LATEST SCAN")
                    .font(Theme.hudLabel(size: 13))
                    .tracking(0.5)
                    .foregroundStyle(Theme.textPrimary)
                Text("\(alerts) FLAGGED \u{00B7} \(watches) TO WATCH \u{00B7} RANKED BY SIGNIFICANCE")
                    .font(Theme.hudCaption(size: 9))
                    .tracking(0.4)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
        }
        .card()
    }
}

private struct InsightCard: View {
    let insight: Insight

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Rectangle()
                    .fill(Theme.color(for: insight.severity).opacity(0.1))
                    .frame(width: 44, height: 44)
                    .overlay(Rectangle().strokeBorder(Theme.color(for: insight.severity).opacity(0.4), lineWidth: 1))
                RegionIcon(region: insight.region, size: 22, color: Theme.color(for: insight.severity))
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    StatusPill(status: insight.severity, compact: true)
                    Spacer()
                    Image(systemName: insight.trend.symbol)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.textSecondary)
                }
                Text(insight.title.uppercased())
                    .font(Theme.hudLabel(size: 14))
                    .tracking(0.4)
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.leading)
                Text(insight.detail.uppercased())
                    .font(Theme.hudCaption(size: 10))
                    .tracking(0.3)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                SignificanceBar(value: insight.significance, tint: Theme.color(for: insight.severity))
                    .padding(.top, 2)
            }
        }
        .card()
    }
}

private struct SignificanceBar: View {
    let value: Double
    let tint: Color

    var body: some View {
        HStack(spacing: 8) {
            Text("SIGNIFICANCE")
                .hudCaptionStyle()
                .foregroundStyle(Theme.textTertiary)
            MetricBar(fraction: value, color: tint, height: 4)
            Text("\(Int((value * 100).rounded()))")
                .font(Theme.hudLabel(size: 11))
                .monospacedDigit()
                .foregroundStyle(tint)
        }
    }
}

private struct InsightDetailSheet: View {
    let insight: Insight

    private var sample: MetricSample { MockData.latestScan.sample(for: insight.region.metric) }
    private var history: [Double] { MockData.history(for: insight.region.metric).map(\.value) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 14) {
                    ZStack {
                        Rectangle()
                            .fill(Theme.color(for: insight.severity).opacity(0.1))
                            .frame(width: 52, height: 52)
                            .overlay(Rectangle().strokeBorder(Theme.color(for: insight.severity).opacity(0.4), lineWidth: 1))
                        RegionIcon(region: insight.region, size: 28, color: Theme.color(for: insight.severity))
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(insight.title.uppercased())
                            .font(Theme.hudTitle(size: 19))
                            .foregroundStyle(Theme.textPrimary)
                        Text(insight.region.displayName.uppercased())
                            .font(Theme.hudCaption(size: 10))
                            .tracking(0.5)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    Spacer()
                }

                StatusPill(status: insight.severity)

                Text(insight.detail.uppercased())
                    .font(Theme.hudLabel(size: 12))
                    .tracking(0.4)
                    .foregroundStyle(Theme.textPrimary.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 10) {
                    SectionHeader(title: insight.region.metric.displayName, subtitle: "Across your last \(history.count) scans")
                    Sparkline(values: history, color: Theme.color(for: insight.severity))
                        .frame(height: 70)
                    HStack {
                        Text("NOW \(insight.region.metric.formatted(sample.value).uppercased())")
                            .font(Theme.hudLabel(size: 12))
                            .tracking(0.4)
                            .foregroundStyle(Theme.textPrimary)
                        Spacer()
                        Text("BASELINE \(insight.region.metric.formatted(sample.baseline).uppercased())")
                            .font(Theme.hudCaption(size: 10))
                            .tracking(0.4)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                .card()
            }
            .padding(20)
        }
        .background(Theme.background.ignoresSafeArea())
    }
}

#Preview {
    InsightsView()
}

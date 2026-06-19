import SwiftUI

/// Screen 1 — the 3D body map.
/// A soft white point-cloud figure on a pure black canvas; tap a region to explore.
struct BodyView: View {
    private let scan = MockData.latestScan
    @State private var selectedRegion: BodyRegion?

    private var statuses: [BodyRegion: HealthStatus] {
        Dictionary(uniqueKeysWithValues: BodyRegion.allCases.map { ($0, scan.sample(for: $0.metric).status) })
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar

                Spacer(minLength: 12)

                BodyPointCloudView(statuses: statuses, selectedRegion: $selectedRegion)
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: 460)

                Spacer(minLength: 12)

                statusLegend
                    .padding(.bottom, 12)
            }
        }
        .sheet(item: $selectedRegion) { region in
            RegionDetailSheet(region: region)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(0)
        }
    }

    private var topBar: some View {
        HStack {
            SquareIconButton(systemName: "xmark") {}
            Spacer()
            SquareIconButton(systemName: "ellipsis") {}
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
    }

    private var statusLegend: some View {
        HStack(spacing: 10) {
            ForEach([HealthStatus.normal, .watch, .alert], id: \.self) { status in
                HStack(spacing: 6) {
                    DeviationDot(status: status, size: 7)
                    Text(status.label.uppercased())
                        .font(Theme.hudCaption(size: 10))
                        .tracking(0.6)
                        .foregroundStyle(Theme.textTertiary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
        }
    }
}

/// Square icon button used in the minimal top bar.
private struct SquareIconButton: View {
    let systemName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
                .frame(width: 40, height: 40)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(systemName)
    }
}

/// Detail sheet shown when a region is tapped.
private struct RegionDetailSheet: View {
    let region: BodyRegion

    private var metric: HealthMetric { region.metric }
    private var sample: MetricSample { MockData.latestScan.sample(for: metric) }
    private var history: [Double] { MockData.history(for: metric).map(\.value) }
    private var firstValue: Double { MockData.firstScan.sample(for: metric).value }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                HStack(spacing: 12) {
                    statTile(title: "Current", value: metric.formatted(sample.value), tint: Theme.textPrimary)
                    statTile(title: "Baseline", value: metric.formatted(sample.baseline), tint: Theme.textSecondary)
                }

                HStack(spacing: 12) {
                    statTile(
                        title: "vs Baseline",
                        value: signed(sample.deviationPercent) + "%",
                        tint: Theme.color(for: sample.status)
                    )
                    statTile(
                        title: "Since first scan",
                        value: signedValue(sample.value - firstValue),
                        tint: Theme.textSecondary
                    )
                }

                VStack(alignment: .leading, spacing: 10) {
                    SectionHeader(title: "Trend", subtitle: "Across your last \(history.count) scans")
                    Sparkline(values: history, color: Theme.color(for: sample.status))
                        .frame(height: 70)
                }
                .card()

                Text(region.blurb.uppercased())
                    .font(Theme.hudCaption(size: 10))
                    .tracking(0.5)
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.horizontal, 4)
            }
            .padding(20)
        }
        .background(Theme.background.ignoresSafeArea())
    }

    private var header: some View {
        HStack(spacing: 14) {
            ZStack {
                Rectangle()
                    .fill(Theme.color(for: sample.status).opacity(0.12))
                    .frame(width: 52, height: 52)
                    .overlay(Rectangle().strokeBorder(Theme.color(for: sample.status).opacity(0.4), lineWidth: 1))
                RegionIcon(region: region, size: 28, color: Theme.color(for: sample.status))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(region.displayName.uppercased())
                    .font(Theme.hudTitle(size: 20))
                    .foregroundStyle(Theme.textPrimary)
                Text(metric.displayName.uppercased())
                    .font(Theme.hudCaption(size: 10))
                    .tracking(0.6)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            StatusPill(status: sample.status)
        }
    }

    private func statTile(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .hudCaptionStyle()
                .foregroundStyle(Theme.textTertiary)
            Text(value)
                .font(Theme.hudData(size: 20))
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: 14)
    }

    private func signed(_ value: Double) -> String {
        String(format: "%+.1f", value)
    }

    private func signedValue(_ value: Double) -> String {
        String(format: "%+.2f", value) + " " + metric.unit
    }
}

#Preview {
    BodyView()
}

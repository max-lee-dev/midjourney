import SwiftUI
import Charts

/// Screen 2 — longitudinal trend of a chosen metric across all scans.
struct TimelineView: View {
    var animateEntrance: Bool = false

    @State private var selectedMetric: HealthMetric = .visceralFat
    @State private var selectedScanID: UUID?
    @State private var contentAppeared: Bool

    init(animateEntrance: Bool = false) {
        self.animateEntrance = animateEntrance
        _contentAppeared = State(initialValue: !animateEntrance)
    }

    private var history: [(date: Date, value: Double)] { MockData.history(for: selectedMetric) }
    private var baseline: Double { MockData.baselineValue(for: selectedMetric) }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 16) {
                    ScreenTitle(eyebrow: "Welcome back, Max", title: "Timeline")
                    metricPicker
                }

                chartCard

                scanStrip
            }
            .padding(20)
            // Clear the floating scan button at the bottom.
            .padding(.bottom, 92)
            .opacity(contentAppeared ? 1 : 0)
            .offset(y: contentAppeared ? 0 : 20)
        }
        .screenBackground()
        .onAppear {
            guard animateEntrance, !contentAppeared else {
                contentAppeared = true
                return
            }
            withAnimation(.easeOut(duration: 0.65).delay(0.12)) {
                contentAppeared = true
            }
        }
    }

    private var metricPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(HealthMetric.allCases) { metric in
                    let isSelected = metric == selectedMetric
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { selectedMetric = metric }
                    } label: {
                        HStack(spacing: 7) {
                            RegionIcon(
                                region: metric.region,
                                size: 16,
                                color: isSelected ? Theme.background : Theme.textSecondary
                            )
                            Text(metric.shortName.uppercased())
                                .font(Theme.hudLabel(size: 11))
                                .tracking(0.6)
                        }
                        .foregroundStyle(isSelected ? Theme.background : Theme.textSecondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(isSelected ? Theme.accent : Theme.surfaceElevated, in: Rectangle())
                        .overlay(
                            Rectangle().strokeBorder(Theme.stroke, lineWidth: isSelected ? 0 : 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 2)
        }
        .horizontalEdgeFade(0.05)
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(selectedMetric.displayName.uppercased())
                        .font(Theme.hudLabel(size: 14))
                        .tracking(0.8)
                        .foregroundStyle(Theme.textPrimary)
                    Text("LATEST \(selectedMetric.formatted(latestValue).uppercased())")
                        .font(Theme.hudCaption(size: 10))
                        .tracking(0.5)
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                changeBadge
            }

            chart
                .frame(height: 200)
                .padding(.vertical, 4)

            HStack(spacing: 16) {
                legendSwatch(color: Theme.accent, label: "You")
                legendSwatch(color: Theme.textTertiary, label: "Cohort baseline", dashed: true)
            }
        }
        .card()
    }

    private var chart: some View {
        Chart {
            RuleMark(y: .value("Baseline", baseline))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                .foregroundStyle(Theme.textTertiary)
                .annotation(position: .top, alignment: .leading) {
                    Text("BASELINE")
                        .font(Theme.hudCaption(size: 8))
                        .tracking(0.5)
                        .foregroundStyle(Theme.textTertiary)
                }

            ForEach(history, id: \.date) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value(selectedMetric.displayName, point.value)
                )
                .foregroundStyle(Theme.accent)
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .butt))
                .interpolationMethod(.catmullRom)

                PointMark(
                    x: .value("Date", point.date),
                    y: .value(selectedMetric.displayName, point.value)
                )
                .foregroundStyle(Theme.accent)
                .symbolSize(28)
            }
        }
        .chartYScale(domain: yDomain)
        .chartXScale(range: .plotDimension(padding: 12))
        .chartPlotStyle { plotArea in
            plotArea
                .background(Theme.surfaceElevated.opacity(0.5))
                .overlay(Rectangle().strokeBorder(Theme.stroke.opacity(0.5), lineWidth: 1))
        }
        .chartXAxis {
            AxisMarks(values: history.map(\.date)) { _ in
                AxisValueLabel(format: .dateTime.month(.abbreviated).year(.twoDigits))
                    .font(Theme.hudCaption(size: 9))
                    .foregroundStyle(Theme.textTertiary)
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Theme.stroke.opacity(0.4))
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Theme.stroke.opacity(0.4))
                AxisValueLabel()
                    .font(Theme.hudCaption(size: 9))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
    }

    private var scanStrip: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Scans", subtitle: "\(MockData.scans.count) scans over 2 years")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(MockData.scansNewestFirst) { scan in
                        scanChip(scan)
                    }
                }
            }
            .contentMargins(.horizontal, 2, for: .scrollContent)
            .horizontalEdgeFade(0.07)
        }
        .card()
    }

    private func scanChip(_ scan: Scan) -> some View {
        let sample = scan.sample(for: selectedMetric)
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(scan.date.shortLabel.uppercased())
                    .font(Theme.hudLabel(size: 11))
                    .tracking(0.5)
                    .foregroundStyle(Theme.textPrimary)
                Spacer(minLength: 8)
                DeviationDot(status: sample.status, size: 8)
            }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(selectedMetric.format(sample.value))
                    .font(Theme.hudData(size: 20))
                    .foregroundStyle(Theme.textPrimary)
                Text(selectedMetric.unit.uppercased())
                    .font(Theme.hudCaption(size: 9))
                    .tracking(0.5)
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .padding(12)
        .frame(width: 120, alignment: .leading)
        .background(Theme.surfaceElevated, in: Rectangle())
        .overlay(Rectangle().strokeBorder(Theme.stroke, lineWidth: 1))
    }

    private func legendSwatch(color: Color, label: String, dashed: Bool = false) -> some View {
        HStack(spacing: 6) {
            if dashed {
                Rectangle()
                    .fill(color)
                    .frame(width: 14, height: 2)
            } else {
                Rectangle().fill(color).frame(width: 8, height: 8)
            }
            Text(label.uppercased())
                .font(Theme.hudCaption(size: 9))
                .tracking(0.5)
                .foregroundStyle(Theme.textSecondary)
        }
    }

    private var changeBadge: some View {
        let delta = latestValue - MockData.firstScan.sample(for: selectedMetric).value
        let improving = selectedMetric.higherIsBetter ? delta >= 0 : delta <= 0
        let tint = improving ? Theme.normal : Theme.alert
        return HStack(spacing: 4) {
            Image(systemName: delta >= 0 ? "arrow.up.right" : "arrow.down.right")
                .font(.system(size: 10, weight: .bold))
            Text(String(format: "%+.2f %@", delta, selectedMetric.unit).uppercased())
                .font(Theme.hudLabel(size: 11))
                .tracking(0.4)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .overlay(Rectangle().strokeBorder(tint.opacity(0.45), lineWidth: 1))
    }

    private var latestValue: Double { history.last?.value ?? 0 }

    private var yDomain: ClosedRange<Double> {
        let values = history.map(\.value) + [baseline]
        let minV = values.min() ?? 0
        let maxV = values.max() ?? 1
        let pad = (maxV - minV) * 0.2 + 0.001
        return (minV - pad)...(maxV + pad)
    }
}

/// Fades the leading and trailing edges of a horizontal scroller so off-screen
/// content dissolves out instead of being hard-clipped.
private struct HorizontalEdgeFade: ViewModifier {
    var fade: CGFloat

    func body(content: Content) -> some View {
        content.mask(
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black, location: fade),
                    .init(color: .black, location: 1 - fade),
                    .init(color: .clear, location: 1)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
    }
}

private extension View {
    func horizontalEdgeFade(_ fade: CGFloat = 0.06) -> some View {
        modifier(HorizontalEdgeFade(fade: fade))
    }
}

#Preview {
    TimelineView()
}

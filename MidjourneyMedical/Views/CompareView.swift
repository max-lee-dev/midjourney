import SwiftUI

/// Screen 3 — pick two scans and see the per-region delta for every metric.
struct CompareView: View {
    @State private var scanAIndex: Int = 0
    @State private var scanBIndex: Int

    private let scans = MockData.scans

    init() {
        _scanBIndex = State(initialValue: MockData.scans.count - 1)
    }

    private var scanA: Scan { scans[scanAIndex] }
    private var scanB: Scan { scans[scanBIndex] }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                ScreenTitle(eyebrow: "Diff", title: "Compare")

                pickers

                summaryStrip

                VStack(spacing: 10) {
                    ForEach(HealthMetric.allCases) { metric in
                        DeltaRow(metric: metric, from: scanA, to: scanB)
                    }
                }
            }
            .padding(20)
        }
        .screenBackground()
    }

    private var pickers: some View {
        HStack(spacing: 12) {
            scanPicker(title: "From", selection: $scanAIndex)
            Image(systemName: "arrow.right")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Theme.accent)
            scanPicker(title: "To", selection: $scanBIndex)
        }
    }

    private func scanPicker(title: String, selection: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .hudCaptionStyle()
                .foregroundStyle(Theme.textTertiary)
            Menu {
                ForEach(scans.indices, id: \.self) { index in
                    Button(scans[index].date.mediumLabel) { selection.wrappedValue = index }
                }
            } label: {
                HStack {
                    Text(scans[selection.wrappedValue].date.shortLabel.uppercased())
                        .font(Theme.hudLabel(size: 14))
                        .tracking(0.5)
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .overlay(Rectangle().strokeBorder(Theme.stroke, lineWidth: 1))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var summaryStrip: some View {
        let days = Calendar.current.dateComponents([.day], from: scanA.date, to: scanB.date).day ?? 0
        let improved = HealthMetric.allCases.filter { isImprovement($0) }.count
        let worsened = HealthMetric.allCases.filter { isWorsening($0) }.count
        return HStack(spacing: 12) {
            summaryTile(value: "\(abs(days))", label: "days apart", tint: Theme.textPrimary)
            summaryTile(value: "\(improved)", label: "improved", tint: Theme.normal)
            summaryTile(value: "\(worsened)", label: "worsened", tint: Theme.alert)
        }
    }

    private func summaryTile(value: String, label: String, tint: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(Theme.hudData(size: 22))
                .foregroundStyle(tint)
            Text(label.uppercased())
                .font(Theme.hudCaption(size: 9))
                .tracking(0.6)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .card(padding: 14)
    }

    private func isImprovement(_ metric: HealthMetric) -> Bool {
        let delta = scanB.sample(for: metric).value - scanA.sample(for: metric).value
        guard delta != 0 else { return false }
        return metric.higherIsBetter ? delta > 0 : delta < 0
    }

    private func isWorsening(_ metric: HealthMetric) -> Bool {
        let delta = scanB.sample(for: metric).value - scanA.sample(for: metric).value
        guard delta != 0 else { return false }
        return metric.higherIsBetter ? delta < 0 : delta > 0
    }
}

private struct DeltaRow: View {
    let metric: HealthMetric
    let from: Scan
    let to: Scan

    private var fromValue: Double { from.sample(for: metric).value }
    private var toValue: Double { to.sample(for: metric).value }
    private var delta: Double { toValue - fromValue }
    private var percent: Double { fromValue == 0 ? 0 : (delta / fromValue) * 100 }

    private var improving: Bool {
        guard delta != 0 else { return true }
        return metric.higherIsBetter ? delta > 0 : delta < 0
    }

    private var tint: Color {
        delta == 0 ? Theme.textSecondary : (improving ? Theme.normal : Theme.alert)
    }

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(metric.displayName.uppercased())
                    .font(Theme.hudLabel(size: 13))
                    .tracking(0.5)
                    .foregroundStyle(Theme.textPrimary)
                Text("\(metric.format(fromValue)) \u{2192} \(metric.format(toValue)) \(metric.unit)")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            HStack(spacing: 5) {
                Image(systemName: delta == 0 ? "minus" : (delta > 0 ? "arrow.up.right" : "arrow.down.right"))
                    .font(.system(size: 11, weight: .bold))
                Text(String(format: "%+.1f%%", percent))
                    .font(Theme.hudLabel(size: 13))
                    .monospacedDigit()
            }
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .overlay(Rectangle().strokeBorder(tint.opacity(0.45), lineWidth: 1))
        }
        .card(padding: 14)
    }
}

#Preview {
    CompareView()
}

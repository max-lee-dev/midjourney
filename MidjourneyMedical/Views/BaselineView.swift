import SwiftUI

/// Screen 5 — cohort percentile for each metric.
struct BaselineView: View {
    private let cohort = MockData.cohort

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                ScreenTitle(eyebrow: "Cohort \u{00B7} Males 18\u{2013}24", title: "Me vs. Baseline")

                headerCard

                VStack(spacing: 12) {
                    ForEach(cohort) { item in
                        BaselineRow(item: item)
                    }
                }
            }
            .padding(20)
        }
        .screenBackground()
    }

    private var headerCard: some View {
        let favorable = cohort.filter(\.isFavorable).count
        return HStack(spacing: 14) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 48, height: 48)
                .overlay(Rectangle().strokeBorder(Theme.accent.opacity(0.45), lineWidth: 1))
            VStack(alignment: .leading, spacing: 3) {
                Text("FAVORABLE ON \(favorable) OF \(cohort.count) METRICS")
                    .font(Theme.hudLabel(size: 13))
                    .tracking(0.4)
                    .foregroundStyle(Theme.textPrimary)
                Text("COMPARED TO OTHERS YOUR AGE AND SEX")
                    .font(Theme.hudCaption(size: 9))
                    .tracking(0.4)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
        }
        .card()
    }
}

private struct BaselineRow: View {
    let item: CohortBaseline

    private var tint: Color { item.isFavorable ? Theme.normal : Theme.watch }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.metric.displayName.uppercased())
                        .font(Theme.hudLabel(size: 13))
                        .tracking(0.4)
                        .foregroundStyle(Theme.textPrimary)
                    Text(item.metric.formatted(item.userValue).uppercased())
                        .font(Theme.hudCaption(size: 10))
                        .tracking(0.4)
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(item.percentileLabel.uppercased())
                        .font(Theme.hudData(size: 18))
                        .foregroundStyle(tint)
                    Text("PERCENTILE")
                        .font(Theme.hudCaption(size: 9))
                        .tracking(0.5)
                        .foregroundStyle(Theme.textTertiary)
                }
            }

            DistributionBar(percentile: item.percentile, tint: tint)

            Text(captionText.uppercased())
                .font(Theme.hudCaption(size: 9))
                .tracking(0.4)
                .foregroundStyle(Theme.textSecondary)
        }
        .card()
    }

    private var captionText: String {
        let direction = item.metric.higherIsBetter ? "higher is better" : "lower is better"
        let pct = Int((item.percentile * 100).rounded())
        let betterThan = item.metric.higherIsBetter ? pct : (100 - pct)
        let standing = betterThan >= 50
            ? "ahead of \(betterThan)%"
            : "behind \(100 - betterThan)%"
        return "\(direction) \u{00B7} \(standing) of your cohort"
    }
}

#Preview {
    BaselineView()
}

import Foundation

/// All mock data for the prototype. One coherent 2-year story:
/// a 19-year-old male on a lean bulk — muscle, lung capacity, and ejection
/// fraction all improving, but visceral fat is quietly climbing and gets flagged.
enum MockData {

    /// Per-metric: (cohort baseline, values for the 6 chronological scans).
    private static let series: [HealthMetric: (baseline: Double, values: [Double])] = [
        .muscleMass:        (41.0, [37.8, 39.2, 40.5, 41.8, 43.0, 44.1]),
        .visceralFat:       (1.10, [0.95, 1.05, 1.18, 1.30, 1.45, 1.58]),
        .boneDensity:       (1.18, [1.22, 1.23, 1.24, 1.24, 1.25, 1.26]),
        .liverFat:          (3.20, [2.60, 2.80, 2.70, 2.90, 3.00, 3.10]),
        .ejectionFraction:  (62.0, [60.0, 61.0, 62.0, 63.0, 64.0, 65.0]),
        .lungCapacity:      (6.00, [5.80, 5.90, 6.00, 6.10, 6.20, 6.30]),
        .arterialStiffness: (5.40, [5.20, 5.30, 5.50, 5.70, 5.90, 6.10]),
        .hydration:         (60.0, [58.5, 61.0, 59.5, 62.0, 60.5, 57.5]),
    ]

    /// Scan dates, oldest first — roughly every ~4.5 months over 2 years.
    private static let scanDates: [Date] = {
        let calendar = Calendar(identifier: .gregorian)
        let components: [DateComponents] = [
            DateComponents(year: 2024, month: 6, day: 14),
            DateComponents(year: 2024, month: 10, day: 22),
            DateComponents(year: 2025, month: 3, day: 8),
            DateComponents(year: 2025, month: 7, day: 19),
            DateComponents(year: 2025, month: 12, day: 2),
            DateComponents(year: 2026, month: 5, day: 28),
        ]
        return components.compactMap { calendar.date(from: $0) }
    }()

    /// Chronological scans (oldest first).
    static let scans: [Scan] = {
        scanDates.enumerated().map { index, date in
            let samples = HealthMetric.allCases.map { metric -> MetricSample in
                let entry = series[metric]!
                return MetricSample(metric: metric, value: entry.values[index], baseline: entry.baseline)
            }
            return Scan(id: UUID(), date: date, samples: samples)
        }
    }()

    /// Scans newest first — handy for pickers and lists.
    static let scansNewestFirst: [Scan] = scans.reversed()

    static var latestScan: Scan { scans.last! }
    static var firstScan: Scan { scans.first! }

    /// Full chronological value history for one metric (for charts/sparklines).
    static func history(for metric: HealthMetric) -> [(date: Date, value: Double)] {
        scans.map { ($0.date, $0.sample(for: metric).value) }
    }

    static func baselineValue(for metric: HealthMetric) -> Double {
        series[metric]!.baseline
    }

    /// AI-surfaced findings, unranked (the view sorts by significance).
    static let insights: [Insight] = [
        Insight(
            title: "Visceral fat is trending up",
            detail: "Visceral fat around your organs has risen 66% over your last 6 scans and now sits 44% above your cohort. This is the kind of thing that usually shows up years before bloodwork notices — and seeing it early means you can adjust your bulk before it becomes a problem.",
            severity: .alert,
            region: .abdomen,
            trend: .rising,
            significance: 0.95
        ),
        Insight(
            title: "Arterial stiffness creeping higher",
            detail: "The stiffness of your large arteries is up 17% since your first scan, now slightly above your cohort. Still mild, but the trend is steady — and it tends to track with the rising visceral fat, so the same changes should help both.",
            severity: .watch,
            region: .brain,
            trend: .rising,
            significance: 0.62
        ),
        Insight(
            title: "Strong skeletal muscle gains",
            detail: "Lean muscle is up 6.3 points (37.8% → 44.1%) and now sits in the 82nd percentile for your cohort. Your training is clearly working.",
            severity: .normal,
            region: .muscles,
            trend: .rising,
            significance: 0.58
        ),
        Insight(
            title: "Lung capacity holding strong",
            detail: "Total lung volume climbed from 5.8 to 6.3 L over two years and now sits in the 80th percentile for your cohort — a solid structural read from the air\u{2013}tissue boundary.",
            severity: .normal,
            region: .lungs,
            trend: .rising,
            significance: 0.51
        ),
        Insight(
            title: "Heart pumping more efficiently",
            detail: "Ejection fraction rose from 60% to 65% since your first scan, consistent with improved cardiovascular fitness. Now in the 70th percentile for your cohort.",
            severity: .normal,
            region: .heart,
            trend: .rising,
            significance: 0.44
        ),
        Insight(
            title: "Hydration varies scan-to-scan",
            detail: "Tissue water content swings a few points between visits. Not concerning — likely reflects timing of fluids and training relative to each scan.",
            severity: .normal,
            region: .kidneys,
            trend: .stable,
            significance: 0.22
        ),
    ]

    static let cohortLabel = "Males 18\u{2013}24"

    /// Where the user falls in their cohort this scan, per metric.
    static let currentPercentiles: [HealthMetric: Double] = [
        .muscleMass: 0.82,
        .visceralFat: 0.74,
        .boneDensity: 0.68,
        .liverFat: 0.40,
        .ejectionFraction: 0.70,
        .lungCapacity: 0.80,
        .arterialStiffness: 0.58,
        .hydration: 0.45,
    ]

    /// Where the user stood at the previous scan — drives "since last visit" deltas.
    static let previousPercentiles: [HealthMetric: Double] = [
        .muscleMass: 0.78,
        .visceralFat: 0.68,
        .boneDensity: 0.66,
        .liverFat: 0.38,
        .ejectionFraction: 0.66,
        .lungCapacity: 0.76,
        .arterialStiffness: 0.52,
        .hydration: 0.48,
    ]

    /// Where the user falls in their cohort, per metric (for the Baseline screen).
    static let cohort: [CohortBaseline] = {
        HealthMetric.allCases.map { metric in
            CohortBaseline(
                metric: metric,
                userValue: latestScan.sample(for: metric).value,
                percentile: currentPercentiles[metric] ?? 0.5,
                cohortLabel: cohortLabel
            )
        }
    }()

    /// Whether a fresh scan is waiting to be revealed. Drives the post-scan
    /// "Wrapped" experience at launch (mocked for the prototype).
    static var hasNewScan = true

    /// Stable identifier for the latest scan — survives relaunches (unlike the
    /// runtime `UUID`), so we can remember whether its reveal has been seen.
    static var latestScanToken: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: latestScan.date)
    }

    /// Per-organ results for the post-scan reveal, ordered head → feet so the
    /// camera pans down the body as each region is revealed.
    static func organResults() -> [OrganScanResult] {
        let previousScan = scans.count >= 2 ? scans[scans.count - 2] : firstScan
        let order = BodyRegion.allCases
        return order.map { region in
            let metric = region.metric
            return OrganScanResult(
                region: region,
                percentile: currentPercentiles[metric] ?? 0.5,
                previousPercentile: previousPercentiles[metric] ?? 0.5,
                currentValue: latestScan.sample(for: metric).value,
                previousValue: previousScan.sample(for: metric).value,
                cohortLabel: cohortLabel,
                status: latestScan.sample(for: metric).status,
                lastScanDate: previousScan.date
            )
        }
    }
}

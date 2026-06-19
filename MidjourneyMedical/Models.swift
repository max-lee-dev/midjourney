import SwiftUI
import simd

/// Clinical status of a reading relative to the user's age/sex baseline.
enum HealthStatus: Int, Comparable {
    case normal
    case watch
    case alert

    static func < (lhs: HealthStatus, rhs: HealthStatus) -> Bool { lhs.rawValue < rhs.rawValue }

    var label: String {
        switch self {
        case .normal: return "Normal"
        case .watch: return "Watch"
        case .alert: return "Flagged"
        }
    }
}

/// The small set of body-composition metrics the prototype tracks.
/// Each metric maps 1:1 to a `BodyRegion` so the Body screen, Timeline,
/// Compare and Baseline screens all share one source of truth.
enum HealthMetric: String, CaseIterable, Identifiable {
    case muscleMass
    case visceralFat
    case boneDensity
    case liverFat
    case restingHeartRate
    case vo2max
    case arterialStiffness
    case hydration

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .muscleMass: return "Muscle Mass"
        case .visceralFat: return "Visceral Fat"
        case .boneDensity: return "Bone Density"
        case .liverFat: return "Liver Fat"
        case .restingHeartRate: return "Resting Heart Rate"
        case .vo2max: return "VO\u{2082} Max"
        case .arterialStiffness: return "Arterial Stiffness"
        case .hydration: return "Hydration"
        }
    }

    var shortName: String {
        switch self {
        case .muscleMass: return "Muscle"
        case .visceralFat: return "Visc. Fat"
        case .boneDensity: return "Bone"
        case .liverFat: return "Liver"
        case .restingHeartRate: return "Rest HR"
        case .vo2max: return "VO\u{2082}"
        case .arterialStiffness: return "Arterial"
        case .hydration: return "Water"
        }
    }

    var unit: String {
        switch self {
        case .muscleMass: return "%"
        case .visceralFat: return "L"
        case .boneDensity: return "g/cm\u{00B2}"
        case .liverFat: return "%"
        case .restingHeartRate: return "bpm"
        case .vo2max: return "ml/kg"
        case .arterialStiffness: return "m/s"
        case .hydration: return "%"
        }
    }

    /// Whether a higher value is clinically better.
    var higherIsBetter: Bool {
        switch self {
        case .muscleMass, .boneDensity, .vo2max, .hydration: return true
        case .visceralFat, .liverFat, .restingHeartRate, .arterialStiffness: return false
        }
    }

    func format(_ value: Double) -> String {
        switch self {
        case .restingHeartRate, .vo2max:
            return String(format: "%.0f", value)
        case .muscleMass, .liverFat, .hydration:
            return String(format: "%.1f", value)
        default:
            return String(format: "%.2f", value)
        }
    }

    func formatted(_ value: Double) -> String { "\(format(value)) \(unit)" }
}

/// A single metric reading inside a scan, with its cohort baseline.
struct MetricSample: Identifiable {
    let metric: HealthMetric
    let value: Double
    /// Age/sex cohort baseline for context (the "normal" reference).
    let baseline: Double

    var id: String { metric.id }

    /// Signed deviation from baseline (positive = above baseline).
    var deviation: Double { (value - baseline) / baseline }

    /// Deviation expressed so positive always means "worse than baseline".
    var adverseDeviation: Double { metric.higherIsBetter ? -deviation : deviation }

    var deviationPercent: Double { deviation * 100 }

    var status: HealthStatus {
        switch adverseDeviation {
        case let d where d >= 0.30: return .alert
        case let d where d >= 0.12: return .watch
        default: return .normal
        }
    }
}

/// A full-body scan taken at a point in time.
struct Scan: Identifiable {
    let id: UUID
    let date: Date
    let samples: [MetricSample]

    func sample(for metric: HealthMetric) -> MetricSample {
        samples.first { $0.metric == metric } ?? MetricSample(metric: metric, value: 0, baseline: 1)
    }

    /// Worst status across all regions — drives the Body screen header.
    var overallStatus: HealthStatus {
        samples.map(\.status).max() ?? .normal
    }

    var flaggedCount: Int { samples.filter { $0.status == .alert }.count }
    var watchCount: Int { samples.filter { $0.status == .watch }.count }
}

/// A tappable anatomical region, mapped 1:1 to a metric.
enum BodyRegion: String, CaseIterable, Identifiable {
    case brain
    case heart
    case lungs
    case liver
    case kidneys
    case abdomen
    case muscles
    case skeleton

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .brain: return "Brain & Vessels"
        case .heart: return "Heart"
        case .lungs: return "Lungs"
        case .liver: return "Liver"
        case .kidneys: return "Kidneys"
        case .abdomen: return "Abdomen"
        case .muscles: return "Skeletal Muscle"
        case .skeleton: return "Skeleton"
        }
    }

    var metric: HealthMetric {
        switch self {
        case .brain: return .arterialStiffness
        case .heart: return .restingHeartRate
        case .lungs: return .vo2max
        case .liver: return .liverFat
        case .kidneys: return .hydration
        case .abdomen: return .visceralFat
        case .muscles: return .muscleMass
        case .skeleton: return .boneDensity
        }
    }

    var sfSymbol: String {
        switch self {
        case .brain: return "brain.head.profile"
        case .heart: return "heart.fill"
        case .lungs: return "lungs.fill"
        case .liver: return "fluid.transmission.fill"
        case .kidneys: return "drop.fill"
        case .abdomen: return "circle.grid.cross.fill"
        case .muscles: return "figure.strengthtraining.traditional"
        case .skeleton: return "figure.stand"
        }
    }

    /// 3D position in the point-cloud body's coordinate space
    /// (y up: head ~+0.9, feet ~-0.9; +z = front of body; +x = anatomical left).
    var anchor3D: SIMD3<Float> {
        switch self {
        case .brain: return SIMD3(0.00, 0.78, 0.05)
        case .heart: return SIMD3(-0.05, 0.42, 0.10)
        case .lungs: return SIMD3(0.06, 0.46, 0.09)
        case .liver: return SIMD3(-0.07, 0.22, 0.11)
        case .kidneys: return SIMD3(0.07, 0.16, 0.06)
        case .abdomen: return SIMD3(0.00, 0.08, 0.12)
        case .muscles: return SIMD3(-0.09, -0.35, 0.10)
        case .skeleton: return SIMD3(0.08, -0.65, 0.05)
        }
    }

    /// Half-height of the vertical highlight band when this region is in focus.
    var focusBandHalfHeight: Float {
        switch self {
        case .brain: return 0.13
        case .heart: return 0.09
        case .lungs: return 0.11
        case .liver: return 0.08
        case .kidneys: return 0.07
        case .abdomen: return 0.10
        case .muscles: return 0.13
        case .skeleton: return 0.15
        }
    }

    /// Lateral radius of the highlight volume around the anchor.
    var focusBandRadius: Float {
        switch self {
        case .brain: return 0.13
        case .heart, .lungs: return 0.15
        case .liver, .kidneys: return 0.13
        case .abdomen: return 0.16
        case .muscles: return 0.14
        case .skeleton: return 0.11
        }
    }

    var blurb: String {
        switch self {
        case .brain: return "Vascular stiffness inferred from aortic pulse-wave velocity."
        case .heart: return "Resting cardiac rhythm and chamber efficiency."
        case .lungs: return "Aerobic capacity estimated from lung volume & perfusion."
        case .liver: return "Hepatic fat fraction from tissue echogenicity."
        case .kidneys: return "Whole-body hydration via tissue water content."
        case .abdomen: return "Visceral adipose volume around the organs."
        case .muscles: return "Lean skeletal muscle as a share of body mass."
        case .skeleton: return "Bone mineral density across load-bearing bone."
        }
    }
}

/// Direction of a longitudinal trend.
enum Trend {
    case rising
    case falling
    case stable

    var symbol: String {
        switch self {
        case .rising: return "arrow.up.right"
        case .falling: return "arrow.down.right"
        case .stable: return "arrow.right"
        }
    }
}

/// An AI-surfaced finding for the Insights screen.
struct Insight: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let severity: HealthStatus
    let region: BodyRegion
    let trend: Trend
    /// 0...1 — drives ranking. Higher = more important to show first.
    let significance: Double
}

/// A metric's position within the user's age/sex cohort, for the Baseline screen.
struct CohortBaseline: Identifiable {
    let metric: HealthMetric
    let userValue: Double
    /// 0...1 — where the user falls in the cohort distribution.
    let percentile: Double
    let cohortLabel: String

    var id: String { metric.id }

    /// Whether the user's percentile is a good place to be for this metric.
    var isFavorable: Bool {
        metric.higherIsBetter ? percentile >= 0.5 : percentile <= 0.5
    }

    var percentileLabel: String {
        Int((percentile * 100).rounded()).ordinalString
    }
}

/// One organ's standing in the latest scan, with movement since the prior visit.
/// Powers the post-scan "Wrapped" reveal.
struct OrganScanResult: Identifiable {
    let region: BodyRegion
    /// 0...1 — where the user falls in their cohort distribution this scan.
    let percentile: Double
    /// 0...1 — the same standing at the previous scan.
    let previousPercentile: Double
    let currentValue: Double
    let previousValue: Double
    let cohortLabel: String
    let status: HealthStatus
    /// Date of the previous scan (the "since" reference).
    let lastScanDate: Date

    var id: String { region.id }

    var metric: HealthMetric { region.metric }

    var percentileDelta: Double { percentile - previousPercentile }
    var valueDelta: Double { currentValue - previousValue }

    /// Whole percentile points moved since the last visit (signed).
    var percentilePointsDelta: Int { Int((percentileDelta * 100).rounded()) }

    /// Whether the raw value moved in the clinically better direction.
    var isImproved: Bool {
        metric.higherIsBetter ? valueDelta > 0 : valueDelta < 0
    }

    /// Whether the current percentile is a good place to be for this metric.
    var isFavorable: Bool {
        metric.higherIsBetter ? percentile >= 0.5 : percentile <= 0.5
    }

    var percentileLabel: String {
        Int((percentile * 100).rounded()).ordinalString
    }
}

extension Int {
    /// Ordinal string for a whole number, e.g. 88 -> "88th", 1 -> "1st".
    var ordinalString: String {
        let suffix: String
        switch self % 100 {
        case 11, 12, 13: suffix = "th"
        default:
            switch self % 10 {
            case 1: suffix = "st"
            case 2: suffix = "nd"
            case 3: suffix = "rd"
            default: suffix = "th"
            }
        }
        return "\(self)\(suffix)"
    }
}

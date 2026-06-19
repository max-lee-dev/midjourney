import SwiftUI

/// Small status badge with sharp corners.
struct StatusPill: View {
    let status: HealthStatus
    var compact: Bool = false

    var body: some View {
        HStack(spacing: 5) {
            Rectangle()
                .fill(Theme.color(for: status))
                .frame(width: 6, height: 6)
            Text(status.label.uppercased())
                .font(.system(size: compact ? 9 : 10, weight: .bold))
                .tracking(0.8)
        }
        .padding(.horizontal, compact ? 7 : 9)
        .padding(.vertical, compact ? 3 : 5)
        .foregroundStyle(Theme.color(for: status))
        .overlay(Rectangle().strokeBorder(Theme.color(for: status).opacity(0.45), lineWidth: 1))
    }
}

/// A flat status marker for compact layouts.
struct DeviationDot: View {
    let status: HealthStatus
    var size: CGFloat = 10

    var body: some View {
        Rectangle()
            .fill(Theme.color(for: status))
            .frame(width: size, height: size)
    }
}

/// "A shallow pool of golden light" backdrop for the scan ritual — warm gold
/// welling up from below, with slow caustic ripples: the half-million elements
/// speaking and listening, like echolocation.
struct GoldenPoolBackdrop: View {
    var rippleCount: Int = 4
    @State private var animate = false

    var body: some View {
        ZStack {
            Theme.background
            Theme.goldenPoolGradient

            GeometryReader { geo in
                let center = CGPoint(x: geo.size.width * 0.5, y: geo.size.height * 0.82)
                ForEach(0..<rippleCount, id: \.self) { index in
                    Circle()
                        .stroke(Theme.accent.opacity(0.10), lineWidth: 1)
                        .frame(width: 120, height: 120)
                        .scaleEffect(animate ? 5.5 : 0.4)
                        .opacity(animate ? 0 : 0.5)
                        .position(center)
                        .animation(
                            .easeOut(duration: 5.0)
                                .repeatForever(autoreverses: false)
                                .delay(Double(index) * 1.25),
                            value: animate
                        )
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .onAppear { animate = true }
    }
}

/// A ring of tiny square elements — each one acts as both a speaker and a
/// microphone ("a choir and an audience"). It pulses outward to evoke the
/// dolphin-like echolocation the scanner uses.
struct EcholocationRing: View {
    var diameter: CGFloat = 190
    var elementCount: Int = 48
    var active: Bool = true

    @State private var pulse = false

    var body: some View {
        ZStack {
            ForEach(0..<elementCount, id: \.self) { index in
                Rectangle()
                    .fill(Theme.accent.opacity(active ? 0.6 : 0.25))
                    .frame(width: 3, height: 3)
                    .offset(y: -diameter / 2)
                    .rotationEffect(.degrees(Double(index) / Double(elementCount) * 360))
            }

            Circle()
                .stroke(Theme.accent.opacity(0.22), lineWidth: 1)
                .frame(width: diameter, height: diameter)
                .scaleEffect(pulse ? 1.14 : 0.92)
                .opacity(pulse ? 0 : 0.6)
        }
        .frame(width: diameter, height: diameter)
        .onAppear {
            withAnimation(.easeOut(duration: 1.8).repeatForever(autoreverses: false)) {
                pulse = true
            }
        }
    }
}

/// A minimal line sparkline drawn from a sequence of values.
struct Sparkline: View {
    let values: [Double]
    var color: Color = Theme.accent
    var lineWidth: CGFloat = 2

    var body: some View {
        GeometryReader { geo in
            let points = normalizedPoints(in: geo.size)
            ZStack {
                if points.count > 1 {
                    linePath(points, closed: false)
                        .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt, lineJoin: .miter))
                    if let last = points.last {
                        Rectangle()
                            .fill(color)
                            .frame(width: lineWidth * 2, height: lineWidth * 2)
                            .position(last)
                    }
                }
            }
        }
    }

    private func normalizedPoints(in size: CGSize) -> [CGPoint] {
        guard let minV = values.min(), let maxV = values.max(), values.count > 1 else { return [] }
        let range = maxV - minV
        let safeRange = range == 0 ? 1 : range
        let stepX = size.width / CGFloat(values.count - 1)
        let inset: CGFloat = lineWidth * 1.5
        let usableHeight = size.height - inset * 2
        return values.enumerated().map { index, value in
            let x = CGFloat(index) * stepX
            let normalized = (value - minV) / safeRange
            let y = inset + usableHeight * (1 - CGFloat(normalized))
            return CGPoint(x: x, y: y)
        }
    }

    private func linePath(_ points: [CGPoint], closed: Bool = true) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        for point in points.dropFirst() { path.addLine(to: point) }
        if closed, let last = points.last, let firstPoint = points.first {
            path.addLine(to: CGPoint(x: last.x, y: 1000))
            path.addLine(to: CGPoint(x: firstPoint.x, y: 1000))
            path.closeSubpath()
        }
        return path
    }
}

/// A horizontal bar showing a value against a 0...1 fraction.
struct MetricBar: View {
    let fraction: Double
    var color: Color = Theme.accent
    var height: CGFloat = 4

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Theme.accent.opacity(0.12))
                Rectangle()
                    .fill(color)
                    .frame(width: max(height, geo.size.width * clampedFraction))
            }
        }
        .frame(height: height)
    }

    private var clampedFraction: CGFloat {
        CGFloat(min(max(fraction, 0), 1))
    }
}

/// A distribution track with a square marker showing cohort percentile.
struct DistributionBar: View {
    let percentile: Double
    var tint: Color = Theme.accent
    var animatedFrom: Double? = nil

    @State private var displayed: Double

    init(percentile: Double, tint: Color = Theme.accent, animatedFrom: Double? = nil) {
        self.percentile = percentile
        self.tint = tint
        self.animatedFrom = animatedFrom
        _displayed = State(initialValue: animatedFrom ?? percentile)
    }

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let x = width * CGFloat(min(max(displayed, 0.02), 0.98))
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Theme.accent.opacity(0.15))
                    .frame(height: 6)

                Rectangle()
                    .fill(Theme.textTertiary.opacity(0.5))
                    .frame(width: 1, height: 14)
                    .position(x: width * 0.5, y: 7)

                Rectangle()
                    .fill(tint)
                    .frame(width: 8, height: 8)
                    .position(x: x, y: 7)
            }
        }
        .frame(height: 14)
        .onAppear {
            guard animatedFrom != nil else { return }
            withAnimation(.spring(response: 0.9, dampingFraction: 0.72).delay(0.35)) {
                displayed = percentile
            }
        }
    }
}

/// A consistent screen section header.
struct SectionHeader: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(Theme.hudLabel(size: 13))
                .tracking(1.0)
                .foregroundStyle(Theme.textPrimary)
            if let subtitle {
                Text(subtitle.uppercased())
                    .font(Theme.hudCaption(size: 10))
                    .tracking(0.6)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }
}

/// Large screen title used at the top of each tab.
struct ScreenTitle: View {
    let eyebrow: String
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(eyebrow.uppercased())
                .hudEyebrowStyle()
                .foregroundStyle(Theme.accent)
            Text(title.uppercased())
                .font(Theme.hudTitle())
                .foregroundStyle(Theme.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension Date {
    var shortLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return formatter.string(from: self)
    }

    var mediumLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: self)
    }
}

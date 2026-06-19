import SwiftUI

// MARK: - Loading flow

enum ScanLoadingPhase: Equatable {
    case initializing
    case acquiring
    case stacking
    case revealing
    case analyzing
    case complete
}

struct ScanLoadingView: View {
    var onComplete: () -> Void

    private let totalSlices = 100

    // ~13 s slice animation — contour rings, MRI stack, perspective spread, compress
    private let initDelayMs = 500
    private let sliceIntervalMs = 55
    private let postAcquireDelayMs = 250
    private let stackAnimationSeconds = 5.0
    private let stackHoldMs = 600
    private let bodyRevealSeconds = 1.7
    private let organCalloutDelayMs = 700
    private let analysisSteps = 28
    private let analysisStepMs = 40
    private let completeHoldMs = 900

    /// Fixed height for the central media area so the slice grid / body never
    /// reflows as the header and footer text change line counts.
    private let mediaHeight: CGFloat = 480

    @State private var phase: ScanLoadingPhase = .initializing
    @State private var loadedSlices = 0
    @State private var stackProgress: Double = 0
    @State private var analysisProgress: Double = 0
    @State private var statusLine = "Warming the pool of light"
    @State private var detailLine = "Priming half a million sound elements"
    @State private var ringPulse = false
    @State private var bodyRevealProgress: Double = 0
    @State private var organCallout: String?

    var body: some View {
        ZStack {
            GoldenPoolBackdrop()

            scannerBackdrop

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 24)
                    .padding(.top, 12)

                Spacer(minLength: 16)

                ZStack {
                    BodySliceGridView(fillFraction: sliceFillFraction)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .opacity(showsBody ? 0 : 1)

                    if showsBody {
                        ScanRevealBodyView(revealProgress: bodyRevealProgress)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .transition(.opacity)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: mediaHeight)
                .padding(.horizontal, 12)

                Spacer(minLength: 16)

                organTicker
                    .padding(.horizontal, 24)
                    .padding(.bottom, 6)

                footer
                    .padding(.horizontal, 24)
                    .padding(.bottom, 28)
            }
        }
        .onAppear { startSequence() }
    }

    // MARK: - Backdrop

    private var scannerBackdrop: some View {
        ZStack {
            Rectangle()
                .strokeBorder(Theme.stroke.opacity(0.25), lineWidth: 1)
                .frame(width: 280, height: 280)
                .opacity(ringPulse ? 0.6 : 0.3)
        }
        .allowsHitTesting(false)
    }

    private var showsBody: Bool {
        phase == .revealing || phase == .analyzing || phase == .complete
    }

    /// Fraction of the contact-sheet grid revealed — fills cell-by-cell as slices acquire.
    private var sliceFillFraction: Double {
        switch phase {
        case .initializing:
            return 0
        case .acquiring:
            return Double(loadedSlices) / Double(totalSlices)
        case .stacking, .revealing, .analyzing, .complete:
            return 1
        }
    }

    // MARK: - Chrome

    private var header: some View {
        VStack(spacing: 6) {
            Text("FULL BODY SCAN")
                .hudEyebrowStyle()
                .foregroundStyle(Theme.accent)

            Text(statusLine.uppercased())
                .font(Theme.hudTitle(size: 20))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.3), value: statusLine)
        }
        .frame(maxWidth: .infinity)
    }

    private var organTicker: some View {
        ZStack {
            if let organCallout {
                Text(organCallout.uppercased())
                    .font(Theme.hudLabel(size: 12))
                    .tracking(0.6)
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .overlay(Rectangle().strokeBorder(Theme.stroke, lineWidth: 1))
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .id(organCallout)
            }
        }
        .frame(height: 46)
        .animation(.easeInOut(duration: 0.35), value: organCallout)
    }

    /// Progressive organ standings shown while the volume stacks together.
    private func organTickerLines() -> [String] {
        let results = MockData.organResults()
        let byRegion = Dictionary(uniqueKeysWithValues: results.map { ($0.region, $0) })

        func tag(_ status: HealthStatus) -> String {
            switch status {
            case .normal: return ""
            case .watch: return " (watch)"
            case .alert: return " (flagged)"
            }
        }
        func name(_ region: BodyRegion) -> String {
            switch region {
            case .muscles: return "Muscle"
            case .brain: return "Brain"
            default: return region.displayName
            }
        }
        func part(_ region: BodyRegion, withUnit: Bool = false) -> String {
            guard let result = byRegion[region] else { return "" }
            let pct = withUnit ? "\(result.percentileLabel) percentile" : result.percentileLabel
            return "\(name(region)): \(pct)\(tag(result.status))"
        }

        return [
            part(.lungs, withUnit: true),
            "\(part(.lungs)) \u{00B7} \(part(.abdomen))",
            "\(part(.abdomen)) \u{00B7} \(part(.muscles))",
            "\(part(.heart)) \u{00B7} \(part(.skeleton))"
        ]
    }

    private var footer: some View {
        VStack(spacing: 14) {
            HStack(spacing: 16) {
                statBlock(value: "500K", label: "Elements")
                statBlock(value: throughputValue, label: "Per second")
                statBlock(value: phase == .complete ? "Done" : "Live", label: "Status")
            }

            VStack(spacing: 8) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Theme.accent.opacity(0.12))
                        Rectangle()
                            .fill(Theme.accent)
                            .frame(width: geo.size.width * overallProgress)
                    }
                }
                .frame(height: 3)

                Text(detailLine.uppercased())
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .tracking(0.4)
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(2)
                    .frame(height: 30, alignment: .topLeading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentTransition(.opacity)
            }
        }
        .padding(18)
        .overlay(Rectangle().strokeBorder(Theme.stroke, lineWidth: 1))
    }

    private func statBlock(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(Theme.hudData(size: 18))
                .foregroundStyle(Theme.accent)
                .contentTransition(.numericText())
            Text(label.uppercased())
                .hudCaptionStyle()
                .foregroundStyle(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    /// Headline data-density flex — terabytes/sec while sound is being captured.
    private var throughputValue: String {
        switch phase {
        case .initializing, .complete: return "—"
        default: return "~1 TB"
        }
    }

    private var overallProgress: CGFloat {
        switch phase {
        case .initializing: return 0.05
        case .acquiring: return 0.1 + 0.45 * CGFloat(loadedSlices) / CGFloat(totalSlices)
        case .stacking: return 0.55 + 0.2 * CGFloat(stackProgress)
        case .revealing: return 0.75 + 0.1 * CGFloat(bodyRevealProgress)
        case .analyzing: return 0.85 + 0.13 * CGFloat(analysisProgress)
        case .complete: return 1
        }
    }

    // MARK: - Sequence

    private func startSequence() {
        withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
            ringPulse = true
        }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(initDelayMs))
            statusLine = "Listening from every angle"
            detailLine = "Sound elements speaking and listening, like echolocation"
            phase = .acquiring

            let acquireDetails = [
                "Half a million elements speaking and listening",
                "Echoes returning from every angle",
                "Sound crossing skin · fat · muscle · bone",
                "Capturing terabytes of echo data each second",
                "Sweeping the body, head to feet"
            ]
            for i in 1...totalSlices {
                try? await Task.sleep(for: .milliseconds(sliceIntervalMs))
                loadedSlices = i
                let bucket = (i - 1) * acquireDetails.count / totalSlices
                detailLine = acquireDetails[min(bucket, acquireDetails.count - 1)]
            }

            try? await Task.sleep(for: .milliseconds(postAcquireDelayMs))
            statusLine = "Turning sound into shape"
            detailLine = "Reading density: water → skin → fat → muscle → bone"
            phase = .stacking

            let lines = organTickerLines()
            withAnimation(.easeInOut(duration: stackAnimationSeconds)) {
                stackProgress = 1
            }

            try? await Task.sleep(for: .milliseconds(Int(stackAnimationSeconds * 1000) + stackHoldMs))

            organCallout = lines[0]
            try? await Task.sleep(for: .milliseconds(organCalloutDelayMs))
            organCallout = lines[1]
            try? await Task.sleep(for: .milliseconds(organCalloutDelayMs))
            organCallout = nil

            statusLine = "Building volume"
            detailLine = "Reconstructing a sub-millimeter map of your body…"
            phase = .revealing
            bodyRevealProgress = 0
            withAnimation(.easeInOut(duration: bodyRevealSeconds)) {
                bodyRevealProgress = 1
            }
            try? await Task.sleep(for: .milliseconds(Int(bodyRevealSeconds * 1000)))

            statusLine = "Analyzing scan"
            detailLine = "Mapping anatomy · comparing baselines…"
            phase = .analyzing

            organCallout = lines[2]
            for step in 1...analysisSteps {
                try? await Task.sleep(for: .milliseconds(analysisStepMs))
                analysisProgress = Double(step) / Double(analysisSteps)
                if step == analysisSteps / 4 { detailLine = "Detecting soft tissue boundaries…" }
                if step == analysisSteps / 3 { organCallout = lines[3] }
                if step == analysisSteps * 7 / 10 { detailLine = "Running AI segmentation…" }
            }

            statusLine = "Scan complete"
            detailLine = "Just sound and water and 60 seconds · 8 regions mapped"
            organCallout = nil
            phase = .complete

            try? await Task.sleep(for: .milliseconds(completeHoldMs))
            onComplete()
        }
    }
}

#Preview {
    ScanLoadingView(onComplete: {})
}

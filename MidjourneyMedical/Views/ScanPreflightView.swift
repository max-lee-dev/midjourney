import SwiftUI

/// Pre-scan setup ritual the user physically performs before capture:
/// 1. Scan the device QR code  ->  2. Step onto the platform (pressure sensing)
/// ->  3. Hold still through a short countdown  ->  hand off to the body sweep.
struct ScanPreflightView: View {
    var onReady: () -> Void

    private enum PreflightStage {
        case ready
        case scanningCode
        case linked
        case awaitingStep
        case presenceDetected
        case holdStill
    }

    @State private var stage: PreflightStage = .ready
    @State private var countdown = 3
    @State private var loadKg = 0

    // Animation drivers
    @State private var scanLineActive = false
    @State private var viewfinderPulse = false
    @State private var readyGlow = false
    @State private var ringTrim: CGFloat = 1

    private let detectedLoad = 72

    var body: some View {
        ZStack {
            GoldenPoolBackdrop()

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 24)
                    .padding(.top, 16)

                if showsScannerReady {
                    scannerReadyBanner
                        .padding(.horizontal, 24)
                        .padding(.top, 22)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                Spacer(minLength: 24)

                centerStage
                    .frame(height: 260)

                Spacer(minLength: 24)

                bottomSection
                    .padding(.horizontal, 24)
                    .padding(.bottom, 36)
            }
        }
    }

    // MARK: - Bottom section (button morphs into the live status panel)

    @ViewBuilder
    private var bottomSection: some View {
        if stage == .ready {
            readyControls
                .transition(.opacity)
        } else {
            statusPanel
                .transition(.opacity)
        }
    }

    private var readyControls: some View {
        VStack(spacing: 16) {
            Text("Just sound and water and 60 seconds.")
                .font(.system(size: 13, weight: .medium))
                .italic()
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .accessibilityLabel("Just sound and water and sixty seconds")

            beginButton
        }
    }

    private var beginButton: some View {
        Button(action: handleBegin) {
            HStack(spacing: 8) {
                Image(systemName: "viewfinder")
                    .font(.system(size: 15, weight: .semibold))
                Text("BEGIN YOUR SCAN")
                    .font(Theme.hudLabel(size: 14))
                    .tracking(0.8)
            }
            .foregroundStyle(Theme.background)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Theme.accent, in: Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Begin your scan")
    }

    private func handleBegin() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.easeInOut(duration: 0.4)) { stage = .scanningCode }
        startSequence()
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 6) {
            Text("MJ-SCAN ONE")
                .hudEyebrowStyle()
                .foregroundStyle(Theme.accent)

            Text(headerTitle)
                .font(Theme.hudTitle(size: 20))
                .foregroundStyle(Theme.textPrimary)
                .contentTransition(.opacity)
                .animation(.easeInOut(duration: 0.3), value: stage)
        }
        .frame(maxWidth: .infinity)
    }

    private var headerTitle: String {
        switch stage {
        case .ready: return "FULL BODY SCAN"
        case .scanningCode, .linked: return "SCAN DEVICE CODE"
        case .awaitingStep, .presenceDetected: return "STEP INTO THE LIGHT"
        case .holdStill: return "RELAX"
        }
    }

    // MARK: - Scanner-ready banner

    /// Shown once the device is linked and the rig is armed, while we wait for
    /// the user to physically step onto the platform.
    private var showsScannerReady: Bool {
        stage == .awaitingStep || stage == .presenceDetected
    }

    private var scannerReadyBanner: some View {
        Text("SCANNER READY\u{2026}")
            .font(.system(size: 20, weight: .heavy, design: .default))
            .tracking(2.5)
            .foregroundStyle(Theme.accent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .padding(.horizontal, 20)
            .background(Theme.accent.opacity(0.05))
            .overlay(Rectangle().strokeBorder(Theme.accent, lineWidth: 1.5))
            .shadow(color: Theme.accent.opacity(readyGlow ? 0.7 : 0.28), radius: readyGlow ? 18 : 8)
            .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: readyGlow)
    }

    // MARK: - Center stage

    @ViewBuilder
    private var centerStage: some View {
        switch stage {
        case .ready:
            qrViewfinder(animated: false)
                .transition(.opacity)
        case .scanningCode, .linked:
            qrViewfinder(animated: true)
                .transition(.opacity)
        case .awaitingStep, .presenceDetected:
            platformGlyph
                .transition(.opacity)
        case .holdStill:
            countdownGlyph
                .transition(.opacity)
        }
    }

    private func qrViewfinder(animated: Bool) -> some View {
        let isLinked = stage == .linked
        let isIdle = stage == .ready

        return Group {
            if isIdle {
                Button(action: handleBegin) {
                    qrViewfinderContent(animated: false, isLinked: false)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Scan device code")
                .accessibilityHint("Double tap to begin scanning")
            } else {
                qrViewfinderContent(animated: animated, isLinked: isLinked)
            }
        }
        .frame(width: 200, height: 200)
    }

    private func qrViewfinderContent(animated: Bool, isLinked: Bool) -> some View {
        ZStack {
            Image(systemName: "qrcode")
                .font(.system(size: 96, weight: .regular))
                .foregroundStyle(Theme.accent.opacity(isLinked ? 0.18 : (animated ? 0.12 : 0.45)))

            ForEach(0..<4, id: \.self) { corner in
                cornerBracket
                    .rotationEffect(.degrees(Double(corner) * 90))
            }
            .frame(width: 180, height: 180)
            .scaleEffect(animated && viewfinderPulse ? 1.02 : 1)
            .animation(animated ? .easeInOut(duration: 1.2).repeatForever(autoreverses: true) : nil, value: viewfinderPulse)

            if animated && !isLinked {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Theme.accent.opacity(0), Theme.accent, Theme.accent.opacity(0)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 168, height: 2)
                    .offset(y: scanLineActive ? 80 : -80)
                    .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: scanLineActive)
            }

            if isLinked {
                Image(systemName: "checkmark")
                    .font(.system(size: 52, weight: .bold))
                    .foregroundStyle(Theme.accent)
                    .transition(.scale.combined(with: .opacity))
            }
        }
    }

    private var cornerBracket: some View {
        // An L-shaped bracket pinned to the top-leading corner.
        Path { path in
            path.move(to: CGPoint(x: 0, y: 28))
            path.addLine(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: 28, y: 0))
        }
        .stroke(Theme.accent, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        .frame(width: 180, height: 180, alignment: .topLeading)
    }

    private var platformGlyph: some View {
        let isActive = stage == .presenceDetected

        return ZStack {
            // Ring of sound elements — a choir and an audience, listening like a dolphin.
            EcholocationRing(diameter: 190, active: isActive)

            // Platform base
            RoundedRectangle(cornerRadius: 2)
                .fill(Theme.accent.opacity(isActive ? 0.12 : 0.05))
                .frame(width: 180, height: 120)
                .overlay(
                    RoundedRectangle(cornerRadius: 2)
                        .strokeBorder(Theme.accent.opacity(isActive ? 0.9 : 0.4), lineWidth: 1)
                )

            // Footpads
            HStack(spacing: 22) {
                footpad(active: isActive)
                footpad(active: isActive)
            }
        }
        .frame(width: 200, height: 200)
    }

    private func footpad(active: Bool) -> some View {
        Image(systemName: "shoeprints.fill")
            .font(.system(size: 44, weight: .regular))
            .foregroundStyle(active ? Theme.accent : Theme.accent.opacity(0.3))
            .symbolEffect(.bounce, value: active)
    }

    private var countdownGlyph: some View {
        ZStack {
            Circle()
                .stroke(Theme.accent.opacity(0.12), lineWidth: 4)
                .frame(width: 180, height: 180)

            Circle()
                .trim(from: 0, to: ringTrim)
                .stroke(Theme.accent, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .frame(width: 180, height: 180)
                .rotationEffect(.degrees(-90))

            Text("\(countdown)")
                .font(.system(size: 92, weight: .heavy, design: .monospaced))
                .foregroundStyle(Theme.accent)
                .contentTransition(.numericText(countsDown: true))
                .animation(.snappy(duration: 0.3), value: countdown)
        }
        .frame(width: 200, height: 200)
    }

    // MARK: - Status panel

    private var statusPanel: some View {
        VStack(spacing: 14) {
            VStack(spacing: 6) {
                Text(statusTitle)
                    .font(Theme.hudLabel(size: 14))
                    .tracking(0.8)
                    .foregroundStyle(Theme.textPrimary)
                    .contentTransition(.opacity)
                    .animation(.easeInOut(duration: 0.3), value: stage)

                Text(statusDetail)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .tracking(0.4)
                    .foregroundStyle(Theme.textTertiary)
                    .multilineTextAlignment(.center)
                    .contentTransition(.opacity)
                    .animation(.easeInOut(duration: 0.3), value: stage)
            }

            HStack(spacing: 16) {
                preflightStat(value: codeStatus, label: "Code")
                preflightStat(value: platformStatus, label: "Platform")
                preflightStat(value: loadStatus, label: "Load")
            }
        }
        .padding(18)
        .overlay(Rectangle().strokeBorder(Theme.stroke, lineWidth: 1))
    }

    private func preflightStat(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(Theme.hudData(size: 14))
                .foregroundStyle(Theme.accent)
                .contentTransition(.numericText())
            Text(label.uppercased())
                .hudCaptionStyle()
                .foregroundStyle(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private var statusTitle: String {
        switch stage {
        case .ready: return ""
        case .scanningCode: return "SCANNING FOR DEVICE CODE"
        case .linked: return "DEVICE LINKED"
        case .awaitingStep: return "STEP INTO THE POOL OF LIGHT"
        case .presenceDetected: return "PRESENCE DETECTED"
        case .holdStill: return "LOWERING YOU IN…"
        }
    }

    private var statusDetail: String {
        switch stage {
        case .ready: return ""
        case .scanningCode: return "Align the code on the scanner inside the frame"
        case .linked: return "Scanner paired · warming the pool"
        case .awaitingStep: return "Stand on the platform, on the marked footpads"
        case .presenceDetected: return "Good — keep both feet on the pads"
        case .holdStill: return "The platform lowers gently · relax your arms at your sides"
        }
    }

    private var codeStatus: String {
        stage == .scanningCode ? "SEARCHING" : "LINKED"
    }

    private var platformStatus: String {
        switch stage {
        case .ready, .scanningCode, .linked: return "STANDBY"
        case .awaitingStep: return "ACTIVE"
        case .presenceDetected, .holdStill: return "LOADED"
        }
    }

    private var loadStatus: String {
        loadKg > 0 ? "\(loadKg) KG" : "—"
    }

    // MARK: - Timeline

    private func startSequence() {
        scanLineActive = true
        viewfinderPulse = true

        Task { @MainActor in
            // 1. Scan the device QR code
            try? await Task.sleep(for: .milliseconds(2_500))

            // 2. Linked confirmation flash
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            withAnimation(.easeInOut(duration: 0.3)) { stage = .linked }
            try? await Task.sleep(for: .milliseconds(800))

            // 3. Wait for the user to step onto the platform
            withAnimation(.easeInOut(duration: 0.4)) { stage = .awaitingStep }
            readyGlow = true
            try? await Task.sleep(for: .milliseconds(3_000))

            // 4. Pressure detected
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            withAnimation(.easeInOut(duration: 0.3)) { stage = .presenceDetected }
            withAnimation(.easeOut(duration: 0.6)) { loadKg = detectedLoad }
            try? await Task.sleep(for: .milliseconds(1_000))

            // 5. Hold-still countdown (3 -> 2 -> 1)
            withAnimation(.easeInOut(duration: 0.4)) { stage = .holdStill }
            ringTrim = 1

            for value in stride(from: 3, through: 1, by: -1) {
                countdown = value
                UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                withAnimation(.linear(duration: 1.0)) {
                    ringTrim = CGFloat(value - 1) / 3.0
                }
                try? await Task.sleep(for: .milliseconds(1_000))
            }

            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            onReady()
        }
    }
}

#Preview {
    ScanPreflightView(onReady: {})
        .preferredColorScheme(.dark)
}

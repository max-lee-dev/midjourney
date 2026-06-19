import SwiftUI
import SceneKit
import simd

// MARK: - HUD wrapper

/// Act 1 of a full scan: a live point-cloud body with a glowing plane sweeping
/// bottom-to-top, lighting up the figure as it passes.
struct BodyScanSweepView: View {
    var onComplete: () -> Void

    @State private var progress: Double = 0
    @State private var finished = false

    private let yMin = -1.02
    private let yMax = 0.98
    private let bodyHeightCm = 190.0
    /// Simulated scan length shown on the HUD (a full minute).
    private let displayScanDurationSeconds = 60.0
    /// Real wait time — playback runs at 2× so 60 s of scan completes in 30 s.
    private let actualScanDurationSeconds = 30.0

    private var regionsByHeight: [BodyRegion] {
        BodyRegion.allCases.sorted { $0.anchor3D.y < $1.anchor3D.y }
    }

    private var currentScanY: Double { yMin + (yMax - yMin) * progress }

    private var currentRegion: BodyRegion? {
        regionsByHeight.last { Double($0.anchor3D.y) <= currentScanY }
    }

    private var secondsRemaining: Double {
        max(0, displayScanDurationSeconds * (1 - progress))
    }

    var body: some View {
        ZStack {
            GoldenPoolBackdrop()

            ScanningBodyView(
                duration: actualScanDurationSeconds,
                onProgress: { progress = $0 },
                onComplete: { finish() }
            )
            .ignoresSafeArea()

            hud
        }
    }

    private var hud: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("FULL BODY SCAN")
                        .hudEyebrowStyle()
                        .foregroundStyle(Theme.accent)
                    Text("SCAN IN PROGRESS \u{2026}")
                        .font(Theme.hudLabel(size: 13))
                        .tracking(1.0)
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                Button(action: finish) {
                    Text("SKIP")
                        .font(Theme.hudLabel(size: 12))
                        .tracking(0.8)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)

            Spacer()

            VStack(spacing: 16) {
                if let region = currentRegion {
                    Text("CAPTURING: \(region.displayName.uppercased())")
                        .font(Theme.hudLabel(size: 12))
                        .tracking(0.8)
                        .foregroundStyle(Theme.textSecondary)
                        .contentTransition(.opacity)
                }

                HUDPanel(progress: CGFloat(progress)) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(String(format: "%.2f", secondsRemaining))
                            .font(.system(size: 42, weight: .heavy, design: .default))
                            .foregroundStyle(Theme.accent)
                            .contentTransition(.numericText())
                            .monospacedDigit()

                        Text("SECONDS REMAINING")
                            .font(Theme.hudLabel(size: 14))
                            .tracking(1.4)
                            .foregroundStyle(Theme.textPrimary)

                        Text("UNTIL SCAN COMPLETE")
                            .font(Theme.hudCaption(size: 9))
                            .tracking(0.8)
                            .foregroundStyle(Theme.textTertiary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .overlay(alignment: .trailing) { progressRail }
    }

    private var progressRail: some View {
        GeometryReader { geo in
            let height = geo.size.height
            ZStack(alignment: .bottom) {
                Rectangle()
                    .fill(Theme.accent.opacity(0.12))
                Rectangle()
                    .fill(Theme.accent)
                    .frame(height: max(4, height * progress))
            }
            .frame(width: 3)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(width: 3)
        .padding(.trailing, 12)
        .padding(.vertical, 120)
    }

    private func finish() {
        guard !finished else { return }
        finished = true
        onComplete()
    }
}

// MARK: - SceneKit scanning view

private final class ScanSCNView: SCNView {
    var onBoundsChange: ((ScanSCNView) -> Void)?

    override func layoutSubviews() {
        super.layoutSubviews()
        onBoundsChange?(self)
    }
}

struct ScanningBodyView: UIViewRepresentable {
    var duration: Double = 30.0
    var onProgress: (Double) -> Void
    var onComplete: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> SCNView {
        let view = ScanSCNView()
        view.onBoundsChange = { [weak coordinator = context.coordinator] scnView in
            coordinator?.syncAspectRatio(from: scnView)
        }
        view.scene = context.coordinator.buildScene()
        view.backgroundColor = .clear
        view.isOpaque = false
        view.antialiasingMode = .multisampling2X
        view.allowsCameraControl = false
        view.autoenablesDefaultLighting = false
        view.rendersContinuously = true
        view.pointOfView = context.coordinator.cameraNode
        view.delegate = context.coordinator
        context.coordinator.scnView = view
        context.coordinator.syncAspectRatio(from: view)
        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        context.coordinator.syncAspectRatio(from: uiView)
    }

    final class Coordinator: NSObject, SCNSceneRendererDelegate {
        let parent: ScanningBodyView
        weak var scnView: SCNView?
        let cameraNode: SCNNode
        private let containerNode = SCNNode()
        private var bodyGeometry: SCNGeometry?
        private var planeNode: SCNNode?
        private var glowNode: SCNNode?
        private var startTime: TimeInterval = 0
        private var finished = false

        /// Smoothed camera state for fluid motion.
        private var currentCamPos = SIMD3<Float>(0, -0.08, 3.35)
        private var currentLookAt = SIMD3<Float>(0, -0.02, 0)
        private var cachedAspect: Float = 9.0 / 19.0

        let yMin: Float = -1.02
        let yMax: Float = 0.98

        /// Approximate body bounds in point-cloud space (head ~+0.92, feet ~-0.95, arms ~±0.30).
        private let bodyCenterY: Float = -0.02
        private let bodySpanY: Float = 1.92
        private let bodySpanX: Float = 0.66

        private static let revealModifier = """
        #pragma arguments
        float scanY;
        #pragma body
        float d = scanY - _geometry.position.y;
        float revealed = smoothstep(-0.02, 0.06, d);
        float band = exp(-pow((_geometry.position.y - scanY) / 0.045, 2.0));
        _geometry.color.rgb = mix(_geometry.color.rgb, float3(1.0, 0.72, 0.0), clamp(band * 0.7, 0.0, 1.0));
        _geometry.color.rgb *= mix(0.16, 1.0, revealed) + band * 0.9;
        """

        init(_ parent: ScanningBodyView) {
            self.parent = parent
            let camera = SCNCamera()
            camera.fieldOfView = 42
            camera.zNear = 0.01
            camera.zFar = 100
            cameraNode = SCNNode()
            cameraNode.camera = camera
            cameraNode.position = SCNVector3(currentCamPos.x, currentCamPos.y, currentCamPos.z)
            super.init()
        }

        func syncAspectRatio(from view: SCNView) {
            let width = view.bounds.width
            let height = max(view.bounds.height, 1)
            cachedAspect = Float(width / height)
        }

        func buildScene() -> SCNScene {
            let scene = SCNScene()
            scene.background.contents = UIColor.clear

            let geometry = BodyPointCloud.build(statuses: [:])
            geometry.setValue(NSNumber(value: yMin), forKey: "scanY")
            geometry.shaderModifiers = [.geometry: Self.revealModifier]
            bodyGeometry = geometry

            let bodyNode = SCNNode(geometry: geometry)
            containerNode.addChildNode(bodyNode)

            // Slightly scale down so arms stay in frame during orbit.
            containerNode.scale = SCNVector3(0.90, 0.90, 0.90)

            let slab = SCNBox(width: 0.66, height: 0.005, length: 0.36, chamferRadius: 0)
            let slabMat = SCNMaterial()
            slabMat.lightingModel = .constant
            slabMat.diffuse.contents = UIColor.clear
            slabMat.emission.contents = UIColor(red: 1.0, green: 0.72, blue: 0.0, alpha: 1)
            slabMat.blendMode = .add
            slabMat.writesToDepthBuffer = false
            slabMat.isDoubleSided = true
            slab.materials = [slabMat]
            let plane = SCNNode(geometry: slab)
            plane.position = SCNVector3(0, yMin, 0)
            containerNode.addChildNode(plane)
            planeNode = plane

            let glow = SCNPlane(width: 0.95, height: 0.22)
            let glowMat = SCNMaterial()
            glowMat.lightingModel = .constant
            glowMat.diffuse.contents = UIColor.clear
            glowMat.emission.contents = UIColor(red: 1.0, green: 0.65, blue: 0.0, alpha: 0.22)
            glowMat.blendMode = .add
            glowMat.writesToDepthBuffer = false
            glowMat.isDoubleSided = true
            glow.materials = [glowMat]
            let glowNode = SCNNode(geometry: glow)
            glowNode.position = SCNVector3(0, yMin, 0.02)
            containerNode.addChildNode(glowNode)
            self.glowNode = glowNode

            scene.rootNode.addChildNode(containerNode)
            scene.rootNode.addChildNode(cameraNode)
            return scene
        }

        func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
            if startTime == 0 { startTime = time }
            let elapsed = time - startTime
            let progress = min(1.0, elapsed / max(0.1, parent.duration))
            let scanY = yMin + (yMax - yMin) * Float(progress)

            bodyGeometry?.setValue(NSNumber(value: scanY), forKey: "scanY")
            planeNode?.position.y = scanY
            glowNode?.position.y = scanY
            let planeVisible = progress > 0.001 && progress < 0.999
            planeNode?.opacity = planeVisible ? 1 : 0
            glowNode?.opacity = planeVisible ? 1 : 0

            updateCamera(progress: Float(progress), scanY: scanY, elapsed: Float(elapsed))

            DispatchQueue.main.async { self.parent.onProgress(progress) }

            if progress >= 1 && !finished {
                finished = true
                DispatchQueue.main.async { self.parent.onComplete() }
            }
        }

        /// Orbits the camera around the figure and tracks the scan band as it rises.
        private func updateCamera(progress: Float, scanY: Float, elapsed: Float) {
            let aspect = cachedAspect
            let fovDegrees = Float(cameraNode.camera?.fieldOfView ?? 42)
            let vFOV = fovDegrees * Float.pi / 180
            let halfV = vFOV * 0.5
            let halfH = atan(tan(halfV) * aspect)

            let padding: Float = 1.22
            let distForHeight = (bodySpanY * padding) / (2 * tan(halfV))
            let distForWidth = (bodySpanX * padding) / (2 * tan(halfH))
            let baseDistance = max(distForHeight, distForWidth)

            // Slow orbit + gentle bob — camera flows, body stays upright.
            let orbit = sin(elapsed * 0.28) * 0.32 + progress * 0.22
            let bob = sin(elapsed * 0.19) * 0.025
            let dolly = sin(elapsed * 0.13) * 0.08

            // Look-at rises with the scan; bias upward so the figure clears the bottom HUD.
            let hudLift: Float = 0.14
            let lookBlend = 0.55 + progress * 0.25
            let lookY = lerp(bodyCenterY + hudLift * 0.35, scanY, lookBlend)
            let targetLookAt = SIMD3<Float>(0, lookY, 0)

            let lateral = sin(orbit) * baseDistance * 0.11
            let depthSwing = cos(orbit) * baseDistance * 0.07
            let targetCam = SIMD3<Float>(
                lateral,
                lookY + 0.04 + bob,
                baseDistance + depthSwing + dolly
            )

            // Exponential smoothing for a natural, weighted feel.
            let smooth: Float = 0.07
            currentLookAt = lerpSIMD3(currentLookAt, targetLookAt, smooth)
            currentCamPos = lerpSIMD3(currentCamPos, targetCam, smooth)

            cameraNode.position = SCNVector3(currentCamPos.x, currentCamPos.y, currentCamPos.z)
            cameraNode.look(at: SCNVector3(currentLookAt.x, currentLookAt.y, currentLookAt.z))
        }
    }
}

private func lerp(_ a: Float, _ b: Float, _ t: Float) -> Float { a + (b - a) * t }
private func lerpSIMD3(_ a: SIMD3<Float>, _ b: SIMD3<Float>, _ t: Float) -> SIMD3<Float> { a + (b - a) * t }

#Preview {
    BodyScanSweepView(onComplete: {})
        .preferredColorScheme(.dark)
}

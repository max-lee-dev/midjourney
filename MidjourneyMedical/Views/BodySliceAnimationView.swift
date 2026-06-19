import SwiftUI
import SceneKit
import simd

// MARK: - Cross-section data

private struct BodyCrossSection {
    let y: Float
    let radiusX: Float
    let radiusZ: Float
    let texture: UIImage
}

private enum BodySliceGenerator {
    static let sliceCount = 44
    static let yMin: Float = -0.55
    static let yMax: Float = 0.55

    /// Smooth torso silhouette half-width (lateral / X) at normalized height
    /// `t` (0 = hips, 1 = shoulders). Catmull-Rom through hand-tuned control
    /// widths so the stack reads as a clean chest -> waist -> hips torso.
    private static let widthControls: [(t: Float, w: Float)] = [
        (0.00, 0.255),   // hips
        (0.18, 0.225),   // lower waist
        (0.35, 0.200),   // narrowest waist
        (0.55, 0.260),   // lower ribs
        (0.80, 0.310),   // chest / shoulders (widest)
        (1.00, 0.220)    // neck taper
    ]

    static func buildSections() -> [BodyCrossSection] {
        var sections: [BodyCrossSection] = []
        sections.reserveCapacity(sliceCount)

        for index in 0..<sliceCount {
            let t = Float(index) / Float(max(sliceCount - 1, 1))
            let y = yMin + (yMax - yMin) * t
            let radiusX = silhouetteWidth(at: t)
            let radiusZ = radiusX * 0.62
            let texture = renderSliceTexture(radiusX: radiusX, radiusZ: radiusZ, seed: index)
            sections.append(BodyCrossSection(y: y, radiusX: radiusX, radiusZ: radiusZ, texture: texture))
        }
        return sections
    }

    private static func silhouetteWidth(at t: Float) -> Float {
        let clamped = min(max(t, 0), 1)
        // Find the control segment containing `clamped`.
        var lower = 0
        for i in 0..<(widthControls.count - 1) where widthControls[i].t <= clamped {
            lower = i
        }
        let upper = min(lower + 1, widthControls.count - 1)
        let p0 = widthControls[max(lower - 1, 0)]
        let p1 = widthControls[lower]
        let p2 = widthControls[upper]
        let p3 = widthControls[min(upper + 1, widthControls.count - 1)]

        let span = max(p2.t - p1.t, 0.0001)
        let localT = (clamped - p1.t) / span
        return catmullRom(p0.w, p1.w, p2.w, p3.w, localT)
    }

    private static func catmullRom(_ p0: Float, _ p1: Float, _ p2: Float, _ p3: Float, _ t: Float) -> Float {
        let t2 = t * t
        let t3 = t2 * t
        return 0.5 * (
            (2 * p1) +
            (-p0 + p2) * t +
            (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 +
            (-p0 + 3 * p1 - 3 * p2 + p3) * t3
        )
    }

    // MARK: - Procedural MRI texture

    private static func renderSliceTexture(radiusX: Float, radiusZ: Float, seed: Int) -> UIImage {
        let size = 160
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        return renderer.image { context in
            let cg = context.cgContext
            cg.setFillColor(UIColor.black.cgColor)
            cg.fill(CGRect(x: 0, y: 0, width: size, height: size))

            let center = CGFloat(size) * 0.5
            let scale = CGFloat(size) * 0.42 / max(CGFloat(max(radiusX, radiusZ)), 0.01)
            let halfW = CGFloat(radiusX) * scale
            let halfH = CGFloat(radiusZ) * scale

            let ellipseRect = CGRect(
                x: center - halfW,
                y: center - halfH,
                width: halfW * 2,
                height: halfH * 2
            )

            // Clip all interior fill to the ellipse silhouette.
            cg.saveGState()
            cg.addEllipse(in: ellipseRect)
            cg.clip()

            var rng = SliceRNG(seed: UInt64(bitPattern: Int64(seed &* 2654435761 &+ 1013904223)))

            // Base tissue fill — dim grey interior.
            cg.setFillColor(UIColor(white: 0.16, alpha: 1.0).cgColor)
            cg.fill(ellipseRect)

            // Grayscale speckle for an MRI-like texture.
            let speckleCount = 220
            for _ in 0..<speckleCount {
                let dx = Float.random(in: -1...1, using: &rng)
                let dz = Float.random(in: -1...1, using: &rng)
                guard dx * dx + dz * dz <= 1 else { continue }
                let tone = Float.random(in: 0.22...0.78, using: &rng)
                let px = center + CGFloat(dx) * halfW
                let py = center + CGFloat(dz) * halfH
                let dot = CGFloat(tone) * 2.6 + 0.8
                cg.setFillColor(UIColor(white: CGFloat(tone), alpha: 0.7).cgColor)
                cg.fillEllipse(in: CGRect(x: px - dot * 0.5, y: py - dot * 0.5, width: dot, height: dot))
            }

            // A few soft organ-like lobes.
            for _ in 0..<5 {
                let ox = Float.random(in: -0.55...0.55, using: &rng)
                let oz = Float.random(in: -0.45...0.45, using: &rng)
                let lobeR = Float.random(in: 0.06...0.18, using: &rng)
                let tone = Float.random(in: 0.35...0.72, using: &rng)
                let px = center + CGFloat(ox) * halfW
                let py = center + CGFloat(oz) * halfH
                let r = CGFloat(lobeR) * scale
                cg.setFillColor(UIColor(white: CGFloat(tone), alpha: 0.32).cgColor)
                cg.fillEllipse(in: CGRect(x: px - r, y: py - r, width: r * 2, height: r * 2))
            }
            cg.restoreGState()

            // Bright rim glow (unclipped so the edge blooms outward).
            cg.setStrokeColor(UIColor(white: 1.0, alpha: 0.95).cgColor)
            cg.setLineWidth(2.2)
            cg.strokeEllipse(in: ellipseRect.insetBy(dx: 1, dy: 1))

            cg.setStrokeColor(UIColor(white: 1.0, alpha: 0.32).cgColor)
            cg.setLineWidth(5)
            cg.strokeEllipse(in: ellipseRect.insetBy(dx: -1, dy: -1))
        }
    }
}

private struct SliceRNG: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 0x9E3779B9 : seed }
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}

// MARK: - SwiftUI wrapper

/// Cinematic slice-stack animation — glowing contour rings drop in and stack on
/// top of each other to build a torso, then fill with MRI cross-section texture.
struct BodySliceAnimationView: UIViewRepresentable {
    var progress: Double

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
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
        context.coordinator.apply(progress: progress)
        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        context.coordinator.apply(progress: progress)
    }

    // MARK: - SceneKit coordinator

    final class Coordinator: NSObject, SCNSceneRendererDelegate {
        weak var scnView: SCNView?
        let cameraNode = SCNNode()
        private let stackRoot = SCNNode()

        /// Constant 3/4 pitch so stacked slices read as discs with visible interiors.
        private let stackTilt: Float = 0.21

        private struct SliceNode {
            let index: Int
            let contourRing: SCNNode
            let texturedPlane: SCNNode
            let section: BodyCrossSection
        }

        private var slices: [SliceNode] = []
        private var lastProgress: Double = -1

        private let cameraRest = SCNVector3(0, 0.02, 2.7)
        private let cameraLookAt = SCNVector3(0, 0, 0)

        func buildScene() -> SCNScene {
            let scene = SCNScene()
            scene.background.contents = UIColor.clear

            let sections = BodySliceGenerator.buildSections()
            slices = sections.enumerated().map { index, section in
                SliceNode(
                    index: index,
                    contourRing: makeContourRing(section: section),
                    texturedPlane: makeTexturedPlane(section: section),
                    section: section
                )
            }

            for slice in slices {
                stackRoot.addChildNode(slice.contourRing)
                stackRoot.addChildNode(slice.texturedPlane)
            }

            stackRoot.eulerAngles = SCNVector3(stackTilt, 0, 0)
            scene.rootNode.addChildNode(stackRoot)

            let camera = SCNCamera()
            camera.fieldOfView = 42
            camera.zNear = 0.01
            camera.zFar = 100
            cameraNode.camera = camera
            cameraNode.position = cameraRest
            cameraNode.look(at: cameraLookAt)
            scene.rootNode.addChildNode(cameraNode)

            return scene
        }

        func apply(progress: Double) {
            guard abs(progress - lastProgress) > 0.0005 else { return }
            lastProgress = progress
            updateAnimation(progress: progress)
        }

        func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
            BodySceneIdleMotion.applyCameraPan(
                to: cameraNode,
                basePosition: cameraRest,
                lookAt: cameraLookAt,
                at: time,
                phase: 0.2
            )
        }

        // MARK: - Node builders

        private func makeContourRing(section: BodyCrossSection) -> SCNNode {
            let baseRadius = max(section.radiusX, section.radiusZ)
            let ring = SCNTorus(ringRadius: CGFloat(baseRadius), pipeRadius: 0.0022)
            let material = SCNMaterial()
            material.lightingModel = .constant
            material.diffuse.contents = UIColor.white
            material.emission.contents = UIColor(white: 1.0, alpha: 0.95)
            material.blendMode = .add
            material.writesToDepthBuffer = false
            material.isDoubleSided = true
            ring.materials = [material]

            let node = SCNNode(geometry: ring)
            node.scale = SCNVector3(section.radiusX / baseRadius, 1, section.radiusZ / baseRadius)
            node.position = SCNVector3(0, section.y, 0)
            node.opacity = 0
            return node
        }

        private func makeTexturedPlane(section: BodyCrossSection) -> SCNNode {
            let plane = SCNPlane(
                width: CGFloat(section.radiusX * 2.05),
                height: CGFloat(section.radiusZ * 2.05)
            )
            let material = SCNMaterial()
            material.lightingModel = .constant
            material.diffuse.contents = section.texture
            material.emission.contents = section.texture
            material.blendMode = .alpha
            material.isDoubleSided = true
            material.writesToDepthBuffer = true
            plane.materials = [material]

            let node = SCNNode(geometry: plane)
            node.position = SCNVector3(0, section.y, 0)
            node.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)
            node.opacity = 0
            return node
        }

        // MARK: - Animation phases

        private func updateAnimation(progress: Double) {
            let p = min(max(progress, 0), 1)

            // Slices drop in + stack bottom -> top, then fill with MRI texture.
            let buildPhase = smoothStep(p, from: 0, to: 0.6)
            let fillPhase = smoothStep(p, from: 0.55, to: 0.9)

            let count = max(slices.count - 1, 1)
            for slice in slices {
                let sliceT = Double(slice.index) / Double(count)

                // Staggered reveal: lower slices land first.
                let landed = staggered(phase: buildPhase, threshold: sliceT)
                let filled = staggered(phase: fillPhase, threshold: sliceT)

                // Drop-in: start above the resting position, ease down onto the stack.
                let dropOffset = Float(1 - landed) * 0.45
                let restingY = slice.section.y
                let y = restingY + dropOffset
                let position = SCNVector3(0, y, 0)

                slice.contourRing.position = position
                slice.texturedPlane.position = position

                // Ring is bright as it lands, then fades as the texture fills in.
                let ringOpacity = landed * (1 - filled)
                let textureOpacity = filled

                slice.contourRing.opacity = CGFloat(ringOpacity)
                slice.texturedPlane.opacity = CGFloat(textureOpacity)

                slice.contourRing.isHidden = ringOpacity < 0.02
                slice.texturedPlane.isHidden = textureOpacity < 0.02
            }
        }

        private func staggered(phase: Double, threshold: Double) -> Double {
            // Each slice gets a short window; +0.12 lead keeps the wave continuous.
            let window = 0.18
            let t = min(max((phase - threshold * (1 - window) + 0.0) / window, 0), 1)
            return t * t * (3 - 2 * t)
        }
    }
}

// MARK: - Helpers

private func smoothStep(_ value: Double, from start: Double, to end: Double) -> Double {
    guard end > start else { return value >= end ? 1 : 0 }
    let t = min(max((value - start) / (end - start), 0), 1)
    return t * t * (3 - 2 * t)
}

#Preview {
    BodySliceAnimationPreview()
        .preferredColorScheme(.dark)
}

private struct BodySliceAnimationPreview: View {
    @State private var progress = 0.0

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            BodySliceAnimationView(progress: progress)
                .ignoresSafeArea()
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 13)) {
                progress = 1
            }
        }
    }
}

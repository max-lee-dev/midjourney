import SwiftUI
import SceneKit
import simd

// MARK: - Point cloud from a real human mesh

/// Loads a dense point cloud pre-sampled from a realistic human body mesh
/// (CC0 male base mesh, surface-sampled offline into `body_points.bin`) and
/// colors each point by proximity to a region's health status.
enum BodyPointCloud {

    /// Raw point samples used for slice reconstruction and other derived geometry.
    static func rawPoints() -> [SIMD3<Float>] {
        let raw = loadPoints()
        return raw.isEmpty ? generateProcedural() : raw
    }

    static func build(statuses: [BodyRegion: HealthStatus], focused: BodyRegion? = nil, tintStrength: Float = 1.0, colorful: Bool = false) -> SCNGeometry {
        var raw = loadPoints()
        if raw.isEmpty { raw = generateProcedural() }

        let tints: [(region: BodyRegion, center: SIMD3<Float>, color: SIMD3<Float>)] = BodyRegion.allCases.map {
            ($0, .init($0.anchor3D), statusColor(statuses[$0] ?? .normal))
        }

        var positions: [SCNVector3] = []
        var colors: [Float] = []
        positions.reserveCapacity(raw.count)
        colors.reserveCapacity(raw.count * 3)

        for p in raw {
            positions.append(SCNVector3(p.x, p.y, p.z))
            let c = etherealColor(for: p, tints: tints, focused: focused, tintStrength: tintStrength, colorful: colorful)
            colors.append(c.x); colors.append(c.y); colors.append(c.z)
        }
        return makeGeometry(positions: positions, colors: colors, colorful: colorful)
    }

    /// Builds an anatomically-proportioned human point cloud in code
    /// (deterministic), used when no pre-sampled `body_points.bin` is present in
    /// the bundle. Points are sampled on the *surface* of tapered elliptical
    /// limbs and ellipsoids (rather than filling random volumes) so the figure
    /// reads as a clean, dense scan rather than a fuzzy blob. Matches the app's
    /// coordinate space: y up (head ~+0.96, feet ~-0.95), x lateral, z
    /// front/back (kept shallow so the figure reads as a body).
    static func generateProcedural() -> [SIMD3<Float>] {
        var rng = SeededGenerator(seed: 0x5CA1AB1E)
        var points: [SIMD3<Float>] = []
        points.reserveCapacity(50000)

        // Surface of a tapered tube between `a` and `b`. `rA`/`rB` are the
        // circular cross-section radii at each end; `widthScale`/`depthScale`
        // stretch the ring into an ellipse along world x (lateral) and z
        // (front/back). A small inward `jitter` gives the shell organic depth.
        func limb(
            from a: SIMD3<Float>,
            to b: SIMD3<Float>,
            rA: Float,
            rB: Float,
            widthScale: Float = 1,
            depthScale: Float = 1,
            jitter: Float = 0.006,
            count: Int
        ) {
            let axis = b - a
            let len = simd_length(axis)
            let dir = len > 1e-5 ? axis / len : SIMD3<Float>(0, 1, 0)
            let helper: SIMD3<Float> = abs(dir.y) < 0.99 ? SIMD3(0, 1, 0) : SIMD3(1, 0, 0)
            let e1 = simd_normalize(simd_cross(helper, dir))
            let e2 = simd_cross(dir, e1)

            for _ in 0..<count {
                let t = Float.random(in: 0...1, using: &rng)
                let center = a + dir * (len * t)
                let r = rA + (rB - rA) * t
                let u = Float.random(in: 0...(2 * .pi), using: &rng)
                var p = center + e1 * (cos(u) * r) + e2 * (sin(u) * r)
                p.x += (p.x - center.x) * (widthScale - 1)
                p.z += (p.z - center.z) * (depthScale - 1)
                let outward = simd_normalize(p - center)
                p += outward * Float.random(in: -jitter...jitter, using: &rng)
                points.append(p)
            }
        }

        // Surface of an ellipsoid centered at `center` with per-axis radii.
        func ellipsoid(
            center: SIMD3<Float>,
            rx: Float,
            ry: Float,
            rz: Float,
            jitter: Float = 0.005,
            count: Int
        ) {
            for _ in 0..<count {
                let cy = Float.random(in: -1...1, using: &rng)
                let a = Float.random(in: 0...(2 * .pi), using: &rng)
                let ring = (1 - cy * cy).squareRoot()
                let n = SIMD3<Float>(ring * cos(a), cy, ring * sin(a))
                var p = center + SIMD3(n.x * rx, n.y * ry, n.z * rz)
                p += n * Float.random(in: -jitter...jitter, using: &rng)
                points.append(p)
            }
        }

        // Head + neck
        ellipsoid(center: SIMD3(0, 0.84, 0.02), rx: 0.10, ry: 0.125, rz: 0.108, count: 4500)
        limb(from: SIMD3(0, 0.74, 0.015), to: SIMD3(0, 0.60, 0.0), rA: 0.05, rB: 0.062, depthScale: 0.92, count: 1300)

        // Shoulders (deltoid caps) + tapered torso (wide chest -> narrow waist)
        ellipsoid(center: SIMD3(0.195, 0.575, 0.0), rx: 0.075, ry: 0.07, rz: 0.072, count: 1400)
        ellipsoid(center: SIMD3(-0.195, 0.575, 0.0), rx: 0.075, ry: 0.07, rz: 0.072, count: 1400)
        limb(from: SIMD3(0, 0.585, 0), to: SIMD3(0, 0.02, 0), rA: 0.155, rB: 0.115, widthScale: 1.30, depthScale: 0.74, count: 9500)

        // Pelvis / hips
        limb(from: SIMD3(0, 0.04, 0), to: SIMD3(0, -0.15, 0), rA: 0.122, rB: 0.128, widthScale: 1.22, depthScale: 0.70, count: 3400)

        // Arms (upper -> forearm), slightly out from the torso, tapered
        func arm(side: Float) {
            limb(from: SIMD3(side * 0.205, 0.55, 0), to: SIMD3(side * 0.255, 0.20, 0.01), rA: 0.058, rB: 0.047, count: 2600)
            limb(from: SIMD3(side * 0.255, 0.20, 0.01), to: SIMD3(side * 0.288, -0.16, 0.015), rA: 0.046, rB: 0.034, count: 2200)
            ellipsoid(center: SIMD3(side * 0.298, -0.235, 0.02), rx: 0.05, ry: 0.075, rz: 0.03, count: 750)
        }
        arm(side: 1)
        arm(side: -1)

        // Legs (thigh -> calf), tapered, with forward-pointing feet
        func leg(side: Float) {
            limb(from: SIMD3(side * 0.095, -0.12, 0), to: SIMD3(side * 0.105, -0.52, 0), rA: 0.10, rB: 0.072, depthScale: 0.92, count: 3900)
            limb(from: SIMD3(side * 0.105, -0.52, 0), to: SIMD3(side * 0.108, -0.91, 0), rA: 0.07, rB: 0.044, depthScale: 0.9, count: 3100)
            limb(from: SIMD3(side * 0.108, -0.93, 0.0), to: SIMD3(side * 0.108, -0.95, 0.13), rA: 0.05, rB: 0.038, count: 900)
        }
        leg(side: 1)
        leg(side: -1)

        return points
    }

    /// Reads packed little-endian Float32 (x,y,z) triples from the bundle.
    private static func loadPoints() -> [SIMD3<Float>] {
        guard let url = Bundle.main.url(forResource: "body_points", withExtension: "bin"),
              let data = try? Data(contentsOf: url) else {
            return []
        }
        let count = data.count / (MemoryLayout<Float32>.size * 3)
        var result = [SIMD3<Float>]()
        result.reserveCapacity(count)
        data.withUnsafeBytes { buffer in
            let floats = buffer.bindMemory(to: Float32.self)
            for i in 0..<count {
                result.append(SIMD3(floats[i * 3], floats[i * 3 + 1], floats[i * 3 + 2]))
            }
        }
        return result
    }

    // MARK: Coloring

    /// Front-lit volumetric gray — points facing the camera (+z) read brightest,
    /// the back falls into shadow, and a soft rim keeps the lateral silhouette
    /// crisp. Gives the dense shell a sense of solid, lit 3D form.
    private static func etherealColor(
        for p: SIMD3<Float>,
        tints: [(region: BodyRegion, center: SIMD3<Float>, color: SIMD3<Float>)],
        focused: BodyRegion? = nil,
        tintStrength: Float = 1.0,
        colorful: Bool = false
    ) -> SIMD3<Float> {
        let base = colorful ? gradientColor(for: p) : SIMD3<Float>(0.66, 0.70, 0.76)

        // Keep the whole figure present, only gently dimming the extremities.
        let vertical = 0.82 + 0.18 * (1 - min(1, abs(p.y - 0.02) / 0.95))
        // Key light from the front: the camera-facing surface is brightest. In
        // colorful mode the floor is lifted so the back of the figure keeps its
        // saturation as the body spins (instead of falling into shadow).
        let front = colorful
            ? 0.55 + 0.45 * smoothstep(-0.14, 0.14, p.z)
            : 0.30 + 0.70 * smoothstep(-0.14, 0.14, p.z)
        // Subtle rim on the outer silhouette so the body's outline stays sharp.
        let rim = 0.12 * smoothstep(0.24, 0.33, abs(p.x))
        let shimmer = 0.97 + 0.03 * sin(p.y * 24 + p.x * 15 + p.z * 11)
        let ceiling: Float = colorful ? 1.0 : 0.94
        let brightness = min(ceiling, (front * vertical + rim) * shimmer * 0.82)

        var color = base * brightness

        // Strong tints widen the reach of each region and lift the saturation so
        // every region reads in its status color simultaneously (ambient view).
        let boosted = tintStrength > 1.0
        let influenceRadius: Float = boosted ? 0.20 : 0.14
        let baseWeight: Float = 0.22 * tintStrength
        let mixAmount: Float = boosted ? 0.62 : 0.35

        var strongest: Float = 0
        for tint in tints {
            let d = simd_distance(p, tint.center)
            var influence = max(0, 1 - d / influenceRadius)
            var weight = influence * influence * baseWeight

            if let focused {
                if tint.region == focused {
                    influence = max(influence, max(0, 1 - d / 0.24))
                    weight = influence * influence * 0.62
                } else {
                    weight *= 0.28
                }
            }

            if weight > strongest {
                strongest = weight
                let amount = focused == tint.region ? 0.55 : mixAmount
                color = mix(color, tint.color * amount, min(weight, 0.95))
            }
        }
        return color
    }

    /// Vivid vertical gradient (feet -> head) for the colorful scan look:
    /// magenta -> violet -> blue -> cyan/teal. `p.y` runs ~-0.95 (feet) to
    /// ~0.96 (head); a gentle lateral hue shift adds richness across the body.
    private static func gradientColor(for p: SIMD3<Float>) -> SIMD3<Float> {
        let stops: [SIMD3<Float>] = [
            SIMD3(0.85, 0.25, 0.70), // feet — magenta
            SIMD3(0.45, 0.35, 0.95), // hips/torso — violet
            SIMD3(0.25, 0.55, 0.95), // chest — blue
            SIMD3(0.30, 0.85, 0.85)  // head — cyan/teal
        ]
        let t = max(0, min(1, (p.y + 0.95) / 1.91))
        let scaled = t * Float(stops.count - 1)
        let idx = min(Int(scaled), stops.count - 2)
        let frac = scaled - Float(idx)
        var color = mix(stops[idx], stops[idx + 1], frac)
        // Subtle lateral shift so left/right edges read with slightly different hue.
        color += SIMD3(0.06, -0.03, 0.04) * p.x
        return simd_clamp(color, SIMD3<Float>(repeating: 0), SIMD3<Float>(repeating: 1))
    }

    private static func statusColor(_ status: HealthStatus) -> SIMD3<Float> {
        switch status {
        case .normal: return SIMD3(0.62, 0.82, 0.32)
        case .watch: return SIMD3(1.0, 0.78, 0.32)
        case .alert: return SIMD3(1.0, 0.42, 0.42)
        }
    }

    // MARK: Geometry assembly

    private static func makeGeometry(positions: [SCNVector3], colors: [Float], colorful: Bool = false) -> SCNGeometry {
        let vertexSource = SCNGeometrySource(vertices: positions)
        let colorData = colors.withUnsafeBufferPointer { Data(buffer: $0) }
        let colorSource = SCNGeometrySource(
            data: colorData,
            semantic: .color,
            vectorCount: positions.count,
            usesFloatComponents: true,
            componentsPerVector: 3,
            bytesPerComponent: MemoryLayout<Float>.size,
            dataOffset: 0,
            dataStride: MemoryLayout<Float>.size * 3
        )

        let indices = (0..<positions.count).map { UInt32($0) }
        let element = SCNGeometryElement(indices: indices, primitiveType: .point)
        element.pointSize = colorful ? 2.8 : 2.2
        element.minimumPointScreenSpaceRadius = colorful ? 1.1 : 0.85
        element.maximumPointScreenSpaceRadius = colorful ? 3.4 : 2.6

        let geometry = SCNGeometry(sources: [vertexSource, colorSource], elements: [element])
        let material = SCNMaterial()
        material.lightingModel = .constant
        material.diffuse.contents = UIColor.white
        material.isLitPerPixel = false
        material.blendMode = .alpha
        material.writesToDepthBuffer = true
        material.readsFromDepthBuffer = true
        geometry.materials = [material]
        return geometry
    }
}

private func mix(_ a: Float, _ b: Float, _ t: Float) -> Float { a + (b - a) * t }
private func mix(_ a: SIMD3<Float>, _ b: SIMD3<Float>, _ t: Float) -> SIMD3<Float> { a + (b - a) * t }
private func smoothstep(_ edge0: Float, _ edge1: Float, _ x: Float) -> Float {
    let t = max(0, min(1, (x - edge0) / (edge1 - edge0)))
    return t * t * (3 - 2 * t)
}

/// Small deterministic RNG so the procedural body is stable across launches.
private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}

// MARK: - Idle camera drift

enum BodySceneIdleMotion {
    /// Very slow orbital pan — a few degrees of arc plus a touch of vertical sway.
    static func applyCameraPan(
        to camera: SCNNode,
        basePosition: SCNVector3,
        lookAt: SCNVector3,
        at time: TimeInterval,
        phase: Double = 0,
        strength: Float = 1
    ) {
        let t = time + phase
        let angle = Float(sin(t * 0.14)) * 0.055 * strength
        let bob = Float(sin(t * 0.11 + 1.0)) * 0.012 * strength

        let relX = basePosition.x - lookAt.x
        let relZ = basePosition.z - lookAt.z
        let radius = (relX * relX + relZ * relZ).squareRoot()
        let baseAngle = atan2(relX, relZ)
        let orbitAngle = baseAngle + angle

        camera.position = SCNVector3(
            lookAt.x + sin(orbitAngle) * radius,
            basePosition.y + bob,
            lookAt.z + cos(orbitAngle) * radius
        )
        camera.look(at: lookAt)
    }
}

// MARK: - SwiftUI wrapper

struct BodyPointCloudView: UIViewRepresentable {
    let statuses: [BodyRegion: HealthStatus]
    @Binding var selectedRegion: BodyRegion?

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.scene = buildScene()
        view.backgroundColor = .clear
        view.isOpaque = false
        view.antialiasingMode = .multisampling2X
        view.allowsCameraControl = false
        view.autoenablesDefaultLighting = false
        view.rendersContinuously = true
        view.pointOfView = context.coordinator.cameraNode
        view.delegate = context.coordinator

        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        view.addGestureRecognizer(tap)
        context.coordinator.scnView = view
        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {}

    private func buildScene() -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = UIColor.clear

        let bodyNode = SCNNode(geometry: BodyPointCloud.build(statuses: statuses))
        bodyNode.name = "body"

        let container = SCNNode()
        container.addChildNode(bodyNode)
        scene.rootNode.addChildNode(container)

        for region in BodyRegion.allCases {
            let marker = makeRegionMarker()
            marker.name = region.rawValue
            marker.position = SCNVector3(region.anchor3D.x, region.anchor3D.y, region.anchor3D.z)
            container.addChildNode(marker)
        }
        return scene
    }

    /// Invisible hit target — keeps the figure clean while regions stay tappable.
    private func makeRegionMarker() -> SCNNode {
        let node = SCNNode()
        let hit = SCNSphere(radius: 0.09)
        hit.firstMaterial?.transparency = 0.001
        hit.firstMaterial?.writesToDepthBuffer = false
        node.addChildNode(SCNNode(geometry: hit))
        return node
    }

    final class Coordinator: NSObject, SCNSceneRendererDelegate {
        let parent: BodyPointCloudView
        weak var scnView: SCNView?
        let cameraNode: SCNNode
        private let cameraRestPosition = SCNVector3(0, 0.02, 2.85)
        private let cameraRestLookAt = SCNVector3(0, 0.02, 0)

        init(_ parent: BodyPointCloudView) {
            self.parent = parent
            let camera = SCNCamera()
            camera.fieldOfView = 36
            camera.zNear = 0.01
            camera.zFar = 100
            cameraNode = SCNNode()
            cameraNode.camera = camera
            cameraNode.position = cameraRestPosition
            super.init()
        }

        func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
            BodySceneIdleMotion.applyCameraPan(
                to: cameraNode,
                basePosition: cameraRestPosition,
                lookAt: cameraRestLookAt,
                at: time
            )
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let view = scnView else { return }
            let point = gesture.location(in: view)
            let hits = view.hitTest(point, options: [SCNHitTestOption.searchMode: SCNHitTestSearchMode.all.rawValue])
            for hit in hits {
                if let name = hit.node.name, let region = BodyRegion(rawValue: name) {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    parent.selectedRegion = region
                    return
                }
            }
        }
    }
}

// MARK: - Wrapped reveal body (camera pans to each region, top → bottom)

struct WrappedBodyFocusView: UIViewRepresentable {
    let statuses: [BodyRegion: HealthStatus]
    let focusedRegion: BodyRegion?
    var ambient: Bool = false
    var spin: Bool = false
    var colorful: Bool = false

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> SCNView {
        context.coordinator.spin = spin
        context.coordinator.colorful = colorful
        let view = SCNView()
        view.scene = context.coordinator.buildScene(statuses: statuses)
        view.backgroundColor = .clear
        view.isOpaque = false
        view.antialiasingMode = colorful ? .multisampling4X : .multisampling2X
        view.allowsCameraControl = false
        view.autoenablesDefaultLighting = false
        view.rendersContinuously = true
        view.pointOfView = context.coordinator.cameraNode
        view.delegate = context.coordinator
        context.coordinator.scnView = view

        if ambient {
            context.coordinator.enterAmbient(statuses: statuses, animated: false)
        } else if let focusedRegion {
            context.coordinator.applyFocus(focusedRegion, statuses: statuses, animated: false)
        } else {
            context.coordinator.resetToFullBody(animated: false)
        }
        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        context.coordinator.sync(focusedRegion: focusedRegion, statuses: statuses, ambient: ambient)
    }

    final class Coordinator: NSObject, SCNSceneRendererDelegate {
        weak var scnView: SCNView?
        let cameraNode = SCNNode()
        let containerNode = SCNNode()
        private var bodyGeometry: SCNGeometry?
        private var bodyNode: SCNNode?
        private var focusGlowNode: SCNNode?
        private var focusRingNode: SCNNode?
        private var highlightVolumeNode: SCNNode?
        private var bandSlabNode: SCNNode?
        private var bandBloomNode: SCNNode?
        private var lastFocused: BodyRegion?
        private var lastStatuses: [BodyRegion: HealthStatus] = [:]
        private var ambientActive = false
        private var ambientStatuses: [BodyRegion: HealthStatus] = [:]

        /// Continuous turntable spin (Scan Summary) — rotates the body in place.
        var spin = false
        var colorful = false
        private let spinSpeed: Float = 0.3

        /// Ambient orbit framing — zoomed out to fit the whole body, steady spin.
        private let ambientRadius: Float = 3.62
        private let ambientCenterY: Float = 0.0
        private let ambientSpeed: Float = 0.22

        private var animatedFocusY: Float = 0
        private var targetFocusY: Float = 0
        private var animatedHalfH: Float = 0.12
        private var targetHalfH: Float = 0.12
        private var animatedRadius: Float = 0.14
        private var targetRadius: Float = 0.14
        private var focusTint = SIMD3<Float>(0.62, 0.82, 0.32)
        private var focusAnchorX: Float = 0
        private var focusAnchorZ: Float = 0
        private var focusActive: Float = 0
        private var focusAnimationStart: TimeInterval = 0
        private var focusAnimationDuration: TimeInterval = 0.9
        private var focusAnimationFromY: Float = 0
        private var focusAnimationFromHalfH: Float = 0.12
        private var focusAnimationFromRadius: Float = 0.14
        private var cameraRestPosition = SCNVector3(0, 0.02, 2.85)
        private var cameraRestLookAt = SCNVector3(0, 0.02, 0)
        private var idleStartTime: TimeInterval = 0

        private static let focusModifier = """
        #pragma arguments
        float focusY;
        float focusX;
        float focusZ;
        float focusHalfH;
        float focusRadius;
        float focusR;
        float focusG;
        float focusB;
        float focusActive;
        #pragma body
        float dy = abs(_geometry.position.y - focusY);
        float vertical = 1.0 - smoothstep(focusHalfH * 0.35, focusHalfH * 1.15, dy);
        float2 deltaXZ = float2(_geometry.position.x - focusX, _geometry.position.z - focusZ);
        float radial = 1.0 - smoothstep(focusRadius * 0.30, focusRadius * 1.25, length(deltaXZ));
        float highlight = vertical * radial * focusActive;
        float dim = focusActive < 0.01 ? 1.0 : mix(0.40, 1.05, highlight);
        _geometry.color.rgb *= dim;
        float band = exp(-pow(dy / max(focusHalfH * 0.62, 0.01), 2.0)) * radial * focusActive;
        _geometry.color.rgb += float3(focusR, focusG, focusB) * band * 1.30;
        _geometry.color.rgb += float3(focusR, focusG, focusB) * highlight * 0.70;
        if (focusActive < 0.01) {
            _geometry.color.rgb *= 1.28;
        }
        """

        func buildScene(statuses: [BodyRegion: HealthStatus]) -> SCNScene {
            let scene = SCNScene()
            scene.background.contents = UIColor.clear

            let geometry = BodyPointCloud.build(statuses: statuses, colorful: colorful)
            geometry.shaderModifiers = [.geometry: Self.focusModifier]
            geometry.setValue(NSNumber(value: 0), forKey: "focusY")
            geometry.setValue(NSNumber(value: 0), forKey: "focusX")
            geometry.setValue(NSNumber(value: 0), forKey: "focusZ")
            geometry.setValue(NSNumber(value: 0.12), forKey: "focusHalfH")
            geometry.setValue(NSNumber(value: 0.14), forKey: "focusRadius")
            geometry.setValue(NSNumber(value: 0.62), forKey: "focusR")
            geometry.setValue(NSNumber(value: 0.82), forKey: "focusG")
            geometry.setValue(NSNumber(value: 0.32), forKey: "focusB")
            geometry.setValue(NSNumber(value: 0), forKey: "focusActive")
            bodyGeometry = geometry

            let body = SCNNode(geometry: geometry)
            bodyNode = body
            containerNode.addChildNode(body)

            let volume = makeHighlightVolume()
            highlightVolumeNode = volume
            containerNode.addChildNode(volume)

            let glow = makeFocusGlow()
            focusGlowNode = glow
            containerNode.addChildNode(glow)

            let ring = makeFocusRing()
            focusRingNode = ring
            containerNode.addChildNode(ring)

            let slab = makeBandSlab()
            bandSlabNode = slab
            containerNode.addChildNode(slab)

            let bloom = makeBandBloom()
            bandBloomNode = bloom
            containerNode.addChildNode(bloom)

            scene.rootNode.addChildNode(containerNode)

            let camera = SCNCamera()
            // Matches ScanRevealBodyView so the crossfade from the reveal screen
            // has no size jump before the camera glides to the first organ.
            camera.fieldOfView = 36
            camera.zNear = 0.01
            camera.zFar = 100
            cameraNode.camera = camera
            scene.rootNode.addChildNode(cameraNode)

            return scene
        }

        func sync(focusedRegion: BodyRegion?, statuses: [BodyRegion: HealthStatus], ambient: Bool) {
            if ambient {
                enterAmbient(statuses: statuses, animated: true)
                return
            }

            if statuses != lastStatuses {
                bodyNode?.geometry = BodyPointCloud.build(statuses: statuses, colorful: colorful)
                if let geometry = bodyNode?.geometry {
                    geometry.shaderModifiers = [.geometry: Self.focusModifier]
                    bodyGeometry = geometry
                    applyFocusUniforms(
                        y: animatedFocusY,
                        halfH: animatedHalfH,
                        radius: animatedRadius,
                        tint: focusTint,
                        active: focusActive
                    )
                }
                lastStatuses = statuses
            }

            guard focusedRegion != lastFocused else { return }

            if let focusedRegion {
                applyFocus(focusedRegion, statuses: statuses, animated: true)
            } else {
                resetToFullBody(animated: true)
            }
        }

        /// Zoomed-out, all-regions-lit, continuously orbiting view shown once the
        /// per-region walkthrough completes. Rebuilds the body with boosted tints
        /// so every region reads in its status color at once.
        func enterAmbient(statuses: [BodyRegion: HealthStatus], animated: Bool) {
            let alreadyAmbient = ambientActive && statuses == ambientStatuses
            ambientActive = true
            ambientStatuses = statuses

            if !alreadyAmbient {
                bodyNode?.geometry = BodyPointCloud.build(statuses: statuses, tintStrength: 2.7)
                if let geometry = bodyNode?.geometry {
                    geometry.shaderModifiers = [.geometry: Self.focusModifier]
                    bodyGeometry = geometry
                }
                lastStatuses = statuses
            }

            focusActive = 0
            focusAnimationDuration = 0
            lastFocused = nil

            applyFocusUniforms(
                y: animatedFocusY,
                halfH: animatedHalfH,
                radius: animatedRadius,
                tint: focusTint,
                active: 0
            )

            let duration = animated ? 0.9 : 0
            SCNTransaction.begin()
            SCNTransaction.animationDuration = duration
            SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            focusGlowNode?.opacity = 0
            focusRingNode?.opacity = 0
            highlightVolumeNode?.opacity = 0
            bandSlabNode?.opacity = 0
            bandBloomNode?.opacity = 0
            SCNTransaction.commit()
        }

        func applyFocus(_ region: BodyRegion, statuses: [BodyRegion: HealthStatus], animated: Bool) {
            if ambientActive {
                ambientActive = false
                bodyNode?.geometry = BodyPointCloud.build(statuses: statuses, colorful: colorful)
                if let geometry = bodyNode?.geometry {
                    geometry.shaderModifiers = [.geometry: Self.focusModifier]
                    bodyGeometry = geometry
                }
                lastStatuses = statuses
            }
            let anchor = region.anchor3D
            let lookAt = SCNVector3(anchor.x, anchor.y, anchor.z)
            let camY = anchor.y + 0.06
            let camZ: Float = 2.28 + max(0, abs(anchor.y) - 0.2) * 0.22
            let targetPos = SCNVector3(anchor.x * 0.18, camY, camZ)
            cameraRestPosition = targetPos
            cameraRestLookAt = lookAt

            let tint = Theme.color(for: statuses[region] ?? .normal)
            let rgb = simdTint(from: tint)
            focusTint = rgb
            focusAnchorX = anchor.x
            focusAnchorZ = anchor.z

            focusAnimationFromY = animatedFocusY
            focusAnimationFromHalfH = animatedHalfH
            focusAnimationFromRadius = animatedRadius
            targetFocusY = anchor.y
            targetHalfH = region.focusBandHalfHeight
            targetRadius = region.focusBandRadius
            focusAnimationDuration = animated ? 0.9 : 0
            focusAnimationStart = CACurrentMediaTime()
            if !animated { idleStartTime = focusAnimationStart }
            focusActive = 1

            updateHighlightVolume(
                centerY: anchor.y,
                halfHeight: region.focusBandHalfHeight,
                radius: region.focusBandRadius,
                tint: tint
            )

            let duration = animated ? 0.9 : 0
            SCNTransaction.begin()
            SCNTransaction.animationDuration = duration
            SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            cameraNode.position = targetPos
            cameraNode.look(at: lookAt)
            focusGlowNode?.position = SCNVector3(anchor.x, anchor.y, anchor.z + 0.06)
            focusRingNode?.position = SCNVector3(anchor.x, anchor.y, anchor.z + 0.06)
            bandSlabNode?.position = SCNVector3(0, anchor.y, 0.02)
            bandBloomNode?.position = SCNVector3(0, anchor.y, 0.03)
            focusGlowNode?.opacity = 1
            focusRingNode?.opacity = 1
            highlightVolumeNode?.opacity = 0.88
            bandSlabNode?.opacity = 1
            bandBloomNode?.opacity = 1
            SCNTransaction.commit()

            updateBandColor(tint)
            applyFocusUniforms(
                y: animated ? focusAnimationFromY : targetFocusY,
                halfH: animated ? focusAnimationFromHalfH : targetHalfH,
                radius: animated ? focusAnimationFromRadius : targetRadius,
                tint: rgb,
                active: 1
            )

            if !animated {
                animatedFocusY = targetFocusY
                animatedHalfH = targetHalfH
                animatedRadius = targetRadius
            }

            if animated {
                pulseFocusRing()
            }

            lastFocused = region
            lastStatuses = statuses
        }

        func resetToFullBody(animated: Bool) {
            if ambientActive {
                ambientActive = false
                bodyNode?.geometry = BodyPointCloud.build(statuses: ambientStatuses, colorful: colorful)
                if let geometry = bodyNode?.geometry {
                    geometry.shaderModifiers = [.geometry: Self.focusModifier]
                    bodyGeometry = geometry
                }
                lastStatuses = ambientStatuses
            }
            let duration = animated ? 0.9 : 0
            focusActive = 0
            cameraRestPosition = SCNVector3(0, 0.02, 2.85)
            cameraRestLookAt = SCNVector3(0, 0.02, 0)
            idleStartTime = CACurrentMediaTime() + duration
            SCNTransaction.begin()
            SCNTransaction.animationDuration = duration
            SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            cameraNode.position = SCNVector3(0, 0.02, 2.85)
            cameraNode.look(at: SCNVector3(0, 0.02, 0))
            focusGlowNode?.opacity = 0
            focusRingNode?.opacity = 0
            highlightVolumeNode?.opacity = 0
            bandSlabNode?.opacity = 0
            bandBloomNode?.opacity = 0
            SCNTransaction.commit()

            applyFocusUniforms(
                y: animatedFocusY,
                halfH: animatedHalfH,
                radius: animatedRadius,
                tint: focusTint,
                active: 0
            )
            lastFocused = nil
        }

        func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
            if ambientActive {
                let angle = Float(time) * ambientSpeed
                cameraNode.position = SCNVector3(
                    sin(angle) * ambientRadius,
                    ambientCenterY + 0.04,
                    cos(angle) * ambientRadius
                )
                cameraNode.look(at: SCNVector3(0, ambientCenterY, 0))
                return
            }

            if focusActive > 0, focusAnimationDuration > 0 {
                let elapsed = time - focusAnimationStart
                let t = Float(min(1, elapsed / focusAnimationDuration))
                let eased = easeInOut(t)

                animatedFocusY = focusAnimationFromY + (targetFocusY - focusAnimationFromY) * eased
                animatedHalfH = focusAnimationFromHalfH + (targetHalfH - focusAnimationFromHalfH) * eased
                animatedRadius = focusAnimationFromRadius + (targetRadius - focusAnimationFromRadius) * eased

                applyFocusUniforms(
                    y: animatedFocusY,
                    halfH: animatedHalfH,
                    radius: animatedRadius,
                    tint: focusTint,
                    active: focusActive
                )

                bandSlabNode?.position.y = animatedFocusY
                bandBloomNode?.position.y = animatedFocusY
                highlightVolumeNode?.position.y = animatedFocusY

                if t >= 1 {
                    focusAnimationDuration = 0
                    idleStartTime = time
                }
            }

            if focusAnimationDuration == 0 {
                if spin {
                    // Continuous turntable: rotate the body in place, keeping the
                    // camera at its rest framing so zoom/position stay constant.
                    containerNode.eulerAngles.y = Float(time) * spinSpeed
                } else {
                    // Ease the drift in from zero so the camera holds exactly on the
                    // last transition frame instead of snapping to an arbitrary point
                    // in the idle sinusoid.
                    let rampDuration: TimeInterval = 0.7
                    let ramp = Float(min(1, max(0, (time - idleStartTime) / rampDuration)))
                    let eased = ramp * ramp * (3 - 2 * ramp)
                    BodySceneIdleMotion.applyCameraPan(
                        to: cameraNode,
                        basePosition: cameraRestPosition,
                        lookAt: cameraRestLookAt,
                        at: time,
                        strength: eased
                    )
                }
            }
        }

        private func applyFocusUniforms(
            y: Float,
            halfH: Float,
            radius: Float,
            tint: SIMD3<Float>,
            active: Float
        ) {
            bodyGeometry?.setValue(NSNumber(value: y), forKey: "focusY")
            bodyGeometry?.setValue(NSNumber(value: focusAnchorX), forKey: "focusX")
            bodyGeometry?.setValue(NSNumber(value: focusAnchorZ), forKey: "focusZ")
            bodyGeometry?.setValue(NSNumber(value: halfH), forKey: "focusHalfH")
            bodyGeometry?.setValue(NSNumber(value: radius), forKey: "focusRadius")
            bodyGeometry?.setValue(NSNumber(value: tint.x), forKey: "focusR")
            bodyGeometry?.setValue(NSNumber(value: tint.y), forKey: "focusG")
            bodyGeometry?.setValue(NSNumber(value: tint.z), forKey: "focusB")
            bodyGeometry?.setValue(NSNumber(value: active), forKey: "focusActive")
        }

        private func easeInOut(_ t: Float) -> Float {
            t * t * (3 - 2 * t)
        }

        private func simdTint(from color: Color) -> SIMD3<Float> {
            let uiColor = UIColor(color)
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
            return SIMD3(Float(r), Float(g), Float(b))
        }

        private func makeHighlightVolume() -> SCNNode {
            let capsule = SCNCapsule(capRadius: 0.14, height: 0.24)
            let material = SCNMaterial()
            material.lightingModel = .constant
            material.diffuse.contents = UIColor.clear
            material.emission.contents = UIColor(red: 0.62, green: 0.82, blue: 0.32, alpha: 0.35)
            material.transparency = 0.82
            material.blendMode = .add
            material.isDoubleSided = true
            material.writesToDepthBuffer = false
            capsule.materials = [material]

            let node = SCNNode(geometry: capsule)
            node.opacity = 0
            return node
        }

        private func makeBandSlab() -> SCNNode {
            let slab = SCNBox(width: 0.72, height: 0.004, length: 0.38, chamferRadius: 0)
            let material = SCNMaterial()
            material.lightingModel = .constant
            material.diffuse.contents = UIColor.clear
            material.emission.contents = UIColor(red: 1.0, green: 0.72, blue: 0.0, alpha: 1)
            material.blendMode = .add
            material.writesToDepthBuffer = false
            material.isDoubleSided = true
            slab.materials = [material]

            let node = SCNNode(geometry: slab)
            node.opacity = 0
            return node
        }

        private func makeBandBloom() -> SCNNode {
            let bloom = SCNPlane(width: 1.0, height: 0.24)
            let material = SCNMaterial()
            material.lightingModel = .constant
            material.diffuse.contents = UIColor.clear
            material.emission.contents = UIColor(red: 1.0, green: 0.72, blue: 0.0, alpha: 0.18)
            material.blendMode = .add
            material.writesToDepthBuffer = false
            material.isDoubleSided = true
            bloom.materials = [material]

            let node = SCNNode(geometry: bloom)
            node.opacity = 0
            return node
        }

        private func updateHighlightVolume(centerY: Float, halfHeight: Float, radius: Float, tint: Color) {
            let uiColor = UIColor(tint)
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)

            let height = max(0.08, halfHeight * 2)
            let capsule = SCNCapsule(capRadius: CGFloat(radius), height: CGFloat(height))
            let material = SCNMaterial()
            material.lightingModel = .constant
            material.diffuse.contents = UIColor.clear
            material.emission.contents = UIColor(red: r, green: g, blue: b, alpha: 0.42)
            material.transparency = 0.78
            material.blendMode = .add
            material.isDoubleSided = true
            material.writesToDepthBuffer = false
            capsule.materials = [material]

            highlightVolumeNode?.geometry = capsule
            highlightVolumeNode?.position = SCNVector3(0, centerY, 0.04)
        }

        private func updateBandColor(_ color: Color) {
            let uiColor = UIColor(color)
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
            let band = UIColor(red: r, green: g, blue: b, alpha: 1)
            bandSlabNode?.geometry?.firstMaterial?.emission.contents = band
            bandBloomNode?.geometry?.firstMaterial?.emission.contents = band.withAlphaComponent(0.22)
            focusGlowNode?.geometry?.firstMaterial?.emission.contents = band.withAlphaComponent(0.75)
            focusRingNode?.geometry?.firstMaterial?.emission.contents = UIColor.white.withAlphaComponent(0.9)
        }

        private func makeFocusGlow() -> SCNNode {
            let sphere = SCNSphere(radius: 0.14)
            let material = SCNMaterial()
            material.lightingModel = .constant
            material.diffuse.contents = UIColor.clear
            material.emission.contents = UIColor(red: 1.0, green: 0.72, blue: 0.0, alpha: 0.65)
            material.blendMode = .add
            material.writesToDepthBuffer = false
            sphere.materials = [material]

            let node = SCNNode(geometry: sphere)
            node.opacity = 0
            return node
        }

        private func makeFocusRing() -> SCNNode {
            let torus = SCNTorus(ringRadius: 0.16, pipeRadius: 0.008)
            let material = SCNMaterial()
            material.lightingModel = .constant
            material.diffuse.contents = UIColor.clear
            material.emission.contents = UIColor.white.withAlphaComponent(0.9)
            material.blendMode = .add
            material.writesToDepthBuffer = false
            torus.materials = [material]

            let node = SCNNode(geometry: torus)
            node.opacity = 0
            return node
        }

        private func pulseFocusRing() {
            guard let ring = focusRingNode else { return }
            ring.scale = SCNVector3(0.65, 0.65, 0.65)
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.55
            SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeOut)
            ring.scale = SCNVector3(1.2, 1.2, 1.2)
            SCNTransaction.commit()
        }
    }
}

// MARK: - Scan volume reveal (slice stack → 3D body)

/// Point-cloud body that materializes feet-first after the slice stack has finished.
struct ScanRevealBodyView: UIViewRepresentable {
    var revealProgress: Double

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
        context.coordinator.updateReveal(revealProgress)
        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        context.coordinator.updateReveal(revealProgress)
    }

    final class Coordinator: NSObject, SCNSceneRendererDelegate {
        weak var scnView: SCNView?
        let cameraNode = SCNNode()
        private var bodyGeometry: SCNGeometry?
        private let cameraRestPosition = SCNVector3(0, -0.02, 3.1)
        private let cameraRestLookAt = SCNVector3(0, -0.02, 0)

        private static let revealModifier = """
        #pragma arguments
        float revealY;
        float revealActive;
        #pragma body
        float edge = 0.07;
        float d = _geometry.position.y - revealY;
        float visible = 1.0 - smoothstep(0.0, edge, d);
        _geometry.color.rgb *= mix(1.0, visible, revealActive);
        """

        func buildScene() -> SCNScene {
            let scene = SCNScene()
            scene.background.contents = UIColor.clear

            let statuses = Dictionary(uniqueKeysWithValues: BodyRegion.allCases.map { ($0, HealthStatus.normal) })
            let geometry = BodyPointCloud.build(statuses: statuses)
            geometry.shaderModifiers = [.geometry: Self.revealModifier]
            geometry.setValue(NSNumber(value: -1.1), forKey: "revealY")
            geometry.setValue(NSNumber(value: 0), forKey: "revealActive")
            bodyGeometry = geometry

            let body = SCNNode(geometry: geometry)
            scene.rootNode.addChildNode(body)

            let camera = SCNCamera()
            camera.fieldOfView = 36
            camera.zNear = 0.01
            camera.zFar = 100
            cameraNode.camera = camera
            cameraNode.position = cameraRestPosition
            cameraNode.look(at: cameraRestLookAt)
            scene.rootNode.addChildNode(cameraNode)

            return scene
        }

        func updateReveal(_ progress: Double) {
            let revealY = Float(-1.1 + progress * 2.2)
            let active = progress > 0.01 ? Float(1) : Float(0)
            bodyGeometry?.setValue(NSNumber(value: revealY), forKey: "revealY")
            bodyGeometry?.setValue(NSNumber(value: active), forKey: "revealActive")
        }

        func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
            BodySceneIdleMotion.applyCameraPan(
                to: cameraNode,
                basePosition: cameraRestPosition,
                lookAt: cameraRestLookAt,
                at: time
            )
        }
    }
}

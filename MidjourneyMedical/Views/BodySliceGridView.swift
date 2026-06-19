import SwiftUI
import UIKit

// MARK: - Contact-sheet grid

/// A contact sheet of axial MRI cross-sections that fill in one-by-one as the
/// scan acquires slices — the torso sweeping down into the legs. Driven entirely
/// by `fillFraction` (0 = empty, 1 = every cell revealed) so reveal stays smooth
/// and cheap without per-cell state.
struct BodySliceGridView: View {
    var fillFraction: Double

    private let columns = 10
    private let rows = 12
    private var sliceCount: Int { columns * rows }

    /// Width of the per-cell fade wave, in cell units.
    private let fadeWidth: Double = 3.0

    private var thumbnails: [UIImage] {
        BodySliceThumbnails.shared.images(count: sliceCount)
    }

    var body: some View {
        GeometryReader { geo in
            let spacing: CGFloat = 4
            let inset: CGFloat = 14
            let availW = geo.size.width - inset * 2
            let availH = geo.size.height - inset * 2
            // Largest square cell that fits all rows and columns inside the panel.
            let cellSize = min(
                (availW - spacing * CGFloat(columns - 1)) / CGFloat(columns),
                (availH - spacing * CGFloat(rows - 1)) / CGFloat(rows)
            )
            // Size the panel to the actual grid content so the border hugs the
            // thumbnails and stays a consistent size regardless of available height.
            let gridW = cellSize * CGFloat(columns) + spacing * CGFloat(columns - 1)
            let gridH = cellSize * CGFloat(rows) + spacing * CGFloat(rows - 1)

            LazyVGrid(
                columns: Array(repeating: GridItem(.fixed(cellSize), spacing: spacing), count: columns),
                spacing: spacing
            ) {
                ForEach(0..<sliceCount, id: \.self) { index in
                    cell(index: index, side: cellSize)
                }
            }
            .frame(width: gridW, height: gridH, alignment: .center)
            .padding(inset)
            .background(panel)
            .frame(width: geo.size.width, height: geo.size.height, alignment: .center)
        }
    }

    private func cell(index: Int, side: CGFloat) -> some View {
        let reveal = revealAmount(for: index)
        return Image(uiImage: thumbnails[index])
            .resizable()
            .interpolation(.medium)
            .scaledToFit()
            .frame(width: side, height: side)
            .opacity(reveal)
            .scaleEffect(0.9 + 0.1 * reveal)
            .animation(.easeOut(duration: 0.18), value: reveal)
    }

    /// Continuous left-to-right, top-to-bottom fill wave from `fillFraction`.
    private func revealAmount(for index: Int) -> Double {
        let frontier = fillFraction * Double(sliceCount)
        return min(max((frontier - Double(index)) / fadeWidth, 0), 1)
    }

    private var panel: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color.white.opacity(0.02))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Theme.stroke.opacity(0.4), lineWidth: 1)
            )
    }
}

// MARK: - Thumbnail cache

private final class BodySliceThumbnails {
    static let shared = BodySliceThumbnails()

    private var cache: [Int: [UIImage]] = [:]

    func images(count: Int) -> [UIImage] {
        if let cached = cache[count] { return cached }
        let built = (0..<count).map { index -> UIImage in
            let t = Float(index) / Float(max(count - 1, 1))
            return BodySliceThumbnailRenderer.render(t: t, seed: index)
        }
        cache[count] = built
        return built
    }
}

// MARK: - Axial slice renderer

/// Renders a single grayscale axial cross-section. As normalized depth `t` goes
/// 0 -> 1 the silhouette sweeps chest -> waist -> hips -> pelvis -> two legs.
private enum BodySliceThumbnailRenderer {
    static func render(t: Float, seed: Int) -> UIImage {
        let size = 120
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        return renderer.image { context in
            let cg = context.cgContext
            let dimension = CGFloat(size)
            cg.setFillColor(UIColor.black.cgColor)
            cg.fill(CGRect(x: 0, y: 0, width: dimension, height: dimension))

            var rng = ThumbRNG(seed: UInt64(bitPattern: Int64(seed &* 2654435761 &+ 1013904223)))
            let center = dimension * 0.5

            for blob in silhouette(t: t, dimension: dimension, center: center) {
                drawSlice(cg: cg, blob: blob, rng: &rng)
            }
        }
    }

    // MARK: Silhouette shape per depth

    private static func silhouette(t: Float, dimension: CGFloat, center: CGFloat) -> [SliceBlob] {
        let maxHalf = dimension * 0.46

        // Torso/abdomen: single rounded ellipse, chest -> waist -> hip profile.
        if t <= 0.62 {
            let w = torsoWidth(at: t / 0.62)
            let halfW = maxHalf * CGFloat(w)
            let halfH = halfW * 0.66
            return [SliceBlob(
                rect: CGRect(x: center - halfW, y: center - halfH, width: halfW * 2, height: halfH * 2),
                isLeg: false
            )]
        }

        // Pelvis: wide, rounded, slightly taller.
        if t <= 0.72 {
            let halfW = maxHalf * 0.92
            let halfH = halfW * 0.74
            return [SliceBlob(
                rect: CGRect(x: center - halfW, y: center - halfH, width: halfW * 2, height: halfH * 2),
                isLeg: false
            )]
        }

        // Legs: two separate circles, shrinking with depth.
        let legT = (t - 0.72) / 0.28
        let radius = maxHalf * CGFloat(0.40 - 0.16 * legT)
        let gap = maxHalf * CGFloat(0.34 - 0.10 * legT)
        let leftX = center - gap
        let rightX = center + gap
        return [
            SliceBlob(rect: CGRect(x: leftX - radius, y: center - radius, width: radius * 2, height: radius * 2), isLeg: true),
            SliceBlob(rect: CGRect(x: rightX - radius, y: center - radius, width: radius * 2, height: radius * 2), isLeg: true)
        ]
    }

    /// Chest (wide) -> narrowest waist -> hips, normalized half-width in 0...1.
    private static func torsoWidth(at u: Float) -> Float {
        // u: 0 = chest (top of torso), 1 = hips (bottom of torso run).
        let chest: Float = 0.96
        let waist: Float = 0.74
        let hip: Float = 0.90
        if u < 0.5 {
            let k = u / 0.5
            return chest + (waist - chest) * smooth(k)
        } else {
            let k = (u - 0.5) / 0.5
            return waist + (hip - waist) * smooth(k)
        }
    }

    private static func smooth(_ x: Float) -> Float {
        let c = min(max(x, 0), 1)
        return c * c * (3 - 2 * c)
    }

    // MARK: Per-blob fill

    private static func drawSlice(cg: CGContext, blob: SliceBlob, rng: inout ThumbRNG) {
        let rect = blob.rect
        let isLeg = blob.isLeg
        cg.saveGState()
        cg.addEllipse(in: rect)
        cg.clip()

        // Base tissue.
        cg.setFillColor(UIColor(white: 0.17, alpha: 1).cgColor)
        cg.fill(rect)

        // Grayscale speckle.
        let speckle = isLeg ? 90 : 200
        for _ in 0..<speckle {
            let dx = Float.random(in: -1...1, using: &rng)
            let dy = Float.random(in: -1...1, using: &rng)
            guard dx * dx + dy * dy <= 1 else { continue }
            let tone = Float.random(in: 0.24...0.82, using: &rng)
            let px = rect.midX + CGFloat(dx) * rect.width * 0.5
            let py = rect.midY + CGFloat(dy) * rect.height * 0.5
            let dot = CGFloat(tone) * 1.9 + 0.6
            cg.setFillColor(UIColor(white: CGFloat(tone), alpha: 0.7).cgColor)
            cg.fillEllipse(in: CGRect(x: px - dot * 0.5, y: py - dot * 0.5, width: dot, height: dot))
        }

        // Soft organ-like lobes (torso only).
        if !isLeg {
            for _ in 0..<4 {
                let ox = Float.random(in: -0.5...0.5, using: &rng)
                let oy = Float.random(in: -0.4...0.4, using: &rng)
                let lobeR = Float.random(in: 0.10...0.26, using: &rng)
                let tone = Float.random(in: 0.36...0.7, using: &rng)
                let px = rect.midX + CGFloat(ox) * rect.width * 0.5
                let py = rect.midY + CGFloat(oy) * rect.height * 0.5
                let r = CGFloat(lobeR) * rect.width * 0.5
                cg.setFillColor(UIColor(white: CGFloat(tone), alpha: 0.3).cgColor)
                cg.fillEllipse(in: CGRect(x: px - r, y: py - r, width: r * 2, height: r * 2))
            }
        }

        // Bright "spine" dot at the back (torso only).
        if !isLeg {
            let r = rect.width * 0.05
            let px = rect.midX
            let py = rect.midY + rect.height * 0.30
            cg.setFillColor(UIColor(white: 0.95, alpha: 0.9).cgColor)
            cg.fillEllipse(in: CGRect(x: px - r, y: py - r, width: r * 2, height: r * 2))
        }
        cg.restoreGState()

        // Bright rim + soft outer glow (unclipped).
        cg.setStrokeColor(UIColor(white: 1, alpha: 0.95).cgColor)
        cg.setLineWidth(1.6)
        cg.strokeEllipse(in: rect.insetBy(dx: 0.8, dy: 0.8))

        cg.setStrokeColor(UIColor(white: 1, alpha: 0.28).cgColor)
        cg.setLineWidth(3.5)
        cg.strokeEllipse(in: rect.insetBy(dx: -0.5, dy: -0.5))
    }
}

private struct SliceBlob {
    let rect: CGRect
    let isLeg: Bool
}

private struct ThumbRNG: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 0x9E3779B9 : seed }
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}

#Preview {
    BodySliceGridPreview()
        .preferredColorScheme(.dark)
}

private struct BodySliceGridPreview: View {
    @State private var fill = 0.0

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            BodySliceGridView(fillFraction: fill)
                .frame(maxHeight: 520)
                .padding()
        }
        .onAppear {
            withAnimation(.linear(duration: 5)) { fill = 1 }
        }
    }
}

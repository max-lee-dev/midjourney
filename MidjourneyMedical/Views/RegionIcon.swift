import SwiftUI

/// Hand-built anatomical line-art for each `BodyRegion`.
/// Stroke-only vector paths in a normalized unit square, matching the
/// app's HUD/blueprint language — thin strokes, square framing, tint-driven.
struct RegionIcon: View {
    let region: BodyRegion
    var size: CGFloat = 24
    var color: Color = Theme.accent
    var lineWidth: CGFloat? = nil

    private var resolvedLineWidth: CGFloat {
        lineWidth ?? min(2.6, max(1.4, size * 0.075))
    }

    var body: some View {
        RegionShape(region: region)
            .stroke(
                color,
                style: StrokeStyle(lineWidth: resolvedLineWidth, lineCap: .round, lineJoin: .round)
            )
            .frame(width: size, height: size)
            .accessibilityLabel(region.displayName)
    }
}

/// The raw geometry behind `RegionIcon`, drawn into the largest centered square.
struct RegionShape: Shape {
    let region: BodyRegion

    func path(in rect: CGRect) -> Path {
        let side = min(rect.width, rect.height)
        let originX = rect.midX - side / 2
        let originY = rect.midY - side / 2

        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: originX + x * side, y: originY + y * side)
        }

        func box(_ x0: CGFloat, _ y0: CGFloat, _ x1: CGFloat, _ y1: CGFloat) -> CGRect {
            let a = point(x0, y0)
            let b = point(x1, y1)
            return CGRect(x: a.x, y: a.y, width: b.x - a.x, height: b.y - a.y)
        }

        var path = Path()

        switch region {
        case .brain:
            path.move(to: point(0.22, 0.52))
            path.addCurve(to: point(0.30, 0.30), control1: point(0.20, 0.42), control2: point(0.22, 0.34))
            path.addCurve(to: point(0.42, 0.26), control1: point(0.34, 0.27), control2: point(0.38, 0.25))
            path.addCurve(to: point(0.50, 0.22), control1: point(0.44, 0.23), control2: point(0.46, 0.22))
            path.addCurve(to: point(0.58, 0.26), control1: point(0.54, 0.22), control2: point(0.56, 0.23))
            path.addCurve(to: point(0.70, 0.30), control1: point(0.62, 0.25), control2: point(0.66, 0.27))
            path.addCurve(to: point(0.78, 0.52), control1: point(0.78, 0.34), control2: point(0.80, 0.42))
            path.addCurve(to: point(0.66, 0.68), control1: point(0.78, 0.60), control2: point(0.74, 0.66))
            path.addCurve(to: point(0.50, 0.70), control1: point(0.61, 0.70), control2: point(0.56, 0.70))
            path.addCurve(to: point(0.34, 0.68), control1: point(0.44, 0.70), control2: point(0.39, 0.70))
            path.addCurve(to: point(0.22, 0.52), control1: point(0.26, 0.66), control2: point(0.22, 0.60))
            path.closeSubpath()

            path.move(to: point(0.50, 0.24))
            path.addCurve(to: point(0.50, 0.68), control1: point(0.43, 0.40), control2: point(0.57, 0.54))

            path.move(to: point(0.50, 0.70))
            path.addCurve(to: point(0.45, 0.86), control1: point(0.50, 0.77), control2: point(0.43, 0.79))

        case .heart:
            path.move(to: point(0.50, 0.34))
            path.addCurve(to: point(0.24, 0.30), control1: point(0.42, 0.20), control2: point(0.28, 0.18))
            path.addCurve(to: point(0.22, 0.50), control1: point(0.18, 0.38), control2: point(0.18, 0.44))
            path.addCurve(to: point(0.50, 0.80), control1: point(0.28, 0.61), control2: point(0.42, 0.71))
            path.addCurve(to: point(0.78, 0.50), control1: point(0.58, 0.71), control2: point(0.72, 0.61))
            path.addCurve(to: point(0.76, 0.30), control1: point(0.82, 0.44), control2: point(0.82, 0.38))
            path.addCurve(to: point(0.50, 0.34), control1: point(0.72, 0.18), control2: point(0.58, 0.20))
            path.closeSubpath()

            path.move(to: point(0.50, 0.40))
            path.addLine(to: point(0.50, 0.72))

        case .lungs:
            path.move(to: point(0.50, 0.18))
            path.addLine(to: point(0.50, 0.40))
            path.move(to: point(0.50, 0.40))
            path.addLine(to: point(0.46, 0.42))
            path.move(to: point(0.50, 0.40))
            path.addLine(to: point(0.54, 0.42))

            path.move(to: point(0.46, 0.42))
            path.addCurve(to: point(0.24, 0.60), control1: point(0.34, 0.44), control2: point(0.24, 0.50))
            path.addCurve(to: point(0.30, 0.80), control1: point(0.24, 0.70), control2: point(0.25, 0.76))
            path.addCurve(to: point(0.44, 0.66), control1: point(0.36, 0.82), control2: point(0.43, 0.76))
            path.addLine(to: point(0.46, 0.42))
            path.closeSubpath()

            path.move(to: point(0.54, 0.42))
            path.addCurve(to: point(0.76, 0.60), control1: point(0.66, 0.44), control2: point(0.76, 0.50))
            path.addCurve(to: point(0.70, 0.80), control1: point(0.76, 0.70), control2: point(0.75, 0.76))
            path.addCurve(to: point(0.56, 0.66), control1: point(0.64, 0.82), control2: point(0.57, 0.76))
            path.addLine(to: point(0.54, 0.42))
            path.closeSubpath()

        case .liver:
            path.move(to: point(0.18, 0.40))
            path.addCurve(to: point(0.50, 0.34), control1: point(0.30, 0.34), control2: point(0.40, 0.33))
            path.addLine(to: point(0.54, 0.40))
            path.addCurve(to: point(0.82, 0.40), control1: point(0.64, 0.33), control2: point(0.76, 0.35))
            path.addCurve(to: point(0.62, 0.64), control1: point(0.84, 0.52), control2: point(0.78, 0.60))
            path.addCurve(to: point(0.30, 0.62), control1: point(0.50, 0.68), control2: point(0.40, 0.66))
            path.addCurve(to: point(0.18, 0.40), control1: point(0.22, 0.58), control2: point(0.16, 0.48))
            path.closeSubpath()

            path.move(to: point(0.30, 0.50))
            path.addCurve(to: point(0.52, 0.52), control1: point(0.38, 0.53), control2: point(0.45, 0.53))

        case .kidneys:
            path.move(to: point(0.30, 0.26))
            path.addCurve(to: point(0.44, 0.44), control1: point(0.40, 0.28), control2: point(0.44, 0.34))
            path.addCurve(to: point(0.44, 0.56), control1: point(0.38, 0.48), control2: point(0.38, 0.52))
            path.addCurve(to: point(0.30, 0.74), control1: point(0.44, 0.66), control2: point(0.40, 0.72))
            path.addCurve(to: point(0.16, 0.50), control1: point(0.20, 0.74), control2: point(0.16, 0.64))
            path.addCurve(to: point(0.30, 0.26), control1: point(0.16, 0.36), control2: point(0.20, 0.26))
            path.closeSubpath()

            path.move(to: point(0.70, 0.26))
            path.addCurve(to: point(0.56, 0.44), control1: point(0.60, 0.28), control2: point(0.56, 0.34))
            path.addCurve(to: point(0.56, 0.56), control1: point(0.62, 0.48), control2: point(0.62, 0.52))
            path.addCurve(to: point(0.70, 0.74), control1: point(0.56, 0.66), control2: point(0.60, 0.72))
            path.addCurve(to: point(0.84, 0.50), control1: point(0.80, 0.74), control2: point(0.84, 0.64))
            path.addCurve(to: point(0.70, 0.26), control1: point(0.84, 0.36), control2: point(0.80, 0.26))
            path.closeSubpath()

        case .abdomen:
            path.addRoundedRect(in: box(0.16, 0.16, 0.84, 0.84), cornerSize: CGSize(width: side * 0.14, height: side * 0.14))
            path.addEllipse(in: box(0.40, 0.40, 0.60, 0.60))
            path.move(to: point(0.50, 0.16))
            path.addLine(to: point(0.50, 0.40))
            path.move(to: point(0.50, 0.60))
            path.addLine(to: point(0.50, 0.84))
            path.move(to: point(0.16, 0.50))
            path.addLine(to: point(0.40, 0.50))
            path.move(to: point(0.60, 0.50))
            path.addLine(to: point(0.84, 0.50))

        case .muscles:
            path.move(to: point(0.50, 0.16))
            path.addCurve(to: point(0.72, 0.50), control1: point(0.66, 0.26), control2: point(0.72, 0.40))
            path.addCurve(to: point(0.50, 0.84), control1: point(0.72, 0.60), control2: point(0.66, 0.74))
            path.addCurve(to: point(0.28, 0.50), control1: point(0.34, 0.74), control2: point(0.28, 0.60))
            path.addCurve(to: point(0.50, 0.16), control1: point(0.28, 0.40), control2: point(0.34, 0.26))
            path.closeSubpath()

            path.move(to: point(0.44, 0.24))
            path.addCurve(to: point(0.44, 0.76), control1: point(0.37, 0.40), control2: point(0.37, 0.60))
            path.move(to: point(0.56, 0.24))
            path.addCurve(to: point(0.56, 0.76), control1: point(0.63, 0.40), control2: point(0.63, 0.60))

        case .skeleton:
            path.move(to: point(0.50, 0.22))
            path.addCurve(to: point(0.40, 0.16), control1: point(0.48, 0.16), control2: point(0.44, 0.14))
            path.addCurve(to: point(0.34, 0.28), control1: point(0.30, 0.18), control2: point(0.28, 0.26))
            path.addCurve(to: point(0.44, 0.34), control1: point(0.38, 0.31), control2: point(0.42, 0.32))
            path.addLine(to: point(0.44, 0.66))
            path.addCurve(to: point(0.34, 0.72), control1: point(0.42, 0.68), control2: point(0.38, 0.69))
            path.addCurve(to: point(0.40, 0.84), control1: point(0.28, 0.74), control2: point(0.30, 0.82))
            path.addCurve(to: point(0.50, 0.78), control1: point(0.44, 0.86), control2: point(0.48, 0.84))
            path.addCurve(to: point(0.60, 0.84), control1: point(0.52, 0.84), control2: point(0.56, 0.86))
            path.addCurve(to: point(0.66, 0.72), control1: point(0.70, 0.82), control2: point(0.72, 0.74))
            path.addCurve(to: point(0.56, 0.66), control1: point(0.62, 0.69), control2: point(0.58, 0.68))
            path.addLine(to: point(0.56, 0.34))
            path.addCurve(to: point(0.66, 0.28), control1: point(0.58, 0.32), control2: point(0.62, 0.31))
            path.addCurve(to: point(0.60, 0.16), control1: point(0.72, 0.26), control2: point(0.70, 0.18))
            path.addCurve(to: point(0.50, 0.22), control1: point(0.56, 0.14), control2: point(0.52, 0.16))
            path.closeSubpath()
        }

        return path
    }
}

#Preview {
    ZStack {
        Theme.background.ignoresSafeArea()
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 24) {
            ForEach(BodyRegion.allCases) { region in
                VStack(spacing: 10) {
                    RegionIcon(region: region, size: 44, color: Theme.accent)
                    Text(region.displayName)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .padding(24)
    }
    .preferredColorScheme(.dark)
}

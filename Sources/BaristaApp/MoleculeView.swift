import AppKit
import SwiftUI

enum MoleculeStyle: String, CaseIterable, Identifiable {
    case catppuccinLatte

    var id: String { rawValue }

    var palette: MoleculePalette {
        switch self {
        case .catppuccinLatte:
            return MoleculePalette(
                carbon: Color(hex: 0x8839EF),
                nitrogen: Color(hex: 0x1E66F5),
                oxygen: Color(hex: 0xD20F39),
                hydrogen: Color(hex: 0x179299)
            )
        }
    }

    var glowColors: [Color] {
        // Catppuccin Latte accents: mauve, blue, sapphire, peach.
        [
            Color(hex: 0x8839EF),
            Color(hex: 0x1E66F5),
            Color(hex: 0x209FB5),
            Color(hex: 0xFE640B)
        ]
    }

    var lineStyle: AnyShapeStyle {
        let colors = [palette.carbon, palette.nitrogen, palette.oxygen, palette.hydrogen]
            .map { $0.opacity(0.9) }
        return AnyShapeStyle(LinearGradient(colors: colors,
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing))
    }

    var lineWidth: CGFloat { 1.6 }

    var nodeSize: CGFloat { 6 }

    func atomFill(for kind: AtomKind) -> AnyShapeStyle {
        let color: Color
        switch kind {
        case .oxygen:
            color = palette.oxygen
        case .nitrogen:
            color = palette.nitrogen
        case .methyl:
            color = palette.hydrogen
        case .carbon:
            color = palette.carbon
        }

        let top = color.opacity(1.0)
        let bottom = color.opacity(0.8)
        return AnyShapeStyle(
            LinearGradient(colors: [top, bottom],
                           startPoint: .topLeading,
                           endPoint: .bottomTrailing)
        )
    }
}

struct MoleculeIcon: View {
    let style: MoleculeStyle

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let atoms: [Atom] = [
                Atom(point: CGPoint(x: w * 0.30, y: h * 0.26), kind: .nitrogen),
                Atom(point: CGPoint(x: w * 0.48, y: h * 0.22), kind: .carbon),
                Atom(point: CGPoint(x: w * 0.62, y: h * 0.32), kind: .carbon),
                Atom(point: CGPoint(x: w * 0.62, y: h * 0.56), kind: .carbon),
                Atom(point: CGPoint(x: w * 0.44, y: h * 0.68), kind: .carbon),
                Atom(point: CGPoint(x: w * 0.26, y: h * 0.58), kind: .nitrogen),
                Atom(point: CGPoint(x: w * 0.74, y: h * 0.26), kind: .nitrogen),
                Atom(point: CGPoint(x: w * 0.82, y: h * 0.46), kind: .carbon),
                Atom(point: CGPoint(x: w * 0.72, y: h * 0.64), kind: .nitrogen),
                Atom(point: CGPoint(x: w * 0.12, y: h * 0.14), kind: .methyl),
                Atom(point: CGPoint(x: w * 0.10, y: h * 0.74), kind: .methyl),
                Atom(point: CGPoint(x: w * 0.90, y: h * 0.18), kind: .methyl),
                Atom(point: CGPoint(x: w * 0.48, y: h * 0.06), kind: .oxygen),
                Atom(point: CGPoint(x: w * 0.40, y: h * 0.88), kind: .oxygen)
            ]

            let bonds: [Bond] = [
                Bond(a: 0, b: 1, kind: .single),
                Bond(a: 1, b: 2, kind: .single),
                Bond(a: 2, b: 3, kind: .single),
                Bond(a: 3, b: 4, kind: .single),
                Bond(a: 4, b: 5, kind: .single),
                Bond(a: 5, b: 0, kind: .single),

                Bond(a: 2, b: 6, kind: .single),
                Bond(a: 6, b: 7, kind: .single),
                Bond(a: 7, b: 8, kind: .single),
                Bond(a: 8, b: 3, kind: .single),
                Bond(a: 3, b: 2, kind: .single),

                Bond(a: 0, b: 9, kind: .single),
                Bond(a: 5, b: 10, kind: .single),
                Bond(a: 6, b: 11, kind: .single),

                Bond(a: 1, b: 12, kind: .double),
                Bond(a: 4, b: 13, kind: .double)
            ]

            ZStack {
                let bondPath = Path { path in
                    for bond in bonds {
                        addBond(to: &path,
                                from: atoms[bond.a].point,
                                to: atoms[bond.b].point,
                                kind: bond.kind,
                                offset: style.lineWidth * 0.6)
                    }
                }

                bondPath
                    .stroke(style.lineStyle,
                            style: StrokeStyle(lineWidth: style.lineWidth,
                                               lineCap: .round,
                                               lineJoin: .round))

                ForEach(0..<atoms.count, id: \.self) { index in
                    let atom = atoms[index]
                    Circle()
                        .fill(style.atomFill(for: atom.kind))
                        .frame(width: nodeSize(for: atom.kind), height: nodeSize(for: atom.kind))
                        .position(atom.point)
                        .shadow(color: Color.black.opacity(0.12), radius: 0.8, x: 0, y: 0)
                }
            }
        }
    }

    private func nodeSize(for kind: AtomKind) -> CGFloat {
        switch kind {
        case .methyl:
            return style.nodeSize * 0.8
        case .oxygen:
            return style.nodeSize * 1.0
        default:
            return style.nodeSize
        }
    }

    private func addBond(to path: inout Path, from start: CGPoint, to end: CGPoint, kind: BondKind, offset: CGFloat) {
        switch kind {
        case .single:
            path.move(to: start)
            path.addLine(to: end)
        case .double:
            let dx = end.x - start.x
            let dy = end.y - start.y
            let length = max(1, sqrt(dx * dx + dy * dy))
            let ox = -dy / length * offset
            let oy = dx / length * offset
            let a1 = CGPoint(x: start.x + ox, y: start.y + oy)
            let b1 = CGPoint(x: end.x + ox, y: end.y + oy)
            let a2 = CGPoint(x: start.x - ox, y: start.y - oy)
            let b2 = CGPoint(x: end.x - ox, y: end.y - oy)
            path.move(to: a1)
            path.addLine(to: b1)
            path.move(to: a2)
            path.addLine(to: b2)
        }
    }
}

enum AtomKind {
    case carbon
    case nitrogen
    case oxygen
    case methyl
}

struct Atom {
    let point: CGPoint
    let kind: AtomKind
}

enum BondKind {
    case single
    case double
}

struct Bond {
    let a: Int
    let b: Int
    let kind: BondKind
}

struct MoleculeActiveGlow: View {
    let colors: [Color]
    let isActive: Bool
    let isVisible: Bool

    private let transitionDuration: TimeInterval = 3
    private let tickInterval: TimeInterval = 0.12

    var body: some View {
        Group {
            if isActive && isVisible {
                TimelineView(.periodic(from: .now, by: tickInterval)) { context in
                    let color = interpolatedColor(at: context.date)
                    GeometryReader { geo in
                        let size = min(geo.size.width, geo.size.height)
                        let glowRadius = size * 0.55
                        let innerRadius = size * 0.18
                        let outerRadius = size * 0.32

                        ZStack {
                            Circle()
                                .fill(
                                    RadialGradient(colors: [
                                        color.opacity(0.9),
                                        color.opacity(0.45),
                                        color.opacity(0)
                                    ], center: .center, startRadius: 0, endRadius: glowRadius)
                                )
                                .frame(width: size, height: size)
                                .blur(radius: outerRadius)

                            Circle()
                                .fill(color.opacity(0.55))
                                .frame(width: size * 0.5, height: size * 0.5)
                                .blur(radius: innerRadius)
                        }
                        .frame(width: size, height: size)
                    }
                }
            } else {
                Color.clear
            }
        }
    }

    private func interpolatedColor(at date: Date) -> Color {
        guard colors.count > 1 else { return colors.first ?? .clear }
        let total = transitionDuration * Double(colors.count)
        let t = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: total)
        let index = Int(t / transitionDuration)
        let progress = (t / transitionDuration) - Double(index)
        let c1 = colors[index % colors.count]
        let c2 = colors[(index + 1) % colors.count]
        return Color.lerp(from: c1, to: c2, t: progress)
    }
}

struct MoleculePalette {
    let carbon: Color
    let nitrogen: Color
    let oxygen: Color
    let hydrogen: Color
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }

    static func lerp(from: Color, to: Color, t: Double) -> Color {
        let a = from.rgba
        let b = to.rgba
        let r = a.r + (b.r - a.r) * t
        let g = a.g + (b.g - a.g) * t
        let bval = a.b + (b.b - a.b) * t
        let o = a.a + (b.a - a.a) * t
        return Color(.sRGB, red: r, green: g, blue: bval, opacity: o)
    }

    private var rgba: (r: Double, g: Double, b: Double, a: Double) {
        let ns = NSColor(self).usingColorSpace(.sRGB) ?? .white
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        ns.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Double(r), Double(g), Double(b), Double(a))
    }
}

import SwiftUI

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

/// The same slate, baize and brass palette as the web scoreboard.
enum Palette {
    static let slate = Color(hex: 0x15181A)
    static let slateTop = Color(hex: 0x23292B)
    static let sink = Color(hex: 0x0F1113)
    static let rail = Color(hex: 0x1C2124)
    static let railEdge = Color(hex: 0x2C3337)
    static let baize = Color(hex: 0x13503A)
    static let baizeLit = Color(hex: 0x1A6B4C)
    static let baizeDeep = Color(hex: 0x0F3F2E)
    static let cushion = Color(hex: 0x4A3418)
    static let brass = Color(hex: 0xC9A24A)
    static let brassDim = Color(hex: 0x8A6F33)
    static let chalk = Color(hex: 0xF2ECE0)
    static let chalkDim = Color(hex: 0x9AA39C)
    static let ink = Color(hex: 0x1A1407)
    static let chip = Color(hex: 0x0D2C20)
    static let foulRed = Color(hex: 0xC4231F)

    static func ball(_ value: Int) -> (fill: Color, label: Color) {
        switch value {
        case 1: (Color(hex: 0xC4231F), .white)
        case 2: (Color(hex: 0xE8C23A), Color(hex: 0x2A2202))
        case 3: (Color(hex: 0x1F7A46), .white)
        case 4: (Color(hex: 0x6B4328), .white)
        case 5: (Color(hex: 0x1F5FB0), .white)
        case 6: (Color(hex: 0xE2749A), Color(hex: 0x40131F))
        default: (Color(hex: 0x141414), .white)
        }
    }
}

extension Font {
    /// Condensed system type stands in for the web version's Oswald.
    static func board(_ size: CGFloat, _ weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight).width(.condensed)
    }
}

/// Small uppercase label above a group of controls.
struct Eyebrow: View {
    let text: String
    var color = Palette.brass

    var body: some View {
        Text(text.uppercased())
            .font(.board(11, .semibold))
            .tracking(1.6)
            .foregroundStyle(color)
    }
}

/// The table's rectangular buttons: fouls, red off, undo, new frame, end visit.
struct ChipStyle: ButtonStyle {
    var prominent = false

    func makeBody(configuration: Configuration) -> some View {
        ChipBody(configuration: configuration, prominent: prominent)
    }

    private struct ChipBody: View {
        let configuration: Configuration
        let prominent: Bool
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(.board(prominent ? 17 : 14, .semibold))
                .tracking(0.8)
                .textCase(.uppercase)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(prominent ? Palette.ink : Palette.chalk)
                .frame(maxWidth: .infinity, minHeight: prominent ? 50 : 42)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(prominent ? Palette.brass : Palette.chip.opacity(0.85))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(prominent ? Palette.brass : Color.white.opacity(0.17))
                )
                .opacity(isEnabled ? 1 : 0.35)
                .scaleEffect(configuration.isPressed ? 0.96 : 1)
                .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
        }
    }
}

struct BallPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

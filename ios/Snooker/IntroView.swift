import SwiftUI

/// The three-second Snookerin intro shown when the app opens: the cue strikes the white,
/// which rolls across and uncovers the name. Every frame is a pure function of the time
/// since it started, so it plays the same on every launch.
struct IntroView: View {
    static let duration: Double = 3
    let onFinish: () -> Void

    /// Set on the first frame on screen, not at init: launch can take most of a second
    /// and the opening of the animation would play unseen behind it.
    @State private var start: Date?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation) { context in
            let t = reduceMotion ? 2.5 : start.map { context.date.timeIntervalSince($0) } ?? 0
            GeometryReader { geo in
                ZStack {
                    IntroBackdrop()
                    CueStrikeScene(t: t, size: geo.size)
                }
            }
        }
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .onTapGesture(perform: onFinish)
        .onAppear { start = .now }
        .task {
            try? await Task.sleep(for: .seconds(reduceMotion ? 1.2 : IntroView.duration))
            onFinish()
        }
        .accessibilityElement()
        .accessibilityLabel("Snookerin. Keep score to lose to Raj.")
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Opens the scoreboard")
    }
}

// MARK: - shared pieces

private struct IntroBackdrop: View {
    var body: some View {
        ZStack {
            RadialGradient(colors: [Palette.baizeLit, Palette.baize, Palette.baizeDeep, Color(hex: 0x0A2A1F)],
                           center: .center, startRadius: 20, endRadius: 520)
            // the nap of the cloth
            Canvas { ctx, size in
                var x: CGFloat = 0
                while x < size.width {
                    ctx.fill(Path(CGRect(x: x, y: 0, width: 1, height: size.height)), with: .color(.white.opacity(0.025)))
                    x += 4
                }
            }
        }
        .ignoresSafeArea()
    }
}

/// "Snookerin" and the tag line, springing in at `appearAt`.
private struct Wordmark: View {
    let t: Double
    let appearAt: Double
    var revealTagline = true

    var body: some View {
        let title = spring(clamp((t - appearAt) / 0.55))
        let tag = ease(clamp((t - appearAt - 0.45) / 0.4))
        VStack(spacing: 10) {
            Text("Snookerin")
                .font(.system(size: 54, design: .serif).italic())
                .foregroundStyle(LinearGradient(colors: [Color(hex: 0xF3D9A0), Palette.brass],
                                                startPoint: .top, endPoint: .bottom))
                .shadow(color: .black.opacity(0.45), radius: 8, y: 4)
                .scaleEffect(0.6 + 0.4 * title)
                .opacity(min(1, title * 1.5))
            if revealTagline {
                Text("Keep score to lose to Raj")
                    .font(.board(15, .semibold))
                    .tracking(2.2)
                    .textCase(.uppercase)
                    .foregroundStyle(Palette.chalk.opacity(0.92))
                    .opacity(tag)
                    .offset(y: 8 * (1 - tag))
            }
        }
    }
}

/// Draws a lit snooker ball: base colour, shade underneath, highlight up-left.
private func drawBall(_ ctx: GraphicsContext, at c: CGPoint, r: CGFloat, color: Color, shadow: Bool = true) {
    let rect = CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)
    if shadow {
        ctx.fill(Path(ellipseIn: rect.offsetBy(dx: r * 0.18, dy: r * 0.35).insetBy(dx: r * 0.08, dy: r * 0.25)),
                 with: .color(.black.opacity(0.35)))
    }
    let circle = Path(ellipseIn: rect)
    ctx.fill(circle, with: .color(color))
    ctx.fill(circle, with: .linearGradient(Gradient(colors: [.clear, .black.opacity(0.45)]),
                                           startPoint: CGPoint(x: c.x, y: c.y - r * 0.2),
                                           endPoint: CGPoint(x: c.x, y: c.y + r)))
    ctx.fill(circle, with: .radialGradient(Gradient(colors: [.white.opacity(0.85), .white.opacity(0.15), .clear]),
                                           center: CGPoint(x: c.x - r * 0.38, y: c.y - r * 0.45),
                                           startRadius: 0, endRadius: r * 0.75))
}

private let cueWhite = Color(hex: 0xF4F1E8)

// MARK: - the cue strike

private struct CueStrikeScene: View {
    let t: Double
    let size: CGSize

    var body: some View {
        let r = size.width * 0.045
        let lineY = size.height * 0.46
        let strike = 0.75
        let startX = size.width * 0.18
        let endX = size.width + r * 2
        let roll = easeOut(clamp((t - strike) / 0.9))
        let ballX = startX + (endX - startX) * CGFloat(roll)

        ZStack {
            Canvas { ctx, size in
                // the cue: draws back, then follows through
                let back = t < 0.35
                    ? -size.width * 0.05 * CGFloat(easeOut(clamp(t / 0.35)))
                    : t < strike
                        ? -size.width * 0.05 - size.width * 0.12 * CGFloat(easeOut(clamp((t - 0.35) / 0.25)))
                        : 0
                let thrust = t < strike - 0.1 ? 0 : size.width * 0.17 * CGFloat(easeOut(clamp((t - strike + 0.1) / 0.12)))
                let tipX = startX - r - 4 + back + thrust - (t > 1.1 ? size.width * CGFloat(easeIn(clamp((t - 1.1) / 0.5))) : 0)
                let length = size.width * 0.95
                var cue = Path()
                cue.move(to: CGPoint(x: tipX, y: lineY - 3.5))
                cue.addLine(to: CGPoint(x: tipX - length, y: lineY - 8))
                cue.addLine(to: CGPoint(x: tipX - length, y: lineY + 8))
                cue.addLine(to: CGPoint(x: tipX, y: lineY + 3.5))
                cue.closeSubpath()
                ctx.fill(cue, with: .linearGradient(Gradient(colors: [Color(hex: 0xE3C08A), Color(hex: 0xA8733C), Color(hex: 0x3B2210)]),
                                                    startPoint: CGPoint(x: tipX, y: lineY),
                                                    endPoint: CGPoint(x: tipX - length, y: lineY)))
                ctx.fill(Path(CGRect(x: tipX - 10, y: lineY - 3.7, width: 8, height: 7.4)), with: .color(Color(hex: 0xF2EEE4)))
                ctx.fill(Path(CGRect(x: tipX - 3, y: lineY - 3.5, width: 3, height: 7)), with: .color(Color(hex: 0x2E6FD0)))

                // a puff of blue chalk at the strike
                let puff = clamp((t - strike) / 0.45)
                if puff > 0, puff < 1 {
                    for k in 0..<10 {
                        let a = Double(k) * 0.63 + 2.2
                        let dist = CGFloat(puff) * (14 + CGFloat(k % 3) * 9)
                        let pr = 2.5 * CGFloat(1 - puff) + 1
                        let c = CGPoint(x: startX - r + CGFloat(cos(a)) * dist, y: lineY + CGFloat(sin(a)) * dist)
                        ctx.fill(Path(ellipseIn: CGRect(x: c.x - pr, y: c.y - pr, width: 2 * pr, height: 2 * pr)),
                                 with: .color(Color(hex: 0x6FA3F0).opacity(0.8 * (1 - puff))))
                    }
                }

                // a faint track behind the rolling white
                if roll > 0 {
                    ctx.fill(Path(CGRect(x: startX, y: lineY - r * 0.12, width: ballX - startX, height: r * 0.24)),
                             with: .linearGradient(Gradient(colors: [.clear, .white.opacity(0.18)]),
                                                   startPoint: CGPoint(x: startX, y: lineY),
                                                   endPoint: CGPoint(x: ballX, y: lineY)))
                }
                drawBall(ctx, at: CGPoint(x: ballX, y: lineY), r: r, color: cueWhite)
            }

            // the title is uncovered as the white rolls past it
            Wordmark(t: t, appearAt: 0.75, revealTagline: false)
                .mask(alignment: .leading) {
                    Rectangle().frame(width: max(0, ballX - (size.width - 300) / 2))
                }
                .frame(width: 300)
                .position(x: size.width / 2, y: lineY - r - 44)
            Text("Keep score to lose to Raj")
                .font(.board(15, .semibold))
                .tracking(2.2)
                .textCase(.uppercase)
                .foregroundStyle(Palette.chalk.opacity(0.92))
                .opacity(ease(clamp((t - 1.6) / 0.4)))
                .position(x: size.width / 2, y: lineY + r + 30)
        }
    }
}

// MARK: - easing

private func clamp(_ x: Double) -> Double { min(1, max(0, x)) }
private func ease(_ x: Double) -> Double { x * x * (3 - 2 * x) }
private func easeIn(_ x: Double) -> Double { x * x * x }
private func easeOut(_ x: Double) -> Double { 1 - pow(1 - x, 3) }
/// Slight overshoot, then settle.
private func spring(_ x: Double) -> Double {
    x <= 0 ? 0 : 1 - exp(-6 * x) * cos(9 * x)
}

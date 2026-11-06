import SwiftUI

/// The three-second Snookerin intro shown when the app opens. Every frame is a pure
/// function of the time since it started, so the animation is the same on every launch.
enum IntroStyle: String, CaseIterable {
    case breakOff, potTheBlack, ballLetters, cueStrike

    static let duration: Double = 3

    /// `-introStyle potTheBlack` on the launch arguments picks a style (UserDefaults reads them).
    static var current: IntroStyle {
        UserDefaults.standard.string(forKey: "introStyle").flatMap(IntroStyle.init) ?? .breakOff
    }
}

struct IntroView: View {
    let style: IntroStyle
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
                    scene(t: t, size: geo.size)
                }
            }
        }
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .onTapGesture(perform: onFinish)
        .onAppear { start = .now }
        .task {
            try? await Task.sleep(for: .seconds(reduceMotion ? 1.2 : IntroStyle.duration))
            onFinish()
        }
        .accessibilityElement()
        .accessibilityLabel("Snookerin. Keep score to lose to Raj.")
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Opens the scoreboard")
    }

    @ViewBuilder
    private func scene(t: Double, size: CGSize) -> some View {
        switch style {
        case .breakOff:
            BreakOffScene(t: t, size: size)
            Wordmark(t: t, appearAt: 1.05).position(x: size.width / 2, y: size.height * 0.62)
        case .potTheBlack:
            PotTheBlackScene(t: t, size: size)
            Wordmark(t: t, appearAt: 1.75).position(x: size.width / 2, y: size.height * 0.6)
        case .ballLetters:
            BallLettersScene(t: t, size: size)
        case .cueStrike:
            CueStrikeScene(t: t, size: size)
        }
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

// MARK: - 1. break-off: the white smashes the pack

private struct BreakOffScene: View {
    let t: Double
    let size: CGSize

    var body: some View {
        Canvas { ctx, size in
            let r = size.width * 0.04
            let apex = CGPoint(x: size.width / 2, y: size.height * 0.44)
            let hit = 0.55
            let rowStep = 2 * r * 0.88

            // fifteen reds racked in a triangle, apex towards the white
            var reds: [CGPoint] = []
            for row in 0..<5 {
                for i in 0...row {
                    reds.append(CGPoint(x: apex.x + (CGFloat(i) - CGFloat(row) / 2) * 2.02 * r,
                                        y: apex.y - CGFloat(row) * rowStep))
                }
            }
            let packCentre = CGPoint(x: apex.x, y: apex.y - 2 * rowStep)

            for (n, red) in reds.enumerated() {
                var p = red
                if t > hit {
                    // outward from the pack, turned by a fixed per-ball amount so the
                    // spread looks random but is the same every launch
                    let outward = atan2(Double(red.y - packCentre.y), Double(red.x - packCentre.x))
                    let angle = outward + sin(Double(n) * 12.9898) * 1.1
                    let dx = CGFloat(cos(angle)), dy = CGFloat(sin(angle))
                    let speed = 430 * (0.5 + 0.6 * abs(sin(Double(n) * 4.1)))
                    let travel = CGFloat(decay(t - hit, k: 2.4) * speed)
                    p = CGPoint(x: fold(red.x + dx * travel, lo: r, hi: size.width - r),
                                y: fold(red.y + dy * travel, lo: r, hi: size.height - r))
                }
                drawBall(ctx, at: p, r: r, color: Palette.ball(1).fill)
            }

            // the white: in from the baulk end, then a stun-run-through after contact
            let startY = size.height * 0.92
            let contactY = apex.y + 2 * r
            let cueY: CGFloat = t < hit
                ? startY + (contactY - startY) * CGFloat(easeIn(clamp((t - 0.1) / (hit - 0.1))))
                : contactY + CGFloat(decay(t - hit, k: 3) * 160)
            drawBall(ctx, at: CGPoint(x: apex.x, y: cueY), r: r, color: cueWhite)

            // a flash of chalk on impact
            let flash = clamp(1 - (t - hit) / 0.25)
            if t > hit, flash > 0 {
                let fr = r * (1.5 + 3 * (1 - flash))
                ctx.fill(Path(ellipseIn: CGRect(x: apex.x - fr, y: contactY - r - fr, width: 2 * fr, height: 2 * fr)),
                         with: .color(.white.opacity(0.5 * flash)))
            }
        }
    }
}

// MARK: - 2. pot the black: it rattles in the jaws, then drops

private struct PotTheBlackScene: View {
    let t: Double
    let size: CGSize

    var body: some View {
        Canvas { ctx, size in
            let r = size.width * 0.075
            let pocket = CGPoint(x: size.width / 2, y: size.height * 0.33)
            let pr = r * 1.45

            // leather rim and the hole
            ctx.fill(Path(ellipseIn: CGRect(x: pocket.x - pr * 1.35, y: pocket.y - pr * 1.35, width: pr * 2.7, height: pr * 2.7)),
                     with: .color(Color(hex: 0x3A2612)))
            ctx.fill(Path(ellipseIn: CGRect(x: pocket.x - pr, y: pocket.y - pr, width: pr * 2, height: pr * 2)),
                     with: .radialGradient(Gradient(colors: [.black, Color(hex: 0x050505), Color(hex: 0x1A1A1A)]),
                                           center: pocket, startRadius: 0, endRadius: pr))

            // roll in on a curve from the bottom left, rattle on the jaw, then drop
            let roll = easeOut(clamp(t / 1.15))
            let from = CGPoint(x: -r * 2, y: size.height * 0.95)
            let control = CGPoint(x: size.width * 0.15, y: size.height * 0.35)
            let jaw = CGPoint(x: pocket.x - pr * 0.55, y: pocket.y + pr * 0.55)
            var p = bezier(from, control, jaw, CGFloat(roll))

            var scale: CGFloat = 1
            var alpha: Double = 1
            if t > 1.15 {
                // two rattles on the jaw
                let s = clamp((t - 1.15) / 0.4)
                let wobble = CGFloat(sin(s * .pi * 4) * (1 - s)) * r * 0.25
                p = CGPoint(x: jaw.x + wobble, y: jaw.y - wobble * 0.5)
            }
            if t > 1.55 {
                let d = easeIn(clamp((t - 1.55) / 0.25))
                p = CGPoint(x: jaw.x + (pocket.x - jaw.x) * CGFloat(d), y: jaw.y + (pocket.y - jaw.y) * CGFloat(d))
                scale = 1 - 0.45 * CGFloat(d)
                alpha = 1 - d
            }
            if alpha > 0 {
                var layer = ctx
                layer.opacity = alpha
                drawBall(layer, at: p, r: r * scale, color: Palette.ball(7).fill, shadow: t < 1.55)
            }

            // a ring of brass light when it drops
            let glow = clamp((t - 1.75) / 0.6)
            if glow > 0, glow < 1 {
                let gr = pr * (1.2 + 2.2 * CGFloat(glow))
                ctx.stroke(Path(ellipseIn: CGRect(x: pocket.x - gr, y: pocket.y - gr, width: gr * 2, height: gr * 2)),
                           with: .color(Palette.brass.opacity(0.7 * (1 - glow))), lineWidth: 4)
            }
        }
    }
}

// MARK: - 3. ball letters: S-N-O-O-K-E-R-I-N drop in on the balls

private struct BallLettersScene: View {
    let t: Double
    let size: CGSize

    private let letters = Array("SNOOKERIN")
    private let values = [1, 2, 3, 4, 5, 6, 7, 1, 1]

    var body: some View {
        let gap: CGFloat = 4
        let d = min(44, (size.width - 32 - gap * 8) / 9)
        let rowY = size.height * 0.45
        let rowWidth = d * 9 + gap * 8
        let tag = ease(clamp((t - 1.75) / 0.45))

        ZStack {
            ForEach(0..<9, id: \.self) { i in
                let local = clamp((t - 0.15 - Double(i) * 0.11) / 0.75)
                let drop = bounce(local)
                let x = (size.width - rowWidth) / 2 + d / 2 + CGFloat(i) * (d + gap)
                let y = -d + (rowY + d) * CGFloat(drop)
                // a little hop along the row once they have all landed
                let hop = t > 1.6 ? CGFloat(max(0, sin((t - 1.6 - Double(i) * 0.06) * 9))) * 6 * CGFloat(clamp(2.4 - t)) : 0
                LetterBall(letter: String(letters[i]), value: values[i], diameter: d)
                    .position(x: x, y: y - hop)
                    .opacity(local > 0 ? 1 : 0)
            }
            Text("Keep score to lose to Raj")
                .font(.board(15, .semibold))
                .tracking(2.2)
                .textCase(.uppercase)
                .foregroundStyle(Palette.chalk.opacity(0.92))
                .opacity(tag)
                .offset(y: 8 * (1 - tag))
                .position(x: size.width / 2, y: rowY + d + 18)
        }
    }
}

private struct LetterBall: View {
    let letter: String
    let value: Int
    let diameter: CGFloat

    var body: some View {
        let colours = Palette.ball(value)
        ZStack {
            Circle().fill(colours.fill)
            Circle().fill(LinearGradient(colors: [.clear, .black.opacity(0.4)], startPoint: .center, endPoint: .bottom))
            Circle().fill(RadialGradient(colors: [.white.opacity(0.8), .white.opacity(0.15), .clear],
                                         center: UnitPoint(x: 0.32, y: 0.26), startRadius: 0, endRadius: diameter * 0.4))
            Text(letter)
                .font(.board(diameter * 0.52, .bold))
                .foregroundStyle(colours.label)
        }
        .frame(width: diameter, height: diameter)
        .shadow(color: .black.opacity(0.45), radius: 3, y: 3)
    }
}

// MARK: - 4. cue strike: the white writes the name as it rolls

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
/// The standard ease-out bounce: a ball dropped onto the cloth.
private func bounce(_ x: Double) -> Double {
    let n = 7.5625, d = 2.75
    if x < 1 / d { return n * x * x }
    if x < 2 / d { let y = x - 1.5 / d; return n * y * y + 0.75 }
    if x < 2.5 / d { let y = x - 2.25 / d; return n * y * y + 0.9375 }
    let y = x - 2.625 / d
    return n * y * y + 0.984375
}
/// Distance covered by something slowing under friction: (1 - e^-kt) / k.
private func decay(_ t: Double, k: Double) -> Double { (1 - exp(-k * t)) / k }
/// Keeps a coordinate inside [lo, hi] by bouncing it off the cushions.
private func fold(_ v: CGFloat, lo: CGFloat, hi: CGFloat) -> CGFloat {
    let span = hi - lo
    var x = (v - lo).truncatingRemainder(dividingBy: 2 * span)
    if x < 0 { x += 2 * span }
    return lo + (x > span ? 2 * span - x : x)
}
private func bezier(_ a: CGPoint, _ c: CGPoint, _ b: CGPoint, _ t: CGFloat) -> CGPoint {
    let u = 1 - t
    return CGPoint(x: u * u * a.x + 2 * u * t * c.x + t * t * b.x,
                   y: u * u * a.y + 2 * u * t * c.y + t * t * b.y)
}

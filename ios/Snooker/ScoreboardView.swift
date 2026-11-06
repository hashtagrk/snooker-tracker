import SwiftUI
import UIKit

/// The whole frame on one screen: header, one row per player, and the table controls
/// anchored at the bottom where a thumb reaches them.
struct ScoreboardView: View {
    let board: Scoreboard
    /// Back to the setup screen to change who is playing.
    var onChangePlayers: () -> Void = {}
    @State private var confirmingNewFrame = false
    @FocusState private var editingSeat: Int?

    private var frame: Frame { board.frame }

    var body: some View {
        VStack(spacing: 10) {
            header
            rails
            table
            Text(ruleNote)
                .font(.board(11))
                .tracking(0.6)
                .textCase(.uppercase)
                .foregroundStyle(Palette.chalkDim)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.top, 4)
        .padding(.bottom, 2)
        .background(background)
        .ignoresSafeArea(.keyboard)
        .confirmationDialog("Start a new frame?", isPresented: $confirmingNewFrame, titleVisibility: .visible) {
            Button("Same players", role: .destructive) {
                board.newFrame()
                haptic(.heavy)
            }
            Button("Change players") { onChangePlayers() }
        } message: {
            Text("Scores and the reds reset.")
        }
    }

    // MARK: header

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(handed) \(Text("Snooker").italic().foregroundStyle(Palette.brass))")
                .font(.system(size: 28, design: .serif))
                .foregroundStyle(Palette.chalk)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            HStack(alignment: .bottom, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Eyebrow(text: "Players")
                    Picker("Players", selection: playersBinding) {
                        ForEach(Array(Frame.playerRange), id: \.self) { Text("\($0)").tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 160)
                }
                if frame.players > 2 {
                    // with two players both rules give the points to the same person
                    VStack(alignment: .leading, spacing: 4) {
                        Eyebrow(text: "Fouls to")
                        Picker("Foul points go to", selection: foulRuleBinding) {
                            Text(frame.players == 3 ? "Both" : "All").tag(FoulRule.allOpponents)
                            Text("Next").tag(FoulRule.nextPlayer)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 120)
                    }
                }
                Spacer(minLength: 0)
            }

            Rectangle().fill(Palette.brassDim).frame(height: 1)
        }
    }

    private var handed: String {
        ["Two", "Three", "Four", "Five"][frame.players - 2] + "-Handed"
    }

    private var playersBinding: Binding<Int> {
        Binding(get: { frame.players }, set: { count in
            editingSeat = nil
            board.apply { $0.setPlayers(count) }
            haptic(.light)
        })
    }

    private var foulRuleBinding: Binding<FoulRule> {
        Binding(get: { frame.foulRule }, set: { rule in board.apply { $0.foulRule = rule } })
    }

    // MARK: player rows

    private var rails: some View {
        VStack(spacing: 6) {
            ForEach(0..<frame.players, id: \.self) { seat in
                PlayerRow(
                    seat: seat,
                    name: Binding(get: { frame.names[seat] }, set: { board.rename(seat: seat, to: $0) }),
                    score: frame.scores[seat],
                    tally: tally(for: seat),
                    atTable: seat == frame.current,
                    editingSeat: $editingSeat
                )
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .animation(.snappy(duration: 0.25), value: frame.players)
        .animation(.snappy(duration: 0.25), value: frame.current)
    }

    private func tally(for seat: Int) -> String {
        let high = frame.highBreaks[seat]
        guard seat == frame.current else { return "High break \(high)" }
        return high > 0 ? "Break \(frame.currentBreak) · high \(high)" : "Break \(frame.currentBreak)"
    }

    // MARK: table

    private var table: some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow(text: potLabel, color: Color(hex: 0xD8EBDF))

            HStack(alignment: .top, spacing: 6) {
                ForEach(Ball.all) { ball in
                    VStack(spacing: 3) {
                        BallButton(
                            ball: ball,
                            isOn: frame.canPot(ball.value),
                            isOffTable: frame.isOffTable(ball.value)
                        ) {
                            board.apply { $0.pot(ball.value) }
                            haptic(.light)
                        }
                        Text(ball.value == 1 && frame.reds > 0 ? "\(frame.reds) left" : " ")
                            .font(.board(10, .semibold))
                            .foregroundStyle(Palette.chalk)
                            .monospacedDigit()
                    }
                }
            }

            HStack(spacing: 6) {
                ForEach(4...7, id: \.self) { value in
                    Button("Foul \(value)") {
                        board.apply { $0.foul(value) }
                        UINotificationFeedbackGenerator().notificationOccurred(.warning)
                    }
                    .accessibilityLabel("Foul, \(value) points")
                }
            }
            .buttonStyle(ChipStyle())

            Grid(horizontalSpacing: 6) {
                GridRow {
                    Button("Red off — no score") {
                        board.apply { $0.redOff() }
                        haptic(.light)
                    }
                    .disabled(frame.reds == 0)
                    .gridCellColumns(2)
                    Button("Undo") {
                        board.undo()
                        haptic(.light)
                    }
                    .disabled(!board.canUndo)
                    Button("New frame") { confirmingNewFrame = true }
                }
            }
            .buttonStyle(ChipStyle())

            Button("End visit") {
                board.apply { $0.endVisit() }
                haptic(.medium)
            }
            .buttonStyle(ChipStyle(prominent: true))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(LinearGradient(colors: [Palette.baizeLit, Palette.baize, Palette.baizeDeep],
                                     startPoint: .top, endPoint: .bottom))
        )
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Palette.cushion, lineWidth: 5))
    }

    private var potLabel: String {
        if frame.reds > 0 { return "Pot" }
        if frame.freeColour { return "Pot — any colour after the last red" }
        if frame.on <= 7 { return "Colours in order — \(Ball.all[frame.on - 1].name.lowercased()) is on" }
        return "Table cleared"
    }

    private var ruleNote: String {
        if frame.foulRule == .nextPlayer { return "A foul gives its points to the next player" }
        switch frame.players {
        case 2: return "A foul gives its points to the opponent"
        case 3: return "A foul gives its points to both opponents"
        default: return "A foul gives its points to all opponents"
        }
    }

    private var background: some View {
        RadialGradient(colors: [Palette.slateTop, Palette.slate, Palette.sink],
                       center: UnitPoint(x: 0.5, y: -0.1), startRadius: 0, endRadius: 700)
            .ignoresSafeArea()
    }

    private func haptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
}

private struct PlayerRow: View {
    let seat: Int
    @Binding var name: String
    let score: Int
    let tally: String
    let atTable: Bool
    var editingSeat: FocusState<Int?>.Binding

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                TextField("Player \(seat + 1)", text: $name)
                    .font(.board(16, .semibold))
                    .foregroundStyle(Palette.chalk)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .focused(editingSeat, equals: seat)
                    .accessibilityLabel("Player \(seat + 1) name")
                Text(tally.uppercased())
                    .font(.board(11, .medium))
                    .tracking(0.8)
                    .foregroundStyle(atTable ? Color(hex: 0xCFE3D6) : Palette.chalkDim)
                    .monospacedDigit()
            }
            Spacer(minLength: 0)
            Text("\(score)")
                .font(.board(34, .semibold))
                .monospacedDigit()
                .foregroundStyle(Palette.chalk)
                .contentTransition(.numericText(value: Double(score)))
                .animation(.snappy, value: score)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, minHeight: 40, maxHeight: 62)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(atTable
                      ? AnyShapeStyle(LinearGradient(colors: [Palette.baizeLit, Palette.baize],
                                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                      : AnyShapeStyle(Palette.rail))
        )
        .overlay(alignment: .leading) {
            UnevenRoundedRectangle(topLeadingRadius: 10, bottomLeadingRadius: 10)
                .fill(atTable ? Palette.brass : Palette.railEdge)
                .frame(width: 4)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(atTable ? Palette.brassDim : Color(hex: 0x262C2F))
        )
        .accessibilityElement(children: .contain)
        .accessibilityValue(atTable ? "At the table, \(score) points" : "\(score) points")
    }
}

private struct BallButton: View {
    let ball: Ball
    let isOn: Bool
    let isOffTable: Bool
    let action: () -> Void

    var body: some View {
        let colours = Palette.ball(ball.value)
        Button(action: action) {
            ZStack {
                Circle().fill(colours.fill)
                // shade underneath and a highlight up-left make it read as a ball
                Circle().fill(LinearGradient(colors: [.clear, .black.opacity(0.4)],
                                             startPoint: .center, endPoint: .bottom))
                Circle().fill(RadialGradient(colors: [.white.opacity(0.8), .white.opacity(0.2), .clear],
                                             center: UnitPoint(x: 0.32, y: 0.26),
                                             startRadius: 0, endRadius: 20))
                Text("\(ball.value)")
                    .font(.board(18, .semibold))
                    .foregroundStyle(colours.label)
            }
            .aspectRatio(1, contentMode: .fit)
            .shadow(color: .black.opacity(0.5), radius: 3, y: 3)
        }
        .buttonStyle(BallPressStyle())
        .disabled(!isOn || isOffTable)
        .opacity(isOffTable ? 0 : (isOn ? 1 : 0.3))
        .animation(.easeOut(duration: 0.2), value: isOffTable)
        .accessibilityLabel("Pot \(ball.name.lowercased()), \(ball.value) \(ball.value == 1 ? "point" : "points")")
        .accessibilityHidden(isOffTable)
    }
}

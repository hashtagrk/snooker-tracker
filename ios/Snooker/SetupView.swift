import SwiftUI
import UIKit

/// The first screen after the intro: how many are playing, and who. Saved players can
/// be seated with a tap; a typed name can be starred to save it for next time.
struct SetupView: View {
    let board: Scoreboard
    let roster: Roster
    let onStart: () -> Void

    @State private var count: Int
    @State private var seats: [String]
    @FocusState private var editingSeat: Int?

    init(board: Scoreboard, roster: Roster, onStart: @escaping () -> Void) {
        self.board = board
        self.roster = roster
        self.onStart = onStart
        // last frame's line-up, so the usual group only has to press Start
        _count = State(initialValue: board.frame.players)
        _seats = State(initialValue: board.frame.names)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Snookerin")
                    .font(.system(size: 34, design: .serif).italic())
                    .foregroundStyle(Palette.brass)
                Text("Keep score to lose to Raj")
                    .font(.board(12, .semibold))
                    .tracking(1.8)
                    .textCase(.uppercase)
                    .foregroundStyle(Palette.chalkDim)
            }

            VStack(alignment: .leading, spacing: 8) {
                Eyebrow(text: "How many players?")
                HStack(spacing: 8) {
                    ForEach(Array(Frame.playerRange), id: \.self) { n in
                        Button("\(n)") { setCount(n) }
                            .buttonStyle(CountStyle(selected: n == count))
                            .accessibilityLabel("\(n) players")
                            .accessibilityAddTraits(n == count ? .isSelected : [])
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Eyebrow(text: "Who's playing?")
                ForEach(0..<count, id: \.self) { seat in
                    seatRow(seat)
                }
            }
            .animation(.snappy(duration: 0.25), value: count)

            if !roster.names.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Eyebrow(text: "Saved players")
                    FlowLayout(spacing: 8) {
                        ForEach(roster.names, id: \.self) { name in
                            savedChip(name)
                        }
                    }
                    Text("Tap to seat or unseat · press and hold to remove")
                        .font(.board(11))
                        .foregroundStyle(Palette.chalkDim)
                }
            }

            Spacer(minLength: 0)

            VStack(spacing: 8) {
                if board.frameInProgress {
                    Button("Resume frame") { onStart() }
                        .buttonStyle(ChipStyle())
                }
                Button("Start frame") {
                    editingSeat = nil
                    board.startFrame(players: count, names: Array(seats.prefix(count)))
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onStart()
                }
                .buttonStyle(ChipStyle(prominent: true))
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RadialGradient(colors: [Palette.slateTop, Palette.slate, Palette.sink],
                           center: UnitPoint(x: 0.5, y: -0.1), startRadius: 0, endRadius: 700)
                .ignoresSafeArea()
        )
        .ignoresSafeArea(.keyboard)
        .onTapGesture { editingSeat = nil }
    }

    // MARK: seats

    private func seatRow(_ seat: Int) -> some View {
        let name = seats[seat].trimmingCharacters(in: .whitespacesAndNewlines)
        let saved = !name.isEmpty && roster.contains(name)
        let colours = Palette.ball([1, 2, 3, 5, 6][seat])
        return HStack(spacing: 10) {
            Text("\(seat + 1)")
                .font(.board(14, .bold))
                .foregroundStyle(colours.label)
                .frame(width: 28, height: 28)
                .background(Circle().fill(colours.fill))
            TextField("Player \(seat + 1)", text: $seats[seat])
                .font(.board(18, .semibold))
                .foregroundStyle(Palette.chalk)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(seat + 1 < count ? .next : .done)
                .focused($editingSeat, equals: seat)
                .onSubmit { editingSeat = seat + 1 < count ? seat + 1 : nil }
                .accessibilityLabel("Player \(seat + 1) name")
            Button {
                saved ? roster.remove(name) : roster.add(name)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                Image(systemName: saved ? "star.fill" : "star")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(saved ? Palette.brass : Palette.chalkDim)
                    .frame(width: 40, height: 40)
            }
            .disabled(name.isEmpty)
            .opacity(name.isEmpty ? 0.3 : 1)
            .accessibilityLabel(saved ? "Remove \(name) from saved players" : "Save \(name.isEmpty ? "this name" : name) for next time")
        }
        .padding(.leading, 10)
        .frame(minHeight: 48)
        .background(RoundedRectangle(cornerRadius: 10).fill(Palette.rail))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color(hex: 0x262C2F)))
    }

    private func seat(of name: String) -> Int? {
        let key = Roster.normalised(name)
        return (0..<count).first { Roster.normalised(seats[$0]) == key }
    }

    // MARK: saved players

    private func savedChip(_ name: String) -> some View {
        let seated = seat(of: name) != nil
        return Button { toggle(name) } label: {
            HStack(spacing: 5) {
                if seated { Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)) }
                Text(name)
            }
            .font(.board(15, .semibold))
            .foregroundStyle(seated ? Palette.ink : Palette.chalk)
            .padding(.horizontal, 14)
            .frame(minHeight: 36)
            .background(Capsule().fill(seated ? Palette.brass : Palette.chip))
            .overlay(Capsule().strokeBorder(seated ? Palette.brass : Color.white.opacity(0.17)))
        }
        .buttonStyle(BallPressStyle())
        .contextMenu {
            Button("Remove from saved players", systemImage: "trash", role: .destructive) { roster.remove(name) }
        }
        .accessibilityLabel(seated ? "\(name), seated" : name)
        .accessibilityHint(seated ? "Takes \(name) out of the frame" : "Seats \(name)")
    }

    /// Seated → unseat. Otherwise take the first empty seat, adding a player if every
    /// seat is taken and there is room for one more.
    private func toggle(_ name: String) {
        editingSeat = nil
        if let seat = seat(of: name) {
            seats[seat] = ""
        } else if let empty = (0..<count).first(where: { seats[$0].trimmingCharacters(in: .whitespaces).isEmpty }) {
            seats[empty] = name
        } else if count < Frame.playerRange.upperBound {
            count += 1
            seats[count - 1] = name
        } else {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            return
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func setCount(_ n: Int) {
        count = n
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}

private struct CountStyle: ButtonStyle {
    let selected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.board(24, .semibold))
            .foregroundStyle(selected ? Palette.ink : Palette.chalk)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(RoundedRectangle(cornerRadius: 12).fill(selected ? Palette.brass : Palette.rail))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(selected ? Palette.brass : Color(hex: 0x2C3337)))
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

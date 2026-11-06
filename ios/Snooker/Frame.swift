import Foundation

/// Who receives the points when a player fouls.
enum FoulRule: String, Codable, CaseIterable {
    case allOpponents
    case nextPlayer
}

struct Ball: Identifiable {
    let value: Int
    let name: String
    var id: Int { value }

    static let all: [Ball] = [
        Ball(value: 1, name: "Red"),
        Ball(value: 2, name: "Yellow"),
        Ball(value: 3, name: "Green"),
        Ball(value: 4, name: "Brown"),
        Ball(value: 5, name: "Blue"),
        Ball(value: 6, name: "Pink"),
        Ball(value: 7, name: "Black"),
    ]
}

/// One frame of snooker for two to five players. Pure value type: every rule lives here
/// so it can be unit-tested without the UI.
struct Frame: Codable, Equatable {
    static let playerRange = 2...5
    static let seats = 5

    /// Arrays always hold `seats` entries; `players` says how many are in the frame.
    var players = 3
    var names = Array(repeating: "", count: Frame.seats)
    var scores = Array(repeating: 0, count: Frame.seats)
    var highBreaks = Array(repeating: 0, count: Frame.seats)
    var current = 0
    var currentBreak = 0
    var reds = 15
    /// The colour to clear next once the reds are gone; 8 means the table is cleared.
    var on = 2
    /// Right after the last red is potted the striker may take any one colour, and it is
    /// re-spotted. Cleared when that colour is potted or the visit ends.
    var freeColour = false
    var foulRule = FoulRule.allOpponents

    var nextPlayer: Int { (current + 1) % players }
    var isCleared: Bool { reds == 0 && !freeColour && on > 7 }

    /// While reds remain, and for the one colour after the last red, every colour is on.
    /// After that the colours come off in order, so only the lowest one left can be potted.
    func canPot(_ value: Int) -> Bool {
        if value == 1 { return reds > 0 }
        if reds > 0 || freeColour { return true }
        return value == on
    }

    /// The red once all fifteen are gone, and each colour cleared in sequence.
    func isOffTable(_ value: Int) -> Bool {
        if value == 1 { return reds == 0 }
        return reds == 0 && !freeColour && value < on
    }

    mutating func pot(_ value: Int) {
        guard canPot(value) else { return }
        scores[current] += value
        currentBreak += value
        highBreaks[current] = max(highBreaks[current], currentBreak)
        if value == 1 {
            reds -= 1
            if reds == 0 { freeColour = true }
        } else if freeColour {
            freeColour = false
        } else if reds == 0 {
            on += 1
        }
    }

    mutating func foul(_ value: Int) {
        switch foulRule {
        case .allOpponents:
            for seat in 0..<players where seat != current { scores[seat] += value }
        case .nextPlayer:
            scores[nextPlayer] += value
        }
        passTurn()
    }

    /// A red potted on a foul stroke: off the table, no points, the visit carries on.
    mutating func redOff() {
        guard reds > 0 else { return }
        reds -= 1
    }

    mutating func endVisit() {
        passTurn()
    }

    mutating func setPlayers(_ count: Int) {
        guard Frame.playerRange.contains(count), count != players else { return }
        // seats that leave the frame lose their points, so adding them back starts them at zero
        for seat in count..<Frame.seats {
            scores[seat] = 0
            highBreaks[seat] = 0
        }
        if current >= count {
            current = 0
            currentBreak = 0
            freeColour = false
        }
        players = count
    }

    /// A fresh frame that keeps the names, the player count and the foul rule.
    func newFrame() -> Frame {
        var fresh = Frame()
        fresh.names = names
        fresh.players = players
        fresh.foulRule = foulRule
        return fresh
    }

    private mutating func passTurn() {
        currentBreak = 0
        freeColour = false
        current = nextPlayer
    }
}

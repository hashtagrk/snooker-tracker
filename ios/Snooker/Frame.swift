import Foundation

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

/// One thing that happened at the table, kept so the frame's history can be shown.
struct Shot: Codable, Equatable {
    enum Kind: String, Codable { case pot, foul, redOff, endVisit, select }
    var kind: Kind
    var seat: Int
    var value = 0
}

/// One player's turn at the table, as the history page shows it.
struct Visit: Identifiable, Equatable {
    let id: Int
    let seat: Int
    var balls: [Int] = []
    var foul: Int?

    var points: Int { balls.reduce(0, +) }
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
    /// While reds remain, a colour is on only straight after a red.
    var colourOn = false
    /// The colour to clear next once the reds are gone; 8 means the table is cleared.
    var on = 2
    /// Right after the last red is potted the striker may take any one colour, and it is
    /// re-spotted. Cleared when that colour is potted or the visit ends.
    var freeColour = false
    /// Everything that happened in the frame, oldest first.
    var log: [Shot] = []

    init() {}

    var nextPlayer: Int { (current + 1) % players }
    var isCleared: Bool { reds == 0 && !freeColour && on > 7 }

    func name(of seat: Int) -> String {
        names[seat].isEmpty ? "Player \(seat + 1)" : names[seat]
    }

    /// Red, then a colour, then red again while reds remain. After the last red any one
    /// colour may be taken; after that the colours come off in order.
    func canPot(_ value: Int) -> Bool {
        if value == 1 { return reds > 0 && !colourOn }
        if reds > 0 { return colourOn }
        if freeColour { return true }
        return value == on
    }

    /// The red once all fifteen are gone, and each colour cleared in sequence.
    func isOffTable(_ value: Int) -> Bool {
        if value == 1 { return reds == 0 }
        return reds == 0 && !freeColour && value < on
    }

    mutating func pot(_ value: Int) {
        guard canPot(value) else { return }
        log.append(Shot(kind: .pot, seat: current, value: value))
        scores[current] += value
        currentBreak += value
        highBreaks[current] = max(highBreaks[current], currentBreak)
        if value == 1 {
            reds -= 1
            if reds == 0 { freeColour = true } else { colourOn = true }
        } else if reds > 0 {
            colourOn = false
        } else if freeColour {
            freeColour = false
        } else {
            on += 1
        }
    }

    /// Every opponent receives the foul points; the visit ends.
    mutating func foul(_ value: Int) {
        log.append(Shot(kind: .foul, seat: current, value: value))
        for seat in 0..<players where seat != current { scores[seat] += value }
        passTurn()
    }

    /// Puts a different player at the table, for when the turn order went astray.
    mutating func select(_ seat: Int) {
        guard (0..<players).contains(seat), seat != current else { return }
        log.append(Shot(kind: .select, seat: seat))
        resetVisit()
        current = seat
    }

    /// A red potted on a foul stroke: off the table, no points, the visit carries on.
    mutating func redOff() {
        guard reds > 0 else { return }
        log.append(Shot(kind: .redOff, seat: current))
        reds -= 1
    }

    mutating func endVisit() {
        log.append(Shot(kind: .endVisit, seat: current))
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
            resetVisit()
        }
        players = count
    }

    /// A fresh frame that keeps the names and the player count.
    func newFrame() -> Frame {
        var fresh = Frame()
        fresh.names = names
        fresh.players = players
        return fresh
    }

    /// The log grouped into visits that scored or fouled, oldest first. Misses are left out.
    var visits: [Visit] {
        var result: [Visit] = []
        var open: Visit?
        func close() {
            if let visit = open, !visit.balls.isEmpty || visit.foul != nil { result.append(visit) }
            open = nil
        }
        for (index, shot) in log.enumerated() {
            if open?.seat != shot.seat {
                close()
                open = Visit(id: index, seat: shot.seat)
            }
            switch shot.kind {
            case .pot: open?.balls.append(shot.value)
            case .foul: open?.foul = shot.value; close()
            case .endVisit, .select: close()
            case .redOff: break
            }
        }
        close()
        return result
    }

    private mutating func passTurn() {
        resetVisit()
        current = nextPlayer
    }

    private mutating func resetVisit() {
        currentBreak = 0
        colourOn = false
        freeColour = false
    }

    // Frames saved by earlier versions lack the newer fields; fill them with defaults.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        players = try c.decodeIfPresent(Int.self, forKey: .players) ?? 3
        names = try c.decodeIfPresent([String].self, forKey: .names) ?? names
        scores = try c.decodeIfPresent([Int].self, forKey: .scores) ?? scores
        highBreaks = try c.decodeIfPresent([Int].self, forKey: .highBreaks) ?? highBreaks
        current = try c.decodeIfPresent(Int.self, forKey: .current) ?? 0
        currentBreak = try c.decodeIfPresent(Int.self, forKey: .currentBreak) ?? 0
        reds = try c.decodeIfPresent(Int.self, forKey: .reds) ?? 15
        colourOn = try c.decodeIfPresent(Bool.self, forKey: .colourOn) ?? false
        on = try c.decodeIfPresent(Int.self, forKey: .on) ?? 2
        freeColour = try c.decodeIfPresent(Bool.self, forKey: .freeColour) ?? false
        log = try c.decodeIfPresent([Shot].self, forKey: .log) ?? []
    }
}

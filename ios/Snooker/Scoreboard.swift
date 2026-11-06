import Foundation
import Observation

/// Holds the frame and its undo history, and saves both so a frame survives the app
/// being closed mid-game.
@MainActor
@Observable
final class Scoreboard {
    private(set) var frame: Frame
    private(set) var history: [Frame]
    /// Frames that were played before this one, oldest first, for the history page.
    private(set) var pastFrames: [Frame]

    private let defaults: UserDefaults
    private static let key = "snooker.frame.v1"
    private static let historyLimit = 200
    private static let pastFrameLimit = 30

    private struct Saved: Codable {
        var frame: Frame
        var history: [Frame]
        var pastFrames: [Frame]

        init(frame: Frame, history: [Frame], pastFrames: [Frame]) {
            self.frame = frame
            self.history = history
            self.pastFrames = pastFrames
        }

        // saves from before past frames were kept have no `pastFrames`
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            frame = try c.decode(Frame.self, forKey: .frame)
            history = try c.decodeIfPresent([Frame].self, forKey: .history) ?? []
            pastFrames = try c.decodeIfPresent([Frame].self, forKey: .pastFrames) ?? []
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.key),
           let saved = try? JSONDecoder().decode(Saved.self, from: data) {
            frame = saved.frame
            history = saved.history
            pastFrames = saved.pastFrames
        } else {
            frame = Frame()
            history = []
            pastFrames = []
        }
    }

    var canUndo: Bool { !history.isEmpty }

    /// Applies one scoring action as a single undo step. Actions that change nothing
    /// (a ball that is not on, say) leave no step behind.
    func apply(_ change: (inout Frame) -> Void) {
        var next = frame
        change(&next)
        guard next != frame else { return }
        history.append(frame)
        if history.count > Self.historyLimit { history.removeFirst() }
        frame = next
        save()
    }

    func undo() {
        guard var previous = history.popLast() else { return }
        // names are not scoring actions; undo never reverts a rename
        previous.names = frame.names
        frame = previous
        save()
    }

    func rename(seat: Int, to name: String) {
        frame.names[seat] = String(name.prefix(18))
        save()
    }

    /// True once anything has been scored, so the setup screen can offer to resume.
    var frameInProgress: Bool {
        canUndo || frame.reds < 15 || frame.scores.contains { $0 != 0 }
    }

    /// Starts a fresh frame with the players chosen on the setup screen.
    func startFrame(players: Int, names: [String]) {
        var fresh = Frame()
        fresh.setPlayers(players)
        for seat in 0..<min(names.count, Frame.seats) {
            fresh.names[seat] = String(names[seat].trimmingCharacters(in: .whitespacesAndNewlines).prefix(18))
        }
        archive()
        frame = fresh
        history = []
        save()
    }

    func newFrame() {
        archive()
        frame = frame.newFrame()
        history = []
        save()
    }

    /// Keeps a frame that was actually played so the history page can show it.
    private func archive() {
        guard frameInProgress else { return }
        pastFrames.append(frame)
        if pastFrames.count > Self.pastFrameLimit { pastFrames.removeFirst() }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(Saved(frame: frame, history: history, pastFrames: pastFrames)) {
            defaults.set(data, forKey: Self.key)
        }
    }
}

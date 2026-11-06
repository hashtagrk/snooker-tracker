import Foundation
import Observation

/// Holds the frame and its undo history, and saves both so a frame survives the app
/// being closed mid-game.
@MainActor
@Observable
final class Scoreboard {
    private(set) var frame: Frame
    private(set) var history: [Frame]

    private let defaults: UserDefaults
    private static let key = "snooker.frame.v1"
    private static let historyLimit = 200

    private struct Saved: Codable {
        var frame: Frame
        var history: [Frame]
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.key),
           let saved = try? JSONDecoder().decode(Saved.self, from: data) {
            frame = saved.frame
            history = saved.history
        } else {
            frame = Frame()
            history = []
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

    func newFrame() {
        frame = frame.newFrame()
        history = []
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(Saved(frame: frame, history: history)) {
            defaults.set(data, forKey: Self.key)
        }
    }
}

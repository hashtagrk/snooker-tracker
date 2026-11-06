import Foundation
import Observation

/// Saved player names, offered on the setup screen so a regular group is seated in a
/// few taps instead of typed out every frame.
@MainActor
@Observable
final class Roster {
    static let defaultNames = ["Raj", "Ajay", "Anvay", "Ninad"]

    private(set) var names: [String]

    private let defaults: UserDefaults
    private static let key = "snooker.roster.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // only a first launch gets the defaults; an emptied list stays empty
        names = defaults.stringArray(forKey: Self.key) ?? Self.defaultNames
    }

    func contains(_ name: String) -> Bool {
        let key = Self.normalised(name)
        return names.contains { Self.normalised($0) == key }
    }

    func add(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !contains(trimmed) else { return }
        names.append(String(trimmed.prefix(18)))
        save()
    }

    func remove(_ name: String) {
        let key = Self.normalised(name)
        names.removeAll { Self.normalised($0) == key }
        save()
    }

    private func save() {
        defaults.set(names, forKey: Self.key)
    }

    static func normalised(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

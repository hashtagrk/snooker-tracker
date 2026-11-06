import XCTest
@testable import Snooker

final class FrameTests: XCTestCase {
    func testFoulGoesToEveryOpponentWithFivePlayers() {
        var frame = Frame()
        frame.setPlayers(5)
        frame.current = 2
        frame.foul(4)
        XCTAssertEqual(Array(frame.scores.prefix(5)), [4, 4, 0, 4, 4])
        XCTAssertEqual(frame.current, 3)
    }

    func testFoulWithTwoPlayersGoesToTheOpponent() {
        var frame = Frame()
        frame.setPlayers(2)
        frame.current = 1
        frame.foul(7)
        XCTAssertEqual(Array(frame.scores.prefix(2)), [7, 0])
        XCTAssertEqual(frame.current, 0)
    }

    func testSelectingAPlayerPutsThemAtTheTable() {
        var frame = Frame()
        frame.setPlayers(4)
        frame.pot(1)
        frame.select(2)
        XCTAssertEqual(frame.current, 2)
        XCTAssertEqual(frame.currentBreak, 0, "a new visit starts")
        XCTAssertEqual(frame.scores[0], 1, "points already scored stay")
        frame.select(4)
        XCTAssertEqual(frame.current, 2, "seat 5 is not in a four-player frame")
    }

    func testRotationWrapsAtPlayerCount() {
        var frame = Frame()
        frame.setPlayers(2)
        frame.endVisit()
        frame.endVisit()
        XCTAssertEqual(frame.current, 0)
    }

    func testRemovedSeatComesBackAtZero() {
        var frame = Frame()
        frame.setPlayers(5)
        frame.current = 4
        frame.pot(1)
        frame.pot(7)
        frame.setPlayers(3)
        XCTAssertEqual(frame.current, 0, "the player at the table left, so the turn resets")
        frame.setPlayers(5)
        XCTAssertEqual(frame.scores[4], 0)
        XCTAssertEqual(frame.highBreaks[4], 0)
    }

    func testPlayerCountStaysInRange() {
        var frame = Frame()
        frame.setPlayers(1)
        frame.setPlayers(6)
        XCTAssertEqual(frame.players, 3)
    }

    func testRedThenColourWhileRedsRemain() {
        var frame = Frame()
        XCTAssertEqual((1...7).filter(frame.canPot), [1], "a visit starts on a red")
        frame.pot(5)
        XCTAssertEqual(frame.scores[0], 0, "a colour cannot be potted first")
        frame.pot(1)
        XCTAssertEqual((1...7).filter(frame.canPot), [2, 3, 4, 5, 6, 7], "a colour after a red")
        frame.pot(7)
        XCTAssertEqual((1...7).filter(frame.canPot), [1], "back to a red")
        frame.pot(1)
        frame.endVisit()
        XCTAssertEqual((1...7).filter(frame.canPot), [1], "the next visit starts on a red")
        XCTAssertFalse((1...7).contains(where: frame.isOffTable))
    }

    func testFoulAfterARedPutsTheNextPlayerOnARed() {
        var frame = Frame()
        frame.pot(1)
        frame.foul(4)
        XCTAssertEqual((1...7).filter(frame.canPot), [1])
    }

    func testVisitsGroupPotsAndFoulsAndSkipMisses() {
        var frame = Frame()
        frame.setPlayers(2)
        frame.pot(1); frame.pot(7); frame.pot(1); frame.pot(6)
        frame.endVisit()                 // player 1: 15
        frame.endVisit()                 // player 2 misses: not shown
        frame.pot(1); frame.foul(5)      // player 1 pots a red, then fouls
        frame.select(0)                  // turn order corrected
        frame.pot(1)
        XCTAssertEqual(frame.visits.map(\.seat), [0, 0, 0])
        XCTAssertEqual(frame.visits.map(\.balls), [[1, 7, 1, 6], [1], [1]])
        XCTAssertEqual(frame.visits.map(\.foul), [nil, 5, nil])
        XCTAssertEqual(frame.visits[0].points, 15)
    }

    func testOldSavesWithoutNewFieldsStillLoad() throws {
        let json = #"{"players":2,"names":["A","B","","",""],"scores":[5,0,0,0,0],"highBreaks":[5,0,0,0,0],"current":0,"currentBreak":0,"reds":14,"on":2,"freeColour":false,"foulRule":"allOpponents"}"#
        let frame = try JSONDecoder().decode(Frame.self, from: Data(json.utf8))
        XCTAssertEqual(frame.scores[0], 5)
        XCTAssertEqual(frame.log, [])
        XCTAssertFalse(frame.colourOn)
    }

    func testColourAfterLastRedIsReSpotted() {
        var frame = Frame()
        frame.reds = 1
        frame.pot(1)
        XCTAssertTrue(frame.freeColour)
        XCTAssertFalse(frame.canPot(1))
        XCTAssertTrue((2...7).allSatisfy(frame.canPot), "any colour may follow the last red")

        frame.pot(6)
        XCTAssertFalse(frame.freeColour)
        XCTAssertEqual(frame.on, 2, "the pink went back on its spot; clearing starts at yellow")
        XCTAssertEqual((2...7).filter(frame.canPot), [2])
    }

    func testColoursComeOffInOrder() {
        var frame = Frame()
        frame.reds = 0
        frame.pot(5)
        XCTAssertEqual(frame.scores[0], 0, "blue is not on before yellow")

        frame.pot(2)
        frame.pot(3)
        XCTAssertTrue(frame.isOffTable(2))
        XCTAssertTrue(frame.isOffTable(3))
        XCTAssertTrue(frame.isOffTable(1), "no reds left, so the red is gone too")
        XCTAssertEqual((2...7).filter(frame.canPot), [4])

        for value in 4...7 { frame.pot(value) }
        XCTAssertTrue(frame.isCleared)
        XCTAssertTrue((1...7).allSatisfy { !frame.canPot($0) })
        XCTAssertEqual(frame.scores[0], 27)
        XCTAssertEqual(frame.highBreaks[0], 27)
    }

    func testMissingTheFreeColourStartsClearanceAtYellow() {
        var frame = Frame()
        frame.reds = 1
        frame.pot(1)
        frame.endVisit()
        XCTAssertFalse(frame.freeColour)
        XCTAssertEqual((2...7).filter(frame.canPot), [2])
    }

    func testLastRedOffOnAFoulGivesNoFreeColour() {
        var frame = Frame()
        frame.reds = 1
        frame.redOff()
        XCTAssertEqual(frame.reds, 0)
        XCTAssertFalse(frame.freeColour)
        XCTAssertEqual((2...7).filter(frame.canPot), [2])
    }

    func testBreaksAndHighBreaks() {
        var frame = Frame()
        frame.pot(1)
        frame.pot(7)
        frame.endVisit()
        frame.endVisit()
        frame.endVisit()
        frame.pot(1)
        XCTAssertEqual(frame.scores[0], 9)
        XCTAssertEqual(frame.highBreaks[0], 8)
        XCTAssertEqual(frame.currentBreak, 1)
    }

    func testNewFrameKeepsNamesAndPlayers() {
        var frame = Frame()
        frame.names[0] = "Asha"
        frame.setPlayers(4)
        frame.pot(1)
        let fresh = frame.newFrame()
        XCTAssertEqual(fresh.names[0], "Asha")
        XCTAssertEqual(fresh.players, 4)
        XCTAssertEqual(fresh.scores, Array(repeating: 0, count: Frame.seats))
        XCTAssertEqual(fresh.reds, 15)
    }
}

@MainActor
final class ScoreboardTests: XCTestCase {
    private func freshDefaults() -> UserDefaults {
        let suite = "snooker.tests.\(UUID().uuidString)"
        return UserDefaults(suiteName: suite)!
    }

    func testUndoStepsBackButKeepsNames() {
        let board = Scoreboard(defaults: freshDefaults())
        board.apply { $0.pot(1) }
        board.rename(seat: 0, to: "Asha")
        board.undo()
        XCTAssertEqual(board.frame.scores[0], 0)
        XCTAssertEqual(board.frame.names[0], "Asha")
        XCTAssertFalse(board.canUndo)
    }

    func testIllegalPotLeavesNoUndoStep() {
        let board = Scoreboard(defaults: freshDefaults())
        board.apply { $0.reds = 0 }
        board.apply { $0.pot(7) }
        XCTAssertEqual(board.history.count, 1)
    }

    func testFrameAndHistorySurviveRelaunch() {
        let defaults = freshDefaults()
        let board = Scoreboard(defaults: defaults)
        board.apply { $0.setPlayers(5) }
        board.apply { $0.pot(1) }
        board.rename(seat: 1, to: "Ben")

        let reopened = Scoreboard(defaults: defaults)
        XCTAssertEqual(reopened.frame, board.frame)
        XCTAssertEqual(reopened.history.count, 2)
        reopened.undo()
        XCTAssertEqual(reopened.frame.scores[0], 0)
        XCTAssertEqual(reopened.frame.players, 5)
    }

    func testNewFrameClearsHistory() {
        let board = Scoreboard(defaults: freshDefaults())
        board.apply { $0.pot(1) }
        board.newFrame()
        XCTAssertFalse(board.canUndo)
        XCTAssertEqual(board.frame.reds, 15)
    }

    func testStartFrameSeatsChosenPlayers() {
        let board = Scoreboard(defaults: freshDefaults())
        board.apply { $0.pot(1) }
        board.startFrame(players: 4, names: ["Raj", " Ajay ", "", "Ninad"])
        XCTAssertEqual(board.frame.players, 4)
        XCTAssertEqual(Array(board.frame.names.prefix(4)), ["Raj", "Ajay", "", "Ninad"])
        XCTAssertEqual(board.frame.scores[0], 0)
        XCTAssertFalse(board.frameInProgress)
    }
}

@MainActor
final class RosterTests: XCTestCase {
    private func freshDefaults() -> UserDefaults {
        UserDefaults(suiteName: "snooker.roster.tests.\(UUID().uuidString)")!
    }

    func testFirstLaunchHasTheDefaultGroup() {
        XCTAssertEqual(Roster(defaults: freshDefaults()).names, ["Raj", "Ajay", "Anvay", "Ninad"])
    }

    func testAddIgnoresBlanksAndDuplicatesAnyCase() {
        let roster = Roster(defaults: freshDefaults())
        roster.add("  ")
        roster.add("raj")
        roster.add(" Vik ")
        XCTAssertEqual(roster.names, ["Raj", "Ajay", "Anvay", "Ninad", "Vik"])
    }

    func testRemoveAndPersist() {
        let defaults = freshDefaults()
        let roster = Roster(defaults: defaults)
        roster.remove("AJAY")
        roster.add("Vik")
        XCTAssertEqual(Roster(defaults: defaults).names, ["Raj", "Anvay", "Ninad", "Vik"])
    }

    func testAnEmptiedListStaysEmpty() {
        let defaults = freshDefaults()
        let roster = Roster(defaults: defaults)
        Roster.defaultNames.forEach(roster.remove)
        XCTAssertEqual(Roster(defaults: defaults).names, [])
    }
}

@MainActor
final class PastFrameTests: XCTestCase {
    func testPlayedFramesAreKeptForHistory() {
        let board = Scoreboard(defaults: UserDefaults(suiteName: "snooker.past.\(UUID().uuidString)")!)
        board.newFrame()
        XCTAssertEqual(board.pastFrames.count, 0, "an unplayed frame is not kept")
        board.apply { $0.pot(1) }
        board.newFrame()
        board.apply { $0.pot(1) }
        board.startFrame(players: 2, names: ["Raj", "Ajay"])
        XCTAssertEqual(board.pastFrames.count, 2)
        XCTAssertEqual(board.pastFrames[0].visits.first?.balls, [1])
    }
}

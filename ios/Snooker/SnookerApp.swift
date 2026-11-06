import SwiftUI
import UIKit

@main
struct SnookerApp: App {
    @State private var board = Scoreboard()
    @State private var roster = Roster()
    @State private var showingIntro = true
    @State private var playing = false
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Segmented pickers in the header take the brass-on-slate look of the web version.
        let segments = UISegmentedControl.appearance()
        segments.selectedSegmentTintColor = UIColor(Palette.brass)
        segments.backgroundColor = UIColor(Palette.sink)
        let font = UIFont.systemFont(ofSize: 13, weight: .semibold, width: .condensed)
        segments.setTitleTextAttributes([.foregroundColor: UIColor(Palette.ink), .font: font], for: .selected)
        segments.setTitleTextAttributes([.foregroundColor: UIColor(Palette.chalkDim), .font: font], for: .normal)
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                // intro, then who's playing, then the table
                if playing {
                    ScoreboardView(board: board) {
                        withAnimation(.easeOut(duration: 0.3)) { playing = false }
                    }
                    .transition(.move(edge: .trailing))
                } else {
                    SetupView(board: board, roster: roster) {
                        withAnimation(.easeOut(duration: 0.3)) { playing = true }
                    }
                    .transition(.move(edge: .leading))
                }
                if showingIntro {
                    IntroView {
                        withAnimation(.easeOut(duration: 0.35)) { showingIntro = false }
                    }
                    .transition(.opacity)
                    .zIndex(1)
                }
            }
            .preferredColorScheme(.dark)
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            // The phone sits on the table between shots; it should not lock mid-frame.
            UIApplication.shared.isIdleTimerDisabled = phase == .active
        }
    }
}

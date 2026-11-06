import SwiftUI
import UIKit

@main
struct SnookerApp: App {
    @State private var board = Scoreboard()
    @State private var showingIntro = true
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
                ScoreboardView(board: board)
                if showingIntro {
                    IntroView(style: .current) {
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

import SwiftUI

/// Who potted what, frame by frame: this frame first, newest visit at the top.
struct HistoryView: View {
    let current: Frame
    let past: [Frame]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                frameSection(current, title: "Frame \(past.count + 1) · now")
                ForEach(Array(past.enumerated().reversed()), id: \.offset) { index, frame in
                    frameSection(frame, title: "Frame \(index + 1)")
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Palette.slate.ignoresSafeArea())
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func frameSection(_ frame: Frame, title: String) -> some View {
        Section {
            let visits = frame.visits
            if visits.isEmpty {
                // frames from before history was recorded have scores but no shots
                Text(frame.scores.contains { $0 != 0 } ? "Played before history was kept" : "Nothing potted yet")
                    .font(.board(14))
                    .foregroundStyle(Palette.chalkDim)
                    .listRowBackground(Palette.rail)
            }
            ForEach(visits.reversed()) { visit in
                VisitRow(name: frame.name(of: visit.seat), visit: visit)
                    .listRowBackground(Palette.rail)
            }
        } header: {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.board(13, .semibold))
                    .tracking(1.2)
                    .foregroundStyle(Palette.brass)
                Text(scoreLine(frame))
                    .font(.board(13))
                    .foregroundStyle(Palette.chalk)
                    .textCase(nil)
            }
        }
    }

    private func scoreLine(_ frame: Frame) -> String {
        (0..<frame.players)
            .map { "\(frame.name(of: $0)) \(frame.scores[$0])" }
            .joined(separator: " · ")
    }
}

private struct VisitRow: View {
    let name: String
    let visit: Visit

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(name)
                .font(.board(16, .semibold))
                .foregroundStyle(Palette.chalk)
                .lineLimit(1)
                .frame(width: 84, alignment: .leading)
            FlowLayout(spacing: 4) {
                ForEach(Array(visit.balls.enumerated()), id: \.offset) { _, value in
                    Circle()
                        .fill(Palette.ball(value).fill)
                        .overlay(Circle().strokeBorder(.white.opacity(value == 7 ? 0.35 : 0.1)))
                        .frame(width: 16, height: 16)
                }
                if let foul = visit.foul {
                    Text("Foul \(foul)")
                        .font(.board(12, .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(Palette.foulRed))
                }
            }
            .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 5 }
            Spacer(minLength: 0)
            if visit.points > 0 {
                Text("\(visit.points)")
                    .font(.board(16, .semibold))
                    .monospacedDigit()
                    .foregroundStyle(Palette.chalk)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
    }

    private var label: String {
        var parts = [name]
        if !visit.balls.isEmpty {
            parts.append(visit.balls.map { Ball.all[$0 - 1].name.lowercased() }.joined(separator: ", "))
            parts.append("\(visit.points) points")
        }
        if let foul = visit.foul { parts.append("foul \(foul)") }
        return parts.joined(separator: ", ")
    }
}

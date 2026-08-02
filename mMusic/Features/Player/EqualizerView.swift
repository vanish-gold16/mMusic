import SwiftUI

/// Полоски-«эквалайзер», пляшущие под общий уровень громкости.
/// Уровень один, поэтому каждая полоска тянется к своей цели со своей скоростью —
/// иначе они двигались бы синхронно, как один блок.
struct EqualizerView: View {
    /// Громкость 0...1, обычно `audioPlayer.level`.
    let level: Double

    var barCount: Int = 6
    var barWidth: CGFloat = 3
    var spacing: CGFloat = 2
    var maxHeight: CGFloat = 20

    /// Насколько быстро каждая полоска догоняет свою цель: 1 — мгновенно, 0.2 — лениво.
    private let speeds: [Double] = [0.5, 0.28, 0.7, 0.22, 0.45, 0.6]

    @State private var bars: [Double] = []

    var body: some View {
        HStack(alignment: .center, spacing: spacing) {
            ForEach(bars.indices, id: \.self) { index in
                Capsule()
                    .frame(width: barWidth, height: max(barWidth, bars[index] * maxHeight))
            }
        }
        .frame(height: maxHeight)
        .onAppear {
            if bars.isEmpty {
                bars = Array(repeating: 0, count: barCount)
            }
        }
        .onChange(of: level) { _, newLevel in
            for index in bars.indices {
                let target = newLevel * Double.random(in: 0.35...1)
                let speed = speeds[index % speeds.count]
                bars[index] += (target - bars[index]) * speed
            }
        }
    }
}

#Preview {
    @Previewable @State var level: Double = 0

    EqualizerView(level: level)
        .foregroundStyle(.orange)
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(33))
                level = .random(in: 0.1...1)
            }
        }
}

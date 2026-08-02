import SwiftUI

/// Полоски-«эквалайзер», пляшущие под общий уровень громкости.
/// Уровень один на всех, поэтому каждой полоске один раз выдаётся свой характер:
/// базовая высота, размах и скорость. Иначе они двигались бы синхронно, как один блок.
struct EqualizerView: View {
    /// Громкость 0...1, обычно `audioPlayer.level`.
    let level: Double

    var barCount: Int = 6
    var barWidth: CGFloat = 3
    var spacing: CGFloat = 2
    var maxHeight: CGFloat = 20

    /// Характер одной полоски. Задаётся при появлении вью и больше не меняется.
    private struct BarProfile {
        /// Базовая высота: 1.0 — полоска высокая, 0.45 — низкая.
        let gain: Double
        /// Размах: насколько сильно она гуляет вокруг своей базы.
        let swing: Double
        /// Скорость догона цели: 0.7 — дёргается резко, 0.2 — плывёт лениво.
        let speed: Double
    }

    @State private var bars: [Double] = []
    @State private var profiles: [BarProfile] = []

    var body: some View {
        HStack(alignment: .center, spacing: spacing) {
            ForEach(bars.indices, id: \.self) { index in
                Capsule()
                    .frame(width: barWidth, height: max(barWidth, bars[index] * maxHeight))
            }
        }
        .frame(height: maxHeight)
        .onAppear {
            guard bars.isEmpty else { return }

            bars = Array(repeating: 0, count: barCount)
            profiles = (0..<barCount).map { _ in
                BarProfile(
                    gain: .random(in: 0.30...1.0),
                    swing: .random(in: 0.10...0.50),
                    speed: .random(in: 0.10...0.60)
                )
            }
        }
        .onChange(of: level) { _, newLevel in
            guard profiles.count == bars.count else { return }

            for index in bars.indices {
                let profile = profiles[index]
                let jitter = Double.random(in: -profile.swing...profile.swing)
                let target = min(max(newLevel * (profile.gain + jitter), 0), 1)

                bars[index] += (target - bars[index]) * profile.speed
            }
        }
    }
}

#Preview {
    @Previewable @State var level: Double = 0

    EqualizerView(level: level, barCount: 12, barWidth: 6, spacing: 4, maxHeight: 80)
        .foregroundStyle(.orange)
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(33))
                level = .random(in: 0.1...1)
            }
        }
}

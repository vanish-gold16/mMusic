import SwiftUI

/// Полоски-«эквалайзер», пляшущие под общий уровень громкости.
/// Уровень один на всех, поэтому у каждой полоски свой фиксированный характер:
/// базовая высота, размах и скорость. Иначе они двигались бы синхронно, как один блок.
struct EqualizerView: View {
    /// Громкость 0...1, обычно `audioPlayer.level`.
    let level: Double

    var barCount: Int = 6
    var barWidth: CGFloat = 3
    var spacing: CGFloat = 2
    var maxHeight: CGFloat = 20

    /// Характер одной полоски.
    private struct BarProfile {
        /// Базовая высота: 1.0 — полоска высокая, 0.35 — низкая.
        let gain: Double
        /// Размах: насколько сильно она гуляет вокруг своей базы.
        let swing: Double
        /// Скорость догона цели: 0.6 — дёргается резко, 0.15 — плывёт лениво.
        let speed: Double
    }

    /// Роли полосок слева направо. Фиксированы, поэтому картинка одинакова
    /// в плеере и в списке и не меняется при перезапуске трека.
    /// Если `barCount` больше длины таблицы — рисунок повторяется по кругу.
    private static let profiles: [BarProfile] = [
        BarProfile(gain: 0.55, swing: 0.20, speed: 0.25),
        BarProfile(gain: 0.80, swing: 0.35, speed: 0.45),
        BarProfile(gain: 1.00, swing: 0.15, speed: 0.60),
        BarProfile(gain: 0.70, swing: 0.50, speed: 0.15),
        BarProfile(gain: 0.90, swing: 0.25, speed: 0.50),
        BarProfile(gain: 0.45, swing: 0.40, speed: 0.35),
        BarProfile(gain: 0.75, swing: 0.18, speed: 0.55),
        BarProfile(gain: 1.00, swing: 0.30, speed: 0.20),
        BarProfile(gain: 0.60, swing: 0.45, speed: 0.40),
        BarProfile(gain: 0.85, swing: 0.22, speed: 0.60),
        BarProfile(gain: 0.35, swing: 0.35, speed: 0.30),
        BarProfile(gain: 0.65, swing: 0.28, speed: 0.48),
    ]

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
            if bars.count != barCount {
                bars = Array(repeating: 0, count: barCount)
            }
        }
        .onChange(of: level) { _, newLevel in
            for index in bars.indices {
                let profile = Self.profiles[index % Self.profiles.count]

                // На тихом разброс гасим: полный размах полоска получает только на громком.
                let jitter = Double.random(in: -profile.swing...profile.swing) * newLevel
                let target = min(max(newLevel * (profile.gain + jitter), 0), 1)

                // Вверх — со своей скоростью, вниз — заметно медленнее.
                let speed = target > bars[index] ? profile.speed : profile.speed * 0.35
                bars[index] += (target - bars[index]) * speed
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

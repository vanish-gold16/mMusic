import SwiftUI

/// Форма волны трека. Сыгранная часть подсвечена, остальное приглушено.
/// Рисуется в `Canvas`: 120 отдельных вьюх ради статичной картинки — расточительство.
struct WaveformView: View {

    let samples: [UInt8]
    /// Доля сыгранного, 0...1.
    let progress: Double
    let played: Color
    let upcoming: Color

    var body: some View {
        Canvas { context, size in
            guard !samples.isEmpty else { return }

            let step = size.width / CGFloat(samples.count)
            let barWidth = max(1, step * 0.55)

            for (index, sample) in samples.enumerated() {
                // Минимальная высота, чтобы тишина осталась линией, а не дырой.
                let height = max(2, CGFloat(sample) / 255 * size.height)
                let x = CGFloat(index) * step + (step - barWidth) / 2
                let bar = CGRect(x: x, y: (size.height - height) / 2, width: barWidth, height: height)

                let isPlayed = Double(index) / Double(samples.count) <= progress

                context.fill(
                    Path(roundedRect: bar, cornerRadius: barWidth / 2),
                    with: .color(isPlayed ? played : upcoming)
                )
            }
        }
    }
}

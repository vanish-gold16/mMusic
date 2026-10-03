import SwiftData
import SwiftUI

/// Один трек на ленте: сколько места он занимает и чем нарисован.
struct TapeSegment: Identifiable {
    let id: PersistentIdentifier
    /// 0 — длительность ещё не прочитана; на ленте такой трек получает среднюю ширину.
    let duration: TimeInterval
    /// Форма волны трека (`Track.waveform`). Пусто — пока не посчитана.
    let samples: [UInt8]

    init(track: Track) {
        id = track.persistentModelID
        duration = track.duration
        samples = track.waveform.map(Array.init) ?? []
    }
}

/// Весь плейлист одной звуковой дорожкой: треки встык, каждый шириной в свою
/// длительность и со своей формой волны. Длинная песня — длинный кусок, тихая —
/// низкий. Играющий трек подсвечен, и сыгранная его часть ярче несыгранной.
///
/// Нажатие на чужой трек запускает плейлист с него, нажатие на играющий —
/// перематывает, как слайдер в плеере. Без `onTap` лента только показывает:
/// так она стоит в строке библиотеки, где нажатие должно открывать плейлист.
///
/// Время текущего трека читается здесь, а не в `PlaylistView`: оно меняется
/// пять раз в секунду, и перерисовываться на каждый тик должна только лента,
/// а не весь список.
struct PlaylistTape: View {

    @Environment(AudioPlayer.self) private var audioPlayer

    let segments: [TapeSegment]
    /// Какой из сегментов сейчас играет. nil — ни один.
    let currentIndex: Int?
    let accent: Color
    /// Нажали на трек `index`, в точку `fraction` (0...1) его длины.
    var onTap: ((_ index: Int, _ fraction: Double) -> Void)?

    /// Шаг столбиков: 2 pt столбик и 1 pt зазор. Число столбиков задаёт ширина
    /// ленты, а не число треков — поэтому она одинаково читается и на пяти песнях,
    /// и на двухстах.
    private let step: CGFloat = 3
    private let barWidth: CGFloat = 2

    /// Доля сыгранного у текущего трека.
    private var progress: Double {
        guard currentIndex != nil, audioPlayer.duration > 0 else { return 0 }
        return audioPlayer.currentTime / audioPlayer.duration
    }

    /// Вес каждого трека на ленте. Непрочитанная длительность заменяется средней
    /// по прочитанным: иначе такой трек схлопнулся бы в ноль и пропал.
    private var weights: [Double] {
        let known = segments.map(\.duration).filter { $0 > 0 }
        let fallback = known.isEmpty ? 180 : known.reduce(0, +) / Double(known.count)

        return segments.map { $0.duration > 0 ? $0.duration : fallback }
    }

    var body: some View {
        GeometryReader { proxy in
            Canvas { context, size in
                draw(in: &context, size: size)
            }
            .contentShape(Rectangle())
            .onTapGesture { location in
                tap(at: location.x, width: proxy.size.width)
            }
        }
        .allowsHitTesting(onTap != nil)
        .accessibilityElement()
        .accessibilityLabel("Playlist timeline")
        // В строке библиотеки лента — украшение: VoiceOver прочтёт имя и паспорт.
        .accessibilityHidden(segments.isEmpty || onTap == nil)
    }

    private func draw(in context: inout GraphicsContext, size: CGSize) {
        let weights = weights
        let total = weights.reduce(0, +)
        guard total > 0 else { return }

        let barCount = max(Int(size.width / step), 1)
        let progress = progress

        // Трек короче одного столбика ни одного своего не получит — тогда
        // подсвечиваем тот столбик, на который приходится его середина.
        let currentBar: Int? = currentIndex.map { index in
            let start = weights[..<index].reduce(0, +)
            return Int((start + weights[index] / 2) / total * Double(barCount))
        }

        var segment = 0
        var segmentStart = 0.0
        var previousSegment = -1

        for bar in 0..<barCount {
            let time = (Double(bar) + 0.5) / Double(barCount) * total
            while segment < weights.count - 1, time >= segmentStart + weights[segment] {
                segmentStart += weights[segment]
                segment += 1
            }

            let isFirstBarOfSegment = segment != previousSegment
            previousSegment = segment

            // Стык треков — пропущенный столбик. Только там, где треку хватает
            // места: на длинном плейлисте зазоры съели бы всю ленту.
            let barsInSegment = weights[segment] / total * Double(barCount)
            if isFirstBarOfSegment, bar > 0, barsInSegment >= 4 { continue }

            let fraction = (time - segmentStart) / weights[segment]
            let height = max(2, CGFloat(level(of: segment, at: fraction)) * size.height)
            let rect = CGRect(
                x: CGFloat(bar) * step,
                y: (size.height - height) / 2,
                width: barWidth,
                height: height
            )

            let color: Color
            if segment == currentIndex || bar == currentBar {
                color = segment == currentIndex && fraction > progress ? accent.opacity(0.4) : accent
            } else {
                color = Color.primary.opacity(0.25)
            }

            context.fill(Path(roundedRect: rect, cornerRadius: barWidth / 2), with: .color(color))
        }
    }

    /// Громкость трека в точке `fraction`, 0...1. Без волны — ровная низкая линия:
    /// трек на ленте есть, просто его форма ещё не посчитана.
    private func level(of segment: Int, at fraction: Double) -> Double {
        let samples = segments[segment].samples
        guard !samples.isEmpty else { return 0.2 }

        let index = min(max(Int(fraction * Double(samples.count)), 0), samples.count - 1)
        return Double(samples[index]) / 255
    }

    private func tap(at x: CGFloat, width: CGFloat) {
        let weights = weights
        let total = weights.reduce(0, +)
        guard total > 0, width > 0 else { return }

        let time = min(max(Double(x / width), 0), 1) * total
        var start = 0.0

        for (index, weight) in weights.enumerated() {
            if time < start + weight || index == weights.count - 1 {
                onTap?(index, min(max((time - start) / weight, 0), 1))
                return
            }
            start += weight
        }
    }
}

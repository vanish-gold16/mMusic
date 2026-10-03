import SwiftUI

/// Обложка альбома как конверт пластинки, из которого выглядывает сам диск.
/// У плейлиста веер карт (`CoverFan`): он подборка разного. Альбом — одна вещь
/// целиком, и у него конверт с пластинкой.
///
/// На диске кольцами лежат треки: первый снаружи, как на настоящем виниле,
/// и толщина кольца — длительность трека. Узор у каждого альбома свой, как лента
/// у плейлиста. Пока играет этот альбом, диск выезжает дальше и крутится,
/// а кольцо текущего трека горит акцентом.
struct AlbumSleeve: View {

    let cover: UIImage?
    let type: Album.AlbumType
    /// Длительности треков в порядке альбома. 0 — ещё не прочитана.
    let durations: [TimeInterval]
    /// Какой трек играет. nil — альбом не играет, диск задвинут в конверт.
    let currentIndex: Int?
    let isPlaying: Bool
    let accent: Color

    /// На сколько диск выглядывает из конверта — в долях стороны конверта.
    private static let restingPeek: CGFloat = 0.2
    private static let playingPeek: CGFloat = 0.32

    /// Ширина к высоте. Место под выехавший диск держится всегда: иначе
    /// играющий вылезал бы на соседнюю ячейку.
    static let aspectRatio: CGFloat = 1 + playingPeek

    private var isOut: Bool { currentIndex != nil }

    /// Радиус диска в долях стороны конверта. Не настоящие 7" и 12" — с ними
    /// сингл почти целиком лежал бы снаружи, — но разницу видно с первого взгляда.
    private var discRadius: CGFloat {
        switch type {
        case .single: 0.38
        case .EP: 0.42
        case .LP: 0.46
        }
    }

    /// Доля яблока (бумажной наклейки) в радиусе диска: у синглов оно крупнее.
    private var labelFraction: CGFloat {
        switch type {
        case .single: 0.5
        case .EP: 0.42
        case .LP: 0.36
        }
    }

    /// Обороты в минуту: синглы — 45, остальное — 33⅓.
    private var rpm: Double {
        type == .single ? 45 : 100.0 / 3
    }

    var body: some View {
        Color.clear
            .aspectRatio(Self.aspectRatio, contentMode: .fit)
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    let side = proxy.size.height

                    ZStack(alignment: .leading) {
                        record(side: side)
                        sleeve(side: side)
                    }
                }
            }
            .accessibilityHidden(true)
    }

    private func record(side: CGFloat) -> some View {
        let radius = side * discRadius
        let peek = isOut ? Self.playingPeek : Self.restingPeek

        return VinylRecord(
            cover: cover,
            durations: durations,
            currentIndex: currentIndex,
            isSpinning: isOut && isPlaying,
            rpm: rpm,
            labelFraction: labelFraction,
            accent: accent
        )
        .frame(width: radius * 2, height: radius * 2)
        // Правый край диска — на `peek` за краем конверта.
        .offset(x: side * (1 + peek) - radius * 2)
        .animation(.spring(duration: 0.55, bounce: 0.25), value: isOut)
    }

    private func sleeve(side: CGFloat) -> some View {
        // Углы острее, чем у карт плейлиста: конверт — картон, а не карточка.
        let shape = RoundedRectangle(cornerRadius: side * 0.04, style: .continuous)

        // Заливка непрозрачная: сквозь полупрозрачную был бы виден диск под конвертом.
        return shape
            .fill(Color(.systemGray5))
            .frame(width: side, height: side)
            .overlay {
                if let cover {
                    Image(uiImage: cover)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "music.note")
                        .font(.system(size: side * 0.22))
                        .foregroundStyle(.secondary)
                }
            }
            .clipShape(shape)
            // Тень уходит вправо, на диск: так видно, что он лежит под конвертом.
            .shadow(color: .black.opacity(0.3), radius: side * 0.04, x: side * 0.02, y: side * 0.02)
    }
}

/// Сам диск: кольца треков, канавки, яблоко с обложкой и блик.
private struct VinylRecord: View {

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let cover: UIImage?
    let durations: [TimeInterval]
    let currentIndex: Int?
    let isSpinning: Bool
    let rpm: Double
    let labelFraction: CGFloat
    let accent: Color

    /// Где кончаются канавки снаружи и начинаются внутри, в долях радиуса.
    /// Между яблоком и последним треком — гладкое поле, как на настоящем диске.
    private var grooveOuter: CGFloat { 0.96 }
    private var grooveInner: CGFloat { labelFraction + 0.06 }

    var body: some View {
        // Крутится только диск: блик неподвижен, как отражение лампы на настоящем.
        TimelineView(.animation(paused: !isSpinning || reduceMotion)) { context in
            disc
                .rotationEffect(.degrees(angle(at: context.date)))
        }
        .overlay {
            sheen
        }
    }

    private var disc: some View {
        ZStack {
            Canvas { context, size in
                draw(in: &context, size: size)
            }

            GeometryReader { proxy in
                let side = min(proxy.size.width, proxy.size.height)

                label
                    .frame(width: side * labelFraction, height: side * labelFraction)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    /// Яблоко с обложкой альбома — у сингла его край видно и в покое,
    /// а у играющего диска оно крутится и показывает, что пластинка идёт.
    private var label: some View {
        ZStack {
            Circle()
                .fill(Color(white: 0.25))

            if let cover {
                Image(uiImage: cover)
                    .resizable()
                    .scaledToFill()
            }
        }
        .clipShape(Circle())
        .overlay {
            // Отверстие под шпиндель.
            Circle()
                .fill(Color(white: 0.05))
                .scaleEffect(0.08)
        }
    }

    /// Два блика напротив друг друга. Первый — чуть ниже «трёх часов»:
    /// там, где диск выглядывает из конверта.
    private var sheen: some View {
        AngularGradient(
            stops: [
                .init(color: .white.opacity(0), location: 0),
                .init(color: .white.opacity(0.14), location: 0.06),
                .init(color: .white.opacity(0), location: 0.16),
                .init(color: .white.opacity(0), location: 0.5),
                .init(color: .white.opacity(0.14), location: 0.56),
                .init(color: .white.opacity(0), location: 0.66),
            ],
            center: .center
        )
        .clipShape(Circle())
        .allowsHitTesting(false)
    }

    /// Угол поворота в момент `date`. Остаток от периода — чтобы не крутить
    /// миллиарды градусов от начала эпохи.
    private func angle(at date: Date) -> Double {
        let period = 60 / rpm
        return date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: period) / period * 360
    }

    /// Вес каждого трека. Непрочитанная длительность заменяется средней по
    /// прочитанным — иначе кольцо такого трека схлопнулось бы в ноль.
    private var weights: [Double] {
        let known = durations.filter { $0 > 0 }
        let fallback = known.isEmpty ? 180 : known.reduce(0, +) / Double(known.count)

        return durations.map { $0 > 0 ? $0 : fallback }
    }

    private func draw(in context: inout GraphicsContext, size: CGSize) {
        let radius = min(size.width, size.height) / 2
        let center = CGPoint(x: size.width / 2, y: size.height / 2)

        func circle(_ r: CGFloat) -> Path {
            Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))
        }

        context.fill(circle(radius), with: .color(Color(white: 0.07)))

        let outer = radius * grooveOuter
        let inner = radius * grooveInner
        let weights = weights
        let total = weights.reduce(0, +)

        if total > 0 {
            var edge = outer

            for (index, weight) in weights.enumerated() {
                let width = (outer - inner) * weight / total
                // Стык треков — гладкая тёмная дорожка, как на настоящей пластинке.
                // Только там, где кольцу хватает толщины, иначе стыки съедят всё.
                let gap: CGFloat = width >= 3 ? 1 : 0

                var band = circle(edge)
                band.addPath(circle(edge - width + gap))

                let color = index == currentIndex ? accent.opacity(0.9) : Color(white: 0.16)
                context.fill(band, with: .color(color), style: FillStyle(eoFill: true))

                edge -= width
            }
        }

        // Канавки поверх колец: без них диск выглядит пластмассой, а не винилом.
        var grooves = Path()
        var r = inner
        while r < outer {
            grooves.addPath(circle(r))
            r += 1.5
        }
        context.stroke(grooves, with: .color(.black.opacity(0.3)), lineWidth: 0.5)

        // Светлый ободок: на тёмной теме без него диск сливался бы с фоном.
        context.stroke(circle(radius - 0.25), with: .color(.white.opacity(0.18)), lineWidth: 0.5)
    }
}

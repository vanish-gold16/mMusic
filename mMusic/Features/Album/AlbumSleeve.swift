import SwiftUI

/// Где играющий трек: на какой пластинке альбома и какой он на ней по счёту.
struct DiscPosition: Equatable {
    let disc: Int
    let track: Int
}

/// Обложка альбома как конверт пластинки, из которого выглядывает сам диск.
/// У плейлиста веер карт (`CoverFan`): он подборка разного. Альбом — одна вещь
/// целиком, и у него конверт с пластинкой.
///
/// На диске кольцами лежат треки: первый снаружи, как на настоящем виниле,
/// и толщина кольца — длительность трека. Узор у каждого альбома свой, как лента
/// у плейлиста. Выдвинутый диск — тот, что играет (в сетке) или открыт (в шапке
/// альбома); он выезжает дальше, крутится, а кольцо текущего трека горит акцентом.
///
/// У альбома из нескольких пластинок за конвертом стопка: каждая следующая
/// выглядывает чуть дальше предыдущей, так что двойной альбом видно из сетки.
///
/// Один и тот же конверт стоит в сетке библиотеки и в шапке альбома; в шапке
/// диск выезжает почти целиком, показывает иглой, сколько сыграно, и отвечает
/// на нажатия.
struct AlbumSleeve: View {

    let cover: UIImage?
    let type: Album.AlbumType
    /// Длительности треков по пластинкам, в порядке альбома. 0 — ещё не прочитана.
    let discs: [[TimeInterval]]
    /// Какая пластинка выдвинута. nil — все в конверте.
    let outDisc: Int?
    /// Где играющий трек. nil — альбом не играет.
    let playing: DiscPosition?
    let isPlaying: Bool
    let accent: Color
    /// Сколько сыграно у текущего трека, 0...1. nil — иглы нет: в сетке время
    /// не читается, иначе вся библиотека перерисовывалась бы пять раз в секунду.
    var progress: Double? = nil
    /// На сколько диск выглядывает из конверта — в долях стороны конверта.
    var restingPeek: CGFloat = 0.2
    var playingPeek: CGFloat = 0.32
    /// На сколько каждая следующая пластинка стопки выглядывает дальше предыдущей.
    var stagger: CGFloat = 0.06
    /// Волны цвета обложки вокруг диска — на странице альбома.
    var showsRipples = false
    /// Нажали на кольцо трека `index` выдвинутой пластинки `disc`, в точку
    /// `fraction` (0...1) его длины. Без него диски только показывают:
    /// в сетке нажатие открывает альбом.
    var onTapTrack: ((_ disc: Int, _ index: Int, _ fraction: Double) -> Void)? = nil
    /// Кольца, подсвеченные серебром, по пластинкам: `marked[k]` — номера треков
    /// пластинки `k`. На странице артиста так видно, где на чужом альбоме он в гостях.
    var marked: [Set<Int>] = []

    /// Ширина к высоте. Место под выехавший диск держится всегда: иначе
    /// играющий вылезал бы на соседнюю ячейку.
    private var aspectRatio: CGFloat { 1 + playingPeek }

    /// Какие пластинки видно, спереди назад. За конвертом помещается три;
    /// выдвинутая видна всегда, даже если она пятая.
    private var stack: [Int] {
        var stack = Array(discs.indices.prefix(3))
        if let outDisc, discs.indices.contains(outDisc), !stack.contains(outDisc) {
            stack[stack.count - 1] = outDisc
        }
        return stack
    }

    /// Глубина пластинки в стопке тех, что в конверте: 0 — передняя.
    private func depth(of disc: Int) -> Int {
        stack.filter { $0 != outDisc }.firstIndex(of: disc) ?? 0
    }

    private func peek(of disc: Int) -> CGFloat {
        disc == outDisc ? playingPeek : restingPeek + stagger * CGFloat(depth(of: disc))
    }

    var body: some View {
        Color.clear
            .aspectRatio(aspectRatio, contentMode: .fit)
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    let side = proxy.size.height

                    ZStack(alignment: .leading) {
                        ForEach(stack, id: \.self) { disc in
                            record(disc, side: side)
                                // Выдвинутая — поверх стопки, остальные — передняя поверх задних.
                                .zIndex(disc == outDisc ? 100 : Double(10 - depth(of: disc)))
                        }

                        sleeve(side: side)
                            .zIndex(200)
                    }
                    // Фоном, а не слоем стопки: волны втрое больше конверта
                    // и раздули бы её рамку, сдвинув конверт.
                    .background(alignment: .leading) {
                        if showsRipples {
                            ripples(side: side)
                        }
                    }
                    .animation(.spring(duration: 0.55, bounce: 0.25), value: outDisc)
                }
            }
    }

    private func record(_ disc: Int, side: CGFloat) -> some View {
        let radius = side * type.discRadius
        let isOut = disc == outDisc
        let isPlayingHere = playing?.disc == disc

        return VinylRecord(
            cover: cover,
            durations: discs[disc],
            currentIndex: isPlayingHere ? playing?.track : nil,
            progress: isPlayingHere ? progress : nil,
            // Крутится только выдвинутая: в конверте её всё равно не видно.
            isSpinning: isOut && isPlayingHere && isPlaying,
            rpm: type.rpm,
            labelFraction: type.labelFraction,
            accent: accent,
            onTapTrack: isOut ? onTapTrack.map { onTap in { onTap(disc, $0, $1) } } : nil,
            marked: marked.indices.contains(disc) ? marked[disc] : []
        )
        .frame(width: radius * 2, height: radius * 2)
        // Правый край диска — на `peek` за краем конверта. Задние чуть выше
        // передних: вровень стопка читалась бы одним толстым диском.
        .offset(
            x: side * (1 + peek(of: disc)) - radius * 2,
            y: isOut ? 0 : -side * 0.015 * CGFloat(depth(of: disc))
        )
    }

    /// Волны расходятся от выдвинутой пластинки, а если все в конверте — от передней.
    private func ripples(side: CGFloat) -> some View {
        let radius = side * type.discRadius
        let source = outDisc ?? stack.first ?? 0
        let breathes = outDisc != nil && playing?.disc == outDisc && isPlaying
        let reach = radius * RecordRipples.reach

        return RecordRipples(accent: accent, breathes: breathes)
            .frame(width: reach * 2, height: reach * 2)
            .offset(x: side * (1 + peek(of: source)) - radius - reach)
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
            .accessibilityHidden(true)
    }
}

extension Album.AlbumType {

    /// Радиус диска в долях стороны конверта. Не настоящие 7" и 12" — с ними
    /// сингл почти целиком лежал бы снаружи, — но разницу видно с первого взгляда.
    var discRadius: CGFloat {
        switch self {
        case .single: 0.38
        case .EP: 0.42
        case .LP: 0.46
        }
    }

    /// Доля яблока (бумажной наклейки) в радиусе диска: у синглов оно крупнее.
    var labelFraction: CGFloat {
        switch self {
        case .single: 0.5
        case .EP: 0.42
        case .LP: 0.36
        }
    }

    /// Обороты в минуту: синглы — 45, остальное — 33⅓.
    var rpm: Double {
        self == .single ? 45 : 100.0 / 3
    }
}

/// Сам диск: кольца треков, канавки, яблоко с обложкой и блик. Стоит в конверте
/// и отдельно — в списке пластинок альбома.
struct VinylRecord: View {

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let cover: UIImage?
    let durations: [TimeInterval]
    let currentIndex: Int?
    let progress: Double?
    let isSpinning: Bool
    let rpm: Double
    let labelFraction: CGFloat
    let accent: Color
    let onTapTrack: ((_ index: Int, _ fraction: Double) -> Void)?
    /// Треки, чьи кольца светлее остальных, — не играющие, а отмеченные.
    var marked: Set<Int> = []
    /// Яблоко всегда стоит ровно. Остановленный диск замирает под любым углом,
    /// как настоящий, — но на пластинке артиста на яблоке лицо, и наклонять его
    /// незачем. Такой диск и не крутится.
    var isUpright = false

    /// Размер диска — нужен, чтобы по точке нажатия найти кольцо.
    @State private var diameter: CGFloat = 0

    /// Где кончаются канавки снаружи и начинаются внутри, в долях радиуса.
    /// Между яблоком и последним треком — гладкое поле, как на настоящем диске.
    private var grooveOuter: CGFloat { 0.96 }
    private var grooveInner: CGFloat { labelFraction + 0.06 }

    var body: some View {
        // Крутится только диск: блик неподвижен, как отражение лампы на настоящем.
        TimelineView(.animation(paused: !isSpinning || reduceMotion)) { context in
            disc
                .rotationEffect(.degrees(isUpright ? 0 : angle(at: context.date)))
        }
        .overlay {
            sheen
        }
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.width
        } action: { width in
            diameter = width
        }
        .contentShape(Circle())
        .onTapGesture { location in
            tap(at: location)
        }
        .allowsHitTesting(onTapTrack != nil)
        .accessibilityHidden(true)
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

        func fillRing(from outer: CGFloat, to inner: CGFloat, with color: Color) {
            var ring = circle(outer)
            ring.addPath(circle(inner))
            context.fill(ring, with: .color(color), style: FillStyle(eoFill: true))
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
                let bottom = edge - width + gap

                if index == currentIndex, let progress {
                    // Игла идёт от края к центру: снаружи сыгранное, внутри — ещё нет.
                    let needle = edge - (edge - bottom) * min(max(progress, 0), 1)
                    fillRing(from: edge, to: needle, with: accent)
                    fillRing(from: needle, to: bottom, with: accent.opacity(0.35))
                } else {
                    let color = if index == currentIndex {
                        accent.opacity(0.9)
                    } else if marked.contains(index) {
                        // Серебро, а не акцент: акцент значит «играет сейчас».
                        Color(white: 0.58)
                    } else {
                        Color(white: 0.16)
                    }
                    fillRing(from: edge, to: bottom, with: color)
                }

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

    /// Расстояние от центра решает, в какой трек попали: кольца лежат
    /// снаружи внутрь в порядке альбома. Угол неважен — диск крутится.
    private func tap(at location: CGPoint) {
        guard let onTapTrack else { return }

        let weights = weights
        let total = weights.reduce(0, +)
        guard total > 0 else { return }

        let radius = diameter / 2
        guard radius > 0 else { return }

        // Где между внешним краем канавок и внутренним: 0 — первый трек, 1 — конец последнего.
        let distance = hypot(location.x - radius, location.y - radius) / radius
        guard distance >= grooveInner, distance <= grooveOuter else { return }

        let time = Double((grooveOuter - distance) / (grooveOuter - grooveInner)) * total
        var start = 0.0

        for (index, weight) in weights.enumerated() {
            if time < start + weight || index == weights.count - 1 {
                onTapTrack(index, min(max((time - start) / weight, 0), 1))
                return
            }
            start += weight
        }
    }
}

/// Волны вокруг пластинки на странице альбома: цвет обложки расходится по
/// странице кругами, как звук от колонки. Пока альбом играет, они дышат
/// громкостью — на ударе ярче и шире.
///
/// Громкость читается здесь, а не на экране альбома: она меняется 30 раз
/// в секунду, и перерисовываться должны только волны.
private struct RecordRipples: View {

    @Environment(AudioPlayer.self) private var audioPlayer
    @Environment(\.colorScheme) private var colorScheme

    let accent: Color
    let breathes: Bool

    /// Докуда расходятся волны — в радиусах диска.
    static let reach: CGFloat = 3.2

    /// На белом цвет заметнее, чем на чёрном, — светлой теме хватает меньшего.
    private var strength: Double {
        colorScheme == .dark ? 0.5 : 0.36
    }

    var body: some View {
        // `punch` читается только при `breathes`: иначе открытый альбом
        // перерисовывался бы под чужую музыку.
        let punch = breathes && audioPlayer.isPlaying ? audioPlayer.punch : 0

        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let maxRadius = min(size.width, size.height) / 2
            let discRadius = maxRadius / Self.reach
            let start = discRadius * 1.1
            let spacing = discRadius * (0.17 + punch * 0.05)

            var r = start
            while r < maxRadius {
                // К краю волны гаснут: у диска они заметны, под текстом — уже нет.
                let fade = pow(1 - (r - start) / (maxRadius - start), 1.8)
                let opacity = strength * fade * (0.7 + punch * 0.6)
                let rect = CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)
                context.stroke(Path(ellipseIn: rect), with: .color(accent.opacity(opacity)), lineWidth: 1)
                r += spacing
            }
        }
        .background {
            EllipticalGradient(
                colors: [accent.opacity(strength * 0.45 + punch * 0.12), .clear],
                center: .center,
                startRadiusFraction: 0,
                endRadiusFraction: 0.5
            )
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

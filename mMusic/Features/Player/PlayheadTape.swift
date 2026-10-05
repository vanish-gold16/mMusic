import SwiftData
import SwiftUI

/// Лента под головкой — главное в плеере.
///
/// Трек идёт через экран формой своей волны, справа налево, мимо неподвижной
/// головки. Слева от неё сыгранное, справа — то, что прозвучит в ближайшие
/// секунды: громкий припев или тихий проигрыш видно до того, как они начнутся.
/// Головка стоит не по центру, а на трети ширины — будущего видно вдвое больше.
///
/// Лента — это и перемотка. Нажатие ставит иглу в то место, куда нажали. Если
/// потянуть, лента отъезжает и показывает трек целиком: палец ведёт головку по
/// всей песне, отпустил — лента возвращается к крупному плану. За концом трека,
/// после короткого ракорда, начинается следующий из очереди, перед началом —
/// хвост предыдущего; нажатие на них переключает трек.
///
/// Время читается здесь, а не в плеере: лента перерисовывается каждый кадр,
/// и весь экран за ней тянуть незачем.
struct PlayheadTape: View {

    let audioPlayer: AudioPlayer
    /// Вертикальная протяжка по ленте — это закрытие плеера. Лента её не обрабатывает,
    /// а отдаёт плееру: вложенный жест иначе забрал бы касание себе целиком.
    var onVerticalDrag: (_ translation: CGSize, _ isFinished: Bool) -> Void = { _, _ in }

    /// Точек ленты на секунду записи в крупном плане: экран вмещает секунд
    /// восемнадцать — шесть сыгранных и двенадцать впереди.
    static let pointsPerSecond: Double = 22
    /// Где стоит головка, в долях ширины.
    static let headFraction: CGFloat = 0.32
    /// Пустой кусок ленты между треками, в секундах.
    static let leader: TimeInterval = 1.2
    /// Поля отъехавшей ленты: трек целиком встаёт между ними.
    static let margin: CGFloat = 24

    /// Последнее время от плеера и когда оно пришло. Плеер сообщает позицию пять
    /// раз в секунду, а лента должна ехать плавно — между отсчётами время
    /// досчитывается само.
    @State private var anchor = Anchor(time: 0, date: .now)
    @State private var scrub: Scrub?
    /// Протяжку решено не считать перемоткой (она вертикальная) — до конца
    /// касания лента её не трогает и отдаёт закрытию плеера.
    @State private var isIgnoringDrag = false
    /// 0 — крупный план у головки, 1 — весь трек по ширине экрана.
    @State private var zoom: Double = 0
    /// Сдвиг ленты при смене трека: новый трек въезжает, а не появляется скачком.
    @State private var slide: CGFloat = 0
    @State private var width: CGFloat = 0
    /// Где была головка на прошлом треке — по этому видно, доиграл он сам или его
    /// переключили.
    @State private var last = Position()

    @GestureState private var isTouching = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct Anchor {
        var time: TimeInterval
        var date: Date
    }

    /// Перемотка пальцем: откуда начали, где палец лёг и куда довели.
    private struct Scrub {
        let startTime: TimeInterval
        let startX: CGFloat
        var time: TimeInterval
    }

    private struct Position {
        var trackID: Track.ID?
        var index = 0
        var time: TimeInterval = 0
        var duration: TimeInterval = 0
    }

    private var store: TapeWaveformStore { .shared }

    /// Длина играющего трека. Пока звук не поднимали (очередь восстановлена
    /// с прошлого запуска), плеер её не знает — берём записанную в модели.
    private var duration: TimeInterval {
        if audioPlayer.duration > 0 { return audioPlayer.duration }
        return audioPlayer.currentTrack?.duration ?? 0
    }

    private var previousTrack: Track? {
        let index = audioPlayer.currentIndex - 1
        return audioPlayer.queue.indices.contains(index) ? audioPlayer.queue[index] : nil
    }

    /// То, что заиграет следом, — с ним лента продолжается за ракордом.
    /// Таймер сна «до конца трека» обрывает ленту: дальше тишина.
    private var nextTrack: Track? {
        guard !audioPlayer.stopsAfterCurrentTrack, !audioPlayer.queue.isEmpty else { return nil }

        switch audioPlayer.repeatMode {
        case .one:
            return audioPlayer.currentTrack
        case .all:
            return audioPlayer.queue[(audioPlayer.currentIndex + 1) % audioPlayer.queue.count]
        case .off:
            let index = audioPlayer.currentIndex + 1
            return audioPlayer.queue.indices.contains(index) ? audioPlayer.queue[index] : nil
        }
    }

    private var reels: [TapeReel] {
        guard let current = audioPlayer.currentTrack else { return [] }

        let duration = duration
        var reels: [TapeReel] = []

        if let previous = previousTrack {
            let length = Self.length(of: previous)
            reels.append(TapeReel(
                role: .previous,
                title: previous.name,
                start: -Self.leader - length,
                duration: length,
                waveform: store.waveform(for: previous, duration: length)
            ))
        }

        reels.append(TapeReel(
            role: .current,
            title: current.name,
            start: 0,
            duration: duration,
            waveform: store.waveform(for: current, duration: duration)
        ))

        if let next = nextTrack {
            let length = Self.length(of: next)
            reels.append(TapeReel(
                role: .next,
                title: next.name,
                start: duration + Self.leader,
                duration: length,
                waveform: store.waveform(for: next, duration: length)
            ))
        }

        return reels
    }

    /// Подпись у начала следующего трека и там, где лента кончается.
    private var captions: TapeCaptions {
        TapeCaptions(
            next: audioPlayer.repeatMode == .one ? "again" : "next",
            end: audioPlayer.stopsAfterCurrentTrack ? "sleep" : "end of queue"
        )
    }

    var body: some View {
        let duration = duration
        let reels = reels

        // Модификаторы разложены по группам: одной цепочкой компилятор не успевал
        // вывести её тип.
        let face = face(duration: duration, reels: reels)
        let interactive = withTouches(face, duration: duration, reels: reels)
        let observed = withPlayback(interactive, duration: duration)

        withAccessibility(observed, duration: duration)
    }

    private func face(duration: TimeInterval, reels: [TapeReel]) -> some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60, paused: !audioPlayer.isPlaying || scrub != nil)) { context in
            TapeFace(
                zoom: zoom,
                slide: slide,
                time: time(at: context.date, duration: duration),
                duration: duration,
                reels: reels,
                isScrubbing: scrub != nil,
                accent: audioPlayer.accent,
                captions: captions
            )
        }
        .frame(height: TapeFace.height)
        .contentShape(Rectangle())
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.width
        } action: { newWidth in
            width = newWidth
        }
    }

    private func withTouches(_ content: some View, duration: TimeInterval, reels: [TapeReel]) -> some View {
        content
            .onTapGesture { location in
                tap(at: location.x, reels: reels, duration: duration)
            }
            .gesture(scrubGesture(duration: duration))
            .onChange(of: isTouching) { _, touching in
                if !touching { touchEnded() }
            }
            // Лёгкий толчок, когда ленту взяли и когда отпустили: палец чувствует,
            // что держит её, не глядя на экран.
            .sensoryFeedback(.impact(weight: .light), trigger: scrub != nil)
    }

    private func withPlayback(_ content: some View, duration: TimeInterval) -> some View {
        content
            .onAppear {
                anchor = Anchor(time: audioPlayer.currentTime, date: .now)
                last = Position(
                    trackID: audioPlayer.currentTrack?.id,
                    index: audioPlayer.currentIndex,
                    time: audioPlayer.currentTime,
                    duration: duration
                )
            }
            .onChange(of: audioPlayer.currentTime) { previous, time in
                timeChanged(from: previous, to: time, duration: duration)
            }
            .onChange(of: audioPlayer.isPlaying) { _, _ in
                anchor = Anchor(time: audioPlayer.currentTime, date: .now)
            }
            .onChange(of: audioPlayer.currentTrack?.id) { _, trackID in
                trackChanged(to: trackID, duration: duration)
            }
            .task(id: audioPlayer.currentTrack?.filename) {
                await loadWaveforms()
            }
    }

    private func withAccessibility(_ content: some View, duration: TimeInterval) -> some View {
        content
            .accessibilityElement()
            .accessibilityLabel("Track position")
            .accessibilityValue("\(Self.clock(audioPlayer.currentTime)) of \(Self.clock(duration))")
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: seek(to: min(audioPlayer.currentTime + 10, duration))
                case .decrement: seek(to: max(audioPlayer.currentTime - 10, 0))
                @unknown default: break
                }
            }
    }

    /// Сначала играющий, потом соседи: следующий понадобится через минуты,
    /// а играющий виден прямо сейчас.
    private func loadWaveforms() async {
        guard let current = audioPlayer.currentTrack else { return }

        await store.load(current)
        if let next = nextTrack { await store.load(next) }
        if let previous = previousTrack { await store.load(previous) }
    }

    // MARK: - Время

    /// Где головка в момент `date`. Между отсчётами плеера время идёт само — со
    /// скоростью ремикса, но не дальше полусекунды от последнего отсчёта: если
    /// плеер замешкался, лента подождёт, а не убежит вперёд звука.
    private func time(at date: Date, duration: TimeInterval) -> TimeInterval {
        if let scrub { return scrub.time }
        guard audioPlayer.isPlaying else { return min(anchor.time, duration) }

        let elapsed = min(max(date.timeIntervalSince(anchor.date), 0), 0.5)
        return min(anchor.time + elapsed * audioPlayer.currentRemix.speed, duration)
    }

    private func seek(to time: TimeInterval) {
        // Звук ещё не поднимали — сначала открываем трек, иначе перематывать нечего.
        if audioPlayer.duration == 0 { audioPlayer.resume() }

        audioPlayer.seek(to: time)
        anchor = Anchor(time: audioPlayer.currentTime, date: .now)
    }

    // MARK: - Касания

    /// Нажатие по крупному плану: в играющий трек — перемотка туда, в соседний —
    /// переход на него.
    private func tap(at x: CGFloat, reels: [TapeReel], duration: TimeInterval) {
        guard scrub == nil, width > 0 else { return }

        let map = TapeMap(width: width, time: time(at: .now, duration: duration), duration: duration, zoom: 0, slide: 0)
        let tapped = map.time(at: x)

        if tapped < 0 {
            guard let previous = reels.first(where: { $0.role == .previous }), tapped >= previous.start else { return }
            audioPlayer.jump(to: audioPlayer.currentIndex - 1)
        } else if tapped <= duration {
            seek(to: tapped)
        } else if let next = reels.first(where: { $0.role == .next }), tapped >= next.start {
            // При повторе одного трека «следующий» — он же, с начала.
            if audioPlayer.repeatMode == .one {
                seek(to: 0)
            } else {
                audioPlayer.playNext()
            }
        }
    }

    /// Протяжка по ленте. Минимальное расстояние больше, чем у нажатия, —
    /// иначе любое касание чуть со сдвигом становилось бы перемоткой.
    private func scrubGesture(duration: TimeInterval) -> some Gesture {
        DragGesture(minimumDistance: 10)
            .updating($isTouching) { _, touching, _ in
                touching = true
            }
            .onChanged { value in
                if scrub == nil {
                    guard !isIgnoringDrag else {
                        onVerticalDrag(value.translation, false)
                        return
                    }

                    // Решается один раз, по первому движению: вертикальная протяжка —
                    // это закрытие плеера, и она уходит ему.
                    guard abs(value.translation.width) > abs(value.translation.height), duration > 0 else {
                        isIgnoringDrag = true
                        onVerticalDrag(value.translation, false)
                        return
                    }

                    let start = time(at: .now, duration: duration)
                    scrub = Scrub(startTime: start, startX: value.location.x, time: start)
                    withAnimation(.smooth(duration: 0.35)) { zoom = 1 }
                }

                guard var current = scrub, width > Self.margin * 2 else { return }

                // Палец ведёт головку в масштабе отъехавшей ленты: ширина экрана —
                // весь трек.
                let pointsPerSecond = Double(width - Self.margin * 2) / duration
                let moved = Double(value.location.x - current.startX) / pointsPerSecond
                current.time = min(max(current.startTime + moved, 0), duration)
                scrub = current
            }
            .onEnded { value in
                if isIgnoringDrag {
                    isIgnoringDrag = false
                    onVerticalDrag(value.translation, true)
                    return
                }

                guard let scrub else { return }

                seek(to: scrub.time)
                self.scrub = nil
                withAnimation(.smooth(duration: 0.4)) { zoom = 0 }
            }
    }

    /// Касание кончилось. Обычно `onEnded` уже всё убрал; если же жест отменила
    /// система, перемотку бросаем, а ленту возвращаем на место. Проверка —
    /// следующим ходом, чтобы `onEnded` успел первым.
    private func touchEnded() {
        Task { @MainActor in
            if isIgnoringDrag {
                // Отменили протяжку, отданную плееру, — пусть вернётся на место.
                isIgnoringDrag = false
                onVerticalDrag(.zero, true)
            }

            guard scrub != nil else { return }

            scrub = nil
            withAnimation(.smooth(duration: 0.4)) { zoom = 0 }
        }
    }

    // MARK: - Смена трека

    /// Новый отсчёт времени от плеера.
    private func timeChanged(from previous: TimeInterval, to time: TimeInterval, duration: TimeInterval) {
        anchor = Anchor(time: time, date: .now)

        guard audioPlayer.currentTrack?.id == last.trackID else { return }

        // Повтор одного трека: он начался заново, и лента должна доехать
        // до его нового начала, а не прыгнуть назад.
        if audioPlayer.repeatMode == .one, last.duration > 0, previous >= last.duration - 1, time < 1 {
            slideIn(by: CGFloat(Self.leader * Self.pointsPerSecond))
        }

        last.time = time
        last.duration = duration
    }

    /// Трек сменился. Если прошлый доиграл сам, лента просто доезжает ракорд —
    /// новый трек и так подходил к головке. Если переключили, новый въезжает
    /// с той стороны, куда шли по очереди.
    private func trackChanged(to trackID: Track.ID?, duration: TimeInterval) {
        let index = audioPlayer.currentIndex
        let finished = last.duration > 0 && last.time >= last.duration - 1
        let advanced = index == last.index + 1 || (index == 0 && last.index > 0)

        if finished, advanced {
            slideIn(by: CGFloat(Self.leader * Self.pointsPerSecond))
        } else if last.trackID != nil {
            slideIn(by: (index >= last.index ? 1 : -1) * width * 0.5)
        }

        anchor = Anchor(time: audioPlayer.currentTime, date: .now)
        last = Position(trackID: trackID, index: index, time: audioPlayer.currentTime, duration: duration)
    }

    /// Лента встаёт со сдвигом и доезжает на место. Сдвиг ставится без анимации,
    /// а возврат — следующим ходом: в одной транзакции SwiftUI склеил бы оба
    /// изменения, и ехать было бы неоткуда.
    private func slideIn(by offset: CGFloat) {
        // С «Уменьшением движения» лента просто встаёт на новое место.
        guard !reduceMotion else { return }

        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) { slide = offset }

        Task { @MainActor in
            withAnimation(.smooth(duration: 0.45)) { slide = 0 }
        }
    }

    // MARK: - Подписи

    private static func length(of track: Track) -> TimeInterval {
        track.duration > 0 ? track.duration : 180
    }

    static func clock(_ time: TimeInterval) -> String {
        let total = Int(max(time, 0))
        let hours = total / 3600
        let minutes = total / 60 % 60
        let seconds = total % 60

        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, seconds)
            : String(format: "%d:%02d", minutes, seconds)
    }
}

/// Один трек на ленте: где он начинается относительно играющего и чем нарисован.
struct TapeReel {

    enum Role {
        case previous, current, next
    }

    let role: Role
    let title: String
    /// Начало относительно начала играющего трека, в секундах: у следующего это
    /// длина играющего плюс ракорд, у предыдущего — меньше нуля.
    let start: TimeInterval
    let duration: TimeInterval
    /// nil — у трека не посчитана даже волна модели; тогда он лежит ровной линией.
    let waveform: TapeWaveform?
}

/// Подписи на ленте: у начала следующего трека («NEXT») и там, где продолжения нет.
struct TapeCaptions: Equatable {
    let next: String
    let end: String
}

/// Где на экране какой момент ленты. Обе раскладки — крупный план у головки
/// и весь трек по ширине — линейны по времени, поэтому любое промежуточное
/// положение тоже прямая: x = origin + время × масштаб.
private struct TapeMap {

    let pointsPerSecond: Double
    let origin: Double
    let headX: CGFloat

    init(width: CGFloat, time: TimeInterval, duration: TimeInterval, zoom: Double, slide: CGFloat) {
        let close = PlayheadTape.pointsPerSecond
        let whole = duration > 0 ? max(Double(width - PlayheadTape.margin * 2) / duration, 0.01) : close

        // Масштаб меняется по логарифму: так отъезд выглядит равномерным,
        // а не рывком в первые кадры.
        let scale = exp(log(close) + (log(whole) - log(close)) * zoom)

        // Головка переезжает со своего места туда, где её момент лежит на
        // отъехавшей ленте, а лента сжимается вокруг неё.
        let closeHead = Double(width * PlayheadTape.headFraction)
        let wholeHead = Double(PlayheadTape.margin) + time * whole
        let head = closeHead + (wholeHead - closeHead) * zoom

        pointsPerSecond = scale
        origin = head - time * scale + Double(slide)
        headX = CGFloat(head)
    }

    func x(at time: TimeInterval) -> CGFloat {
        CGFloat(origin + time * pointsPerSecond)
    }

    func time(at x: CGFloat) -> TimeInterval {
        (Double(x) - origin) / pointsPerSecond
    }
}

/// Сама лента: столбики, головка, счётчик и подписи. Отъезд и въезд анимируются
/// через `Animatable`: SwiftUI сам подставляет промежуточные `zoom` и `slide`,
/// и лента перерисовывается в каждом кадре перехода, даже на паузе.
private struct TapeFace: View, Animatable {

    var zoom: Double
    var slide: CGFloat

    var animatableData: AnimatablePair<Double, CGFloat> {
        get { AnimatablePair(zoom, slide) }
        set {
            zoom = newValue.first
            slide = newValue.second
        }
    }

    let time: TimeInterval
    let duration: TimeInterval
    let reels: [TapeReel]
    let isScrubbing: Bool
    let accent: Color
    let captions: TapeCaptions

    /// Строка счётчика над лентой, сами столбики и строка подписей под ними.
    static let counterHeight: CGFloat = 26
    static let barsHeight: CGFloat = 64
    static let captionHeight: CGFloat = 22
    static var height: CGFloat { counterHeight + barsHeight + captionHeight }

    /// Столбики не теснее этого — иначе отъехавшая лента слипается в полосу.
    private static let minimumPitch: Double = 3.4

    var body: some View {
        GeometryReader { proxy in
            let map = TapeMap(width: proxy.size.width, time: time, duration: duration, zoom: zoom, slide: slide)

            ZStack(alignment: .topLeading) {
                Canvas { context, size in
                    drawBars(in: &context, size: size, map: map)
                }
                // Края ленты растворяются — видно, что она тянется дальше. У отъехавшей
                // ленты трек целиком на экране, и гасить края незачем.
                .mask { edgeFade }

                Canvas { context, size in
                    drawHead(in: &context, map: map)
                    drawCaptions(in: &context, size: size, map: map)
                }

                counter(map: map, width: proxy.size.width)
            }
        }
        .frame(height: Self.height)
    }

    private var edgeFade: some View {
        let fade = 0.1 * (1 - zoom)

        return LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .black, location: fade),
                .init(color: .black, location: 1 - fade),
                .init(color: .clear, location: 1)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    // MARK: - Столбики

    private func drawBars(in context: inout GraphicsContext, size: CGSize, map: TapeMap) {
        let middle = Self.counterHeight + Self.barsHeight / 2
        let visibleStart = map.time(at: 0)
        let visibleEnd = map.time(at: size.width)

        var played = Path()
        var upcoming = Path()
        var before = Path()
        var after = Path()

        for reel in reels {
            guard let waveform = reel.waveform else {
                // Волны нет — тонкая линия по всей длине: трек на ленте есть,
                // его форма просто ещё не посчитана.
                let rect = CGRect(
                    x: map.x(at: reel.start),
                    y: middle - 1,
                    width: CGFloat(reel.duration * map.pointsPerSecond),
                    height: 2
                )
                switch reel.role {
                case .previous: before.addRect(rect)
                case .current: upcoming.addRect(rect)
                case .next: after.addRect(rect)
                }
                continue
            }

            let lod = waveform.lod(forPointsPerSecond: map.pointsPerSecond, minimumPitch: Self.minimumPitch)
            let levels = waveform.lods[lod]
            let step = waveform.secondsPerLevel * Double(1 << lod)
            let pitch = CGFloat(step * map.pointsPerSecond)
            let barWidth = max(1, pitch * 0.6)

            let first = max(Int(((visibleStart - reel.start) / step).rounded(.down)), 0)
            let last = min(Int(((visibleEnd - reel.start) / step).rounded(.up)), levels.count - 1)
            guard first <= last else { continue }

            for index in first...last {
                let start = reel.start + Double(index) * step
                guard start < reel.start + reel.duration else { break }

                let height = max(2, CGFloat(levels[index]) * Self.barsHeight)
                let rect = CGRect(
                    x: map.x(at: start) + (pitch - barWidth) / 2,
                    y: middle - height / 2,
                    width: barWidth,
                    height: height
                )
                let bar = Path(roundedRect: rect, cornerRadius: barWidth / 2)

                switch reel.role {
                case .previous:
                    before.addPath(bar)
                case .next:
                    after.addPath(bar)
                case .current:
                    if start + step / 2 <= time {
                        played.addPath(bar)
                    } else {
                        upcoming.addPath(bar)
                    }
                }
            }
        }

        // Соседи нужны крупному плану. На отъехавшей ленте трек один — они гаснут,
        // чтобы не торчать огрызками у краёв.
        let neighbours = 1 - zoom
        context.fill(before, with: .color(accent.opacity(0.3 * neighbours)))
        context.fill(after, with: .color(.primary.opacity(0.14 * neighbours)))
        context.fill(upcoming, with: .color(.primary.opacity(0.3)))
        context.fill(played, with: .color(accent))
    }

    // MARK: - Головка и подписи

    private func drawHead(in context: inout GraphicsContext, map: TapeMap) {
        var line = Path()
        line.move(to: CGPoint(x: map.headX, y: Self.counterHeight - 3))
        line.addLine(to: CGPoint(x: map.headX, y: Self.counterHeight + Self.barsHeight + 3))

        context.stroke(line, with: .color(isScrubbing ? accent : .primary), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
    }

    /// Подписи нужны крупному плану; на отъехавшей ленте трек один, и они гаснут.
    private func drawCaptions(in context: inout GraphicsContext, size: CGSize, map: TapeMap) {
        let opacity = 1 - zoom
        guard opacity > 0.01 else { return }

        context.opacity = opacity
        let y = Self.counterHeight + Self.barsHeight + 6
        let limit = size.width - PlayheadTape.margin

        if let next = reels.first(where: { $0.role == .next }) {
            draw("\(captions.next)  ·  \(next.title)", from: map.x(at: next.start), limit: limit, y: y, in: &context)
        } else {
            draw(captions.end, from: map.x(at: duration) + 6, limit: limit, y: y, in: &context)
        }
    }

    /// Подпись едет вместе с началом трека, а пока оно за краем экрана — ждёт у края,
    /// как закладка: что дальше, видно всегда, а не только в последние секунды.
    private func draw(_ caption: String, from x: CGFloat, limit: CGFloat, y: CGFloat, in context: inout GraphicsContext) {
        let text = context.resolve(
            Text(Self.shortened(caption).uppercased())
                .font(.caption2.weight(.semibold))
                .tracking(1.2)
                .foregroundStyle(Color.primary.opacity(0.55))
        )

        let size = text.measure(in: CGSize(width: 320, height: 20))
        context.draw(text, in: CGRect(x: min(x, limit - size.width), y: y, width: size.width, height: size.height))
    }

    private static func shortened(_ caption: String) -> String {
        caption.count > 34 ? caption.prefix(33) + "…" : caption
    }

    // MARK: - Счётчик

    /// Время у головки — цифры перекатываются, как в счётчике магнитофона.
    /// Справа — сколько осталось. На отъехавшей ленте счётчик едет за головкой,
    /// но не заходит за края.
    private func counter(map: TapeMap, width: CGFloat) -> some View {
        let seconds = Int(max(time, 0))
        let remaining = Int(max(duration - time, 0).rounded(.up))

        return ZStack(alignment: .topLeading) {
            Text(PlayheadTape.clock(TimeInterval(seconds)))
                .font(.system(size: isScrubbing ? 15 : 13, weight: isScrubbing ? .bold : .semibold))
                .monospacedDigit()
                .foregroundStyle(isScrubbing ? AnyShapeStyle(accent) : AnyShapeStyle(.primary))
                .contentTransition(.numericText(countsDown: false))
                .animation(.snappy(duration: 0.25), value: seconds)
                .fixedSize()
                .position(x: min(max(map.headX, 30), width - 90), y: Self.counterHeight / 2 - 2)

            Text("−" + PlayheadTape.clock(TimeInterval(remaining)))
                .font(.caption.weight(.medium))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .contentTransition(.numericText(countsDown: true))
                .animation(.snappy(duration: 0.25), value: remaining)
                .fixedSize()
                .frame(width: width - PlayheadTape.margin, height: Self.counterHeight - 4, alignment: .trailing)
        }
        .allowsHitTesting(false)
    }
}

import SwiftUI

/// Текст играющего трека на месте обложки. Под ним остаются и ползунок, и кнопки:
/// читать можно, не теряя управления и не уходя с экрана.
///
/// Карточки и матового стекла нет намеренно — текст лежит прямо на «дышащем» фоне
/// плеера, как и остальное его содержимое, и растворяется у краёв вместо обрыва.
///
/// Текст с таймкодами идёт вслед за музыкой (`SyncedLyricsView`), обычный —
/// просто читается куплетами.
struct LyricsPanel: View {

    let audioPlayer: AudioPlayer
    /// Открыть редактор. Нужен, пока текста нет: пустая панель должна не просто
    /// сообщать о пустоте, а предлагать её заполнить.
    let onEdit: () -> Void

    @State private var lookup: LyricsLookupStatus = .idle

    private var track: Track? { audioPlayer.currentTrack }
    private var text: String { track?.lyrics ?? "" }
    private var accent: Color { audioPlayer.accent }

    var body: some View {
        Group {
            if let lines = Lyrics.synced(text) {
                SyncedLyricsView(lines: lines, audioPlayer: audioPlayer, accent: accent)
                    // У каждого трека своя подсвеченная строка и своя прокрутка:
                    // новый трек начинает панель заново, а не с места прошлого.
                    .id(track?.filename)
            } else if !stanzas.isEmpty {
                scroll
            } else {
                empty
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: track?.filename) {
            // «Не нашлось» относилось к прошлому треку.
            lookup = .idle
        }
    }

    private var stanzas: [String] { Lyrics.stanzas(of: text) }

    private var scroll: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                // Куплеты — просто куски текста, своего id у них нет, поэтому
                // ForEach считает по позиции.
                ForEach(Array(stanzas.enumerated()), id: \.offset) { _, stanza in
                    Text(stanza)
                        .lineSpacing(6)
                }
            }
            .font(.title3.weight(.semibold))
            .textSelection(.enabled)
            // Выделение текста — цветом обложки, как всё остальное в плеере.
            .tint(accent)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 16)
        }
        .scrollIndicators(.hidden)
        .lyricsFade()
    }

    /// Пустая панель не просто сообщает о пустоте, а предлагает её заполнить —
    /// пунктирными слотами, как везде в приложении, где «сюда можно что-то положить».
    /// Главный из них — поиск: чаще всего нужны слова песни, а они уже есть в LRCLIB.
    private var empty: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(lookup.kicker)
                .font(.caption2)
                .fontWeight(.semibold)
                .tracking(1.2)
                .foregroundStyle(.secondary)
                .contentTransition(.opacity)

            Text(lookup.hint)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                LyricsLookupSlot(status: lookup, accent: accent, action: find)
                DashedSlot(title: "Write", systemImage: "square.and.pencil", action: onEdit)
            }
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.easeOut(duration: 0.2), value: lookup)
    }

    /// Ищет текст в LRCLIB и сразу кладёт его в трек: панель пуста, затирать
    /// нечего, а «найти и потом ещё сохранить» — лишний шаг.
    private func find() {
        guard let track, lookup != .searching else { return }

        // Плеер знает длительность играющего трека, даже если в библиотеке
        // она ещё не записана, — а по ней выбирается запись с верными таймкодами.
        let query = LyricsLookup.Query(track: track, duration: audioPlayer.duration)
        let filename = track.filename
        lookup = .searching

        Task {
            let status = await LyricsLookupStatus.run(query) { text in
                // Пока шёл поиск, текст могли вписать руками — его не трогаем.
                // Пишется в тот трек, для которого искали, даже если играет уже другой.
                guard !track.hasLyrics else { return }
                track.lyrics = text
            }

            // Трек сменился — «не нашлось» к новому не относится.
            guard self.track?.filename == filename else { return }
            lookup = status
        }
    }
}

// MARK: - Синхронный текст

/// Текст с таймкодами: строка, которая звучит, горит, остальные притушены.
/// Панель сама держит звучащую строку на виду, а нажатие на строку
/// перематывает к ней — как лента, только по словам.
private struct SyncedLyricsView: View {

    let lines: [Lyrics.Line]
    let audioPlayer: AudioPlayer
    let accent: Color

    @State private var active: Int?
    /// Когда текст в последний раз листали пальцем. Пока человек читает
    /// сам, панель не утаскивает текст у него из-под пальца.
    @State private var scrolledByHandAt = Date.distantPast

    /// Сколько панель ждёт после ручной прокрутки, прежде чем снова
    /// повести текст за музыкой.
    private let handPause: TimeInterval = 4

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(lines.indices, id: \.self) { index in
                        row(index) {
                            seek(to: index, proxy: proxy)
                        }
                        .id(index)
                    }
                }
                .padding(.top, 16)
                // Запас снизу: последние строки тоже могут подняться
                // к месту чтения, а не застрять у нижнего края.
                .padding(.bottom, 160)
            }
            .scrollIndicators(.hidden)
            .lyricsFade()
            .onScrollPhaseChange { _, phase in
                if phase == .interacting || phase == .decelerating {
                    scrolledByHandAt = .now
                }
            }
            .onChange(of: active) { _, index in
                guard let index, Date.now.timeIntervalSince(scrolledByHandAt) > handPause else { return }
                withAnimation(.spring(response: 0.5, dampingFraction: 0.9)) {
                    proxy.scrollTo(index, anchor: Self.readingLine)
                }
            }
        }
        // Время плеера меняется пять раз в секунду. Читает его отдельная
        // пустая вьюха, а панели сообщает только смену строки — иначе весь
        // текст перерисовывался бы на каждом тике.
        .background {
            LyricsClock(audioPlayer: audioPlayer, lines: lines) { index in
                active = index
            }
        }
    }

    /// Звучащая строка держится на трети высоты: выше видно, что было,
    /// ниже — что будет, и глазу не приходится прыгать к краю.
    private static let readingLine = UnitPoint(x: 0.5, y: 0.3)

    private func row(_ index: Int, action: @escaping () -> Void) -> some View {
        let line = lines[index]
        let isActive = index == active
        let isPast = active.map { index < $0 } ?? false

        return Button(action: action) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                // Лампа, как на клавишах деки: горит у строки, которая звучит.
                DeckLamp(isOn: isActive, accent: accent)
                    .rotationEffect(.degrees(90))
                    .frame(width: 3)
                    .opacity(isActive ? 1 : 0)
                    .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 6 }

                // Проигрыш — точки, чтобы было видно, что слова ещё будут.
                Text(line.text.isEmpty ? "•  •  •" : line.text)
                    .font(.title2.weight(.bold))
                    .lineSpacing(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundStyle(isActive ? Color.primary : Color.secondary)
                    // Спетое гаснет сильнее того, что впереди: глаз ищет,
                    // куда читать дальше, а не что уже было.
                    .opacity(isActive ? 1 : (isPast ? 0.45 : 0.75))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.25), value: isActive)
        .accessibilityLabel(line.text.isEmpty ? "Instrumental break" : line.text)
        .accessibilityHint("Plays from this line")
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    /// Нажатая строка — это и «играй отсюда», и «веди текст снова сам».
    private func seek(to index: Int, proxy: ScrollViewProxy) {
        // Звук ещё не поднимали — сначала открываем трек, иначе
        // перематывать нечего. Так же поступает лента.
        if audioPlayer.duration == 0 { audioPlayer.resume() }

        audioPlayer.seek(to: lines[index].time)
        scrolledByHandAt = .distantPast
        active = index

        withAnimation(.spring(response: 0.5, dampingFraction: 0.9)) {
            proxy.scrollTo(index, anchor: Self.readingLine)
        }
    }
}

/// Следит за временем плеера и сообщает, какая строка звучит.
private struct LyricsClock: View {

    let audioPlayer: AudioPlayer
    let lines: [Lyrics.Line]
    let onLine: (Int?) -> Void

    /// Время плеера обновляется раз в 0,2 секунды, и строка загоралась бы
    /// уже после первого слова. Небольшое опережение возвращает её к началу.
    private static let lead: TimeInterval = 0.2

    var body: some View {
        let index = Lyrics.activeIndex(in: lines, at: audioPlayer.currentTime + Self.lead)

        Color.clear
            .onChange(of: index, initial: true) { _, index in
                onLine(index)
            }
    }
}

// MARK: - Поиск

/// Как прошёл поиск в LRCLIB. Общий для панели и редактора: обе кнопки
/// говорят об одном и том же одними словами.
enum LyricsLookupStatus: Equatable {
    case idle
    case searching
    case notFound
    case instrumental
    case failed

    /// Ищет и отдаёт найденный текст в `save`. Возвращает, чем кончилось:
    /// нашлось — снова `.idle`, кнопке больше нечего сообщать.
    static func run(_ query: LyricsLookup.Query, save: (String) -> Void) async -> LyricsLookupStatus {
        do {
            switch try await LyricsLookup.find(query) {
            case let .lyrics(text, _):
                save(text)
                return .idle
            case .instrumental:
                return .instrumental
            case .notFound:
                return .notFound
            }
        } catch {
            return .failed
        }
    }

    var kicker: String {
        switch self {
        case .idle: "NO TEXT YET"
        case .searching: "SEARCHING LRCLIB"
        case .notFound: "NOT ON LRCLIB"
        case .instrumental: "INSTRUMENTAL"
        case .failed: "NO CONNECTION"
        }
    }

    var hint: String {
        switch self {
        case .idle, .searching:
            "Find pulls the words from LRCLIB — often timed to the music. Or write your own: a translation, a note."
        case .notFound:
            "Nobody has added this track there yet. Check the title and artist — or write the text yourself."
        case .instrumental:
            "LRCLIB lists this track as having no words."
        case .failed:
            "LRCLIB didn't answer. Try again in a moment."
        }
    }
}

/// Слот поиска: тот же пунктир, что у `DashedSlot`, но цветом обложки —
/// это главное действие пустой панели. Пока идёт поиск, вместо значка крутится
/// индикатор, а нажатия не принимаются.
private struct LyricsLookupSlot: View {

    let status: LyricsLookupStatus
    let accent: Color
    let action: () -> Void

    private var isSearching: Bool { status == .searching }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isSearching {
                    ProgressView()
                        .controlSize(.small)
                        .tint(accent)
                } else {
                    Image(systemName: "icloud.and.arrow.down")
                }
                Text(title)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(accent)
            .frame(maxWidth: .infinity, minHeight: 60)
            .background {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .strokeBorder(accent.opacity(0.7), style: StrokeStyle(lineWidth: 1.5, dash: [5, 5]))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isSearching)
    }

    private var title: String {
        switch status {
        case .searching: "Searching…"
        case .failed: "Try again"
        default: "Find lyrics"
        }
    }
}

private extension View {

    /// Маска гасит текст у краёв: видно, что он продолжается, а строка не
    /// обрубается ровно пополам о невидимую границу.
    func lyricsFade() -> some View {
        mask {
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black, location: 0.07),
                    .init(color: .black, location: 0.93),
                    .init(color: .clear, location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}

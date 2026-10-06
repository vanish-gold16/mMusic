import SwiftData
import SwiftUI

/// Итоги года — как годовой чарт на последних страницах музыкального журнала.
///
/// Наверху год крупными сжатыми словами (если лет несколько — все, открытый
/// напечатан в полную силу, как разделы библиотеки). Под ним часы с музыкой —
/// самой крупной цифрой в приложении, — потом весь год одной звуковой дорожкой
/// по дням, как неделя на главной, и чарты треков, артистов и жанров
/// с большими номерами. Страница светится цветом обложки трека номер один.
struct WrappedView: View {

    @Environment(AudioPlayer.self) private var audioPlayer

    @Query private var events: [PlayEvent]
    /// Библиотека нужна топу треков: история помнит имя файла, но обложку и
    /// возможность включить песню даёт только сам трек.
    @Query private var libraryTracks: [Track]
    /// А артисты — чтобы строка артиста вела на его страницу.
    @Query private var libraryArtists: [Artist]

    @State private var year = Calendar.current.component(.year, from: .now)
    /// Цвета обложки трека номер один — ими светится страница.
    @State private var palette: CoverPalette?

    private var availableYears: [Int] {
        let years = WrappedSummary.years(in: events)
        return years.isEmpty ? [Calendar.current.component(.year, from: .now)] : years
    }

    /// Треки библиотеки по имени файла — по нему строка топа находит свой трек.
    private var tracksByFilename: [String: Track] {
        Dictionary(libraryTracks.map { ($0.filename, $0) }, uniquingKeysWith: { first, _ in first })
    }

    private var artistsByName: [String: Artist] {
        Dictionary(libraryArtists.map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })
    }

    var body: some View {
        // Свод — это проход по всей истории, поэтому считается один раз за
        // перерисовку и дальше передаётся уже готовым.
        let summary = WrappedSummary.make(from: events, year: year)
        let topTrack = summary.topTracks.first.flatMap { tracksByFilename[$0.key] }

        ScrollView {
            LazyVStack(alignment: .leading, spacing: 36) {
                masthead(summary)
                    .padding(.top, 4)

                if summary.plays == 0 {
                    LibraryEmptyState(text: "Nothing played in \(String(year)) yet")
                } else {
                    // Над цифрами такого кегля и так много воздуха — шрифт
                    // оставляет его под заглавные, которых в числе нет.
                    headline(summary)
                        .padding(.top, -20)
                    yearTape(summary)
                    topTracks(summary.topTracks)
                    chart("TOP ARTISTS", entries: summary.topArtists, linksToArtists: true)
                    chart("TOP GENRES", entries: summary.topGenres)
                }
            }
            .padding(.bottom, 32)
        }
        // `containerBackground`, а не `background`: у экрана в навигации своя
        // непрозрачная подложка.
        .containerBackground(for: .navigation) {
            CoverAura(palette: palette, breathes: false)
        }
        .tint(palette?.accent ?? audioPlayer.accent)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            // Открываем на последнем годе, где что-то слушали, а не на календарном.
            if !availableYears.contains(year), let latest = availableYears.first { year = latest }
        }
        .task(id: topTrack?.displayArtwork?.count) {
            await loadPalette(topTrack?.displayArtwork)
        }
    }

    // MARK: - Шапка

    private func masthead(_ summary: WrappedSummary) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if availableYears.count > 1 {
                // Самый крупный кегль, при котором все годы встают в строку.
                ViewThatFits(in: .horizontal) {
                    yearIndex(size: 44)
                    yearIndex(size: 34)
                    yearIndex(size: 26)
                }
            } else {
                Text(String(year))
                    .font(.system(size: 44, weight: .heavy).width(.compressed))
            }

            Text(passport(summary))
                .font(.caption2)
                .fontWeight(.semibold)
                .tracking(1.2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
    }

    private func yearIndex(size: CGFloat) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: size * 0.4) {
            ForEach(availableYears, id: \.self) { option in
                let isOpen = option == year

                Button {
                    withAnimation(.snappy(duration: 0.25)) { year = option }
                } label: {
                    Text(String(option))
                        .font(.system(size: size, weight: .heavy).width(.compressed))
                        .foregroundStyle(isOpen ? AnyShapeStyle(.primary) : AnyShapeStyle(.tertiary))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isOpen ? .isSelected : [])
            }
        }
        // Идеальная ширина, а не сжатая: по ней `ViewThatFits` и выбирает кегль.
        .fixedSize()
    }

    /// «IN MUSIC  ·  312 PLAYS  ·  87 DAYS  ·  12 IN A ROW».
    private func passport(_ summary: WrappedSummary) -> String {
        guard summary.plays > 0 else { return "IN MUSIC" }

        return [
            "IN MUSIC",
            ArtistDiscography.count(summary.plays, "PLAY", "PLAYS"),
            ArtistDiscography.count(summary.activeDays, "DAY", "DAYS"),
            summary.longestStreak > 1 ? "\(summary.longestStreak) IN A ROW" : nil,
        ]
        .compactMap { $0 }
        .joined(separator: "  ·  ")
    }

    // MARK: - Часы

    /// Час — естественная единица года, но в январе или у новичка часов ещё нет,
    /// и «0 hours» было бы обидной неправдой: тогда крупно идут минуты.
    /// Рядом — широта вкуса: одни часы не говорят, крутили вы весь год один
    /// альбом или полторы сотни разных песен.
    private func headline(_ summary: WrappedSummary) -> some View {
        let hours = summary.totalHours
        let value = hours >= 1 ? hours : summary.totalMinutes
        let unit = hours >= 1
            ? (hours == 1 ? "HOUR OF MUSIC" : "HOURS OF MUSIC")
            : (value == 1 ? "MINUTE OF MUSIC" : "MINUTES OF MUSIC")

        let details = [
            unit,
            ArtistDiscography.count(summary.distinctTracks, "TRACK", "TRACKS"),
            ArtistDiscography.count(summary.distinctArtists, "ARTIST", "ARTISTS"),
        ]
        .compactMap { $0 }
        .joined(separator: "  ·  ")

        return VStack(alignment: .leading, spacing: 0) {
            Text(value.formatted())
                .font(.system(size: 132, weight: .heavy).width(.compressed))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .foregroundStyle(.tint)

            Text(details)
                .font(.caption2)
                .fontWeight(.semibold)
                .tracking(1.2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Год

    /// Подпись самого громкого месяца — под дорожкой, а не у разделителя:
    /// там на неё не хватало места, и она рвалась на две строки. Его буква
    /// на дорожке горит тем же цветом.
    private func yearTape(_ summary: WrappedSummary) -> some View {
        let busiest = summary.monthlySeconds.indices.max { summary.monthlySeconds[$0] < summary.monthlySeconds[$1] }

        return VStack(alignment: .leading, spacing: 14) {
            CrateDivider(title: "THE YEAR")

            YearTape(
                daily: summary.dailySeconds,
                year: year,
                busiestMonth: summary.busiestMonth == nil ? nil : busiest,
                accent: palette?.accent ?? audioPlayer.accent
            )

            if let month = summary.busiestMonth {
                HStack(spacing: 0) {
                    Text("BUSIEST  ·  ")
                        .foregroundStyle(.secondary)
                    Text(month.name.uppercased())
                        .foregroundStyle(.tint)
                    Text("  ·  \(Self.listening(month.seconds))")
                        .foregroundStyle(.secondary)
                }
                .font(.caption2)
                .fontWeight(.semibold)
                .tracking(1.2)
                .accessibilityElement(children: .combine)
            }
        }
        .padding(.horizontal)
    }

    /// «41 H» или «35 MIN» — как время в паспортах по всему приложению.
    private static func listening(_ seconds: TimeInterval) -> String {
        let minutes = Int((seconds / 60).rounded())
        return minutes >= 60 ? "\(minutes / 60) H" : "\(minutes) MIN"
    }

    // MARK: - Чарты

    /// Единственный чарт, который умеет играть: за строкой артиста или жанра
    /// нет одного трека, который она означает.
    private func topTracks(_ entries: [WrappedSummary.Entry]) -> some View {
        let peak = entries.first?.seconds ?? 0
        // Часть топа могла уже уйти из библиотеки — история её помнит, а играть
        // нечего. Очередь собирается из того, что осталось.
        let available = entries.compactMap { tracksByFilename[$0.key] }

        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                CrateDivider(title: "TOP TRACKS", detail: "\(entries.count)")

                if !available.isEmpty {
                    Button {
                        audioPlayer.play(available)
                    } label: {
                        Image(systemName: "play.fill")
                            .font(.subheadline.weight(.semibold))
                            .frame(width: 22, height: 22)
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
                    .padding(.top, 8)
                    .accessibilityLabel("Play top tracks")
                }
            }

            ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                let track = tracksByFilename[entry.key]

                Button {
                    guard let track,
                          let start = available.firstIndex(where: { $0.persistentModelID == track.persistentModelID })
                    else { return }

                    audioPlayer.play(available, startingAt: start)
                } label: {
                    ChartRow(rank: index + 1, entry: entry, peak: peak, track: track)
                }
                .buttonStyle(.plain)
                .disabled(track == nil)
            }
        }
        .padding(.horizontal)
    }

    /// Чарт артистов или жанров. В чарте артистов строка того, кто ещё
    /// в библиотеке, ведёт на его страницу.
    @ViewBuilder
    private func chart(_ title: String, entries: [WrappedSummary.Entry], linksToArtists: Bool = false) -> some View {
        if !entries.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                CrateDivider(title: title, detail: "\(entries.count)")

                ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                    let row = ChartRow(rank: index + 1, entry: entry, peak: entries[0].seconds)

                    if linksToArtists, let artist = artistsByName[entry.key] {
                        NavigationLink {
                            ArtistView(artist: artist)
                        } label: {
                            row
                        }
                        .buttonStyle(.plain)
                    } else {
                        row
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Цвета

    /// Цвета обложки трека номер один. Миниатюры хватает: нужен только цвет.
    private func loadPalette(_ data: Data?) async {
        guard let data else {
            palette = nil
            return
        }

        let palette = await Task.detached(priority: .utility) {
            UIImage.thumbnail(from: data, side: 200)?.coverPalette
        }.value

        guard !Task.isCancelled else { return }
        self.palette = palette
    }
}

/// Строка чарта: большой номер, как в годовом чарте журнала, обложка, если это
/// трек, имя с полоской доли и время. Номер один напечатан цветом страницы.
private struct ChartRow: View {

    let rank: Int
    let entry: WrappedSummary.Entry
    /// Время первой строки: от него меряется полоска доли.
    let peak: TimeInterval
    var track: Track? = nil

    @State private var cover: UIImage?

    var body: some View {
        HStack(spacing: 12) {
            Text("\(rank)")
                .font(.system(size: 34, weight: .heavy).width(.compressed))
                .monospacedDigit()
                .foregroundStyle(rank == 1 ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
                .frame(width: 24, alignment: .leading)

            if track != nil {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(.quaternary)
                    .frame(width: 44, height: 44)
                    .overlay {
                        if let cover {
                            Image(uiImage: cover)
                                .resizable()
                                .scaledToFill()
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.name)
                    .font(.system(size: 20, weight: .heavy).width(.compressed))
                    .lineLimit(1)

                if let track, !track.artistNames.isEmpty {
                    Text(track.artistNames.joined(separator: ", "))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                ShareBar(seconds: entry.seconds, peak: peak)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(entry.minutes) MIN")
                    .foregroundStyle(.primary)

                Text(entry.count == 1 ? "1 PLAY" : "\(entry.count) PLAYS")
                    .foregroundStyle(.secondary)
            }
            .font(.caption2)
            .fontWeight(.semibold)
            .tracking(1.2)
            .monospacedDigit()
        }
        .contentShape(.rect)
        .task(id: track?.displayArtwork?.count) {
            await loadCover()
        }
    }

    /// Обложка здесь 44 pt — около 130 px на экране @3x.
    private func loadCover() async {
        guard let data = track?.displayArtwork else {
            cover = nil
            return
        }

        let image = await Task.detached(priority: .utility) {
            UIImage.thumbnail(from: data, side: 140)
        }.value

        guard !Task.isCancelled else { return }
        cover = image
    }
}

/// Полоска доли: длина — время строки относительно первой в чарте. По ней
/// сразу видно, отрыв это или почти ничья.
private struct ShareBar: View {

    let seconds: TimeInterval
    let peak: TimeInterval

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.quaternary)

                Capsule()
                    .fill(.tint)
                    .frame(width: max(4, proxy.size.width * (peak > 0 ? seconds / peak : 0)))
            }
        }
        .frame(height: 3)
    }
}

/// Год одной звуковой дорожкой: столбик — несколько дней подряд, высота —
/// сколько в эти дни звучала музыка. Тот же рисунок, что у недели на главной
/// (`WeekTape`), только в масштабе года. Под дорожкой — буквы месяцев, самый
/// громкий месяц — цветом страницы. В текущем году ещё не наступившие дни
/// едва видны: год не кончился.
private struct YearTape: View {

    let daily: [TimeInterval]
    let year: Int
    /// Месяц с самым большим временем, с нуля. nil — год пустой.
    let busiestMonth: Int?
    let accent: Color

    private let step: CGFloat = 3
    private let barWidth: CGFloat = 2
    private let tapeHeight: CGFloat = 64
    private let labelHeight: CGFloat = 14

    /// Сегодняшний день года, с нуля, — если открыт текущий год.
    private var today: Int? {
        let calendar = Calendar.current
        guard calendar.component(.year, from: .now) == year,
              let day = calendar.ordinality(of: .day, in: .year, for: .now)
        else { return nil }
        return day - 1
    }

    /// С какого дня года начинается каждый месяц, с нуля.
    private var monthStarts: [Int] {
        let calendar = Calendar.current
        return (1...12).map { month in
            guard let date = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
                  let day = calendar.ordinality(of: .day, in: .year, for: date)
            else { return 0 }
            return day - 1
        }
    }

    var body: some View {
        let today = today
        let monthStarts = monthStarts
        let letters = Calendar.current.veryShortMonthSymbols

        Canvas { context, size in
            let days = max(daily.count, 1)
            let count = max(Int(size.width / step), 1)

            // Дни раскладываются по столбикам; столбик — сумма своих дней.
            var bars = [TimeInterval](repeating: 0, count: count)
            for (day, seconds) in daily.enumerated() {
                bars[min(day * count / days, count - 1)] += seconds
            }
            let peak = bars.max() ?? 0

            for bar in 0..<count {
                let firstDay = bar * days / count
                let isFuture = today.map { firstDay > $0 } ?? false

                // Корень, а не прямая доля: иначе тихие недели рядом с самой
                // громкой пропали бы совсем.
                let level = peak > 0 ? sqrt(bars[bar] / peak) : 0
                let height = bars[bar] > 0 ? max(3, level * tapeHeight) : 2
                let rect = CGRect(
                    x: CGFloat(bar) * step,
                    y: (tapeHeight - height) / 2,
                    width: barWidth,
                    height: height
                )

                let color: Color = if isFuture {
                    .primary.opacity(0.06)
                } else if bars[bar] > 0 {
                    accent
                } else {
                    .primary.opacity(0.15)
                }
                context.fill(Path(roundedRect: rect, cornerRadius: 1), with: .color(color))
            }

            // Буквы месяцев — под первым столбиком каждого месяца.
            for (month, start) in monthStarts.enumerated() where letters.indices.contains(month) {
                let x = CGFloat(start * count / days) * step
                let style: Color = month == busiestMonth ? accent : .secondary
                context.draw(
                    Text(letters[month])
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(style),
                    at: CGPoint(x: x, y: tapeHeight + 4),
                    anchor: .topLeading
                )
            }
        }
        .frame(height: tapeHeight + labelHeight + 4)
        .accessibilityElement()
        .accessibilityLabel("Listening through the year")
    }
}

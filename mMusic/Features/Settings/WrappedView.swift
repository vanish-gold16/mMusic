import SwiftData
import SwiftUI

/// Итоги года. Крупные цифры моноширинно и почти без украшений —
/// сама статистика здесь и есть содержание.
struct WrappedView: View {

    @Environment(AudioPlayer.self) private var audioPlayer

    @Query private var events: [PlayEvent]
    /// Библиотека нужна топу треков: история помнит имя файла, но обложку и
    /// возможность включить песню даёт только сам трек.
    @Query private var libraryTracks: [Track]
    /// А артисты — ради фотографий в топе.
    @Query private var libraryArtists: [Artist]

    @State private var year = Calendar.current.component(.year, from: .now)

    /// Высота столбика месяца. Задана числом, а не местом на экране: полоса года
    /// должна выглядеть одинаково и в январе, и в декабре.
    private let monthBarHeight: CGFloat = 88

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
        ScrollView {
            // Свод — это проход по всей истории, поэтому считается один раз за
            // перерисовку и дальше передаётся уже готовым.
            report(WrappedSummary.make(from: events, year: year))
                .padding(.vertical)
        }
        .navigationTitle("\(String(year)) in music")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            // Открываем на последнем годе, где что-то слушали, а не на календарном.
            if !availableYears.contains(year), let latest = availableYears.first { year = latest }
        }
    }

    @ViewBuilder
    private func report(_ summary: WrappedSummary) -> some View {
        LazyVStack(alignment: .leading, spacing: 28) {
            if availableYears.count > 1 {
                Picker("Year", selection: $year) {
                    ForEach(availableYears, id: \.self) { year in
                        Text(String(year)).tag(year)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
            }

            if summary.plays == 0 {
                LibraryEmptyState(text: "Nothing played in \(String(year)) yet")
            } else {
                headline(summary)
                stats(summary)
                months(summary)
                topTracks(summary.topTracks)
                list("Top artists", entries: summary.topArtists, artists: artistsByName)
                list("Top genres", entries: summary.topGenres)
            }
        }
    }

    /// Час — естественная единица года, но в январе или у новичка часов ещё нет,
    /// и «0 hours» было бы обидной неправдой: тогда крупно идут минуты.
    private func headline(_ summary: WrappedSummary) -> some View {
        let hours = summary.totalHours
        let value = hours >= 1 ? hours : summary.totalMinutes
        let unit = hours >= 1
            ? (hours == 1 ? "hour" : "hours")
            : (value == 1 ? "minute" : "minutes")

        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(value.formatted())
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .foregroundStyle(.tint)

                Text(unit)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            Text(breadth(summary))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
    }

    /// Широта вкуса рядом с его глубиной: одни часы не говорят, крутили вы весь
    /// год один альбом или полторы сотни разных песен.
    private func breadth(_ summary: WrappedSummary) -> String {
        let tracks = summary.distinctTracks == 1 ? "1 track" : "\(summary.distinctTracks) tracks"
        let artists = summary.distinctArtists == 1 ? "1 artist" : "\(summary.distinctArtists) artists"

        return "\(tracks) • \(artists)"
    }

    private func stats(_ summary: WrappedSummary) -> some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 76), alignment: .leading)],
            alignment: .leading,
            spacing: 16
        ) {
            stat("\(summary.plays)", label: summary.plays == 1 ? "play" : "plays")
            stat("\(summary.activeDays)", label: summary.activeDays == 1 ? "day" : "days")
            stat("\(summary.longestStreak)", label: "in a row")

            if let month = summary.busiestMonth {
                stat(String(month.name.prefix(3)), label: "busiest")
            }
        }
        .padding(.horizontal)
    }

    private func stat(_ value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.title2)
                .bold()
                .monospacedDigit()

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    /// Год столбиками. Все двенадцать одного цвета: длина уже и есть значение,
    /// красить её ещё и оттенком — сказать одно и то же дважды. Число подписано
    /// только у пика: двенадцать чисел в ряд всё равно никто не прочитает.
    private func months(_ summary: WrappedSummary) -> some View {
        let peak = summary.monthlySeconds.max() ?? 0
        let symbols = Calendar.current.veryShortMonthSymbols

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionLabel("Months")

                Spacer()

                if let month = summary.busiestMonth {
                    Text("\(month.name) • \(Int((month.seconds / 60).rounded())) min")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                }
            }

            HStack(alignment: .bottom, spacing: 4) {
                ForEach(Array(symbols.enumerated()), id: \.offset) { index, symbol in
                    VStack(spacing: 6) {
                        monthBar(seconds: summary.monthlySeconds[index], peak: peak)

                        Text(symbol)
                            .font(.caption2)
                            .foregroundStyle(summary.monthlySeconds[index] > 0 ? .secondary : .tertiary)
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    private func monthBar(seconds: TimeInterval, peak: TimeInterval) -> some View {
        let shape = UnevenRoundedRectangle(topLeadingRadius: 4, topTrailingRadius: 4)
        let filled = peak > 0 ? monthBarHeight * (seconds / peak) : 0

        return ZStack(alignment: .bottom) {
            // Дорожка пустого месяца еле видна: это мера, а не значение.
            shape.fill(.quaternary.opacity(0.5))

            // Месяц с крохотным временем всё равно получает несколько точек
            // высоты: иначе он неотличим от месяца, когда не слушали вовсе.
            shape
                .fill(.tint)
                .frame(height: seconds > 0 ? max(3, filled) : 0)
        }
        .frame(height: monthBarHeight)
    }

    /// Единственный список, который умеет играть: за строкой артиста или жанра
    /// нет одного трека, который она означает.
    private func topTracks(_ entries: [WrappedSummary.Entry]) -> some View {
        let peak = entries.first?.seconds ?? 0
        // Часть топа могла уже уйти из библиотеки — история её помнит, а играть
        // нечего. Очередь собирается из того, что осталось.
        let available = entries.compactMap { tracksByFilename[$0.key] }

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionLabel("Top tracks")

                Spacer()

                if !available.isEmpty {
                    Button {
                        audioPlayer.play(available)
                    } label: {
                        Image(systemName: "play.fill")
                    }
                    .padding(.horizontal)
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
                    row(rank: index + 1, entry: entry, peak: peak, track: track)
                }
                .buttonStyle(.plain)
                .disabled(track == nil)
            }
        }
    }

    /// Артисты передаются словарём: фотография есть только у тех, кто ещё в
    /// библиотеке и кому её поставили, — у жанров же лица нет вовсе.
    @ViewBuilder
    private func list(
        _ title: String,
        entries: [WrappedSummary.Entry],
        artists: [String: Artist] = [:]
    ) -> some View {
        if !entries.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(title)

                ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                    row(rank: index + 1, entry: entry, peak: entries[0].seconds, artist: artists[entry.key])
                }
            }
        }
    }

    private func row(
        rank: Int,
        entry: WrappedSummary.Entry,
        peak: TimeInterval,
        track: Track? = nil,
        artist: Artist? = nil
    ) -> some View {
        HStack(spacing: 12) {
            Text("\(rank)")
                .font(.subheadline)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 18, alignment: .trailing)

            if let track {
                artwork(track)
            } else if let artist, artist.artwork != nil {
                ArtistAvatar(artist: artist, size: 40)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(entry.name)
                    .lineLimit(1)

                shareBar(entry.seconds, of: peak)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(entry.minutes) min")
                    .font(.subheadline)
                    .monospacedDigit()

                Text(entry.count == 1 ? "1 play" : "\(entry.count) plays")
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
        .contentShape(.rect)
    }

    private func artwork(_ track: Track) -> some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(.quaternary)
            .frame(width: 40, height: 40)
            .overlay {
                if let data = track.displayArtwork, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "music.note")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    /// Полоска доли: длина — время строки относительно первой в списке. По ней
    /// сразу видно, отрыв это или почти ничья.
    private func shareBar(_ seconds: TimeInterval, of peak: TimeInterval) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.quaternary)

                Capsule()
                    .fill(.tint)
                    .frame(width: max(4, proxy.size.width * (peak > 0 ? seconds / peak : 0)))
            }
        }
        .frame(height: 4)
    }
}

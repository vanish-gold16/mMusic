import SwiftData
import SwiftUI

/// Страница артиста. Наверху его пластинка: фотография на яблоке, кольца — его
/// релизы за всю карьеру (`ArtistRecord`), рядом — сколько времени вы вместе.
/// Ниже имя крупным сжатым шрифтом, паспорт и кнопки.
///
/// Пластинки разложены по разделителям, как в ящике магазина: альбомы,
/// синглы с EP и чужие пластинки, где он гость, — у тех светятся кольца
/// его треков. В самом низу — все его треки.
struct ArtistView: View {

    @Environment(AudioPlayer.self) private var audioPlayer
    @Environment(\.modelContext) private var modelContext
    /// Открыты изнутри плеера — значит, и фон продолжаем его.
    @Environment(\.isInsidePlayer) private var isInsidePlayer

    @Bindable var artist: Artist

    @State private var sortOption: SortOption = .mostPlayed
    /// Время с артистом — снимок, а не живой запрос: пока трек играет, история
    /// пересчитывается пять раз в секунду, и `@Query` перерисовывал бы на каждый
    /// тик весь список треков. Снимок обновляется, когда играть начинает
    /// следующий трек, — то есть ровно тогда, когда прошлое число устарело.
    @State private var listening: ArtistListening?

    /// Уменьшенная фотография и цвета страницы. Считаются в `.task`, а не
    /// в `body`: фотография весит мегабайты, а `body` пересчитывается на каждой
    /// смене трека.
    @State private var photo: UIImage?
    @State private var photoPalette: CoverPalette?

    private enum SortOption: String, CaseIterable, Identifiable {
        case mostPlayed = "Most played"
        case albumOrder = "Album order"
        case name = "Name"
        case recent = "Recently played"

        var id: String { rawValue }

        var systemImage: String {
            switch self {
            case .albumOrder: "square.stack"
            case .mostPlayed: "play.circle"
            case .name: "textformat"
            case .recent: "clock"
            }
        }
    }

    private let albumColumns = [GridItem(.flexible(), spacing: 16, alignment: .top),
                                GridItem(.flexible(), spacing: 16, alignment: .top)]

    /// Синглы мельче альбомов, как семидюймовки рядом с двенадцатидюймовыми,
    /// и их обычно больше — в три колонки.
    private let singleColumns = Array(repeating: GridItem(.flexible(), spacing: 12, alignment: .top), count: 3)

    private var discography: ArtistDiscography {
        ArtistDiscography(artist: artist)
    }

    /// Порядок по альбомам — исходный, его и оставляем как есть.
    private func sorted(_ tracks: [Track]) -> [Track] {
        switch sortOption {
        case .mostPlayed:
            // При равном счёте порядок альбома — иначе непрослушанные встают как попало.
            tracks.enumerated()
                .sorted { ($0.element.playCount, $1.offset) > ($1.element.playCount, $0.offset) }
                .map(\.element)
        case .albumOrder:
            tracks
        case .name:
            tracks.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .recent:
            tracks.sorted { ($0.lastPlayedAt ?? .distantPast) > ($1.lastPlayedAt ?? .distantPast) }
        }
    }

    /// Играет его трек — откуда бы его ни запустили.
    private var isPlayingArtist: Bool {
        audioPlayer.currentTrack?.artists.contains { $0.persistentModelID == artist.persistentModelID } ?? false
    }

    /// Пока играет его трек, страница в цветах этого трека и дышит под него;
    /// в остальное время — в цветах фотографии или последней пластинки.
    private var pagePalette: CoverPalette? {
        isPlayingArtist ? audioPlayer.palette : photoPalette
    }

    private var accent: Color {
        pagePalette?.accent ?? audioPlayer.accent
    }

    var body: some View {
        let discography = discography
        let tracks = sorted(discography.tracks)

        ScrollView {
            LazyVStack(alignment: .leading, spacing: 28) {
                header(discography: discography, tracks: tracks)

                if !discography.albums.isEmpty {
                    shelf("ALBUMS", count: discography.albums.count) {
                        LazyVGrid(columns: albumColumns, spacing: 24) {
                            ForEach(discography.albums) { album in
                                AlbumCell(album: album, byline: coauthors(of: album))
                            }
                        }
                    }
                }

                if !discography.singles.isEmpty {
                    shelf(singlesTitle(discography.singles), count: discography.singles.count) {
                        LazyVGrid(columns: singleColumns, spacing: 20) {
                            ForEach(discography.singles) { album in
                                AlbumCell(album: album, byline: coauthors(of: album), isCompact: true)
                            }
                        }
                    }
                }

                if !discography.featuredOn.isEmpty {
                    shelf("FEATURED ON", count: discography.featuredOn.count) {
                        LazyVGrid(columns: albumColumns, spacing: 24) {
                            ForEach(discography.featuredOn) { album in
                                AlbumCell(
                                    album: album,
                                    byline: hosts(of: album),
                                    guestTracks: discography.guestTracks(on: album)
                                )
                            }
                        }
                    }
                }

                if tracks.isEmpty {
                    LibraryEmptyState(text: "Nothing in the library credits this artist yet")
                } else {
                    trackList(tracks)
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        // Кнопки, эквалайзер и подсветка — в цвет страницы.
        .tint(accent)
        .task(id: audioPlayer.currentTrack?.id) {
            listening = ArtistListening.make(
                for: artist.name,
                filenames: Set(tracks.map(\.filename)),
                in: modelContext
            )
        }
        .task(id: [artist.artwork?.count, discography.newestCover?.count]) {
            await loadPhoto(fallback: discography.newestCover)
        }
        // `containerBackground`, а не `background`: у вложенного экрана своя
        // непрозрачная подложка, и закрасить её можно только фоном контейнера —
        // зато он ложится и под панель навигации.
        .containerBackground(for: .navigation) {
            if isInsidePlayer {
                PlayerBackground(audioPlayer: audioPlayer)
            } else {
                CoverAura(palette: pagePalette, breathes: isPlayingArtist)
            }
        }
    }

    // MARK: - Шапка

    /// Пластинка и время вместе, под ними имя, паспорт и кнопки. Всё по левому
    /// краю: круглое фото по центру с именем под ним — ровно та страница
    /// артиста, на которую эта не должна быть похожа.
    private func header(discography: ArtistDiscography, tracks: [Track]) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .center, spacing: 20) {
                ArtistRecord(
                    artist: artist,
                    releases: discography.career,
                    photo: photo,
                    labelPaper: photoPalette?.accent,
                    accent: accent,
                    onTapRelease: playRelease
                )
                .frame(width: 196, height: 196)

                timeTogether
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(artist.name)
                    .font(.system(size: 44, weight: .heavy).width(.compressed))
                    .lineLimit(3)
                    .minimumScaleFactor(0.6)

                Text(passport(discography: discography, tracks: tracks))
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .tracking(1.2)
                    .lineSpacing(3)
                    .foregroundStyle(.secondary)
            }

            if !tracks.isEmpty {
                controls(tracks)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
    }

    /// Время с артистом — одной цифрой рядом с пластинкой, как на обороте
    /// конверта пишут хронометраж. Часы дублируют минуты намеренно:
    /// «1 240» само по себе уже не читается как время.
    private var timeTogether: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let listening, listening.plays > 0 {
                Text(listening.minutes.formatted())
                    .font(.system(size: 44, weight: .heavy).width(.compressed))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)

                Text(listening.minutes == 1 ? "MINUTE TOGETHER" : "MINUTES TOGETHER")
                    .foregroundStyle(.secondary)

                if let details = togetherDetails(listening) {
                    Text(details)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 6)
                }
            } else {
                Text("NOT PLAYED YET")
                    .foregroundStyle(.tertiary)
            }
        }
        .font(.caption2)
        .fontWeight(.semibold)
        .tracking(1.2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    /// Часы и месяц первой встречи, по строке на каждое.
    private func togetherDetails(_ listening: ArtistListening) -> String? {
        var lines: [String] = []

        if let long = listening.hoursAndMinutes { lines.append(long) }

        if let first = listening.firstPlayedAt {
            let month = first.formatted(.dateTime.month(.abbreviated).year().locale(.interface))
            lines.append("since \(month)")
        }

        return lines.isEmpty ? nil : lines.joined(separator: "\n").uppercased()
    }

    /// Две строки: пластинки — «2 ALBUMS  ·  1 EP  ·  6 SINGLES», под ними
    /// треки — «48 TRACKS  ·  312 PLAYS». Только то, чего больше нуля. Строки
    /// заданы руками, а не переносом: одной строкой паспорт рвался посередине,
    /// и точка повисала в конце.
    private func passport(discography: ArtistDiscography, tracks: [Track]) -> String {
        let plays = tracks.reduce(0) { $0 + $1.playCount }
        let music = [
            ArtistDiscography.count(tracks.count, "TRACK", "TRACKS"),
            ArtistDiscography.count(plays, "PLAY", "PLAYS"),
        ].compactMap { $0 }

        let lines = [discography.recordsSummary, music.isEmpty ? nil : music.joined(separator: "  ·  ")]
            .compactMap { $0 }

        return lines.isEmpty ? "NOTHING HERE YET" : lines.joined(separator: "\n")
    }

    /// Запуск и перемешивание всех треков. Без ленты, как у альбома: где
    /// играющая пластинка, и так видно по кольцам.
    private func controls(_ tracks: [Track]) -> some View {
        let isPlayingHere = contains(audioPlayer.currentTrack, in: tracks) && audioPlayer.isPlaying

        return HStack(spacing: 12) {
            Button {
                playOrPause(tracks)
            } label: {
                Label(isPlayingHere ? "Pause" : "Play", systemImage: isPlayingHere ? "pause.fill" : "play.fill")
                    .font(.headline)
                    .contentTransition(.symbolEffect(.replace))
                    .padding(.horizontal, 12)
                    .frame(height: 36)
            }
            .buttonStyle(.glassProminent)

            Button {
                audioPlayer.playShuffled(tracks)
            } label: {
                Image(systemName: "shuffle")
                    .font(.body.weight(.semibold))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .accessibilityLabel("Shuffle")

            RadarArtistButton(name: artist.name)
        }
    }

    // MARK: - Пластинки

    /// Раздел за разделителем ящика: крупная метка, черта и число.
    private func shelf<Content: View>(
        _ title: String,
        count: Int,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            CrateDivider(title: title, detail: "\(count)")
            content()
        }
        .padding(.horizontal)
    }

    /// «SINGLES & EPs», а если EP нет или нет синглов — только то, что есть.
    private func singlesTitle(_ releases: [Album]) -> String {
        let hasEPs = releases.contains { $0.type == .EP }
        let hasSingles = releases.contains { $0.type == .single }

        switch (hasSingles, hasEPs) {
        case (true, true): return "SINGLES & EPs"
        case (false, true): return "EPs"
        default: return "SINGLES"
        }
    }

    /// Под своей пластинкой — только те, с кем он её делил: его имя здесь
    /// и так на каждой.
    private func coauthors(of album: Album) -> String {
        let others = otherArtists(on: album)
        return others.isEmpty ? "" : "with \(others.joined(separator: ", "))"
    }

    /// Под чужой — чья она.
    private func hosts(of album: Album) -> String {
        otherArtists(on: album).joined(separator: ", ")
    }

    private func otherArtists(on album: Album) -> [String] {
        album.artists
            .filter { $0.persistentModelID != artist.persistentModelID }
            .map(\.name)
    }

    // MARK: - Треки

    private func trackList(_ tracks: [Track]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                CrateDivider(title: "TRACKS", detail: "\(tracks.count)")
                sortMenu
            }
            .padding(.horizontal)
            .padding(.bottom, 6)

            ForEach(tracks) { track in
                TrackCell(track: track, queue: tracks, leadingStyle: .artwork, showPlayCount: true)
            }
        }
    }

    private var sortMenu: some View {
        Menu {
            Picker("Sort By", selection: $sortOption) {
                ForEach(SortOption.allCases) { option in
                    Label(option.rawValue, systemImage: option.systemImage)
                        .tag(option)
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
                .font(.subheadline.weight(.semibold))
                .frame(width: 22, height: 22)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .padding(.top, 8)
        .accessibilityLabel("Sort tracks")
    }

    // MARK: - Воспроизведение

    private func contains(_ track: Track?, in tracks: [Track]) -> Bool {
        guard let track else { return false }
        return tracks.contains { $0.id == track.id }
    }

    /// Играет что-то из этого — ставит паузу и снимает её. Играет что-то
    /// другое — запускает это с начала.
    private func playOrPause(_ tracks: [Track]) {
        if contains(audioPlayer.currentTrack, in: tracks) {
            audioPlayer.togglePlayPause()
        } else {
            audioPlayer.play(tracks)
        }
    }

    /// Кольцо на пластинке артиста: играет эта пластинка — пауза,
    /// иначе она ставится с начала.
    private func playRelease(_ album: Album) {
        playOrPause(album.tracklist)
    }

    // MARK: - Фотография

    /// Яблоко на пластинке — около 100 pt, это ~300 px на экране @3x; с запасом
    /// под цвета. Без фотографии цвета берутся с последней пластинки, а яблоко
    /// остаётся пустым: чужая обложка на месте лица сбивала бы с толку.
    private func loadPhoto(fallback: Data?) async {
        let data = artist.artwork

        let (image, palette) = await Task.detached(priority: .utility) {
            let image = data.flatMap { UIImage.thumbnail(from: $0, side: 400) }
            let source = image ?? fallback.flatMap { UIImage.thumbnail(from: $0, side: 200) }
            return (image, source?.coverPalette)
        }.value

        guard !Task.isCancelled else { return }

        photo = image
        photoPalette = palette
    }
}

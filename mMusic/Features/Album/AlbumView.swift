import SwiftData
import SwiftUI

/// Страница альбома — как пластинка, которую достали из ящика и перевернули.
///
/// Наверху конверт с диском. Пока альбом играет, диск выезжает почти целиком
/// и крутится, а на кольце текущего трека игла показывает, сколько сыграно.
/// По кольцам можно нажимать — как опустить иглу на нужную дорожку. От диска
/// по странице расходятся волны цвета обложки и дышат под музыку.
///
/// Ниже — оборот конверта: трек-лист по сторонам A и B с номерами «A1», «B2»
/// и мелкий текст внизу. С плейлистом общий только шрифт: у того веер карт,
/// лента и свечение, у альбома — одна пластинка и волны от неё.
///
/// Альбом из нескольких пластинок открывается закрытым: в конверте стопка,
/// а вместо трек-листа — сами пластинки, каждая со своим узором колец.
/// Выбранная выезжает из конверта, и под ней — её стороны: у второй C и D,
/// как на двойном виниле.
struct AlbumView: View {

    @Environment(AudioPlayer.self) var audioPlayer
    @Environment(ToastCenter.self) private var toasts

    var album: Album

    @State private var editingAlbum = false
    @State private var showAddToPlaylist = false

    /// Уменьшенная обложка и её цвета. Считаются один раз в `.task`, а не в `body`:
    /// полноразмерная обложка весит мегабайты, а `body` пересчитывается на каждой
    /// смене трека.
    @State private var cover: UIImage?
    @State private var coverPalette: CoverPalette?

    /// Открытая пластинка альбома из нескольких. nil — альбом закрыт,
    /// и на экране выбор пластинки.
    @State private var openDisc: Int?
    /// Играющую пластинку открываем сами один раз, при первом показе.
    /// Иначе закрытый альбом открывался бы снова при каждом возврате на экран.
    @State private var didOpenPlayingDisc = false

    private var sortedTracks: [Track] {
        album.tracks.sorted { $0.position < $1.position }
    }

    private var isMultiDisc: Bool {
        album.discCount > 1
    }

    /// Где играющий трек, если он из этого альбома. Очередь, как у плейлиста,
    /// проверять незачем: альбом у трека один.
    private var playing: DiscPosition? {
        album.position(of: audioPlayer.currentTrack)
    }

    /// Пока альбом играет, страница в цветах играющего трека — у трека может
    /// быть своя обложка. В остальное время — в цветах конверта.
    private var pagePalette: CoverPalette? {
        playing != nil ? audioPlayer.palette : coverPalette
    }

    private var accent: Color {
        pagePalette?.accent ?? audioPlayer.accent
    }

    /// Что на экране и что играют кнопки: у открытой пластинки — она,
    /// в остальных случаях — весь альбом.
    private func scope(in discs: [[Track]]) -> [Track] {
        if isMultiDisc, let openDisc, discs.indices.contains(openDisc) {
            return discs[openDisc]
        }
        return sortedTracks
    }

    var body: some View {
        let discs = album.discs
        let scope = scope(in: discs)
        let isClosed = isMultiDisc && openDisc == nil

        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                AlbumHero(
                    album: album,
                    discs: discs,
                    openDisc: openDisc,
                    cover: cover,
                    accent: accent,
                    onTapTrack: { disc, index, fraction in
                        tapRing(index, fraction, in: discs[disc])
                    }
                )
                .padding(.horizontal)
                .padding(.top, 8)

                titleBlock

                if isMultiDisc, let openDisc {
                    discBar(openDisc)
                }

                if !scope.isEmpty {
                    controls(scope)
                }

                if isClosed {
                    discList(discs)
                } else if scope.isEmpty, isMultiDisc {
                    LibraryEmptyState(text: "Nothing on this disc yet")
                } else {
                    tracklist(scope, disc: openDisc ?? 0)
                }

                linerNotes
                    .padding(.top, 8)
            }
            .padding(.bottom, 24)
        }
        // Кнопки, эквалайзер и подсветка — в цвет пластинки. Строго до `.toolbar`
        // и `.sheet`: листы правки остаются в цвете всего приложения.
        .tint(accent)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    album.isFavourite.toggle()
                } label: {
                    Image(systemName: album.isFavourite ? "star.fill": "star")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        editingAlbum = true
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }

                    // Треки уходят в порядке альбома: sortedTracks уже упорядочен
                    // по position, а плейлист раздаёт позиции подряд.
                    Button {
                        showAddToPlaylist = true
                    } label: {
                        Label("Add to a Playlist", systemImage: "text.badge.plus")
                    }

                    Divider()

                    Button {
                        audioPlayer.enqueueNext(sortedTracks)
                        toasts.enqueuedNext(sortedTracks.count)
                    } label: {
                        Label("Play next", systemImage: "text.line.first.and.arrowtriangle.forward")
                    }
                    Button {
                        audioPlayer.enqueueLast(sortedTracks)
                        toasts.enqueuedLast(sortedTracks.count)
                    } label: {
                        Label("Play after", systemImage: "text.line.last.and.arrowtriangle.forward")
                    }

                    Divider()

                    ShareLink(items: sortedTracks.map { AudioFileStore.url(for: $0.filename) }) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
            }
        }
        .sheet(isPresented: $editingAlbum) {
            EditAlbumView(album: album)
        }
        .sheet(isPresented: $showAddToPlaylist) {
            AddToPlaylistView(tracks: sortedTracks)
        }
        .task(id: album.artwork?.count) {
            await loadCover()
        }
        .onAppear {
            // Альбом уже играет — его пластинка «на проигрывателе», с неё и начинаем.
            guard !didOpenPlayingDisc else { return }
            didOpenPlayingDisc = true
            if isMultiDisc { openDisc = playing?.disc }
        }
        .onChange(of: playing?.disc) { previous, current in
            // Пластинка доиграла, и пошла следующая: открытая едет за ней.
            // Если же открыта другая, её не отбираем — человек её смотрит.
            guard isMultiDisc, let current, openDisc == previous, previous != nil else { return }
            withAnimation(.spring(duration: 0.55, bounce: 0.2)) {
                openDisc = current
            }
        }
        .onChange(of: album.discCount) { _, count in
            // Пластинку убрали в редакторе — открытой больше нет.
            if let openDisc, openDisc >= count || count == 1 {
                self.openDisc = nil
            }
        }
    }

    // MARK: - Шапка

    /// Имя, авторы капсулами и паспорт альбома.
    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(album.name)
                .font(.system(size: 40, weight: .heavy).width(.compressed))
                .lineLimit(3)
                .minimumScaleFactor(0.6)

            if !album.artists.isEmpty {
                ArtistPillRow(artists: album.artists)
            }

            Text(passport)
                .font(.caption2)
                .fontWeight(.semibold)
                .tracking(1.2)
                .foregroundStyle(.secondary)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
    }

    /// «LP  ·  2024  ·  11 TRACKS  ·  43 MIN», у двойного — «2×LP  ·  …».
    private var passport: String {
        let tracks = sortedTracks
        var parts = [album.formatLabel]

        if let release = album.release {
            parts.append(String(Calendar.current.component(.year, from: release)))
        }
        if album.type != .single || tracks.count > 1 {
            parts.append(tracks.count == 1 ? "1 track" : "\(tracks.count) tracks")
        }

        let minutes = RecordSides.minutes(of: tracks)
        if minutes > 0 {
            parts.append(minutes >= 60 ? "\(minutes / 60) h \(minutes % 60) min" : "\(minutes) min")
        }

        return parts.joined(separator: "  ·  ").uppercased()
    }

    /// Запуск и перемешивание того, что на экране: весь альбом или открытая
    /// пластинка. Без ленты, как у плейлиста: всё, что она показывала бы,
    /// уже есть на диске — дорожки, текущий трек и игла.
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
        }
        .padding(.horizontal)
    }

    // MARK: - Пластинки

    /// Закрытый альбом: вместо трек-листа — его пластинки.
    private func discList(_ discs: [[Track]]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            CrateDivider(title: "DISCS", detail: "\(discs.count)", size: 22)

            ForEach(discs.indices, id: \.self) { disc in
                AlbumDiscRow(album: album, disc: disc, tracks: discs[disc], cover: cover, accent: accent) {
                    withAnimation(.spring(duration: 0.55, bounce: 0.2)) {
                        openDisc = disc
                    }
                }
            }
        }
        .padding(.horizontal)
    }

    /// Над открытой пластинкой: дорога обратно к выбору и чья это пластинка.
    private func discBar(_ disc: Int) -> some View {
        let title = album.title(ofDisc: disc)

        return HStack(spacing: 12) {
            Button {
                withAnimation(.spring(duration: 0.55, bounce: 0.2)) {
                    openDisc = nil
                }
            } label: {
                Label("Discs", systemImage: "chevron.left")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.glass)

            VStack(alignment: .leading, spacing: 2) {
                Text("DISC \(disc + 1) OF \(album.discCount)")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .tracking(1.2)
                    .foregroundStyle(.secondary)

                if !title.isEmpty {
                    Text(title)
                        .font(.system(size: 22, weight: .heavy).width(.compressed))
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal)
    }

    // MARK: - Оборот конверта

    /// Трек-лист одной пластинки по сторонам. У альбома из одной пластинки
    /// и короткой стороны одна — тогда без разделителя и с обычными номерами;
    /// у альбома из нескольких номер всегда с буквой: «C3» сразу говорит,
    /// с какой он пластинки.
    private func tracklist(_ tracks: [Track], disc: Int) -> some View {
        let sides = RecordSides.split(tracks, type: album.type)
        let hasSides = sides.count > 1
        let lettered = hasSides || isMultiDisc

        return VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(sides.enumerated()), id: \.offset) { sideIndex, side in
                let letter = RecordSides.letter(disc: disc, side: sideIndex)

                if hasSides {
                    let minutes = RecordSides.minutes(of: side)
                    CrateDivider(title: "SIDE \(letter)", detail: minutes > 0 ? "\(minutes) MIN" : "", size: 22)
                        .padding(.horizontal)
                        .padding(.top, sideIndex == 0 ? 0 : 16)
                }

                ForEach(Array(side.enumerated()), id: \.element.id) { position, track in
                    TrackCell(
                        track: track,
                        queue: tracks,
                        showDuration: true,
                        number: lettered ? "\(letter)\(position + 1)" : nil,
                        showsOnlyGuests: true
                    )
                }
            }
        }
    }

    /// Мелкий текст внизу конверта: ℗, даты, жанры.
    private var linerNotes: some View {
        VStack(alignment: .leading, spacing: 6) {
            Rectangle()
                .fill(.quaternary)
                .frame(width: 32, height: 1)
                .padding(.bottom, 6)

            if let release = album.release {
                let year = Calendar.current.component(.year, from: release)
                let artists = album.artistNames.joined(separator: ", ")
                Text("℗ \(String(year)) \(artists)".trimmingCharacters(in: .whitespaces))

                Text("Released \(release.formatted(Self.dateStyle))")
            }

            Text("Added \(album.addedAt.formatted(Self.dateStyle))")

            let genres = album.genres.map(\.rawValue)
            if !genres.isEmpty {
                Text(genres.joined(separator: "  ·  "))
            }
        }
        .textCase(.uppercase)
        .font(.caption2)
        .fontWeight(.semibold)
        .tracking(1.2)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
    }

    private static let dateStyle = Date.FormatStyle(date: .long, time: .omitted).locale(.interface)

    // MARK: - Воспроизведение

    private func contains(_ track: Track?, in tracks: [Track]) -> Bool {
        guard let track else { return false }
        return tracks.contains { $0.id == track.id }
    }

    /// Играет что-то из этого — кнопка ставит паузу и снимает её. Играет что-то
    /// другое — запускает это с начала.
    private func playOrPause(_ tracks: [Track]) {
        if contains(audioPlayer.currentTrack, in: tracks) {
            audioPlayer.togglePlayPause()
        } else {
            audioPlayer.play(tracks)
        }
    }

    /// Нажатие на кольцо выдвинутой пластинки. На играющем треке оно перематывает,
    /// как игла, опущенная в другое место дорожки; на остальных запускает трек
    /// с начала — кольца слишком тонкие, чтобы попасть в нужную секунду.
    private func tapRing(_ index: Int, _ fraction: Double, in tracks: [Track]) {
        guard tracks.indices.contains(index) else { return }

        // `duration` пуст, пока звук не подняли (очередь восстановлена с прошлого
        // запуска), — перематывать там нечего, трек просто запускается.
        if audioPlayer.currentTrack?.id == tracks[index].id, audioPlayer.duration > 0 {
            audioPlayer.seek(to: fraction * audioPlayer.duration)
            return
        }

        audioPlayer.play(tracks, startingAt: index)
    }

    // MARK: - Обложка

    /// Конверт в шапке — около 250 pt, это ~750 px на экране @3x. Цвета страницы
    /// берутся с той же миниатюры: второй раз декодировать обложку незачем.
    private func loadCover() async {
        guard let data = album.artwork else {
            cover = nil
            coverPalette = nil
            return
        }

        let (image, palette) = await Task.detached(priority: .utility) {
            let image = UIImage.thumbnail(from: data, side: 800)
            return (image, image?.coverPalette)
        }.value

        guard !Task.isCancelled else { return }

        cover = image
        coverPalette = palette
    }
}

/// Конверт в шапке альбома. Время текущего трека читается здесь, а не в
/// `AlbumView`: оно меняется пять раз в секунду, и перерисовываться на каждый
/// тик должна только пластинка, а не весь трек-лист.
private struct AlbumHero: View {

    @Environment(AudioPlayer.self) private var audioPlayer

    let album: Album
    let discs: [[Track]]
    let openDisc: Int?
    let cover: UIImage?
    let accent: Color
    let onTapTrack: (_ disc: Int, _ index: Int, _ fraction: Double) -> Void

    var body: some View {
        let playing = album.position(of: audioPlayer.currentTrack)
        let isCurrent = playing != nil

        // Время и пауза читаются только у играющего альбома: открытая страница
        // чужого альбома не должна перерисовываться под чужую музыку.
        let progress: Double? = isCurrent && audioPlayer.duration > 0
            ? audioPlayer.currentTime / audioPlayer.duration
            : nil

        // Пластинка одна — она выезжает, пока играет. Пластинок несколько —
        // выезжает та, что открыта: закрытый альбом держит все в конверте.
        let outDisc = album.discCount > 1 ? openDisc : playing?.disc

        AlbumSleeve(
            cover: cover,
            type: album.type,
            discs: discs.map { $0.map(\.duration) },
            outDisc: outDisc,
            playing: playing,
            isPlaying: isCurrent && audioPlayer.isPlaying,
            accent: accent,
            progress: progress,
            restingPeek: 0.28,
            playingPeek: 0.5,
            showsRipples: true,
            onTapTrack: onTapTrack
        )
    }
}

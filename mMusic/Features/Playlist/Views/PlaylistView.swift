import SwiftUI
import SwiftData

struct PlaylistView: View {
    
    @Environment(\.modelContext) private var modelContext
    @Environment(AudioPlayer.self) var audioPlayer
    @Environment(\.dismiss) private var dismiss

    /// Что открыто из меню «…» или слота «Add music».
    @State private var action: PlaylistAction?

    /// Уменьшенные обложки для веера. Декодируются один раз в `.task`, а не в `body`:
    /// полноразмерная обложка весит мегабайты, а `body` пересчитывается на каждой
    /// смене трека.
    @State private var covers: [UIImage] = []
    /// Цвета передней обложки — ими светится страница, пока плейлист не играет.
    @State private var coverPalette: CoverPalette?

    let playlist: Playlist

    private var tracks: [Track] {
        playlist.orderedTracks
    }

    /// Играет именно этот плейлист. От этого зависит, ставит ли кнопка паузу
    /// или запускает плейлист заново.
    private var isSource: Bool {
        audioPlayer.isQueue(from: tracks)
    }

    /// Пока плейлист играет, страница красится в цвета играющего трека и меняет их
    /// вместе с ним; в остальное время — в цвета своей обложки.
    private var pagePalette: CoverPalette? {
        isSource ? audioPlayer.palette : coverPalette
    }

    var body: some View {
        List {
            header
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())

            ForEach(tracks) { track in
                TrackCell(
                    track: track,
                    queue: tracks,
                    leadingStyle: .artwork,
                    showDuration: true,
                    onRemoveFromPlaylist: { remove(track) },
                    // Без этого плейлист, который запускают с песни, а не кнопкой,
                    // навсегда оставался «давно не игравшим» и не поднимался в списке.
                    onPlay: { playlist.markPlayed() }
                )
            }
            .onMove { source, destination in
                moveTracks(from: source, to: destination)
            }
            .onDelete { offsets in
                removeTracks(at: offsets)
            }
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())

            addMusicSlot
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
        }
        .listStyle(.plain)
        .listRowSpacing(8)
        .scrollContentBackground(.hidden)
        // `containerBackground`, а не `background`: у экрана в навигации своя
        // непрозрачная подложка, и закрасить её можно только фоном контейнера.
        .containerBackground(for: .navigation) {
            CoverAura(palette: pagePalette, breathes: isSource)
        }
        // Кнопки и подсветка — в цвет страницы. Строго до `.toolbar` и `.sheet`:
        // листы правки остаются в цвете всего приложения.
        .tint(pagePalette?.accent ?? audioPlayer.accent)
        .task(id: playlist.fanCovers.map(\.count)) {
            await loadCovers()
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    PlaylistMenuItems(playlist: playlist, action: $action, isOnItsPage: true)
                } label: {
                    Image(systemName: "ellipsis")
                }
            }
        }
        // Удалённый плейлист раньше так и оставался открытым на экране.
        .playlistActions(playlist, action: $action, onLeave: { dismiss() })
    }

    // MARK: - Шапка

    /// Веер обложек, имя крупным сжатым шрифтом и пульт. Всё по левому краю:
    /// центрированная квадратная обложка с именем под ней — ровно та страница,
    /// на которую этот экран не должен быть похож.
    private var header: some View {
        VStack(alignment: .leading, spacing: 20) {
            CoverFan(covers: covers, size: 190)
                .padding(.top, 8)

            VStack(alignment: .leading, spacing: 6) {
                Text(playlist.name)
                    .font(.system(size: 44, weight: .heavy).width(.compressed))
                    .lineLimit(3)
                    .minimumScaleFactor(0.6)

                if !playlist.playlistDescription.isEmpty {
                    Text(playlist.playlistDescription)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Text(playlist.summary(includingArtists: true))
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .tracking(1.2)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }

            if !tracks.isEmpty {
                deck
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    /// Пульт вместо пары одинаковых капсул Play / Shuffle: запуск, лента всего
    /// плейлиста и перемешивание одной строкой. Лента заодно показывает,
    /// где в плейлисте играющий трек и сколько от него осталось.
    private var deck: some View {
        let isPlayingHere = isSource && audioPlayer.isPlaying

        return HStack(spacing: 14) {
            Button {
                playOrPause()
            } label: {
                Image(systemName: isPlayingHere ? "pause.fill" : "play.fill")
                    .font(.title2)
                    .frame(width: 36, height: 36)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.glassProminent)
            .buttonBorderShape(.circle)
            .accessibilityLabel(isPlayingHere ? "Pause" : "Play")

            PlaylistTape(
                segments: tracks.map(TapeSegment.init(track:)),
                currentIndex: tracks.firstIndex { $0.id == audioPlayer.currentTrack?.id },
                accent: pagePalette?.accent ?? audioPlayer.accent,
                onTap: tapTape
            )
            .frame(height: 44)

            Button {
                playlist.markPlayed()
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
    }

    /// Пустое место в конце стопки строк. В пустом плейлисте оно крупнее:
    /// кроме него на экране делать нечего.
    private var addMusicSlot: some View {
        DashedSlot(title: tracks.isEmpty ? "Add the first tracks" : "Add music", isLarge: tracks.isEmpty) {
            action = .addMusic
        }
        .padding(.horizontal)
        .padding(.top, 4)
    }

    // MARK: - Воспроизведение

    /// Играет этот плейлист — кнопка ставит паузу и снимает её. Играет что-то
    /// другое — запускает плейлист с начала.
    private func playOrPause() {
        if isSource {
            audioPlayer.togglePlayPause()
        } else {
            playlist.markPlayed()
            audioPlayer.play(tracks)
        }
    }

    /// По играющему треку лента работает как слайдер, по остальным — как
    /// трек-лист: трек запускается с начала, а не с места нажатия.
    private func tapTape(_ index: Int, _ fraction: Double) {
        guard tracks.indices.contains(index) else { return }

        // `duration` пуст, пока звук не подняли (очередь восстановлена с прошлого
        // запуска), — перематывать там нечего, трек просто запускается.
        if audioPlayer.currentTrack?.id == tracks[index].id, audioPlayer.duration > 0 {
            audioPlayer.seek(to: fraction * audioPlayer.duration)
            return
        }

        playlist.markPlayed()
        audioPlayer.play(tracks, startingAt: index)
    }

    // MARK: - Обложки

    /// Декодирование и разбор цветов — в фоне: на главном потоке обложка
    /// в несколько мегабайт подвешивала бы переход на экран.
    private func loadCovers() async {
        let sources = playlist.fanCovers

        // Главная карта веера — 190 pt, то есть около 570 px на экране @3x.
        let (images, palette) = await Task.detached(priority: .utility) {
            let images = sources.compactMap { UIImage.thumbnail(from: $0, side: 600) }
            return (images, images.first?.coverPalette)
        }.value

        // Пока считали, состав мог поменяться — тогда уже запущен новый расчёт.
        guard !Task.isCancelled else { return }

        covers = images
        coverPalette = palette
    }

    // MARK: - Правка состава

    /// Убирает трек из плейлиста, не трогая ни файл, ни запись в библиотеке:
    /// удаляется только связка `TrackPlaylistItem`.
    private func remove(_ track: Track) {
        guard let index = playlist.items
            .sorted(by: { $0.position < $1.position })
            .firstIndex(where: { $0.track.persistentModelID == track.persistentModelID })
        else { return }

        removeTracks(at: IndexSet(integer: index))
    }

    private func removeTracks(at offsets: IndexSet) {
        var items = playlist.items.sorted { $0.position < $1.position }

        for index in offsets where items.indices.contains(index) {
            modelContext.delete(items[index])
        }

        // Позиции пересчитываются, иначе в нумерации остаются дыры,
        // и следующая перестановка съезжает.
        items.remove(atOffsets: offsets)
        for (index, item) in items.enumerated() {
            item.position = index
        }
    }

    private func moveTracks(from: IndexSet, to: Int) {
        var items = playlist.items.sorted { $0.position < $1.position }
        items.move(fromOffsets: from, toOffset: to)

        for (index, item) in items.enumerated() {
            item.position = index
        }
    }
    
}

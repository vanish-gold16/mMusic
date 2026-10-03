import SwiftUI
import SwiftData

struct PlaylistView: View {
    
    @Environment(\.modelContext) private var modelContext
    @Environment(AudioPlayer.self) var audioPlayer
    @Environment(ToastCenter.self) private var toasts
    
    @State private var isShowingTrackPicker = false
    @State private var editingPlaylist = false
    @State private var showDeleteConfirmation = false

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

    /// Складывается из уже прочитанных длительностей — файлы для этого больше не открываются.
    private var totalDuration: TimeInterval {
        tracks.reduce(0) { $0 + $1.duration }
    }

    /// Очередь плеера собрана из этого плейлиста: в ней все его треки, и играет
    /// один из них. Лишние треки в очереди не мешают — их могли добавить через
    /// «Play next». От этого зависит, ставит ли кнопка паузу или запускает плейлист заново.
    private var isSource: Bool {
        guard let current = audioPlayer.currentTrack, !tracks.isEmpty else { return false }

        let ids = Set(tracks.map(\.id))
        guard ids.contains(current.id) else { return false }

        return ids.isSubset(of: Set(audioPlayer.queue.map(\.id)))
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
                    onRemoveFromPlaylist: { remove(track) }
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
            PlaylistAura(palette: pagePalette, breathes: isSource)
        }
        // Кнопки и подсветка — в цвет страницы. Строго до `.toolbar` и `.sheet`:
        // листы правки остаются в цвете всего приложения.
        .tint(pagePalette?.accent ?? audioPlayer.accent)
        .task(id: coverSources.map(\.count)) {
            await loadCovers()
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    VStack {
                        ControlGroup {
                            Button {
                                playlist.isFavourite.toggle()
                            } label: {
                                Label("Favourite", systemImage: playlist.isFavourite ? "star.fill" : "star")
                            }
                            ShareLink(items: playlist.orderedTracks.map { AudioFileStore.url(for: $0.filename) }) {
                                Label("Share", systemImage: "square.and.arrow.up")
                            }
                        }
                        Divider()
                        
                        Button {
                            playlist.markPlayed()
                            audioPlayer.play(playlist.orderedTracks)
                        } label: {
                            Label("Play", systemImage: "play")
                        }
                        Button {
                            playlist.markPlayed()
                            audioPlayer.playShuffled(playlist.orderedTracks)
                        } label: {
                            Label("Shuffle", systemImage: "shuffle")
                        }
                        
                        Divider()
                        
                        Button {
                            editingPlaylist = true
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }

                        Menu {
                            ForEach(PlaylistSort.allCases) { option in
                                Button {
                                    applySort(option)
                                } label: {
                                    Label(option.rawValue, systemImage: option.systemImage)
                                }
                            }
                        } label: {
                            Label("Sort", systemImage: "arrow.up.arrow.down")
                        }
                        
                        Divider()
                        
                        Button {
                            audioPlayer.enqueueNext(playlist.orderedTracks)
                            toasts.enqueuedNext(playlist.orderedTracks.count)
                        } label: {
                            Label("Play next", systemImage: "text.line.first.and.arrowtriangle.forward")
                        }
                        Button {
                            audioPlayer.enqueueLast(playlist.orderedTracks)
                            toasts.enqueuedLast(playlist.orderedTracks.count)
                        } label: {
                            Label("Play after", systemImage: "text.line.last.and.arrowtriangle.forward")
                        }
                        
                        Divider()
                        
                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .tint(.red)
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
            }
        }
        .sheet(isPresented: $isShowingTrackPicker) {
            TrackPickerView(playlist: playlist)
        }
        .sheet(isPresented: $editingPlaylist) {
            EditPlaylistView(playlist: playlist)
        }
        .confirmationDialog(
            "Delete \"\(playlist.name)\"?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                let name = playlist.name
                modelContext.delete(playlist)
                toasts.removed("Deleted \(name)")
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This playlist will be permanently deleted.")
        }
    }

    // MARK: - Шапка

    /// Веер обложек, имя крупным сжатым шрифтом и пульт. Всё по левому краю:
    /// центрированная квадратная обложка с именем под ней — ровно та страница,
    /// на которую этот экран не должен быть похож.
    private var header: some View {
        VStack(alignment: .leading, spacing: 20) {
            CoverFan(covers: covers)
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

                Text(summary)
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

    /// Паспорт плейлиста одной строкой. Раньше он стоял в самом низу,
    /// под всеми треками, где его никто не видел.
    private var summary: String {
        guard !tracks.isEmpty else { return "NO TRACKS YET" }

        var parts = [tracks.count == 1 ? "1 track" : "\(tracks.count) tracks"]

        let minutes = Int((totalDuration / 60).rounded())
        if minutes > 0 {
            parts.append(minutes >= 60 ? "\(minutes / 60) h \(minutes % 60) min" : "\(minutes) min")
        }

        let artists = Set(tracks.flatMap(\.artistNames)).count
        if artists > 0 {
            parts.append(artists == 1 ? "1 artist" : "\(artists) artists")
        }

        return parts.joined(separator: "  ·  ").uppercased()
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

    /// Пустое место в стопке строк — пунктир той же формы, что и строки над ним.
    /// В пустом плейлисте оно крупнее: кроме него на экране делать нечего.
    private var addMusicSlot: some View {
        Button {
            isShowingTrackPicker = true
        } label: {
            Label(tracks.isEmpty ? "Add the first tracks" : "Add music", systemImage: "plus")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: tracks.isEmpty ? 120 : 60)
                .background {
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .strokeBorder(.secondary.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [5, 5]))
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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

    /// Из чего собирать веер: своя обложка плейлиста, затем обложки треков —
    /// по одной на альбом, иначе три карты подряд оказались бы одной картинкой.
    private var coverSources: [Data] {
        var sources: [Data] = []
        if let own = playlist.artwork { sources.append(own) }

        var seenAlbums = Set<PersistentIdentifier>()
        for track in tracks where sources.count < 3 {
            guard let data = track.displayArtwork else { continue }

            if let album = track.album, album.artwork != nil,
               !seenAlbums.insert(album.persistentModelID).inserted {
                continue
            }
            sources.append(data)
        }

        return sources
    }

    /// Декодирование и разбор цветов — в фоне: на главном потоке обложка
    /// в несколько мегабайт подвешивала бы переход на экран.
    private func loadCovers() async {
        let sources = coverSources

        let (images, palette) = await Task.detached(priority: .utility) {
            let images = sources.compactMap(Self.thumbnail(from:))
            return (images, images.first?.coverPalette)
        }.value

        // Пока считали, состав мог поменяться — тогда уже запущен новый расчёт.
        guard !Task.isCancelled else { return }

        covers = images
        coverPalette = palette
    }

    /// Карта веера — 168 pt, то есть около 500 px на экране @3x. Пропорции
    /// сохраняются: квадрат вырезает уже сама карта.
    nonisolated private static func thumbnail(from data: Data) -> UIImage? {
        guard let image = UIImage(data: data) else { return nil }

        let scale = min(512 / min(image.size.width, image.size.height), 1)
        return image.preparingThumbnail(of: CGSize(
            width: image.size.width * scale,
            height: image.size.height * scale
        ))
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

    /// Переписывает позиции раз и навсегда: дальше порядок снова ручной.
    private func applySort(_ option: PlaylistSort) {
        for (index, item) in option.sorted(playlist.items).enumerated() {
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

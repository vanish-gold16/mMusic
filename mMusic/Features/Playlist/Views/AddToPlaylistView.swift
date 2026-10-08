import SwiftData
import SwiftUI

/// Куда положить треки: в существующий плейлист или в новый, созданный тут же.
///
/// Не таблица, а маленькая страница: наверху крупно то, что кладёшь, под ним
/// пунктирный слот нового плейлиста — по всему приложению так выглядит «сюда
/// можно что-то положить», — и плейлисты стеклянными карточками с веером
/// обложек, как в библиотеке, только мельче. Лист светится цветом обложки
/// того, что кладёшь.
struct AddToPlaylistView: View {

    let tracks: [Track]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AudioPlayer.self) private var audioPlayer
    @Environment(ToastCenter.self) private var toasts

    @Query(sort: \Playlist.name) private var playlists: [Playlist]

    @State private var newPlaylistName = ""
    /// Цвета обложки первого из треков.
    @State private var palette: CoverPalette?

    private var trimmedName: String {
        newPlaylistName.trimmingCharacters(in: .whitespaces)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                        .padding(.top, 4)

                    newPlaylistSlot

                    if !playlists.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            CrateDivider(title: "PLAYLISTS", detail: "\(playlists.count)", size: 22)

                            ForEach(playlists.byLastAdded) { playlist in
                                Button {
                                    add(to: playlist)
                                } label: {
                                    PlaylistPickRow(
                                        playlist: playlist,
                                        alreadyThere: countAlreadyThere(in: playlist),
                                        adding: tracks.count
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .containerBackground(for: .navigation) {
                CoverAura(palette: palette, breathes: false)
            }
            .tint(palette?.accent ?? audioPlayer.accent)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    SheetActionButton(.close) { dismiss() }
                }
            }
            .task(id: tracks.first?.displayArtwork?.count) {
                await loadPalette()
            }
        }
        // Лист открывается наполовину: список плейлистов короткий, а закрывать
        // его протяжкой удобнее, чем целиться в «CLOSE».
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Шапка

    /// Один трек — его имя; несколько — сколько их. Под ним паспорт: артист
    /// трека или общая длина.
    private var header: some View {
        let title = tracks.count == 1 ? tracks[0].name : "\(tracks.count) tracks"

        var parts = ["ADD TO A PLAYLIST"]
        if tracks.count == 1 {
            let artists = tracks[0].artistNames.joined(separator: ", ")
            if !artists.isEmpty { parts.append(artists.uppercased()) }
        } else {
            let minutes = Int((tracks.reduce(0) { $0 + $1.duration } / 60).rounded())
            if minutes > 0 {
                parts.append(minutes >= 60 ? "\(minutes / 60) H \(minutes % 60) MIN" : "\(minutes) MIN")
            }
        }

        return VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 34, weight: .heavy).width(.compressed))
                .lineLimit(2)
                .minimumScaleFactor(0.6)

            Text(parts.joined(separator: "  ·  "))
                .font(.caption2)
                .fontWeight(.semibold)
                .tracking(1.2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    // MARK: - Новый плейлист

    /// Пунктир с полем имени прямо в нём: набрал имя — появилась кнопка,
    /// Return делает то же самое.
    private var newPlaylistSlot: some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)

        return HStack(spacing: 12) {
            Image(systemName: "plus")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            TextField("New playlist", text: $newPlaylistName)
                .font(.system(size: 22, weight: .heavy).width(.compressed))
                .submitLabel(.done)
                .onSubmit { if !trimmedName.isEmpty { createAndAdd() } }

            if !trimmedName.isEmpty {
                Button("Create") { createAndAdd() }
                    .font(.subheadline.weight(.semibold))
                    .buttonStyle(.glassProminent)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 60)
        .background {
            shape.strokeBorder(.secondary.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [5, 5]))
        }
        .animation(.snappy(duration: 0.2), value: trimmedName.isEmpty)
    }

    // MARK: - Действия

    /// Сколько из выбранных треков уже лежит в плейлисте.
    private func countAlreadyThere(in playlist: Playlist) -> Int {
        let existing = Set(playlist.items.map(\.track.persistentModelID))
        return tracks.filter { existing.contains($0.persistentModelID) }.count
    }

    private func createAndAdd() {
        let playlist = Playlist(name: trimmedName, items: [])
        modelContext.insert(playlist)
        add(to: playlist)
    }

    /// Уже лежащие в плейлисте треки пропускаются — иначе повторное нажатие
    /// набивает плейлист дублями.
    private func add(to playlist: Playlist) {
        let existing = Set(playlist.items.map(\.track.persistentModelID))
        var position = playlist.items.count
        var added = 0

        for track in tracks where !existing.contains(track.persistentModelID) {
            modelContext.insert(TrackPlaylistItem(track: track, playlist: playlist, position: position))
            position += 1
            added += 1
        }

        // Раньше про пропуски сообщал алерт с кнопкой «ОК» — он останавливал
        // на ровном месте. Теперь то же самое говорит плашка, которая гаснет сама.
        toasts.addedToPlaylist(added: added, skipped: tracks.count - added, playlist: playlist.name)
        dismiss()
    }

    /// Цвета листа — с миниатюры: нужен только цвет.
    private func loadPalette() async {
        guard let data = tracks.first?.displayArtwork else { return }

        let palette = await Task.detached(priority: .utility) {
            UIImage.thumbnail(from: data, side: 200)?.coverPalette
        }.value

        guard !Task.isCancelled else { return }
        self.palette = palette
    }
}

/// Плейлист в листе — строка библиотеки в миниатюре: веер, сжатое имя
/// и паспорт. Про дубли сказано до нажатия, а не после: иначе выбор выглядит
/// как «нажал — и ничего не произошло». Где уже лежит всё — галочка.
private struct PlaylistPickRow: View {

    let playlist: Playlist
    /// Сколько из добавляемых треков уже здесь.
    let alreadyThere: Int
    /// Сколько треков добавляют.
    let adding: Int

    @State private var covers: [UIImage] = []

    private let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)

    private var isComplete: Bool { alreadyThere == adding }

    private var status: String {
        if alreadyThere == 0 { return playlist.summary(includingArtists: false) }
        if isComplete { return adding == 1 ? "ALREADY HERE" : "ALL \(adding) ALREADY HERE" }
        return "\(alreadyThere) OF \(adding) ALREADY HERE"
    }

    var body: some View {
        HStack(spacing: 6) {
            CoverFan(covers: covers, size: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text(playlist.name)
                    .font(.system(size: 22, weight: .heavy).width(.compressed))
                    .lineLimit(1)

                Text(status)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .tracking(1.2)
                    .foregroundStyle(alreadyThere > 0 ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Image(systemName: isComplete ? "checkmark.circle.fill" : "plus.circle")
                .font(.title3)
                .foregroundStyle(isComplete ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                .accessibilityLabel(isComplete ? "Already here" : "Add")
        }
        .padding(10)
        .contentShape(shape)
        .glassEffect(.regular, in: shape)
        .task(id: playlist.fanCovers.map(\.count)) {
            await loadCovers()
        }
    }

    /// Главная карта веера здесь 44 pt — около 130 px на экране @3x.
    private func loadCovers() async {
        let sources = playlist.fanCovers

        let images = await Task.detached(priority: .utility) {
            sources.compactMap { UIImage.thumbnail(from: $0, side: 140) }
        }.value

        guard !Task.isCancelled else { return }
        covers = images
    }
}

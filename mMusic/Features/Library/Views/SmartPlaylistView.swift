import SwiftData
import SwiftUI

/// Содержимое автоподборки. Пересчитывается на лету из `@Query`, поэтому
/// хранить её как настоящий плейлист незачем — она всегда актуальна.
///
/// Устроена как экран плейлиста — веер обложек, сжатое имя, паспорт, пульт
/// с лентой и свечение цветом обложки, — потому что это и есть плейлист, только
/// собранный правилом. Отличает её наклейка на обложке и правило под именем.
/// Слепок на сегодня можно оставить себе обычным плейлистом — пунктирный слот
/// в конце, как «Add music» у плейлиста.
struct SmartPlaylistView: View {

    let playlist: SmartPlaylist

    @Environment(AudioPlayer.self) private var audioPlayer
    @Environment(\.modelContext) private var modelContext
    @Environment(ToastCenter.self) private var toasts

    @Query private var allTracks: [Track]

    /// Имя плейлиста, в который подборку уже оставили. nil — ещё не оставляли.
    @State private var keptAs: String?

    /// Уменьшенные обложки для веера и цвета передней. Считаются в `.task`:
    /// полноразмерная обложка весит мегабайты.
    @State private var covers: [UIImage] = []
    @State private var coverPalette: CoverPalette?

    private let fanSize: CGFloat = 190

    var body: some View {
        let tracks = playlist.tracks(from: allTracks)
        // Играет именно эта подборка: от этого зависит, ставит ли кнопка паузу
        // или запускает подборку заново.
        let isSource = audioPlayer.isQueue(from: tracks)
        let pagePalette = isSource ? audioPlayer.palette : coverPalette

        ScrollView {
            LazyVStack(alignment: .leading, spacing: 8) {
                header(tracks, isSource: isSource, accent: pagePalette?.accent ?? audioPlayer.accent)
                    .padding(.bottom, 8)

                if tracks.isEmpty {
                    LibraryEmptyState(text: "Nothing here right now")
                } else {
                    ForEach(tracks) { track in
                        TrackCell(
                            track: track,
                            queue: tracks,
                            leadingStyle: .artwork,
                            // Счётчик — там, где по нему и собрано; в остальных
                            // подборках полезнее длительность.
                            showPlayCount: playlist == .mostPlayed,
                            showDuration: playlist != .mostPlayed
                        )
                    }

                    keepSlot(tracks)
                }
            }
            .padding(.vertical)
        }
        // `containerBackground`, а не `background`: у экрана в навигации своя
        // непрозрачная подложка, и закрасить её можно только фоном контейнера.
        .containerBackground(for: .navigation) {
            CoverAura(palette: pagePalette, breathes: isSource)
        }
        .tint(pagePalette?.accent ?? audioPlayer.accent)
        .task(id: tracks.fanCovers().map(\.count)) {
            await loadCovers(tracks.fanCovers())
        }
    }

    // MARK: - Шапка

    /// Веер с наклейкой, имя, правило, паспорт и пульт. Всё по левому краю,
    /// как у плейлиста.
    private func header(_ tracks: [Track], isSource: Bool, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            CoverFan(covers: covers, size: fanSize)
                .hypeSticker(playlist, accent: accent, fanSize: fanSize)
                .padding(.top, 8)

            VStack(alignment: .leading, spacing: 6) {
                Text(playlist.title)
                    .font(.system(size: 44, weight: .heavy).width(.compressed))
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)

                Text(playlist.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(tracks.summary(includingArtists: true))
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .tracking(1.2)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }

            if !tracks.isEmpty {
                deck(tracks, isSource: isSource, accent: accent)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
    }

    /// Пульт как у плейлиста: запуск, лента всей подборки и перемешивание.
    private func deck(_ tracks: [Track], isSource: Bool, accent: Color) -> some View {
        let isPlayingHere = isSource && audioPlayer.isPlaying

        return HStack(spacing: 14) {
            Button {
                if isSource {
                    audioPlayer.togglePlayPause()
                } else {
                    audioPlayer.play(tracks)
                }
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
                currentIndex: isSource ? tracks.firstIndex { $0.id == audioPlayer.currentTrack?.id } : nil,
                accent: accent,
                onTap: { index, fraction in tapTape(index, fraction, in: tracks) }
            )
            .frame(height: 44)

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
    }

    /// По играющему треку лента работает как слайдер, по остальным — как
    /// трек-лист: трек запускается с начала.
    private func tapTape(_ index: Int, _ fraction: Double, in tracks: [Track]) {
        guard tracks.indices.contains(index) else { return }

        if audioPlayer.currentTrack?.id == tracks[index].id, audioPlayer.duration > 0 {
            audioPlayer.seek(to: fraction * audioPlayer.duration)
            return
        }

        audioPlayer.play(tracks, startingAt: index)
    }

    // MARK: - Слепок

    /// Оставить подборку себе: завтра она изменится, а оставленный плейлист — нет.
    private func keepSlot(_ tracks: [Track]) -> some View {
        DashedSlot(
            title: keptAs.map { "Kept as \($0)" } ?? "Keep as playlist",
            systemImage: keptAs == nil ? "text.badge.plus" : "checkmark"
        ) {
            let kept = playlist.keep(tracks, in: modelContext)
            keptAs = kept.name
            toasts.show("Kept as \(kept.name)", systemImage: "text.badge.plus")
        }
        .disabled(keptAs != nil)
        .padding(.horizontal)
        .padding(.top, 4)
    }

    // MARK: - Обложки

    /// Главная карта веера — 190 pt, около 570 px на экране @3x. Цвета страницы
    /// берутся с той же миниатюры.
    private func loadCovers(_ sources: [Data]) async {
        let (images, palette) = await Task.detached(priority: .utility) {
            let images = sources.compactMap { UIImage.thumbnail(from: $0, side: 600) }
            return (images, images.first?.coverPalette)
        }.value

        guard !Task.isCancelled else { return }

        covers = images
        coverPalette = palette
    }
}

extension SmartPlaylist {

    /// Слепок подборки обычным плейлистом. В имени месяц: подборка
    /// меняется, и через полгода «Most played» без даты сбивал бы с толку.
    @discardableResult
    func keep(_ tracks: [Track], in context: ModelContext) -> Playlist {
        let month = Date.now.formatted(.dateTime.month(.wide).year().locale(.interface))
        let kept = Playlist(name: "\(title), \(month)", items: [])
        context.insert(kept)

        for (position, track) in tracks.enumerated() {
            context.insert(TrackPlaylistItem(track: track, playlist: kept, position: position))
        }

        return kept
    }
}

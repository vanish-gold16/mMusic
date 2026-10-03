import SwiftUI

/// Строка плейлиста в библиотеке и поиске — уменьшенная шапка его экрана:
/// тот же веер обложек, то же сжатое имя, тот же паспорт и та же лента.
///
/// Лента здесь — отпечаток плейлиста: у каждого свой силуэт из длин и громкостей
/// его треков, и узнаёшь его раньше, чем прочтёшь имя. У играющего плейлиста
/// на ней горит текущий трек, а сама строка подкрашена — как играющая строка трека.
struct PlaylistCell: View {

    @Environment(AudioPlayer.self) private var audioPlayer

    let playlist: Playlist

    /// Уменьшенные обложки для веера — декодируются в `.task`, не в `body`.
    @State private var covers: [UIImage] = []

    private let shape = RoundedRectangle(cornerRadius: 28, style: .continuous)

    var body: some View {
        let tracks = playlist.orderedTracks
        // Подсвечивается только запущенный плейлист: песня может лежать в пяти
        // сразу, и гореть всем пяти строкам незачем.
        let isSource = audioPlayer.isQueue(from: tracks)

        // Рамка веера уже оставляет запас под повёрнутые карты — отступ поменьше.
        HStack(spacing: 6) {
            CoverFan(covers: covers, size: 64)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(playlist.name)
                        .font(.system(size: 26, weight: .heavy).width(.compressed))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Spacer(minLength: 0)

                    // Акцент — только значкам. Повешенный на всю строку, он красил бы
                    // и имя: `.primary` — это первый уровень текущего стиля, а не чёрный.
                    Group {
                        if playlist.isFavourite {
                            Image(systemName: "star.fill")
                                .accessibilityLabel("Favourite")
                        }
                        if playlist.isPinned {
                            Image(systemName: "pin.fill")
                                .accessibilityLabel("Pinned")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.tint)
                }

                Text(playlist.summary(includingArtists: false))
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .tracking(1.2)
                    .foregroundStyle(.secondary)

                if !tracks.isEmpty {
                    PlaylistTape(
                        segments: tracks.map(TapeSegment.init(track:)),
                        currentIndex: isSource ? tracks.firstIndex { $0.id == audioPlayer.currentTrack?.id } : nil,
                        accent: audioPlayer.accent
                    )
                    .frame(height: 18)
                    .padding(.top, 2)
                }
            }
        }
        .padding(12)
        .contentShape(shape)
        // Превью контекстного меню той же формы, что и стекло, — без него
        // система вырезает прямоугольник с острыми углами.
        .contentShape(.contextMenuPreview, shape)
        .glassEffect(isSource ? .regular.tint(audioPlayer.accent.opacity(0.28)) : .regular, in: shape)
        .task(id: playlist.fanCovers.map(\.count)) {
            await loadCovers()
        }
    }

    /// Карта веера здесь 64 pt — около 200 px на экране @3x.
    private func loadCovers() async {
        let sources = playlist.fanCovers

        let images = await Task.detached(priority: .utility) {
            sources.compactMap { UIImage.thumbnail(from: $0, side: 200) }
        }.value

        guard !Task.isCancelled else { return }
        covers = images
    }
}

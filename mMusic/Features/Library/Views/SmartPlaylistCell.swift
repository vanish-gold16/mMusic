import SwiftUI

/// Автоподборка в библиотеке — сестра строки плейлиста: тот же веер обложек
/// и сжатое имя, но с наклейкой на обложке и правилом вместо ленты. Подборка
/// меняется сама, и узнают её по тому, что в ней собрано, а не по силуэту.
/// Играющая подкрашена, как играющий плейлист.
struct SmartPlaylistCell: View {

    @Environment(AudioPlayer.self) private var audioPlayer

    let playlist: SmartPlaylist
    let tracks: [Track]

    /// Уменьшенные обложки и цвет наклейки — считаются в `.task`, не в `body`.
    @State private var covers: [UIImage] = []
    @State private var coverAccent: Color?

    private let shape = RoundedRectangle(cornerRadius: 28, style: .continuous)
    private let fanSize: CGFloat = 68

    var body: some View {
        let isSource = audioPlayer.isQueue(from: tracks)

        // Рамка веера уже оставляет запас под повёрнутые карты — отступ поменьше.
        HStack(spacing: 6) {
            CoverFan(covers: covers, size: fanSize)
                .hypeSticker(playlist, accent: coverAccent ?? audioPlayer.accent, fanSize: fanSize)

            VStack(alignment: .leading, spacing: 4) {
                Text(playlist.title)
                    .font(.system(size: 26, weight: .heavy).width(.compressed))
                    .lineLimit(1)

                Text(playlist.subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(tracks.summary(includingArtists: false))
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .tracking(1.2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .contentShape(shape)
        // Превью контекстного меню той же формы, что и стекло.
        .contentShape(.contextMenuPreview, shape)
        .glassEffect(isSource ? .regular.tint(audioPlayer.accent.opacity(0.28)) : .regular, in: shape)
        .task(id: tracks.fanCovers().map(\.count)) {
            await loadCovers()
        }
    }

    /// Главная карта веера здесь 68 pt — около 200 px на экране @3x.
    private func loadCovers() async {
        let sources = tracks.fanCovers()

        let (images, palette) = await Task.detached(priority: .utility) {
            let images = sources.compactMap { UIImage.thumbnail(from: $0, side: 210) }
            return (images, images.first?.coverPalette)
        }.value

        guard !Task.isCancelled else { return }
        covers = images
        coverAccent = palette?.accent
    }
}

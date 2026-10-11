import SwiftData
import SwiftUI

/// Строка артиста в библиотеке и поиске — уменьшенная шапка его страницы:
/// та же пластинка с его релизами кольцами, сжатое имя и строка пластинок.
/// Играет его трек — на диске горит кольцо играющей пластинки, а справа
/// пляшут полоски, как у играющей пластинки в стопке на главной.
struct ArtistsTabArtistCell: View {

    @Environment(AudioPlayer.self) private var audioPlayer

    /// Что открыто из меню: переименование, фотография, радар или вопрос.
    @State private var action: ArtistAction?

    /// Уменьшенная фотография и цвет бумажного яблока. Считаются в `.task`,
    /// а не в `body`: фотография и обложка весят мегабайты.
    @State private var photo: UIImage?
    @State private var labelPaper: Color?

    var artist: Artist

    var body: some View {
        let discography = ArtistDiscography(artist: artist)
        let isPlayingArtist = audioPlayer.isPlaying
            && audioPlayer.currentTrack?.artists.contains { $0.persistentModelID == artist.persistentModelID } == true

        NavigationLink {
            ArtistView(artist: artist)
        } label: {
            HStack(spacing: 14) {
                ArtistDisc(
                    name: artist.name,
                    releases: discography.career,
                    photo: photo,
                    labelPaper: labelPaper,
                    accent: audioPlayer.accent
                )
                .frame(width: 58, height: 58)

                VStack(alignment: .leading, spacing: 3) {
                    Text(artist.name)
                        .font(.system(size: 24, weight: .heavy).width(.compressed))
                        .lineLimit(1)

                    Text(discography.recordsSummary ?? "NO RECORDS YET")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .tracking(1.2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                if isPlayingArtist {
                    PlayingBars()
                        .foregroundStyle(.tint)
                        .accessibilityLabel("Playing")
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            ArtistMenuItems(artist: artist, tracks: discography.tracks, action: $action)
        }
        .task(id: [artist.artwork?.count, discography.newestCover?.count]) {
            await loadLabel(cover: discography.newestCover)
        }
        .artistActions(artist, tracks: discography.tracks, action: $action)
    }

    /// Яблоко здесь около 30 pt — 90 px на экране @3x. Без фотографии
    /// с обложки нужен только цвет, и её хватает совсем маленькой.
    private func loadLabel(cover: Data?) async {
        let photoData = artist.artwork

        let (image, palette) = await Task.detached(priority: .utility) {
            if let photoData {
                return (UIImage.thumbnail(from: photoData, side: 180), nil as CoverPalette?)
            }
            return (nil as UIImage?, cover.flatMap { UIImage.thumbnail(from: $0, side: 100) }?.coverPalette)
        }.value

        guard !Task.isCancelled else { return }

        photo = image
        labelPaper = palette?.accent
    }
}

/// Полоски играющего артиста. Громкость читается здесь: она меняется 30 раз
/// в секунду, и перерисовываться должны полоски, а не вся строка.
private struct PlayingBars: View {

    @Environment(AudioPlayer.self) private var audioPlayer

    var body: some View {
        EqualizerView(level: audioPlayer.level, barCount: 4, maxHeight: 14)
    }
}

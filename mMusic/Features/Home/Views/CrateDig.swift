import SwiftData
import SwiftUI

/// Пластинка, которую давно не доставали: вытащена из ящика наугад и лежит
/// в конверте — диск в нём, его не ставили. Вместо «Recommended for you»
/// приложение напоминает о том, что у тебя уже есть.
struct CrateDig: View {

    @Environment(AudioPlayer.self) private var audioPlayer

    let album: Album
    /// Когда альбом ставили в последний раз. nil — ни разу.
    let lastPlayedAt: Date?
    let onDigAgain: () -> Void

    @State private var cover: UIImage?
    /// Что открыто из меню по долгому нажатию на конверт.
    @State private var action: AlbumAction?

    private var sortedTracks: [Track] {
        album.tracklist
    }

    /// «UNTOUCHED SINCE MAY», «UNTOUCHED SINCE NOV 2025» или «NEVER SPUN».
    private var dust: String {
        guard let lastPlayedAt else { return "NEVER SPUN" }

        let sameYear = Calendar.current.isDate(lastPlayedAt, equalTo: .now, toGranularity: .year)
        let style: Date.FormatStyle = sameYear
            ? .dateTime.month(.wide).locale(.interface)
            : .dateTime.month(.abbreviated).year().locale(.interface)

        return "Untouched since \(lastPlayedAt.formatted(style))".uppercased()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            NavigationLink {
                AlbumView(album: album)
            } label: {
                AlbumSleeve(
                    cover: cover,
                    type: album.type,
                    discs: album.tracklistDiscs.map { $0.map(\.duration) },
                    outDisc: nil,
                    playing: nil,
                    isPlaying: false,
                    accent: .clear
                )
                .frame(width: 168)
            }
            .buttonStyle(.plain)
            .contextMenu {
                AlbumMenuItems(album: album, action: $action)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(album.name)
                    .font(.system(size: 24, weight: .heavy).width(.compressed))
                    .lineLimit(3)
                    .minimumScaleFactor(0.7)

                Text(album.artistNames.joined(separator: ", "))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                Text(dust)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .tracking(1.2)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 2)

                HStack(spacing: 10) {
                    Button {
                        audioPlayer.play(sortedTracks)
                    } label: {
                        Image(systemName: "play.fill")
                            .font(.body.weight(.semibold))
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.glassProminent)
                    .buttonBorderShape(.circle)
                    .accessibilityLabel("Play \(album.name)")

                    Button(action: onDigAgain) {
                        Image(systemName: "arrow.clockwise")
                            .font(.body.weight(.semibold))
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
                    .accessibilityLabel("Dig out another")
                }
                .padding(.top, 10)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal)
        .albumActions(album, action: $action)
        .task(id: album.persistentModelID) {
            await loadCover()
        }
    }

    /// Конверт — 168 pt шириной, сторона около 130 pt: ~400 px на @3x.
    private func loadCover() async {
        guard let data = album.artwork else {
            cover = nil
            return
        }

        let image = await Task.detached(priority: .utility) {
            UIImage.thumbnail(from: data, side: 400)
        }.value

        guard !Task.isCancelled else { return }
        cover = image
    }
}

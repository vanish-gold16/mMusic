import SwiftData
import SwiftUI

/// Строка выбора трека в плейлист. Нажимается вся целиком, как строка выбора
/// в альбом: попадать в маленький плюс справа, листая сотню треков, неудобно.
/// Выбранная подкрашена тем же стеклом, что играющая строка трека, —
/// приложение уже говорит этим цветом «вот это».
struct PlaylistTrackPickCell: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(AudioPlayer.self) private var audioPlayer

    var track: Track
    var playlist: Playlist

    private var isPicked: Bool {
        playlist.items.contains { $0.track == track }
    }

    var body: some View {
        let isPicked = isPicked

        HStack(spacing: 12) {
            PickCover(track: track)

            VStack(alignment: .leading, spacing: 2) {
                Text(track.name)
                    .bold()
                    .lineLimit(1)

                // У трека без авторов строки нет: пустая оставляла бы под именем дыру.
                if !track.artistNames.isEmpty {
                    Text(track.artistNames.joined(separator: ", "))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            Image(systemName: isPicked ? "checkmark.circle.fill" : "plus.circle")
                .font(.title3)
                .foregroundStyle(isPicked ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 32)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .glassEffect(isPicked ? .regular.tint(audioPlayer.accent.opacity(0.28)) : .regular)
        .padding(.horizontal)
        .onTapGesture {
            withAnimation(.snappy) { swapIsPicked() }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityValue(isPicked ? "In the playlist" : "")
    }

    func swapIsPicked() {
        if isPicked {
            if let item = playlist.items.first(where: { $0.track == track }) {
                playlist.items.removeAll { $0.track == track }
                modelContext.delete(item)
            }
        } else {
            let position = (playlist.items.map(\.position).max() ?? -1) + 1
            let item = TrackPlaylistItem(track: track, playlist: playlist, position: position)
            playlist.items.append(item)
        }
    }
}

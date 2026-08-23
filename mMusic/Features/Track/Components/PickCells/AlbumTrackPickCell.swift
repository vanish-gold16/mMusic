import SwiftData
import SwiftUI

/// Строка выбора трека в альбом. Нажимается вся целиком: попадать в маленький
/// плюс справа при сборке альбома из полусотни треков — занятие на любителя.
struct AlbumTrackPickCell: View {

    var track: Track
    @Binding var addedTracks: [TrackDraft]
    /// Альбом, который собираем. Нужен, чтобы отличить «трек уже здесь»
    /// от «трек лежит в чужом альбоме и уедет оттуда».
    var currentAlbum: Album?

    private func matches(_ draft: TrackDraft) -> Bool {
        draft.sourceTrack == track.persistentModelID
    }

    private var pickedIndex: Int? {
        addedTracks.firstIndex(where: matches)
    }

    private var isPicked: Bool { pickedIndex != nil }

    /// Альбом, из которого трек уедет, если его выбрать. nil — забирать не у кого.
    private var albumToLeave: Album? {
        guard let album = track.album,
              album.persistentModelID != currentAlbum?.persistentModelID
        else { return nil }

        return album
    }

    var body: some View {
        HStack(spacing: 12) {
            artwork

            VStack(alignment: .leading, spacing: 2) {
                Text(track.name)
                    .bold()
                    .lineLimit(1)

                Text(track.artistNames.joined(separator: ", "))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                // Предупреждение, а не запрет: перенести трек из альбома в альбом
                // можно, но делать это молча нельзя — в том альбоме он пропадёт.
                if let albumToLeave {
                    Label("Moves out of \(albumToLeave.name)", systemImage: "arrow.turn.up.right")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            indicator
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        // Выбранная строка красится тем же стеклом, что и играющая в списках, —
        // приложение уже говорит этим цветом «вот это».
        .glassEffect(isPicked ? .regular.tint(Color.accentColor.opacity(0.28)) : .regular)
        .padding(.horizontal)
        .onTapGesture {
            withAnimation(.snappy) { swapIsPicked() }
        }
    }

    private var artwork: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(Color.gray.opacity(0.2))
            .frame(width: 40, height: 40)
            .overlay {
                if let data = track.displayArtwork, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "music.note")
                        .foregroundStyle(.secondary)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 2))
    }

    /// У выбранного трека вместо галочки — его номер в альбоме: порядком выбора
    /// задаётся порядок треков, и это единственное место, где это видно.
    private var indicator: some View {
        Group {
            if let pickedIndex {
                Text("\(pickedIndex + 1)")
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .frame(width: 26, height: 26)
                    .background(Color.accentColor, in: Circle())
            } else {
                Image(systemName: "plus.circle")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(width: 26, height: 26)
            }
        }
        .frame(width: 32)
    }

    private func swapIsPicked() {
        if isPicked {
            addedTracks.removeAll(where: matches)
            return
        }

        let draft = TrackDraft(
            name: track.name,
            genre: track.genre,
            artists: track.artistNames.map { ArtistDraft(name: $0) },
            stagedURL: AudioFileStore.url(for: track.filename),
            sourceTrack: track.persistentModelID
        )

        addedTracks.append(draft)
    }
}

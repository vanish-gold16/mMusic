import SwiftData
import SwiftUI

/// Строка выбора трека в альбом. Нажимается вся целиком: попадать в маленький
/// плюс справа при сборке альбома из полусотни треков — занятие на любителя.
struct AlbumTrackPickCell: View {

    @Environment(AudioPlayer.self) private var audioPlayer

    var track: Track
    @Binding var addedTracks: [TrackDraft]
    /// Альбом, который собираем. Нужен, чтобы отличить «трек уже здесь»
    /// от «трек лежит в чужом альбоме и уедет оттуда».
    var currentAlbum: Album?
    /// Формат альбома, который собираем: от него зависит, уйдёт ли трек
    /// со своего сингла или разделит песню с ним.
    var type: Album.AlbumType

    /// Узнанный в файле сингл тоже считается выбранным: он уже едет в альбом,
    /// и второй черновик того же трека сломал бы нумерацию.
    private func matches(_ draft: TrackDraft) -> Bool {
        (draft.sourceTrack ?? draft.existingTrack) == track.persistentModelID
    }

    private var pickedIndex: Int? {
        addedTracks.firstIndex(where: matches)
    }

    private var isPicked: Bool { pickedIndex != nil }

    /// Трек уже лежит в этом альбоме. Выбирать нечего, и убрать его отсюда тоже
    /// нельзя: лист умеет только добавлять, а убирают трек смахиванием в самом
    /// альбоме.
    private var isAlreadyHere: Bool {
        guard let currentAlbum else { return false }
        return track.album?.persistentModelID == currentAlbum.persistentModelID
    }

    /// Что станет с прежним альбомом трека, если его выбрать. nil — трек ниоткуда не уходит.
    private var joinNote: TrackJoinNote? {
        TrackJoinNote(track: track, joining: currentAlbum, type: type)
    }

    var body: some View {
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

                if isAlreadyHere {
                    Label("Already in this album", systemImage: "checkmark")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                // Предупреждение, а не запрет: перенести трек из альбома в альбом
                // можно, но делать это молча нельзя — в том альбоме он пропадёт.
                // С сингла песня не пропадает, и подпись говорит и это.
                if let joinNote {
                    Label(joinNote.text, systemImage: joinNote.systemImage)
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
        .glassEffect(isPicked ? .regular.tint(audioPlayer.accent.opacity(0.28)) : .regular)
        .padding(.horizontal)
        // Уже добавленные приглушены и не нажимаются: строка сообщает о состоянии,
        // а не предлагает действие.
        .opacity(isAlreadyHere ? 0.5 : 1)
        .onTapGesture {
            guard !isAlreadyHere else { return }
            withAnimation(.snappy) { swapIsPicked() }
        }
    }

    /// У выбранного трека вместо галочки — его номер в альбоме: порядком выбора
    /// задаётся порядок треков, и это единственное место, где это видно.
    private var indicator: some View {
        Group {
            if isAlreadyHere {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(width: 26, height: 26)
            } else if let pickedIndex {
                Text("\(pickedIndex + 1)")
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .frame(width: 26, height: 26)
                    .background(.tint, in: Circle())
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
            // С ролями: гость остаётся гостем и в строке черновика, и в редакторе.
            artists: track.artistDrafts,
            stagedURL: AudioFileStore.url(for: track.filename),
            sourceTrack: track.persistentModelID
        )

        addedTracks.append(draft)
    }
}

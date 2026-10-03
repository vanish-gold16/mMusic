import SwiftUI

/// Пластинка в списке закрытого альбома: диск со своим узором колец, номер,
/// название и паспорт. Нажатие достаёт её из конверта.
///
/// Узор у каждой пластинки свой — вторую от первой отличаешь раньше, чем
/// прочтёшь номер. Играющая подсвечена, и её диск крутится.
struct AlbumDiscRow: View {

    @Environment(AudioPlayer.self) private var audioPlayer

    let album: Album
    let disc: Int
    let tracks: [Track]
    let cover: UIImage?
    let accent: Color
    let action: () -> Void

    private let shape = RoundedRectangle(cornerRadius: 28, style: .continuous)

    var body: some View {
        let playingIndex = tracks.firstIndex { $0.id == audioPlayer.currentTrack?.id }
        let isPlayingHere = playingIndex != nil
        let title = album.title(ofDisc: disc)

        Button(action: action) {
            HStack(spacing: 14) {
                // `isPlaying` читается только у играющей пластинки: остальные
                // строки не должны перерисовываться на каждой паузе.
                VinylRecord(
                    cover: cover,
                    durations: tracks.map(\.duration),
                    currentIndex: playingIndex,
                    progress: nil,
                    isSpinning: isPlayingHere && audioPlayer.isPlaying,
                    rpm: album.type.rpm,
                    labelFraction: album.type.labelFraction,
                    accent: accent,
                    onTapTrack: nil
                )
                .frame(width: 76, height: 76)

                VStack(alignment: .leading, spacing: 3) {
                    // Номер — в мелкой строке, когда крупно стоит название;
                    // без названия крупно стоит сам номер.
                    Text((title.isEmpty ? sides : "Disc \(disc + 1)  ·  \(sides)").uppercased())
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .tracking(1.2)
                        .foregroundStyle(.secondary)

                    Text(title.isEmpty ? "Disc \(disc + 1)" : title)
                        .font(.system(size: 26, weight: .heavy).width(.compressed))
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    Text(passport)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .tracking(1.2)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .contentShape(shape)
            .glassEffect(isPlayingHere ? .regular.tint(accent.opacity(0.28)) : .regular, in: shape)
        }
        .buttonStyle(.plain)
    }

    /// «Sides C–D» — у пустой и короткой пластинки сторона одна.
    private var sides: String {
        let first = RecordSides.letter(disc: disc, side: 0)
        return RecordSides.split(tracks, type: album.type).count > 1
            ? "Sides \(first)–\(RecordSides.letter(disc: disc, side: 1))"
            : "Side \(first)"
    }

    /// «8 TRACKS  ·  40 MIN».
    private var passport: String {
        guard !tracks.isEmpty else { return "EMPTY" }

        var parts = [tracks.count == 1 ? "1 track" : "\(tracks.count) tracks"]

        let minutes = RecordSides.minutes(of: tracks)
        if minutes > 0 {
            parts.append("\(minutes) min")
        }

        return parts.joined(separator: "  ·  ").uppercased()
    }
}

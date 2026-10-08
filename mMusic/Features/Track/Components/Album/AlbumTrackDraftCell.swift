import SwiftUI

/// Строка трека в собираемом альбоме — та же, что строка трека на странице
/// готового альбома: номер на пластинке, имя, приглашённые и длительность
/// в стеклянной капсуле. Авторов альбома здесь нет: они написаны в шапке.
struct AlbumTrackDraftCell: View {
    var draft: TrackDraft
    var position: Int
    /// Длительность — у трека из библиотеки она берётся из самого трека,
    /// поэтому приходит снаружи, а не из черновика.
    var duration: TimeInterval = 0
    /// Откуда трек переедет, если он уже есть в библиотеке. nil — трек новый.
    var origin: String?

    private var featuredNames: [String] {
        var names: [String] = []
        for artist in draft.artists {
            if artist.role != .main {
                names.append(artist.name)
            }
        }
        return names
    }

    var body: some View {
        HStack {
            Text("\(position)")
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 40, height: 40)

            VStack(alignment: .leading) {
                Text(draft.name)
                    .bold()
                    .lineLimit(1)
                if !featuredNames.isEmpty {
                    Text("feat. \(featuredNames.joined(separator: ", "))")
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                // Тот же значок, что в пикере у трека, который уедет из чужого альбома.
                if let origin {
                    Label(origin, systemImage: "arrow.turn.up.right")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if duration > 0 {
                Text(Duration.seconds(duration).formatted(.time(pattern: .minuteSecond)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            // Строку открывают, чтобы поправить трек, — шеврон об этом говорит.
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
                .frame(width: 28)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .glassEffect()
        .padding(.horizontal)
    }
}

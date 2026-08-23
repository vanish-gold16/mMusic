import SwiftUI

/// Плашка «у трека сегодня день рождения»: сколько лет, сколько прослушиваний
/// и сколько времени вы провели вместе.
struct BirthdayCard: View {

    let birthday: TrackBirthday
    let onPlay: () -> Void

    private var track: Track { birthday.track }

    var body: some View {
        Button(action: onPlay) {
            HStack(spacing: 14) {
                artwork

                VStack(alignment: .leading, spacing: 4) {
                    Text(birthday.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tint)

                    Text(track.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(details)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)

                Image(systemName: "play.fill")
                    .font(.title3)
                    .foregroundStyle(.tint)
            }
            .padding(12)
            .contentShape(Rectangle())
            .glassEffect()
        }
        .buttonStyle(.plain)
    }

    /// Обложка со свечкой в углу: без неё плашка неотличима от обычной строки трека.
    private var artwork: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(.quaternary)
            .frame(width: 64, height: 64)
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
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(alignment: .topTrailing) {
                Text("🎂")
                    .font(.caption)
                    .padding(4)
                    .background(.thinMaterial, in: Circle())
                    .offset(x: 6, y: -6)
            }
    }

    private var details: String {
        "\(birthday.summary) • since \(track.addedAt.formatted(.dateTime.month(.abbreviated).year()))"
    }
}

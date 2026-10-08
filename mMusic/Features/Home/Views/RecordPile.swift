import SwiftData
import SwiftUI

/// Альбом в стопке у проигрывателя и когда его в последний раз ставили.
struct PiledRecord: Identifiable {
    let album: Album
    let lastPlayedAt: Date

    var id: PersistentIdentifier { album.persistentModelID }
}

/// Недавно игравшее — не лента квадратных карточек, а стопка пластинок
/// у проигрывателя, корешками к тебе. Сверху та, что ставили последней.
/// Корешки лежат чуть вразнобой, как положенные рукой, а играющая
/// выдвинута из стопки.
struct RecordPile: View {

    let records: [PiledRecord]

    var body: some View {
        VStack(spacing: 5) {
            ForEach(records) { record in
                RecordSpine(album: record.album, lastPlayedAt: record.lastPlayedAt)
            }
        }
        .padding(.horizontal)
    }
}

/// Корешок пластинки: залит главным цветом обложки, на торце — сама обложка,
/// на корешке — имя и когда её ставили.
private struct RecordSpine: View {

    @Environment(AudioPlayer.self) private var audioPlayer

    let album: Album
    let lastPlayedAt: Date

    @State private var cover: UIImage?
    @State private var palette: CoverPalette?

    private var sortedTracks: [Track] {
        album.tracklist
    }

    /// Небольшой разброс, свой у каждого альбома и одинаковый от запуска
    /// к запуску: `hashValue` в Swift меняется при каждом запуске, и стопка
    /// перекладывалась бы сама собой.
    private var jitter: (angle: Double, shift: CGFloat) {
        let seed = album.name.unicodeScalars.reduce(UInt64(5381)) { ($0 &* 33) &+ UInt64($1.value) }
        let angle = Double(seed % 17) / 16 * 1.6 - 0.8
        let shift = CGFloat((seed / 17) % 13)

        return (angle, shift)
    }

    var body: some View {
        // Играет ли альбом — читается здесь: перерисоваться на смене трека
        // должен один корешок, а не вся главная.
        let isCurrent = audioPlayer.currentTrack?.album?.persistentModelID == album.persistentModelID
        let jitter = jitter

        NavigationLink {
            AlbumView(album: album)
        } label: {
            spine(isCurrent: isCurrent)
        }
        .buttonStyle(.plain)
        .rotationEffect(.degrees(isCurrent ? 0 : jitter.angle))
        // Играющая выдвинута из стопки вправо — её видно сразу.
        .padding(.trailing, 28)
        .offset(x: isCurrent ? 28 : jitter.shift)
        .animation(.spring(duration: 0.5, bounce: 0.2), value: isCurrent)
        .contextMenu {
            Button {
                audioPlayer.play(sortedTracks)
            } label: {
                Label("Play", systemImage: "play")
            }
            Button {
                audioPlayer.playShuffled(sortedTracks)
            } label: {
                Label("Shuffle", systemImage: "shuffle")
            }
        }
        .task(id: album.artwork?.count) {
            await loadCover()
        }
    }

    private func spine(isCurrent: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: 6, style: .continuous)
        // Пока цвета не посчитаны — обычный текст на сером корешке.
        let ink: Color = palette.map { $0.isLight ? .black : .white } ?? .primary

        return HStack(spacing: 12) {
            coverEnd

            VStack(alignment: .leading, spacing: 1) {
                Text(album.name)
                    .font(.system(size: 19, weight: .heavy).width(.compressed))
                    .lineLimit(1)

                Text(album.artistNames.joined(separator: ", "))
                    .font(.caption)
                    .opacity(0.75)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if isCurrent, audioPlayer.isPlaying {
                EqualizerView(level: audioPlayer.level, barCount: 4, maxHeight: 14)
                    .frame(width: 22, height: 16)
            } else {
                Text(Self.ago(lastPlayedAt))
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .tracking(1.2)
                    .opacity(0.7)
            }
        }
        .foregroundStyle(ink)
        .padding(5)
        .padding(.trailing, 9)
        .background {
            shape.fill(palette?.base ?? Color(.systemGray5))
        }
        .overlay {
            // Играющий корешок обведён акцентом — тем же цветом, что и всё,
            // что сейчас звучит.
            if isCurrent {
                shape.strokeBorder(.tint, lineWidth: 2)
            } else {
                shape.strokeBorder(.white.opacity(0.1), lineWidth: 0.5)
            }
        }
        .clipShape(shape)
        .shadow(color: .black.opacity(0.18), radius: 3, y: 2)
        .contentShape(shape)
    }

    private var coverEnd: some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(.black.opacity(0.2))
            .frame(width: 42, height: 42)
            .overlay {
                if let cover {
                    Image(uiImage: cover)
                        .resizable()
                        .scaledToFill()
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
    }

    /// Торец — 42 pt, около 130 px на @3x; цвета берутся с той же миниатюры.
    private func loadCover() async {
        guard let data = album.artwork ?? album.tracklist.first?.displayArtwork else {
            cover = nil
            palette = nil
            return
        }

        let (image, found) = await Task.detached(priority: .utility) {
            let image = UIImage.thumbnail(from: data, side: 160)
            return (image, image?.coverPalette)
        }.value

        guard !Task.isCancelled else { return }
        cover = image
        palette = found
    }

    /// «12 MIN AGO», «3 H AGO», «YESTERDAY», «4 D AGO», а дальше — дата.
    static func ago(_ date: Date, now: Date = .now) -> String {
        let minutes = Int(now.timeIntervalSince(date) / 60)

        let text: String
        if minutes < 2 {
            text = "just now"
        } else if minutes < 60 {
            text = "\(minutes) min ago"
        } else if minutes < 24 * 60 {
            text = "\(minutes / 60) h ago"
        } else if Calendar.current.isDateInYesterday(date) {
            text = "yesterday"
        } else if minutes < 7 * 24 * 60 {
            text = "\(minutes / (24 * 60)) d ago"
        } else {
            text = date.formatted(.dateTime.month(.abbreviated).day().locale(.interface))
        }

        return text.uppercased()
    }
}

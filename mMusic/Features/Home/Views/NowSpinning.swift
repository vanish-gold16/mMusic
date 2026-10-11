import SwiftUI

/// Первое, что видно на главной: что лежит на проигрывателе. Играющий трек —
/// или тот, на котором остановились в прошлый раз: очередь восстанавливается
/// при запуске, и «play» продолжает с того же места.
///
/// Время читается здесь, а не в `HomeView`: оно меняется пять раз в секунду,
/// и перерисовываться на каждый тик должен только проигрыватель.
struct NowSpinning: View {

    @Environment(AudioPlayer.self) private var audioPlayer

    let track: Track

    @State private var cover: UIImage?
    /// Что открыто из меню по долгому нажатию на имя.
    @State private var action: TrackAction?

    /// Пластинка, на которой лежит трек. У трека без альбома она из него одного.
    private var discTracks: [Track] {
        guard let album = track.album else { return [track] }
        return album.discs[album.clampedDisc(of: track)]
    }

    var body: some View {
        let tracks = discTracks
        let index = tracks.firstIndex { $0.id == track.id } ?? 0
        let progress = audioPlayer.duration > 0 ? audioPlayer.currentTime / audioPlayer.duration : 0

        VStack(alignment: .leading, spacing: 18) {
            Turntable(
                cover: cover,
                type: track.album?.type ?? .single,
                durations: tracks.map(\.duration),
                currentIndex: index,
                progress: progress,
                isPlaying: audioPlayer.isPlaying,
                accent: audioPlayer.accent,
                onTapTrack: { tapped, fraction in
                    tapRing(tapped, fraction, in: tracks)
                }
            )

            HStack(alignment: .center, spacing: 14) {
                Button {
                    audioPlayer.togglePlayPause()
                } label: {
                    Image(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title2)
                        .frame(width: 36, height: 36)
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.circle)
                .accessibilityLabel(audioPlayer.isPlaying ? "Pause" : "Play")

                titleBlock
            }

            Text(passport)
                .font(.caption2)
                .fontWeight(.semibold)
                .tracking(1.2)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.horizontal)
        .trackActions(track, action: $action)
        .task(id: track.id) {
            await loadCover()
        }
    }

    /// Имя трека ведёт на страницу его альбома — там вся пластинка целиком.
    /// Долгое нажатие — меню трека, как у строки в списке.
    private var titleBlock: some View {
        titleLink
            .contextMenu {
                TrackMenuItems(track: track, action: $action, showsEnqueue: false)
            }
    }

    @ViewBuilder
    private var titleLink: some View {
        let label = VStack(alignment: .leading, spacing: 2) {
            Text(track.name)
                .font(.system(size: 30, weight: .heavy).width(.compressed))
                .lineLimit(2)

            HStack(spacing: 4) {
                Text(track.artistNames.joined(separator: ", "))
                    .lineLimit(1)
                if track.album != nil {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        if let album = track.album {
            NavigationLink {
                AlbumView(album: album)
            } label: {
                label
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        } else {
            label
        }
    }

    /// «NOW SPINNING  ·  A3  ·  2:14 LEFT», на паузе — «PAUSED  ·  A3  ·  1:02 IN».
    /// Если звук ещё не поднимали (очередь восстановлена с прошлого запуска),
    /// времени нет — тогда пишется, когда трек ставили.
    private var passport: String {
        var parts: [String] = []

        if audioPlayer.isPlaying {
            parts.append("now spinning")
        } else if audioPlayer.duration > 0 {
            parts.append("paused")
        } else {
            parts.append("where you left off")
        }

        if let number = track.album?.recordNumber(of: track) {
            parts.append(number)
        }

        if audioPlayer.duration > 0 {
            let time = audioPlayer.isPlaying
                ? "\(Self.clock(audioPlayer.duration - audioPlayer.currentTime)) left"
                : "\(Self.clock(audioPlayer.currentTime)) in"
            parts.append(time)
        } else if let lastPlayedAt = track.lastPlayedAt {
            parts.append(lastPlayedAt.formatted(.relative(presentation: .named).locale(.interface)))
        }

        return parts.joined(separator: "  ·  ").uppercased()
    }

    private static func clock(_ seconds: TimeInterval) -> String {
        Duration.seconds(max(seconds, 0)).formatted(.time(pattern: .minuteSecond))
    }

    /// По играющему кольцу — перемотка, по остальным — трек с начала,
    /// как на странице альбома.
    private func tapRing(_ index: Int, _ fraction: Double, in tracks: [Track]) {
        guard tracks.indices.contains(index) else { return }

        // `duration` пуст, пока звук не подняли (очередь восстановлена с прошлого
        // запуска), — перематывать там нечего, трек просто запускается.
        if audioPlayer.currentTrack?.id == tracks[index].id, audioPlayer.duration > 0 {
            audioPlayer.seek(to: fraction * audioPlayer.duration)
            return
        }

        audioPlayer.play(tracks, startingAt: index)
    }

    /// Яблоко пластинки — около 110 pt, ~330 px на @3x.
    private func loadCover() async {
        guard let data = track.displayArtwork else {
            cover = nil
            return
        }

        let image = await Task.detached(priority: .utility) {
            UIImage.thumbnail(from: data, side: 360)
        }.value

        guard !Task.isCancelled else { return }
        cover = image
    }
}

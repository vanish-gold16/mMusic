import SwiftUI

/// Микс главной: кассета и под ней пульт, как у плейлиста, — запуск, лента
/// всего микса и новая кассета. Удачную подборку можно оставить себе
/// плейлистом.
struct MixtapeSection: View {

    @Environment(AudioPlayer.self) private var audioPlayer
    @Environment(ToastCenter.self) private var toasts

    @State private var showAddToPlaylist = false

    let mix: [Track]
    let number: Int
    let palette: CoverPalette?
    let onReroll: () -> Void
    let onKeep: () -> Void

    /// Играет именно микс: тогда пульт ставит паузу, а кассета крутится.
    private var isSource: Bool {
        audioPlayer.isQueue(from: mix)
    }

    private var accent: Color {
        palette?.accent ?? audioPlayer.accent
    }

    /// «25 TRACKS  ·  1 H 32 MIN  ·  19 ARTISTS».
    private var summary: String {
        var parts = [mix.count == 1 ? "1 track" : "\(mix.count) tracks"]

        let total = mix.reduce(0) { $0 + $1.duration }
        if total >= 60 {
            parts.append(total.listeningLabel)
        }

        let artists = Set(mix.flatMap(\.artistNames)).count
        if artists > 1 {
            parts.append("\(artists) artists")
        }

        return parts.joined(separator: "  ·  ").uppercased()
    }

    var body: some View {
        let isSource = isSource
        let currentIndex = isSource ? mix.firstIndex { $0.id == audioPlayer.currentTrack?.id } : nil
        let isPlayingHere = isSource && audioPlayer.isPlaying

        VStack(alignment: .leading, spacing: 16) {
            MixtapeCassette(
                mix: mix,
                number: number,
                detail: summary,
                palette: palette,
                currentIndex: currentIndex,
                isSpinning: isPlayingHere
            )
            .contextMenu {
                Button {
                    audioPlayer.playShuffled(mix)
                } label: {
                    Label("Shuffle", systemImage: "shuffle")
                }

                Divider()

                Button {
                    audioPlayer.enqueueNext(mix)
                    toasts.enqueuedNext(mix.count)
                } label: {
                    Label("Play next", systemImage: "text.line.first.and.arrowtriangle.forward")
                }
                Button {
                    audioPlayer.enqueueLast(mix)
                    toasts.enqueuedLast(mix.count)
                } label: {
                    Label("Play after", systemImage: "text.line.last.and.arrowtriangle.forward")
                }

                Divider()

                Button(action: onKeep) {
                    Label("Keep as playlist", systemImage: "text.badge.plus")
                }
                // Удачный микс можно не только оставить целиком, но и долить в свой плейлист.
                Button {
                    showAddToPlaylist = true
                } label: {
                    Label("Add to a Playlist", systemImage: "text.badge.plus")
                }
                Button(action: onReroll) {
                    Label("Record a new one", systemImage: "arrow.clockwise")
                }
            }
            .sheet(isPresented: $showAddToPlaylist) {
                AddToPlaylistView(tracks: mix)
            }

            HStack(spacing: 12) {
                Button {
                    if isSource {
                        audioPlayer.togglePlayPause()
                    } else {
                        audioPlayer.play(mix)
                    }
                } label: {
                    Image(systemName: isPlayingHere ? "pause.fill" : "play.fill")
                        .font(.title2)
                        .frame(width: 36, height: 36)
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.circle)
                .accessibilityLabel(isPlayingHere ? "Pause" : "Play mixtape")

                PlaylistTape(
                    segments: mix.map(TapeSegment.init(track:)),
                    currentIndex: currentIndex,
                    accent: accent,
                    onTap: tapTape
                )
                .frame(height: 44)

                Button(action: onReroll) {
                    Image(systemName: "arrow.clockwise")
                        .font(.body.weight(.semibold))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .accessibilityLabel("Record a new mixtape")

                Button(action: onKeep) {
                    Image(systemName: "text.badge.plus")
                        .font(.body.weight(.semibold))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .accessibilityLabel("Keep as playlist")
            }
        }
        .tint(accent)
        .padding(.horizontal)
    }

    /// Как у ленты плейлиста: по играющему треку — перемотка, по остальным —
    /// микс с этого трека.
    private func tapTape(_ index: Int, _ fraction: Double) {
        guard mix.indices.contains(index) else { return }

        if audioPlayer.currentTrack?.id == mix[index].id, audioPlayer.duration > 0 {
            audioPlayer.seek(to: fraction * audioPlayer.duration)
            return
        }

        audioPlayer.play(mix, startingAt: index)
    }
}

/// Кассета, которая знает, сколько микса уже проиграно. Отдельный вид ради
/// времени: оно тикает пять раз в секунду, и перерисовываться должна кассета,
/// а не пульт рядом с ней.
private struct MixtapeCassette: View {

    @Environment(AudioPlayer.self) private var audioPlayer
    @Environment(ToastCenter.self) private var toasts

    @State private var showAddToPlaylist = false

    let mix: [Track]
    let number: Int
    let detail: String
    let palette: CoverPalette?
    let currentIndex: Int?
    let isSpinning: Bool

    /// Доля микса до текущего места. Непрочитанные длительности считаются
    /// средними — как на ленте.
    private var progress: Double {
        guard let currentIndex else { return 0 }

        let known = mix.map(\.duration).filter { $0 > 0 }
        let fallback = known.isEmpty ? 180 : known.reduce(0, +) / Double(known.count)
        let weights = mix.map { $0.duration > 0 ? $0.duration : fallback }
        let total = weights.reduce(0, +)
        guard total > 0 else { return 0 }

        let current = audioPlayer.duration > 0 ? audioPlayer.currentTime / audioPlayer.duration : 0
        return (weights[..<currentIndex].reduce(0, +) + weights[currentIndex] * current) / total
    }

    var body: some View {
        Cassette(
            title: "Mixtape",
            number: number,
            detail: detail,
            palette: palette,
            progress: progress,
            isSpinning: isSpinning
        )
    }
}

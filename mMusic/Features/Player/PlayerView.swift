import SwiftUI

struct PlayerView: View {
    let audioPlayer: AudioPlayer

    @State private var sliderValue: TimeInterval = 0
    @State private var isScrubbing = false

    /// Сглаженная громкость для фона: тянется за `audioPlayer.level`, но лениво,
    /// иначе фон мигал бы на каждой ноте.
    @State private var glow: Double = 0

    /// Ползучие границы громкости этого трека — подстраиваются сами,
    /// чтобы фон одинаково хорошо дышал и на тихой записи, и на громкой.
    @State private var quiet: Double = 0
    @State private var loud: Double = 1

    var body: some View {
        Text(String(format: "%.2f", punch))
        VStack(spacing: 32) {
            RoundedRectangle(cornerRadius: 16)
                .fill(.quaternary)
                .overlay {
                    if let data = audioPlayer.currentTrack?.displayArtwork,
                       let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Image(systemName: "music.note")
                            .font(.system(size: 64))
                            .foregroundStyle(.secondary)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .aspectRatio(1, contentMode: .fit)
                .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 4) {
                Text(audioPlayer.currentTrack?.name ?? "")
                    .font(.title2)
                    .bold()
                    .lineLimit(1)
                Text(audioPlayer.currentTrack?.artistNames.joined(separator: ", ") ?? "")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 16) {
                HStack(spacing: 40) {
                    Button {
                        audioPlayer.playPrevious()
                    } label: {
                        Image(systemName: "backward.end.fill")
                            .font(.largeTitle)
                            .frame(width: 60, height: 60)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PressableButtonStyle())

                    Button {
                        audioPlayer.togglePlayPause()
                    } label: {
                        Image(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 44))
                            .frame(width: 60, height: 60)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PressableButtonStyle())

                    Button {
                        audioPlayer.playNext()
                    } label: {
                        Image(systemName: "forward.end.fill")
                            .font(.largeTitle)
                            .frame(width: 60, height: 60)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PressableButtonStyle())
                }
                .foregroundStyle(.orange)

                VStack(spacing: 4) {
                    Slider(
                        value: $sliderValue,
                        in: 0...max(audioPlayer.duration, 0.01)
                    ) { editing in
                        isScrubbing = editing
                        if !editing {
                            audioPlayer.seek(to: sliderValue)
                        }
                    }
                    .tint(.orange)

                    HStack {
                        Text(timeString(sliderValue))
                        Spacer()
                        Text("-" + timeString(audioPlayer.duration - sliderValue))
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                }
            }

            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 32)
        .presentationDragIndicator(.visible)
        .presentationBackground { artworkBackground }
        .onAppear { sliderValue = audioPlayer.currentTime }
        .onChange(of: audioPlayer.level) { _, newLevel in
            // Резкий подъём, медленный спад — так удары читаются как удары.
            let speed = newLevel > glow ? 0.45 : 0.06
            glow += (newLevel - glow) * speed

            // Границы мгновенно раздвигаются наружу и очень медленно сползают внутрь.
            loud = max(glow, loud + (glow - loud) * 0.004)
            quiet = min(glow, quiet + (glow - quiet) * 0.004)
        }
        .onChange(of: audioPlayer.currentTime) { _, newValue in
            guard !isScrubbing else { return }
            sliderValue = newValue
        }
        .onChange(of: audioPlayer.currentIndex) { _, _ in
            isScrubbing = false
            sliderValue = audioPlayer.currentTime

            // У нового трека своя громкость — границы ищем заново.
            quiet = 0
            loud = 1
        }
    }

    /// Где `glow` находится между тихим и громким местом этого трека, 0...1.
    /// `span` не даёт делить на почти-ноль: на ровном месте фон должен замереть,
    /// а не раздувать микроскопические колебания до полного размаха.
    private var punch: Double {
        let span = max(loud - quiet, 0.12)
        return min(max((glow - quiet) / span, 0), 1)
    }

    @ViewBuilder
    private var artworkBackground: some View {
        if let data = audioPlayer.currentTrack?.displayArtwork,
           let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .blur(radius: 60)                  // константа — пересчитывается один раз
                .scaleEffect(1.25 + punch * 0.45)  // на громком фон наплывает
                .clipped()
                .saturation(0.9 + punch * 1.6)     // и вспыхивает цветом
                .brightness(punch * 0.12)
                .hueRotation(.degrees(punch * 18)) // оттенок ведёт — фон «переливается»
                .overlay {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .opacity(0.9 - punch * 0.7) // вуаль тончает, обложка проступает
                }
        } else {
            Color.black
        }
    }

    private func timeString(_ time: TimeInterval) -> String {
        let total = Int(max(0, time.rounded()))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

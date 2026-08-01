import SwiftUI

struct PlayerView: View {
    let audioPlayer: AudioPlayer

    @State private var sliderValue: TimeInterval = 0
    @State private var isScrubbing = false

    var body: some View {
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
        .onAppear { sliderValue = audioPlayer.currentTime }
        .onChange(of: audioPlayer.currentTime) { _, newValue in
            guard !isScrubbing else { return }
            sliderValue = newValue
        }
        .onChange(of: audioPlayer.currentIndex) { _, _ in
            isScrubbing = false
            sliderValue = audioPlayer.currentTime
        }
    }

    private func timeString(_ time: TimeInterval) -> String {
        let total = Int(max(0, time.rounded()))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

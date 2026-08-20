import SwiftUI

struct MiniPlayerView: View {
    let audioPlayer: AudioPlayer

    @Binding var isPlayerPresented: Bool

    var body: some View {
        if let track = audioPlayer.currentTrack {
            HStack(spacing: 12) {
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 8)
                        .overlay {
                            if let data = track.displayArtwork, let uiImage = UIImage(data: data) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } else {
                                Image(systemName: "music.note")
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .frame(width: 30, height: 30)
                    VStack(alignment: .leading) {
                        Text(track.name)
                            .lineLimit(1)
                            .font(.subheadline)
                            .bold()
                        Text(track.artistNames.joined(separator: ", "))
                            .lineLimit(1)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
                .contentShape(Rectangle())
                .onTapGesture { isPlayerPresented = true }

                HStack {
                    Button {
                        audioPlayer.playPrevious()
                    } label: {
                        Image(systemName: "backward.end.fill")
                            .font(.title2)
                            .frame(width: 30, height: 30)
                            .contentShape(Rectangle())
                    }
                    .foregroundStyle(.tint)
                    .buttonStyle(PressableButtonStyle())
                    
                    Button {
                        audioPlayer.togglePlayPause()
                    } label: {
                        Image(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title2)
                            .frame(width: 30, height: 30)
                            .contentShape(Rectangle())
                    }
                    .foregroundStyle(.tint)
                    .buttonStyle(PressableButtonStyle())
                    
                    Button {
                        audioPlayer.playNext()
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.title2)
                            .frame(width: 30, height: 30)
                            .contentShape(Rectangle())
                    }
                    .foregroundStyle(.tint)
                    .buttonStyle(PressableButtonStyle())
                }
                .padding(.horizontal)
            }
            .frame(maxHeight: .infinity)
            .padding(.horizontal)
        }
    }
    
}

import SwiftUI

struct MiniPlayerView: View {
    let audioPlayer: AudioPlayer
    
    var body: some View {
        if let track = audioPlayer.currentTrack {
            HStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 40, height: 40)
                    .overlay(Image(systemName: "music.note"))
                VStack(alignment: .leading) {
                    Text(track.name)
                    Text(track.artist)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    audioPlayer.togglePlayPause()
                } label: {
                    Image(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title2)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .padding(.horizontal)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .glassEffect(in: .rect(cornerRadius: 24))
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
    }
    
}

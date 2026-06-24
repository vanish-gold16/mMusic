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
                Image(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .glassEffect()
            .padding(.horizontal)
        }
    }
}

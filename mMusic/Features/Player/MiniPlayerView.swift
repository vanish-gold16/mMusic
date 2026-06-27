import SwiftUI

struct MiniPlayerView: View {
    let audioPlayer: AudioPlayer
    
    var body: some View {
        if let track = audioPlayer.currentTrack {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 30, height: 30)
                    .overlay(Image(systemName: "music.note"))
                VStack(alignment: .leading) {
                    Text(track.name)
                        .lineLimit(1)
                        .font(.subheadline)
                        .bold()
                    Text(track.artist)
                        .lineLimit(1)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                HStack {
                    Spacer()
                    
                    Button {
                        audioPlayer.togglePlayPause()
                    } label: {
                        Image(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title2)
                            .frame(width: 30, height: 30)
                            .contentShape(Rectangle())
                    }
                    
                    Spacer()
                    
                    Button {
                        
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.title2)
                            .frame(width: 30, height: 30)
                            .contentShape(Rectangle())
                    }
                }
                .padding(.horizontal)
            }
            .frame(maxHeight: .infinity)
            .padding(.horizontal)
        }
    }
    
}

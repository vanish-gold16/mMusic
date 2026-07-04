import SwiftUI

struct PlaylistView: View {
    
    let playlist: Playlist
    
    var body: some View {
        ScrollView {
            VStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 250, height: 250)
                    .overlay {
                        if let data = playlist.artwork, let uiImage = UIImage(data: data) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                        } else {
                            Image(systemName: "music.note")
                                .resizable()
                                .scaledToFill()
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                Text(playlist.name)
                    .font(.largeTitle)
                    .bold()
                Text(playlist.playlistDescription)
                HStack {
                    Button {
                        
                    } label: {
                        Capsule()
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .padding(.horizontal)
                            .overlay {
                                HStack {
                                    Image(systemName: "play.fill")
                                        .tint(.primary)
                                    Text("Play")
                                        .foregroundStyle(.primary)
                                        .bold()
                                }
                            }
                    }
                    Button {
                        
                    } label: {
                        Capsule()
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .padding(.horizontal)
                            .overlay {
                                HStack {
                                    Image(systemName: "shuffle")
                                        .tint(.primary)
                                    Text("Shuffle")
                                        .foregroundStyle(.primary)
                                        .bold()
                                }
                            }
                    }
                }
                ForEach(playlist.tracks) { track in
                    PlaylistTrackCell(track: track)
                }
            }
        }
    }
}

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
                                .frame(width: 200, height: 200)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                Text(playlist.name)
                    .font(.largeTitle)
                    .bold()
                Text(playlist.playlistDescription)
                    .padding(.horizontal)
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
                                        .tint(.primary)
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
                                        .tint(.primary)
                                        .bold()
                                }
                            }
                    }
                    
                    Spacer()
                }
                
                ForEach(playlist.tracks) { track in
                    Divider()
                    PlaylistTrackCell(track: track)
                }
                
                Divider()
                
                HStack {
                    Color.clear
                        .frame(width: 10)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 50, height: 50)
                        .overlay {
                            Image(systemName: "plus")
                                .resizable()
                                .bold()
                                .frame(width: 20, height: 20)
                                .tint(.orange)
                                .tint(.orange)
                        }
                    Text("Add Music")
                    Spacer()
                }
                
                Divider()
                
            }
        }
    }
}

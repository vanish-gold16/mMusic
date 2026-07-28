import SwiftUI
import SwiftData

struct PlaylistView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(AudioPlayer.self) var audioPlayer
    
    @State private var isShowingTrackPicker = false
    @State private var editingPlaylist = false
    @State private var showDeleteConfirmation = false

    let playlist: Playlist
    
    var body: some View {
        ScrollView {
            VStack {
                RoundedRectangle(cornerRadius: 12)
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
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                Text(playlist.name)
                    .font(.largeTitle)
                    .bold()
                Text(playlist.playlistDescription)
                    .padding(.horizontal)
                    .font(.subheadline)
                    .tint(.secondary)
                HStack {
                    Button {
                        audioPlayer.play(playlist.tracks.shuffled())
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
                        audioPlayer.play(playlist.tracks)
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
                    TrackCell(track: track, queue: playlist.tracks)
                }

                Button {
                    isShowingTrackPicker = true
                } label: {
                    HStack {
                        Color.clear
                            .frame(width: 16)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 40, height: 40)
                            .overlay {
                                Image(systemName: "plus")
                                    .resizable()
                                    .bold()
                                    .frame(width: 15, height: 15)
                                    .tint(.orange)
                            }
                        Text("Add Music")
                            .tint(.primary)
                        Spacer()
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    VStack {
                        ControlGroup {
                            Button {
                                
                            } label: {
                                Label("Favourite", systemImage: "star")
                            }
                            Button {
                                
                            } label: {
                                Label("Share", systemImage: "square.and.arrow.up")
                            }
                        }
                        Divider()
                        
                        Button {
                            
                        } label: {
                            Label("Play", systemImage: "play")
                        }
                        Button {
                            
                        } label: {
                            Label("Shuffle", systemImage: "shuffle")
                        }
                        
                        Divider()
                        
                        Button {
                            editingPlaylist = true
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        
                        Divider()
                        
                        Button {
                            
                        } label: {
                            Label("Play next", systemImage: "text.line.first.and.arrowtriangle.forward")
                        }
                        Button {
                            
                        } label: {
                            Label("Play after", systemImage: "text.line.last.and.arrowtriangle.forward")
                        }
                        
                        Divider()
                        
                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .tint(.red)
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
            }
        }
        .sheet(isPresented: $isShowingTrackPicker) {
            TrackPickerView(playlist: playlist)
        }
        .sheet(isPresented: $editingPlaylist) {
            EditPlaylistView(playlist: playlist)
        }
        .confirmationDialog(
            "Delete \"\(playlist.name)\"?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                modelContext.delete(playlist)
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This playlist will be permanently deleted.")
        }
    }
}

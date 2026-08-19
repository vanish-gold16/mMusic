import SwiftUI
import SwiftData

struct PlaylistsView: View {
    let columns = [GridItem(.flexible(), alignment: .top)]
    
    @Query private var playlists: [Playlist]
    @Environment(\.modelContext) private var modelContext
    @Environment(AudioPlayer.self) private var audioPlayer
    
    @State private var isCreating = false
    @State private var editedPlaylist: Playlist?
    @State private var playlistToDelete: Playlist?
    
    var body: some View {
        VStack {
            ScrollView {
                LazyVStack(spacing: 5) {
                    ForEach(playlists) { playlist in
                        NavigationLink {
                            PlaylistView(playlist: playlist)
                        } label: {
                            PlaylistCell(playlist: playlist)
                        }
                        .contextMenu() {
                            VStack {
                                ControlGroup {
                                    Button {
                                        playlist.isPinned = !playlist.isPinned
                                    } label: {
                                        if playlist.isPinned {
                                            Label("Unpin", systemImage: "pin.fill")
                                        } else {
                                            Label("Pin", systemImage: "pin")
                                        }
                                    }
                                    ShareLink(items: playlist.orderedTracks.map { AudioFileStore.url(for: $0.filename) }) {
                                        Label("Share", systemImage: "square.and.arrow.up")
                                    }
                                }
                                
                                Divider()
                                
                                Button {
                                    audioPlayer.play(playlist.orderedTracks)
                                } label: {
                                    Label("Play", systemImage: "play")
                                }
                                Button {
                                    audioPlayer.playShuffled(playlist.orderedTracks)
                                } label: {
                                    Label("Shuffle", systemImage: "shuffle")
                                }
                                
                                Divider()
                                
                                Button {
                                    editedPlaylist = playlist
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                
                                Divider()
                                
                                Button {
                                    audioPlayer.enqueueNext(playlist.orderedTracks)
                                } label: {
                                    Label("Play next", systemImage: "text.line.first.and.arrowtriangle.forward")
                                }
                                Button {
                                    audioPlayer.enqueueLast(playlist.orderedTracks)
                                } label: {
                                    Label("Play after", systemImage: "text.line.last.and.arrowtriangle.forward")
                                }
                                
                                Divider()
                                
                                Button(role: .destructive) {
                                    playlistToDelete = playlist
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                .tint(.red)
                            }
                        }
                        .sheet(item: $editedPlaylist) { playlist in
                            EditPlaylistView(playlist: playlist)
                        }
                    }
                }
            }
        }
        .confirmationDialog(
            "Delete \"\(playlistToDelete?.name ?? "")\"?",
            isPresented: Binding(
                get: { playlistToDelete != nil },
                set: { if !$0 { playlistToDelete = nil } }
            ),
            titleVisibility: .visible,
            presenting: playlistToDelete
        ) { playlist in
            Button("Delete", role: .destructive) {
                modelContext.delete(playlist)
            }
            Button("Cancel", role: .cancel) { }
        } message: { _ in
            Text("This playlist will be permanently deleted.")
        }
        .navigationTitle("Playlists")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        isCreating = true
                    } label: {
                        Label("Create a Playlist", systemImage: "music.note.list")
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $isCreating) {
            CreatePlaylistView()
        }
    }
}

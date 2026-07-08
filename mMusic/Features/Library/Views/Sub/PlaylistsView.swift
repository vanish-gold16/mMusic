import SwiftUI
import SwiftData

struct PlaylistsView: View {
    let columns = [GridItem(.flexible(), alignment: .top)]
    
    @Query private var playlists: [Playlist]
    @Environment(\.modelContext) private var modelContext
    
    @State private var isCreating = false
    @State private var editedPlaylist: Playlist?
    
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
                                    editedPlaylist = playlist
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
                                    modelContext.delete(playlist)
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

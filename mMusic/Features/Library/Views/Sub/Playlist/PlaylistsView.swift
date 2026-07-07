import SwiftUI
import SwiftData

struct PlaylistsView: View {
    let columns = [GridItem(.flexible(), alignment: .top)]
    
    @Query private var playlists: [Playlist]
    @Environment(\.modelContext) private var modelContext
    
    @State private var isCreating = false
    @State private var showEdit = false
    
    var body: some View {
        VStack {
            Button {
                isCreating = true
            } label: {
                Image(systemName: "plus")
                Text("New Playlist")
            }
            .buttonStyle(.glassProminent)
            .frame(maxWidth: .infinity)
            .sheet(isPresented: $isCreating) {
                CreatePlaylistView()
            }
            
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
                                    showEdit = true
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
                        .sheet(isPresented: $showEdit) {
                            EditPlaylistView(playlist: playlist)
                        }
                    }
                }
            }
        }
        .navigationTitle("Playlists")
        .navigationBarTitleDisplayMode(.inline)
    }
}

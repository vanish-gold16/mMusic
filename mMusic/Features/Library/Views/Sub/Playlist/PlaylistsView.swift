import SwiftUI
import SwiftData

struct PlaylistsView: View {
    let columns = [GridItem(.flexible(), alignment: .top)]
    
    @Query private var playlists: [Playlist]
    @Environment(\.modelContext) private var modelContext
    
    @State private var isCreating = false
    
    var body: some View {
        NavigationStack {
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
                            PlaylistCell(playlist: playlist)
                        }
                    }
                }
            }
        }
        .navigationTitle("Playlists")
        .navigationBarTitleDisplayMode(.inline)
    }
}

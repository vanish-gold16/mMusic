import SwiftUI
import SwiftData

struct LibraryView: View {
    let columns = [GridItem(.flexible(), alignment: .top), GridItem(.flexible(), alignment: .top)]

    @Query private var tracks: [Track]
    @Environment(\.modelContext) private var modelContext
    @Environment(AudioPlayer.self) private var audioPlayer

    @State private var selectedCategory: LibraryCategory = .playlists

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                Spacer()
                
                ForEach(LibraryCategory.allCases, id: \.self) { category in
                    NavigationLink(destination: destinationView(for: category)) {
                        HStack {
                            Label(category.rawValue, systemImage: category.icon)
                                .foregroundColor(.orange)
                                .font(.title2)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                                .font(.subheadline)
                        }
                    }
                    
                    Divider()
                    
                    .animation(.easeOut, value: selectedCategory)
                }
                
                VStack(alignment: .leading) {
                    Text("Recently added")
                        .font(.title)
                        .bold()
                        .frame(maxWidth: .infinity, alignment: .leading)
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(tracks) { track in
                            TrackCell(track: track)
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
        .navigationTitle("Library")
    }
    
    @ViewBuilder
    func destinationView (for category: LibraryCategory) -> some View {
        switch category {
        case .playlists: PlaylistsView()
        case .songs: SongsView()
        case .albums: AlbumsView()
        case .artists: ArtistsView()
        }
    }
}

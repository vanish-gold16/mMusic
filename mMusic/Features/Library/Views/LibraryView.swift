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
                            VStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.gray.opacity(0.2))
                                    .aspectRatio(1, contentMode: .fit)
                                    .overlay {
                                        if let data = track.artwork, let uiImage = UIImage(data: data) {
                                            Image(uiImage: uiImage)
                                                .resizable()
                                                .scaledToFill()
                                        } else {
                                            Image(systemName: "music.note")
                                        }
                                    }
                                Text(track.name)
                                    .lineLimit(1)
                                Text(track.artist)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .onTapGesture {
                                audioPlayer.play(track)
                            }
                            .contextMenu() {
                                VStack {
                                    ControlGroup {
                                        Button {
                                            
                                        } label: {
                                            Label("Favourite", systemImage: track.isFavourite ? "star.fill" : "star")
                                        }
                                        
                                        Button {
                                            
                                        } label: {
                                            Label("Share", systemImage: "square.and.arrow.up")
                                        }
                                    }
                                    
                                    Divider()
                                    
                                    Button {
                                        
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    
                                    Divider()
                                    
                                    Button(role: .destructive) {
                                        let url = URL.documentsDirectory.appending(path: track.filename)
                                        try? FileManager.default.removeItem(at: url)
                                        modelContext.delete(track)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                    
                                    .tint(.red)
                                }
                            }
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

import SwiftUI
import SwiftData

struct PlaylistView: View {
    
    @Environment(\.modelContext) private var modelContext
    @Environment(AudioPlayer.self) var audioPlayer
    
    @State private var isShowingTrackPicker = false
    @State private var editingPlaylist = false
    @State private var showDeleteConfirmation = false
    
    let playlist: Playlist

    /// Складывается из уже прочитанных длительностей — файлы для этого больше не открываются.
    private var totalDuration: TimeInterval {
        playlist.orderedTracks.reduce(0) { $0 + $1.duration }
    }
    
    var body: some View {
        List {
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
                        audioPlayer.play(playlist.orderedTracks)
                    } label: {
                        Capsule()
                            .foregroundStyle(.tint)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .padding(.horizontal)
                            .overlay {
                                HStack {
                                    Image(systemName: "play.fill")
                                    Text("Play")
                                        .bold()
                                }
                                .foregroundStyle(.white)
                            }
                    }
                    Button {
                        audioPlayer.playShuffled(playlist.orderedTracks)
                    } label: {
                        Capsule()
                            .foregroundStyle(.tint)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .padding(.horizontal)
                            .overlay {
                                HStack {
                                    Image(systemName: "shuffle")
                                    Text("Shuffle")
                                        .bold()
                                }
                                .foregroundStyle(.white)
                            }
                    }
                }
            }
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())

            ForEach(playlist.orderedTracks) { track in
                TrackCell(track: track, queue: playlist.orderedTracks, leadingStyle: .artwork)
            }
            .onMove { source, destination in
                moveTracks(from: source, to: destination)
            }
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())

            Button {
                isShowingTrackPicker = true
            } label: {
                HStack {
                    Color.clear
                        .frame(width: 16)
                    Image(systemName: "plus")
                        .resizable()
                        .bold()
                        .frame(width: 15, height: 15)
                        .frame(width: 40, height: 40)
                    Text("Add Music")
                        .tint(.primary)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
                .glassEffect()
                .padding(.horizontal)
            }
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())

            if !playlist.orderedTracks.isEmpty {
                Text("\(playlist.orderedTracks.count) songs • \(Duration.seconds(totalDuration).formatted(.units(allowed: [.hours, .minutes], width: .wide)))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top)
                    .frame(maxWidth: .infinity)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
            }
        }
        .listStyle(.plain)
        .listRowSpacing(8)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    VStack {
                        ControlGroup {
                            Button {
                                playlist.isFavourite.toggle()
                            } label: {
                                Label("Favourite", systemImage: playlist.isFavourite ? "star.fill" : "star")
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
                            editingPlaylist = true
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }

                        Menu {
                            ForEach(PlaylistSort.allCases) { option in
                                Button {
                                    applySort(option)
                                } label: {
                                    Label(option.rawValue, systemImage: option.systemImage)
                                }
                            }
                        } label: {
                            Label("Sort", systemImage: "arrow.up.arrow.down")
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
    
    /// Переписывает позиции раз и навсегда: дальше порядок снова ручной.
    private func applySort(_ option: PlaylistSort) {
        for (index, item) in option.sorted(playlist.items).enumerated() {
            item.position = index
        }
    }

    private func moveTracks(from: IndexSet, to: Int) {
        var items = playlist.items.sorted { $0.position < $1.position }
        items.move(fromOffsets: from, toOffset: to)

        for (index, item) in items.enumerated() {
            item.position = index
        }
    }
    
}

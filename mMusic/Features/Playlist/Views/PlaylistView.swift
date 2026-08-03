import SwiftUI
import SwiftData
import AVFoundation

struct PlaylistView: View {
    
    @Environment(\.modelContext) private var modelContext
    @Environment(AudioPlayer.self) var audioPlayer
    
    @State private var isShowingTrackPicker = false
    @State private var editingPlaylist = false
    @State private var showDeleteConfirmation = false
    @State private var totalDuration: TimeInterval = 0
    
    let playlist: Playlist
    
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
                            .backgroundStyle(.orange)
                    }
                    Button {
                        audioPlayer.play(playlist.orderedTracks.shuffled())
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
                            .backgroundStyle(.orange)
                    }
                }
                
                Spacer()
            }
            
            ForEach(playlist.orderedTracks) { track in
                TrackCell(track: track, queue: playlist.orderedTracks, leadingStyle: .artwork)
            }
            .onMove { from, to in
                moveTracks(from: from, to: to)
            }
            .listRowSeparator(.hidden)      // убрать разделители
            .listRowBackground(Color.clear) // убрать белую подложку строки
            .listRowInsets(EdgeInsets())    // убрать системные отступы (у тебя свои внутри ячейки)
            
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
                        .tint(.orange)
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
            .listRowSeparator(.hidden)      // убрать разделители
            .listRowBackground(Color.clear) // убрать белую подложку строки
            .listRowInsets(EdgeInsets())    // убрать системные отступы (у тебя свои внутри ячейки)
            
            if !playlist.orderedTracks.isEmpty {
                Text("\(playlist.orderedTracks.count) songs • \(Duration.seconds(totalDuration).formatted(.units(allowed: [.hours, .minutes], width: .wide)))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top)
                    .listRowSeparator(.hidden)      // убрать разделители
                    .listRowBackground(Color.clear) // убрать белую подложку строки
                    .listRowInsets(EdgeInsets())    // убрать системные отступы (у тебя свои внутри ячейки)
            }
        }
        .listStyle(.plain)
        .task(id: playlist.orderedTracks.map(\.filename)) {
            await calculateTotalDuration()
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
    
    private func calculateTotalDuration() async {
        var total: TimeInterval = 0
        for track in playlist.orderedTracks {
            let url = URL.documentsDirectory.appending(path: track.filename)
            let asset = AVURLAsset(url: url)
            if let duration = try? await asset.load(.duration) {
                total += CMTimeGetSeconds(duration)
            }
        }
        totalDuration = total
    }
    
    private func moveTracks(from: IndexSet, to: Int) {
        var items = playlist.items.sorted { $0.position < $1.position }
        items.move(fromOffsets: from, toOffset: to)

        for (index, item) in items.enumerated() {
            item.position = index
        }
    }
    
}

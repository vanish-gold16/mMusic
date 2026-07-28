import SwiftData
import SwiftUI

struct TrackCell: View {
    
    @Environment(AudioPlayer.self) private var audioPlayer
    @Environment(\.modelContext) private var modelContext
    
    @State private var showEditTrack: Bool = false
    @State private var showDeleteConfirmation: Bool = false

    enum LeadingStyle {
        case number
        case artwork
    }

    var track: Track
    var queue: [Track] = []
    var leadingStyle: LeadingStyle = .number

    var body: some View {
        HStack {
            Image(systemName: "star.fill")
                .foregroundStyle(.orange)
                .opacity(track.isFavourite ? 1 : 0)
                .frame(width: 16)
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.gray.opacity(0.2))
                .frame(width: 40, height: 40)
                .overlay {
                    switch leadingStyle {
                    case .number:
                        Text("\(track.position + 1)")
                    case .artwork:
                        if let data = track.displayArtwork, let uiImage = UIImage(data: data) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                        } else {
                            Image(systemName: "music.note")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 2))
            VStack(alignment: .leading) {
                Text(track.name)
                    .bold()
                    .lineLimit(1)
                Text(track.artistNames.joined(separator: ", "))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Menu {
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
                    showEditTrack = true
                } label: {
                    Label("Edit track", systemImage: "pencil")
                }
                
                Button {
                    
                } label: {
                    Label("Add to a Playlist", systemImage: "text.badge.plus")
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
                
                Button {
                    
                } label: {
                    Label("Go to Album", systemImage: "music.note.square.stack")
                }
                
                Divider()

                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label("Remove", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .glassEffect()
        .padding(.horizontal)
        .onTapGesture {
            let list = queue.isEmpty ? [track] : queue  // ← подумай, не перепутал ли порядок
            let index = list.firstIndex { $0.id == track.id } ?? 0
            audioPlayer.play(list, startingAt: index)
        }
        .sheet(isPresented: $showEditTrack) {
            EditTrackView(track: track)
        }
        .confirmationDialog(
            "Remove \"\(track.name)\"?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive) {
                let url = URL.documentsDirectory.appending(path: track.filename)
                try? FileManager.default.removeItem(at: url)
                modelContext.delete(track)
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This track will be permanently deleted.")
        }
    }
}

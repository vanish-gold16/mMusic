import PhotosUI
import SwiftUI
import SwiftData

struct SettingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Artist.name) private var allArtists: [Artist]
    
    @State private var showImagePicker = false
    @State private var showAddArtist = false
    
    @State private var name = ""
    @State private var artists: [ArtistDraft] = []
    @State private var newArtistName = ""
    @State private var genre: Genre = .pop
    @State private var artworkData: Data?
    
    private var suggestions: [Artist] {
        if newArtistName.isEmpty {
            return []
        } else {
            return allArtists.filter { $0.name.localizedCaseInsensitiveContains(newArtistName) }
        }
    }
    
    let file: PickedFile
    
    var body: some View {
        
        NavigationStack {
            
            Form {
                Section {
                    VStack {
                        if let artworkData, let uiImage = UIImage(data: artworkData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 150)
                        } else {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.2))
                                .overlay {
                                    Image(systemName: "music.note")
                                }
                                .scaledToFit()
                                .frame(height: 150)
                        }
                        
                        Button {
                            showImagePicker = true
                        } label: {
                            Label("Pick an image", systemImage: "photo")
                                .labelStyle(.titleAndIcon)
                        }
                        .buttonStyle(.glassProminent)
                        .sheet(isPresented: $showImagePicker) {
                            ImagePicker(imageData: $artworkData)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                }
                Section("name") {
                    TextField("", text: $name)
                }
                Section("artists") {
                    FlowLayout(spacing: 8) {
                        ForEach(artists) { draft in
                            TrackArtistCell(name: draft.name, showDelete: true, onRemove: {
                                artists.removeAll { $0.id == draft.id }
                            })
                        }
                        
                        Button {
                            newArtistName = ""
                            showAddArtist = true
                        } label: {
                            Image(systemName: "plus")
                                .padding(.horizontal, 5)
                                .padding(.vertical, 5)
                                .background(Color.gray.opacity(0.2), in: Circle())
                        }
                        .buttonStyle(.borderless)
                        .fixedSize()
                        .popover(isPresented: $showAddArtist) {
                            VStack(spacing: 16) {
                                TextField("artist name", text: $newArtistName)
                                    .padding(10)
                                    .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 8))
                                if suggestions != [] {
                                    ScrollView {
                                        ForEach(suggestions) { artist in
                                            TrackArtistCell(name: artist.name, showDelete: false, onTap: {
                                                artists.append(ArtistDraft(name: artist.name))
                                                showAddArtist = false
                                            })
                                        }
                                    }
                                }
                                Button("add") {
                                    artists.append(ArtistDraft(name: newArtistName))
                                    showAddArtist = false
                                }
                                .buttonStyle(.glassProminent)
                            }
                            .padding()
                            .frame(width: 280, height: 220)
                            .presentationCompactAdaptation(.popover)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                Section {
                    Picker("genre", selection: $genre) {
                        ForEach(Genre.allCases, id: \.self) { genre in
                            Text(genre.rawValue).tag(genre)
                        }
                    }
                }
            }
            .navigationTitle("Track settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("save") {
                        save()
                    }
                }
            }
        }
    }
    
    init(file: PickedFile) {
        self.file = file
        let parsed = file.url.parseMusic()
        _name = State(initialValue: parsed.name)
        _artists = State(initialValue: [ArtistDraft(name: parsed.artist)])
    }
    
    private func save() {
        let source = file.url
        let destination = URL.documentsDirectory.appending(path: source.lastPathComponent)
        
        source.startAccessingSecurityScopedResource()
        do {
            try FileManager.default.copyItem(at: source, to: destination)
        } catch {
            print("Copy error: \(error)")
        }
        source.stopAccessingSecurityScopedResource()
        
        let album = Album(name: name)
        let track = Track(name: name, album: album, credits: [], genre: genre, filename: source.lastPathComponent, artwork: artworkData)
        
        modelContext.insert(album)
        modelContext.insert(track)
        
        for (position, draft) in artists.enumerated() {
            let artistModel = findOrCreateArtist(named: draft.name)
            let credit = Credit(artist: artistModel, role: .main, position: position, track: track)
            
            track.credits.append(credit)
            
            modelContext.insert(credit)
        }
        
        dismiss()
    }
    
    private func findOrCreateArtist(named name: String) -> Artist {
        let descriptor = FetchDescriptor<Artist>(
            predicate: #Predicate { $0.name == name }
        )
        if let existing = try? modelContext.fetch(descriptor).first {
            return existing
        }
        let newArtist = Artist(name: name, credits: [])
        modelContext.insert(newArtist)
        return newArtist
    }
    
}

/// Раскладывает капсулы в строку, перенося на следующую, когда не влезают по ширине.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalWidth: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth, currentX > 0 {
                currentX = 0
                currentY += rowHeight + spacing
                rowHeight = 0
            }
            currentX += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            totalWidth = max(totalWidth, currentX - spacing)
        }
        return CGSize(width: totalWidth, height: currentY + rowHeight)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        var currentX = bounds.minX
        var currentY = bounds.minY
        var rowHeight: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > bounds.maxX, currentX > bounds.minX {
                currentX = bounds.minX
                currentY += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: currentX, y: currentY), anchor: .topLeading, proposal: ProposedViewSize(size))
            currentX += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

extension URL {
    func parseMusic() -> (name: String, artist: String) {
        let base = deletingPathExtension().lastPathComponent
            .replacingOccurrences(of: "_", with: " ")
        
        if let range = base.range(of: " — ")        // длинное тире
            ?? base.range(of: " – ")         // среднее тире (en-dash) ← добавили
            ?? base.range(of: " - ") {
            let artist = String(base[..<range.lowerBound])
            let title = String(base[range.upperBound...])
            return (name: title, artist: artist)
        } else {
            return (name: base, artist: "unknown")
        }
    }
}

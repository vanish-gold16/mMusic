import PhotosUI
import SwiftUI
import SwiftData

struct SettingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var showImagePicker = false
    
    @State private var name = ""
    @State private var artists: [ArtistDraft] = []
    @State private var genre: Genre = .pop
    @State private var artworkData: Data?
    @State private var release = Date()
    @State private var hasReleaseOn = false
    
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
                    ArtistsEditor(artists: $artists)
                }
                Section {
                    Picker("genre", selection: $genre) {
                        ForEach(Genre.allCases, id: \.self) { genre in
                            Text(genre.rawValue).tag(genre)
                        }
                    }
                }
                Section("release") {
                    Toggle("has release date", isOn: $hasReleaseOn)
                    DatePicker("release date", selection: $release, displayedComponents: .date)
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
        let names = parsed.artist
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let drafts = names.isEmpty ? [ArtistDraft(name: parsed.artist)] : names.map { ArtistDraft(name: $0) }
        _artists = State(initialValue: drafts)
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
        
        let album = Album(name: name, release: release, artwork: artworkData)
        let track = Track(name: name, album: album, credits: [], genre: genre, filename: source.lastPathComponent)
        
        modelContext.insert(album)
        modelContext.insert(track)
        
        for (position, draft) in artists.enumerated() {
            let artistModel = modelContext.findOrCreateArtist(named: draft.name)
            let credit = Credit(artist: artistModel, role: draft.role, position: position, album: album)
            
            modelContext.insert(credit)
        }
        
        dismiss()
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

extension ModelContext {
    func findOrCreateArtist(named name: String) -> Artist {
        let descriptor = FetchDescriptor<Artist>(predicate: #Predicate { $0.name == name })
        if let existing = try? fetch(descriptor).first { return existing }
        let new = Artist(name: name, credits: [])
        insert(new)
        return new
    }
}

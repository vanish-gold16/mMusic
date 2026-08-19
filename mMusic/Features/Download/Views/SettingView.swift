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
    @State private var importError: String?
    
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
                    if hasReleaseOn {
                        DatePicker("release date", selection: $release, displayedComponents: .date)
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
            .alert(
                "Import failed",
                isPresented: Binding(
                    get: { importError != nil },
                    set: { if !$0 { importError = nil } }
                ),
                presenting: importError
            ) { _ in
                Button("OK", role: .cancel) { }
            } message: { message in
                Text(message)
            }
        }
    }

    init(file: PickedFile) {
        self.file = file
        _name = State(initialValue: file.url.parseMusic().name)
        let names = file.url.parsedArtistNames()
        let drafts = names.isEmpty ? [ArtistDraft(name: "unknown")] : names.map { ArtistDraft(name: $0) }
        _artists = State(initialValue: drafts)
    }
    
    private func save() {
        // Файл кладём первым: если копирование сорвётся, в базе не останется трека,
        // ссылающегося в пустоту — раньше ошибка просто печаталась в консоль.
        let filename: String
        do {
            filename = try AudioFileStore.importFile(from: file.url)
        } catch {
            importError = error.localizedDescription
            return
        }

        let album = Album(name: name, type: .single, release: hasReleaseOn ? release : nil, artwork: artworkData)
        let track = Track(name: name, album: album, credits: [], genre: genre, filename: filename)

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

import PhotosUI
import SwiftUI
import SwiftData

struct SettingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var showImagePicker = false
    
    @State private var name = ""
    @State private var artists: [ArtistDraft] = []
    @State private var newArtistName = ""
    @State private var genre: Genre = .pop
    @State private var artworkData: Data?
    
    let file: PickedFile
    
    var body: some View {
        
        NavigationStack {
            
            VStack {
                
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
                    }
                    .buttonStyle(.glassProminent)
                    .sheet(isPresented: $showImagePicker) {
                        ImagePicker(imageData: $artworkData)
                    }
                    
                }
                
                Form {
                    
                    Section("name") {
                        TextField("", text: $name)
                    }
                    
                    Section("artist") {
                        ForEach(artists) { draft in
                            HStack {
                                Image(systemName: "person.fill")
                                Text(draft.name)
                                Button(role: .destructive) {
                                    artists.removeAll { $0.id == draft.id }
                                } label: {
                                    Image(systemName: "xmark")
                                }
                                .buttonStyle(.borderless)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.gray.opacity(0.2), in: Capsule())
                            Button {
                                
                            } label: {
                                Image(systemName: "plus")
                            }
                            TextField("", text: $newArtistName)
                        }
                        
                        Section {
                            Picker("genre", selection: $genre) {
                                ForEach(Genre.allCases, id: \.self) { genre in
                                    Text(genre.rawValue).tag(genre)
                                }
                            }
                        }
                    }
                    .padding(.top)
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
                let artistModel = Artist(name: draft.name, credits: [])
                let credit = Credit(artist: artistModel, role: .main, position: position, track: track)

                track.credits.append(credit)

                modelContext.insert(artistModel)
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

import PhotosUI
import SwiftUI
import SwiftData

struct SettingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var name = ""
    @State private var artist = ""
    @State private var genre: Genre = .pop
    @State private var showImagePicker = false
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
                        TextField("", text: $artist)
                    }
                    
                    Section {
                        Picker("Genre", selection: $genre) {
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
                        
                    }
                }
            }
        }
    }
    
    init(file: PickedFile) {
        self.file = file
        let track = file.url.parseMusic()
        _name = State(initialValue: track.name)
        _artist = State(initialValue: track.artist)
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
        
        let track = Track(name: name, artist: artist, genre: genre, filename: source.lastPathComponent)
        modelContext.insert(track)
        
        dismiss()
    }
    
}

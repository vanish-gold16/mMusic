import SwiftUI
import PhotosUI

struct SettingView: View {
    @State private var name = ""
    @State private var artist = ""
    @State private var genre: Genre = .pop
    @State private var showImagePicker = false
    @State private var artworkData: Data?
    
    let file: PickedFile
    
    var body: some View {
        Spacer()
        
        Form {
            
            Section("cover") {
                
                Button {
                    showImagePicker = true
                } label: {
                    Label("", systemImage: "photo")
                }
                .sheet(isPresented: $showImagePicker) {
                    ImagePicker(imageData: $artworkData)
                }
                
                if let artworkData, let uiImage = UIImage(data: artworkData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 150)
                }
            }
            
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
    
    init(file: PickedFile) {
        self.file = file
        let track = file.url.parseMusic()
        _name = State(initialValue: track.name)
        _artist = State(initialValue: track.artist)
    }
    
}

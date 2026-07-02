import SwiftUI
import SwiftData

struct CreatePlaylistView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var showImagePicker = false

    @State private var name = ""
    @State private var description = ""
    @State private var artworkData: Data?

    var body: some View {
        NavigationStack {
            VStack {
                VStack {
                    if let artworkData, let uiImage = UIImage(data: artworkData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 150)
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.2))
                            .overlay {
                                Image(systemName: "music.note")
                            }
                            .scaledToFit()
                            .frame(maxWidth: 150)
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
                .padding(.top)
                
                Form {
                    Section("name") {
                        TextField("", text: $name)
                    }
                    
                    Section("desctiption") {
                        TextField("", text: $description)
                    }
                }
            }
        }
    }

    private func create() {
        
    }
}

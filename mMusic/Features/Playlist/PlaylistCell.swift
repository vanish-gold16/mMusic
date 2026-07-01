import SwiftUI

struct PlaylistCell: View {
    
    @Binding var playlist: Playlist
    
    @State private var isCreating = false
    
    var body: some View {
        VStack {
            Capsule()
                .fill(Color.gray.opacity(0.2))
                .aspectRatio(contentMode: .fit)
                .overlay {
                    HStack {
                        if let data = playlist.artwork, let uiImage = UIImage(data: data) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                        }
                        else {
                            Image(systemName: "music.note")
                        }
                        
                        Divider()
                        
                        Text(playlist.name)
                    }
                }
                .onTapGesture {
                    
                }
        }
    }
    
}

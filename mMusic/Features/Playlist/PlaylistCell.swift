import SwiftUI

struct PlaylistCell: View {
    
    let playlist: Playlist
    
    @State private var isCreating = false
    
    var body: some View {
        Divider()
        
        HStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.2))
                .overlay {
                    if let data = playlist.artwork, let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                    } else {
                        Image(systemName: "music.note")
                    }
                }
                .frame(width: 60, height: 60)
            Text(playlist.name)
                .bold()
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
        }
        .contextMenu {
            
        }
        .foregroundStyle(.primary)
    }
    
}

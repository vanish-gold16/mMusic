import SwiftUI

/// Кружок артиста: фотография, если её поставили, и микрофон, если нет.
/// Один вид на все экраны — иначе артист выглядит по-разному в списке,
/// на своей странице и в капсуле под обложкой.
struct ArtistAvatar: View {

    let artist: Artist
    var size: CGFloat = 70

    var body: some View {
        Circle()
            .fill(Color.gray.opacity(0.2))
            .frame(width: size, height: size)
            .overlay {
                if let data = artist.artwork, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "music.mic")
                        .resizable()
                        .scaledToFit()
                        // Символ занимает не весь кружок: ему нужны поля,
                        // иначе микрофон упирается в края.
                        .frame(width: size * 0.4, height: size * 0.4)
                        .foregroundStyle(.secondary)
                }
            }
            .clipShape(Circle())
    }
}

import SwiftUI
import UIKit

/// Обложка релиза из каталога — картинка по адресу, а не из базы: релиза
/// в библиотеке ещё нет. Пока качается — серый квадрат с диском.
struct RemoteCover: View {

    let url: URL?
    /// Сторона миниатюры в пикселях: на полке хватает трёхсот, в карточке
    /// релиза нужна крупная.
    var pixels: CGFloat = 360
    var cornerRadius: CGFloat = 4
    /// Круглая — фотография артиста, а не обложка.
    var isCircle = false

    @State private var image: UIImage?

    var body: some View {
        Rectangle()
            .fill(Color(.systemGray5))
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: isCircle ? "person.fill" : "opticaldisc")
                        .font(.title2)
                        .foregroundStyle(.tertiary)
                }
            }
            .clipShape(isCircle ? AnyShape(Circle()) : AnyShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)))
            .task(id: url) {
                image = await RemoteImages.image(at: url, pixels: pixels)
            }
    }
}

/// Скачанные обложки. Держатся в памяти, пока приложение живо, а с диска
/// их отдаёт кэш URLSession: полка на главной не качает их на каждом заходе.
enum RemoteImages {

    private static let cache = NSCache<NSString, UIImage>()

    static func image(at url: URL?, pixels: CGFloat) async -> UIImage? {
        guard let url else { return nil }

        let key = "\(url.absoluteString)#\(Int(pixels))" as NSString
        if let cached = cache.object(forKey: key) { return cached }

        guard let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }

        // Декодирование картинки — не для главного потока: на полке их с десяток.
        let image = await Task.detached(priority: .utility) {
            UIImage.thumbnail(from: data, side: pixels)
        }.value

        if let image { cache.setObject(image, forKey: key) }
        return image
    }

    /// Цвета обложки — для фона карточки релиза.
    static func palette(at url: URL?) async -> CoverPalette? {
        guard let image = await image(at: url, pixels: 200) else { return nil }
        return await Task.detached(priority: .utility) { image.coverPalette }.value
    }
}

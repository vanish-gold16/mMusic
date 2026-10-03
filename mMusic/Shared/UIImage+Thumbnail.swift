import UIKit

extension UIImage {

    /// Уменьшенная копия, у которой короткая сторона не больше `side` пикселей.
    /// Пропорции сохраняются: квадрат вырезает уже тот, кто рисует.
    ///
    /// `nonisolated`: вызывается из фоновой задачи — полноразмерная обложка весит
    /// мегабайты, и декодировать её на главном потоке значит подвешивать переходы.
    nonisolated static func thumbnail(from data: Data, side: CGFloat) -> UIImage? {
        guard let image = UIImage(data: data) else { return nil }

        let scale = min(side / min(image.size.width, image.size.height), 1)
        return image.preparingThumbnail(of: CGSize(
            width: image.size.width * scale,
            height: image.size.height * scale
        ))
    }
}

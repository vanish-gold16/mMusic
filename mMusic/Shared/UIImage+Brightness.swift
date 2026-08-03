import CoreImage.CIFilterBuiltins
import UIKit

extension UIImage {
    /// Средняя яркость картинки: 0 — чёрная, 1 — белая.
    ///
    /// Считается один раз на обложку, результат кладётся в `@State`.
    /// Вызывать из `body` нельзя: там свойство пересчитывалось бы на каждой перерисовке.
    ///
    /// `nonisolated` — в проекте всё по умолчанию на главном потоке, а это свойство
    /// не трогает интерфейс и должно вызываться из фоновой задачи.
    nonisolated var averageBrightness: Double? {
        guard let cgImage else { return nil }   // свойство самой картинки, self опускается

        let input = CIImage(cgImage: cgImage)

        // Фильтр схлопывает всю картинку в один пиксель — это и есть средний цвет.
        let filter = CIFilter.areaAverage()
        filter.inputImage = input
        filter.extent = input.extent
        guard let output = filter.outputImage else { return nil }

        // Забираем из картинки 1×1 четыре байта: R, G, B, A.
        var pixel = [UInt8](repeating: 0, count: 4)
        Self.brightnessContext.render(
            output,
            toBitmap: &pixel,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )

        let r = Double(pixel[0]) / 255
        let g = Double(pixel[1]) / 255
        let b = Double(pixel[2]) / 255

        // Веса неравные: глаз сильнее всего реагирует на зелёный, слабее всего на синий.
        return 0.299 * r + 0.587 * g + 0.114 * b
    }

    /// Создание `CIContext` стоит дороже самого усреднения, поэтому он один на всё приложение.
    nonisolated private static let brightnessContext = CIContext()
}

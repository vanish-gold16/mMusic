import CoreImage.CIFilterBuiltins
import UIKit

extension UIImage {
    /// Средняя яркость картинки: 0 — чёрная, 1 — белая.
    var averageBrightness: Double? {
        guard let cgImage else { return nil }   // свойство самой картинки, self опускается

        let input = CIImage(cgImage: cgImage)
        
        
    }
}

import AVKit
import SwiftUI

/// Кнопка выбора устройства вывода — наушники, колонка, AirPlay.
/// Системная: список устройств приложению рисовать не разрешено.
struct RoutePickerButton: UIViewRepresentable {

    var tint: UIColor
    var activeTint: UIColor

    func makeUIView(context: Context) -> AVRoutePickerView {
        let view = AVRoutePickerView(frame: .zero)
        view.prioritizesVideoDevices = false

        return view
    }

    func updateUIView(_ view: AVRoutePickerView, context: Context) {
        view.tintColor = tint
        view.activeTintColor = activeTint
    }
}

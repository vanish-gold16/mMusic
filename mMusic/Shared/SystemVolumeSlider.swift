import MediaPlayer
import SwiftUI

/// Системный слайдер громкости.
///
/// Своего сделать нельзя: `AVAudioSession.outputVolume` доступна только на чтение,
/// а менять громкость приложению разрешено единственным способом — через `MPVolumeView`.
/// Поэтому берём его и прячем всё лишнее, оставляя одну дорожку.
struct SystemVolumeSlider: UIViewRepresentable {

    var tint: UIColor

    func makeUIView(context: Context) -> MPVolumeView {
        let view = MPVolumeView(frame: .zero)
        // Кнопка AirPlay здесь не нужна — она стоит отдельно, своя.
        view.showsRouteButton = false
        view.setVolumeThumbImage(UIImage(), for: .normal)

        return view
    }

    func updateUIView(_ view: MPVolumeView, context: Context) {
        view.tintColor = tint
    }
}

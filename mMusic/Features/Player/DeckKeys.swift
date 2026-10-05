import SwiftUI

/// Клавиши деки: назад, пуск, вперёд и два режима по краям.
///
/// Как на магнитофоне: клавиша включённого режима «залипает» — над ней горит лампа.
/// Так состояние видно издали, не разглядывая оттенок значка: играет ли трек,
/// перемешана ли очередь, повторяется ли она. У «назад» и «вперёд» лампы нет —
/// они ничего не включают, а только нажимаются.
struct DeckKeys: View {

    let audioPlayer: AudioPlayer

    var body: some View {
        let accent = audioPlayer.accent

        // Клавиши стоят тесно, но не сливаются: зазор чуть больше дистанции,
        // на которой стекло соседей перетекает друг в друга.
        GlassEffectContainer(spacing: 4) {
            HStack(spacing: 6) {
                DeckKey(
                    systemImage: "shuffle",
                    title: "Shuffle",
                    lamp: audioPlayer.isShuffled,
                    accent: accent
                ) {
                    audioPlayer.toggleShuffle()
                }
                .frame(width: 50)

                DeckKey(systemImage: "backward.fill", title: "Previous", accent: accent) {
                    audioPlayer.playPrevious()
                }
                .frame(width: 66)

                DeckKey(
                    systemImage: audioPlayer.isPlaying ? "pause.fill" : "play.fill",
                    title: audioPlayer.isPlaying ? "Pause" : "Play",
                    lamp: audioPlayer.isPlaying,
                    isMain: true,
                    accent: accent
                ) {
                    audioPlayer.togglePlayPause()
                }

                DeckKey(systemImage: "forward.fill", title: "Next", accent: accent) {
                    audioPlayer.playNext()
                }
                .frame(width: 66)

                DeckKey(
                    systemImage: audioPlayer.repeatMode.systemImage,
                    title: audioPlayer.repeatMode.title,
                    lamp: audioPlayer.repeatMode.isActive,
                    accent: accent
                ) {
                    audioPlayer.cycleRepeatMode()
                }
                .frame(width: 50)
            }
        }
        .frame(height: 62)
    }
}

/// Одна клавиша. `lamp == nil` — у клавиши нет лампы: она ничего не включает.
struct DeckKey: View {

    let systemImage: String
    /// Имя для голосового доступа — значок сам по себе не читается.
    let title: String
    var lamp: Bool? = nil
    /// Главная клавиша — «пуск»: шире остальных и подкрашена цветом обложки.
    var isMain = false
    let accent: Color
    let action: () -> Void

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
    }

    private var isLit: Bool { lamp ?? false }

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(isMain ? .title2 : .body.weight(.semibold))
                .contentTransition(.symbolEffect(.replace))
                .foregroundStyle(isLit && !isMain ? AnyShapeStyle(accent) : AnyShapeStyle(.primary))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(alignment: .top) {
                    if let lamp {
                        DeckLamp(isOn: lamp, accent: accent)
                            .padding(.top, 9)
                    }
                }
                .contentShape(shape)
        }
        .buttonStyle(DeckKeyStyle())
        .glassEffect(glass, in: shape)
        .accessibilityLabel(title)
        .accessibilityValue(lamp.map { $0 ? "on" : "off" } ?? "")
    }

    private var glass: Glass {
        if isMain {
            return .regular.tint(accent.opacity(isLit ? 0.5 : 0.3)).interactive()
        }
        return isLit ? .regular.tint(accent.opacity(0.22)).interactive() : .regular.interactive()
    }
}

/// Лампа над клавишей: горит — режим включён. Светится цветом обложки,
/// погасшая — едва заметная чёрточка, чтобы было видно, что лампа здесь есть.
struct DeckLamp: View {

    let isOn: Bool
    let accent: Color

    var body: some View {
        Capsule()
            .fill(isOn ? AnyShapeStyle(accent) : AnyShapeStyle(Color.primary.opacity(0.2)))
            .frame(width: 12, height: 3)
            .shadow(color: isOn ? accent.opacity(0.9) : .clear, radius: 4)
            .animation(.easeOut(duration: 0.2), value: isOn)
            .accessibilityHidden(true)
    }
}

/// Клавиша проседает под пальцем, как механическая. Значок не исчезает, как у
/// кнопок с `PressableButtonStyle`: клавиша — это вещь, а не картинка.
private struct DeckKeyStyle: ButtonStyle {

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .offset(y: configuration.isPressed ? 1.5 : 0)
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.spring(duration: 0.2, bounce: 0.4), value: configuration.isPressed)
    }
}

/// Кнопка панели под клавишами: слово вместо значка, лампа вместо подсветки —
/// как подписи на передней панели усилителя.
struct PanelSwitch: View {

    let title: String
    /// nil — у кнопки нет лампы: она открывает, а не включает.
    var isOn: Bool? = nil
    let accent: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            PanelSwitchLabel(title: title, isOn: isOn, accent: accent)
        }
        .buttonStyle(.plain)
        .accessibilityValue(isOn.map { $0 ? "on" : "off" } ?? "")
    }
}

struct PanelSwitchLabel: View {

    let title: String
    var isOn: Bool? = nil
    let accent: Color

    var body: some View {
        HStack(spacing: 6) {
            if let isOn {
                Circle()
                    .fill(isOn ? AnyShapeStyle(accent) : AnyShapeStyle(Color.primary.opacity(0.22)))
                    .frame(width: 5, height: 5)
                    .shadow(color: isOn ? accent.opacity(0.9) : .clear, radius: 3)
            }

            Text(title.uppercased())
                .font(.caption2)
                .fontWeight(.semibold)
                .tracking(1.2)
                .monospacedDigit()
                .lineLimit(1)
        }
        .foregroundStyle(isOn == true ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .animation(.easeOut(duration: 0.2), value: isOn)
    }
}

import SwiftUI

/// Пульт ремикса: скорость, тон, зал, глухость, бас и эхо играющего трека,
/// переключатели винила, 8D и радио и готовые режимы.
///
/// Всё происходит вживую — ручка двигает параметр звукового тракта тем же кадром,
/// звук не прерывается и никакого второго файла не появляется. Положения ручек
/// остаются у трека, поэтому завтра он заиграет так же.
struct RemixView: View {

    let audioPlayer: AudioPlayer

    @Environment(\.dismiss) private var dismiss

    /// Палец на ручке. Пока он там, лист не даёт себя утащить вниз — иначе
    /// движение по ручке закрывало бы панель.
    @State private var isAdjusting = false
    /// Высота содержимого — под неё подгоняется лист.
    @State private var contentHeight: CGFloat = 560

    private var remix: RemixSettings { audioPlayer.currentRemix }
    private var accent: Color { audioPlayer.accent }

    var body: some View {
        VStack(spacing: 18) {
            header
            timeAndSpace
            colour
            switches
            presets
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 12)
        .fixedSize(horizontal: false, vertical: true)
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.height
        } action: { height in
            contentHeight = height
        }
        .frame(maxHeight: .infinity, alignment: .top)
        // Ровно под содержимое: пустая половина листа выглядела бы недоделкой,
        // а режимов стало столько, что заранее посчитанная высота не годится.
        .presentationDetents([.height(contentHeight)])
        .presentationDragIndicator(.visible)
        // Тот же стеклянный лист, что у очереди: сквозь него виден цвет плеера.
        .presentationBackground(.regularMaterial)
        .interactiveDismissDisabled(isAdjusting)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Remix")
                    .font(.title3.bold())

                Text(audioPlayer.currentTrack?.name ?? "")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            SheetActionButton(.close) { dismiss() }
        }
    }

    /// Первый ряд — то, с чего ремикс начинался: время, высота, зал.
    private var timeAndSpace: some View {
        HStack(spacing: 24) {
            knob("Speed", \.speed, range: RemixSettings.speedRange, neutral: 1) {
                String(format: "%.2f×", $0)
            }

            KnobView(
                title: remix.isVinyl ? "Pitch • vinyl" : "Pitch",
                // При связке ручка показывает то, что реально звучит, и двигать
                // её нечем — значение приходит от скорости, а не от пальца.
                value: remix.isVinyl ? .constant(remix.effectivePitch) : binding(\.pitch),
                range: RemixSettings.pitchRange,
                neutral: 0,
                accent: accent,
                caption: { _ in semitones(remix.effectivePitch) },
                isEnabled: !remix.isVinyl,
                onAdjustingChange: { isAdjusting = $0 }
            )

            knob("Reverb", \.reverb, range: RemixSettings.reverbRange, neutral: 0) {
                "\(Int($0))%"
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// Второй ряд — окраска: глухость, бас, эхо.
    private var colour: some View {
        HStack(spacing: 24) {
            knob("Muffle", \.muffle, range: RemixSettings.muffleRange, neutral: 0) {
                "\(Int($0))%"
            }

            knob("Bass", \.bass, range: RemixSettings.bassRange, neutral: 0) {
                decibels($0)
            }

            knob("Echo", \.echo, range: RemixSettings.echoRange, neutral: 0) {
                "\(Int($0))%"
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// Переключатели — как кнопки на панели плеера: слово и лампа.
    private var switches: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                // Связка тона со скоростью — то, чем ремикс отличается от растянутой
                // записи: у пластинки на других оборотах голос тоже уезжает.
                toggle("Vinyl", \.isVinyl)
                toggle("8D", \.isOrbiting)
                toggle("Radio", \.isRadio)
            }

            Text("Vinyl ties the pitch to the speed. 8D circles your head — use headphones.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    /// Все режимы на виду, строками, а не лентой с прокруткой вбок: за краем
    /// экрана их никто не находил бы.
    private var presets: some View {
        FlowLayout(spacing: 8) {
            ForEach(RemixSettings.presets) { preset in
                Button {
                    apply(preset)
                } label: {
                    Text(preset.name)
                        .font(.footnote.weight(.medium))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                .background(
                    remix.sounds(like: preset.settings)
                        ? accent.opacity(0.3)
                        : Color.primary.opacity(0.08),
                    in: Capsule()
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Детали

    private func knob(
        _ title: String,
        _ keyPath: WritableKeyPath<RemixSettings, Double>,
        range: ClosedRange<Double>,
        neutral: Double,
        caption: @escaping (Double) -> String
    ) -> some View {
        KnobView(
            title: title,
            value: binding(keyPath),
            range: range,
            neutral: neutral,
            accent: accent,
            caption: caption,
            onAdjustingChange: { isAdjusting = $0 }
        )
    }

    private func toggle(_ title: String, _ keyPath: WritableKeyPath<RemixSettings, Bool>) -> some View {
        let isOn = remix[keyPath: keyPath]

        return Button {
            withAnimation(.snappy) {
                binding(keyPath).wrappedValue.toggle()
            }
        } label: {
            PanelSwitchLabel(title: title, isOn: isOn, accent: accent)
                .padding(.horizontal, 16)
        }
        .buttonStyle(.plain)
        .glassEffect(isOn ? .regular.tint(accent.opacity(0.22)).interactive() : .regular.interactive(), in: .capsule)
        .accessibilityValue(isOn ? "on" : "off")
    }

    /// Ручка привязана прямо к треку: сеттер уходит в звук, а не в @State,
    /// поэтому изменение слышно, пока палец ещё на экране.
    private func binding<Value>(_ keyPath: WritableKeyPath<RemixSettings, Value>) -> Binding<Value> {
        Binding(
            get: { audioPlayer.currentRemix[keyPath: keyPath] },
            set: { newValue in
                var settings = audioPlayer.currentRemix
                settings[keyPath: keyPath] = newValue
                audioPlayer.updateRemix(settings)
            }
        )
    }

    /// «Original» — это не набор нулей, а отсутствие ремикса: трек забывает
    /// про ручки и снова слушается общей скорости из настроек.
    private func apply(_ preset: RemixSettings.Preset) {
        withAnimation(.snappy) {
            if preset.settings.isNeutral {
                audioPlayer.resetRemix()
            } else {
                audioPlayer.updateRemix(preset.settings)
            }
        }
    }

    /// «+3 st», «−2.5 st», «0 st» — со знаком, потому что важно направление.
    private func semitones(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        guard abs(rounded) >= 0.05 else { return "0 st" }

        let sign = rounded > 0 ? "+" : "−"
        return String(format: "%@%.1f st", sign, abs(rounded))
    }

    /// «+6 dB», «−3 dB», «0 dB» — бас тоже со знаком: его можно и убрать.
    private func decibels(_ value: Double) -> String {
        let rounded = Int(value.rounded())
        guard rounded != 0 else { return "0 dB" }

        return "\(rounded > 0 ? "+" : "−")\(abs(rounded)) dB"
    }
}

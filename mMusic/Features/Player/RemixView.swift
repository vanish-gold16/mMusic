import SwiftUI

/// Пульт ремикса: скорость, тон и эхо играющего трека.
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

    private var remix: RemixSettings { audioPlayer.currentRemix }

    var body: some View {
        VStack(spacing: 18) {
            header
            knobs
            vinyl
            presets
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .frame(maxHeight: .infinity, alignment: .top)
        // Ровно под содержимое: пустая половина листа выглядела бы недоделкой.
        .presentationDetents([.height(330)])
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

            Button("Done") { dismiss() }
                .font(.subheadline.weight(.semibold))
        }
    }

    private var knobs: some View {
        HStack(spacing: 24) {
            KnobView(
                title: "Speed",
                value: binding(\.speed),
                range: RemixSettings.speedRange,
                neutral: 1,
                accent: audioPlayer.accent,
                caption: { String(format: "%.2f×", $0) },
                onAdjustingChange: { isAdjusting = $0 }
            )

            KnobView(
                title: remix.isVinyl ? "Pitch • vinyl" : "Pitch",
                // При связке ручка показывает то, что реально звучит, и двигать
                // её нечем — значение приходит от скорости, а не от пальца.
                value: remix.isVinyl ? .constant(remix.effectivePitch) : binding(\.pitch),
                range: RemixSettings.pitchRange,
                neutral: 0,
                accent: audioPlayer.accent,
                // Показывается то, что реально звучит: при связке тон считается
                // от скорости, и ручка стоит там же.
                caption: { _ in semitones(remix.effectivePitch) },
                // При связке тон ведёт скорость — двигать его отдельно нечем.
                isEnabled: !remix.isVinyl,
                onAdjustingChange: { isAdjusting = $0 }
            )

            KnobView(
                title: "Reverb",
                value: binding(\.reverb),
                range: RemixSettings.reverbRange,
                neutral: 0,
                accent: audioPlayer.accent,
                caption: { "\(Int($0))%" },
                onAdjustingChange: { isAdjusting = $0 }
            )
        }
        .frame(maxWidth: .infinity)
    }

    /// Связка тона со скоростью — то, чем ремикс отличается от растянутой записи:
    /// у пластинки на других оборотах голос тоже уезжает.
    private var vinyl: some View {
        Toggle(isOn: binding(\.isVinyl)) {
            VStack(alignment: .leading, spacing: 1) {
                Text("Vinyl")
                    .font(.subheadline.weight(.medium))
                Text("Pitch follows the speed, like a record played faster")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .tint(audioPlayer.accent)
    }

    private var presets: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
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
                            ? audioPlayer.accent.opacity(0.3)
                            : Color.primary.opacity(0.08),
                        in: Capsule()
                    )
                }
            }
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
        // Лента доезжает до края экрана, а не упирается в поля панели: так видно,
        // что справа есть ещё.
        .padding(.horizontal, -20)
        .contentMargins(.horizontal, 20, for: .scrollContent)
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
}

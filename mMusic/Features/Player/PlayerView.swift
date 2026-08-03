import SwiftUI

struct PlayerView: View {
    let audioPlayer: AudioPlayer
    
    @State private var sliderValue: TimeInterval = 0
    @State private var isScrubbing = false
    
    /// Сглаженная громкость для фона: тянется за `audioPlayer.level`, но лениво,
    /// иначе фон мигал бы на каждой ноте.
    @State private var glow: Double = 0
    @State private var artworkWidth: CGFloat = 0
    
    /// Ползучие границы громкости этого трека — подстраиваются сами,
    /// чтобы фон одинаково хорошо дышал и на тихой записи, и на громкой.
    @State private var quiet: Double = 0
    @State private var loud: Double = 1
    @State private var isRangeCalibrated = false
    
    var body: some View {
        VStack(spacing: 32) {
            RoundedRectangle(cornerRadius: 16)
                .fill(.quaternary)
                .overlay {
                    if let data = audioPlayer.currentTrack?.displayArtwork,
                       let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Image(systemName: "music.note")
                            .font(.system(size: 64))
                            .foregroundStyle(.secondary)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .aspectRatio(1, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.size.width
                } action: { newWidth in
                    artworkWidth = newWidth
                }
                .contentShape(Rectangle())
                .onTapGesture(count: 2) { location in
                    if location.x < artworkWidth {
                        audioPlayer.playPrevious()
                    } else {
                        audioPlayer.playNext()
                    }
                }
                .onTapGesture {
                    audioPlayer.togglePlayPause()
                }
                .gesture(
                    DragGesture(minimumDistance: 30)
                        .onEnded { value in
                            let dx = value.translation.width
                            let yx = value.translation.height
                            
                            guard abs(dx) > abs(yx) else { return }
                            
                            if dx < 0 {
                                audioPlayer.playNext()
                            } else {
                                audioPlayer.playPrevious()
                            }
                        }
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(audioPlayer.currentTrack?.name ?? "")
                    .font(.title2)
                    .bold()
                    .lineLimit(1)
                Text(audioPlayer.currentTrack?.artistNames.joined(separator: ", ") ?? "")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 16) {
                
                VStack(spacing: 4) {
                    Slider(
                        value: $sliderValue,
                        in: 0...max(audioPlayer.duration, 0.01)
                    ) { editing in
                        isScrubbing = editing
                        if !editing {
                            audioPlayer.seek(to: sliderValue)
                        }
                    }
                    .tint(.orange)
                    
                    HStack {
                        Text(timeString(sliderValue))
                        Spacer()
                        Text("-" + timeString(audioPlayer.duration - sliderValue))
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 32)
        .presentationDragIndicator(.visible)
        .presentationBackground { artworkBackground }
        .onAppear { sliderValue = audioPlayer.currentTime }
        .onChange(of: audioPlayer.level) { _, newLevel in
            // Вспышка мгновенная, гаснет плавно — так удары читаются как удары.
            if newLevel > glow {
                glow = newLevel
            } else {
                glow += (newLevel - glow) * 0.06
            }
            
            // Первый замер нового трека задаёт коридор вокруг его реальной громкости.
            // Без этого стартовые 0...1 несколько секунд врут в сторону максимума.
            guard isRangeCalibrated else {
                quiet = max(glow - 0.15, 0)
                loud = min(glow + 0.15, 1)
                isRangeCalibrated = true
                return
            }
            
            // Дальше границы мгновенно раздвигаются наружу и медленно сползают внутрь.
            loud = max(glow, loud + (glow - loud) * 0.004)
            quiet = min(glow, quiet + (glow - quiet) * 0.004)
        }
        .onChange(of: audioPlayer.currentTime) { _, newValue in
            guard !isScrubbing else { return }
            sliderValue = newValue
        }
        .onChange(of: audioPlayer.currentIndex) { _, _ in
            isScrubbing = false
            sliderValue = audioPlayer.currentTime
            
            // У нового трека своя громкость — калибруемся заново.
            isRangeCalibrated = false
        }
    }
    
    /// Где `glow` находится между тихим и громким местом этого трека, 0...1.
    /// `span` не даёт делить на почти-ноль: на ровном месте фон должен замереть,
    /// а не раздувать микроскопические колебания до полного размаха.
    private var punch: Double {
        let span = max(loud - quiet, 0.12)
        return min(max((glow - quiet) / span, 0), 1)
    }
    
    @ViewBuilder
    private var artworkBackground: some View {
        if let data = audioPlayer.currentTrack?.displayArtwork,
           let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .blur(radius: 60)                  // константа — пересчитывается один раз
                .scaleEffect(1.25 + punch * 0.45)  // на громком фон наплывает
                .clipped()
                .saturation(0.9 + punch * 1.6)     // и вспыхивает цветом
                .brightness(punch * 0.12)
                .hueRotation(.degrees(punch * 18)) // оттенок ведёт — фон «переливается»
                .overlay {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .opacity(0.9 - punch * 0.7) // вуаль тончает, обложка проступает
                }
        } else {
            Color.black
        }
    }
    
    private func timeString(_ time: TimeInterval) -> String {
        let total = Int(max(0, time.rounded()))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

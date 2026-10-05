import SwiftData
import SwiftUI

/// Пластинка артиста в шапке его страницы. На яблоке — его фотография,
/// а кольца — его пластинки, от первой снаружи к последней у яблока: как треки
/// на диске альбома, только в масштабе всей карьеры. Толщина кольца —
/// длительность: альбом лежит широкой дорожкой, сингл — тонкой.
///
/// Кольцо того, что играет сейчас, горит акцентом; нажатие на кольцо ставит
/// эту пластинку. Сам диск не крутится: лицо, бегущее по кругу со скоростью
/// 33 оборота в минуту, смотрелось бы аттракционом.
///
/// Фотографию ставят здесь же, нажатием на яблоко: своего экрана правки
/// у артиста нет, в отличие от трека и альбома.
struct ArtistRecord: View {

    @Environment(AudioPlayer.self) private var audioPlayer

    @Bindable var artist: Artist
    /// Пластинки в порядке колец, от первой к последней.
    let releases: [Album]
    /// Уменьшенная фотография; nil — фотографии нет.
    let photo: UIImage?
    let accent: Color
    let onTapRelease: (Album) -> Void

    @State private var showImagePicker = false

    /// Доля яблока в радиусе диска — крупнее, чем у пластинок: на нём лицо.
    private let labelFraction: CGFloat = 0.52

    var body: some View {
        // Играющая пластинка читается здесь: на смене трека перерисоваться
        // должен диск, а не вся страница.
        let playingAlbum = audioPlayer.currentTrack?.album?.persistentModelID
        let currentIndex = releases.firstIndex { $0.persistentModelID == playingAlbum }

        VinylRecord(
            cover: photo,
            durations: releases.map { $0.tracks.reduce(0) { $0 + $1.duration } },
            currentIndex: currentIndex,
            progress: nil,
            isSpinning: false,
            rpm: Album.AlbumType.LP.rpm,
            labelFraction: labelFraction,
            accent: accent,
            onTapTrack: releases.isEmpty ? nil : { index, _ in
                guard releases.indices.contains(index) else { return }
                onTapRelease(releases[index])
            },
            isUpright: true
        )
        .overlay {
            GeometryReader { proxy in
                let side = min(proxy.size.width, proxy.size.height) * labelFraction

                photoMenu(side: side)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(imageData: $artist.artwork)
        }
    }

    /// Яблоко — кнопка фотографии. Поверх диска, поэтому нажатие сюда
    /// не уходит в кольца.
    private func photoMenu(side: CGFloat) -> some View {
        Menu {
            Button {
                showImagePicker = true
            } label: {
                Label(artist.artwork == nil ? "Add photo" : "Change photo", systemImage: "photo")
            }

            if artist.artwork != nil {
                Button(role: .destructive) {
                    artist.artwork = nil
                } label: {
                    Label("Remove photo", systemImage: "trash")
                }
            }
        } label: {
            Circle()
                .fill(.clear)
                .frame(width: side, height: side)
                .overlay {
                    if photo == nil {
                        Image(systemName: "music.mic")
                            .font(.system(size: side * 0.3))
                            .foregroundStyle(Color(white: 0.6))
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "camera.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(7)
                        .background(.thinMaterial, in: Circle())
                        .offset(x: 6, y: 6)
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        // Иначе VoiceOver читает кнопку как «Artist, Camera» — по названиям
        // символов внутри неё.
        .accessibilityLabel("Artist photo")
    }
}

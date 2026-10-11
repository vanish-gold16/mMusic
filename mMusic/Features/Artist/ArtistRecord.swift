import SwiftData
import SwiftUI

/// Пластинка артиста в шапке его страницы (`ArtistDisc`) с кнопкой фотографии
/// на яблоке. Нажатие на кольцо ставит эту пластинку.
///
/// Фотографию ставят здесь же — нажатием на яблоко — или из меню «…»:
/// своего экрана правки у артиста нет, в отличие от трека и альбома.
struct ArtistRecord: View {

    @Bindable var artist: Artist
    /// Пластинки в порядке колец, от первой к последней.
    let releases: [Album]
    /// Уменьшенная фотография; nil — фотографии нет.
    let photo: UIImage?
    /// Цвет бумажного яблока, пока фотографии нет.
    let labelPaper: Color?
    let accent: Color
    let onTapRelease: (Album) -> Void

    @State private var showImagePicker = false

    var body: some View {
        ArtistDisc(
            name: artist.name,
            releases: releases,
            photo: photo,
            labelPaper: labelPaper,
            accent: accent,
            onTapRelease: releases.isEmpty ? nil : onTapRelease
        )
        .overlay {
            GeometryReader { proxy in
                let side = min(proxy.size.width, proxy.size.height) * ArtistDisc.labelFraction

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

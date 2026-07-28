import SwiftUI

struct AlbumView: View {
    
    @Environment(AudioPlayer.self) var audioPlayer
    
    var album: Album
    
    private var sortedTracks: [Track] {
        album.tracks.sorted {
            $0.position < $1.position
        }
    }

    @State private var backgroundArtwork: UIImage?

    var body: some View {
        ScrollView {
            VStack {
                HStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 175, height: 175)
                        .overlay {
                            if let data = album.artwork, let uiImage = UIImage(data: data) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFit()
                                    .cornerRadius(12)
                            } else {
                                Image(systemName: "music.note")
                            }
                        }
                    VStack {
                        Text(album.name)
                            .font(.title)
                            .bold()
                        Text(album.artistNames.joined(separator: ", "))
                            .font(.title2)
                            .foregroundStyle(.orange)
                        Text(album.genres.map(\.rawValue).joined(separator: ", "))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                
                HStack {
                    Button {
                        audioPlayer.play(sortedTracks)
                    } label: {
                        Capsule()
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .padding(.horizontal)
                            .overlay {
                                HStack {
                                    Image(systemName: "play.fill")
                                        .tint(.primary)
                                    Text("Play")
                                        .tint(.primary)
                                        .bold()
                                }
                            }
                    }
                    Button {
                        audioPlayer.play(sortedTracks.shuffled())
                    } label: {
                        Capsule()
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .padding(.horizontal)
                            .overlay {
                                HStack {
                                    Image(systemName: "shuffle")
                                        .tint(.primary)
                                    Text("Shuffle")
                                        .tint(.primary)
                                        .bold()
                                }
                            }
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                VStack {
                    let sortedTracks = album.tracks.sorted { $0.position < $1.position }
                    ForEach(sortedTracks) { track in
                        TrackCell(track: track, queue: sortedTracks)
                    }
                }

                Spacer()
                
                if let release = album.release {
                    Text(release.formatted(date: .abbreviated, time: .omitted))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                }
                
                Text(album.type.rawValue)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
            }
        }
        .background {
            artworkBackground
        }
        .task {
            backgroundArtwork = await Self.makeBackgroundArtwork(from: album.artwork)
        }
    }

    /// Заливка из цветов обложки. Миниатюра 12×12 растягивается на весь экран, поэтому
    /// от картинки остаются только цветовые пятна — деталей, дающих резкие светлые и тёмные
    /// половины, в ней уже нет. Все слои лежат в одном ZStack, чтобы под safe area
    /// не оставалось полос: `ignoresSafeArea` применяется сразу ко всей стопке.
    private var artworkBackground: some View {
        ZStack {
            Color(.systemBackground)

            if let backgroundArtwork {
                Image(uiImage: backgroundArtwork)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
                    .blur(radius: 40, opaque: true)
                    .saturation(0.45)
                    .opacity(0.7)
            }

            Rectangle()
                .fill(.ultraThinMaterial)
        }
        .ignoresSafeArea()
    }

    /// Уменьшение картинки — не самая дешёвая операция, поэтому уводим её с главного потока.
    private static func makeBackgroundArtwork(from data: Data?) async -> UIImage? {
        guard let data else { return nil }

        return await Task.detached(priority: .utility) {
            UIImage(data: data)?.preparingThumbnail(of: CGSize(width: 12, height: 12))
        }.value
    }
}

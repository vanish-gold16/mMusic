import SwiftUI

struct AlbumView: View {
    var album: Album

    var body: some View {
        ScrollView {
            VStack {
                HStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 175, height: 175)
                        .overlay {
                            if let data = album.artwork, let uiImage = UIImage(data: data) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFit()
                                    .cornerRadius(8)
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

                ForEach(album.tracks.sorted { $0.position < $1.position }) { track in
                    Divider()
                    TrackCell(track: track)
                }

                Divider()
                
                Spacer()
                
                if let release = album.release {
                    Text(release.formatted(date: .abbreviated, time: .omitted))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                }
            }
        }
    }
}

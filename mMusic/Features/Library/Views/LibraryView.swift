//
//  LibraryView.swift
//  mMusic
//
//  Created by Vanya on 22.06.2026.
//

import SwiftUI

struct LibraryView: View {
    let columns = [GridItem(.flexible(), alignment: .top), GridItem(.flexible(), alignment: .top)]

    @State private var trackStore = TrackStore()
    @State private var audioPlayer = AudioPlayer()

    @State private var selectedCategory: LibraryCategory = .playlists

    var body: some View {
        List {
            ForEach(LibraryCategory.allCases, id: \.self) { category in
                NavigationLink(destination: destinationView(for: category)) {
                    Label(category.rawValue, systemImage: category.icon)
                        .foregroundColor(.orange)
                        .font(.title2)
                }
                .animation(.easeOut, value: selectedCategory)
            }

            VStack(alignment: .leading) {
                Text("Recently added")
                    .font(.title)
                    .bold()
                    .frame(maxWidth: .infinity, alignment: .leading)
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(trackStore.tracks) { track in
                        VStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.2))
                                .aspectRatio(1, contentMode: .fit)
                                .overlay {
                                    Image(systemName: "music.note")
                                }
                            Text(track.name)
                                .lineLimit(1)
                            Text(track.artist)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .onTapGesture {
                            audioPlayer.play(track)
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .onAppear{
            trackStore.load()
        }
        .safeAreaInset(edge: .bottom) {
            MiniPlayerView(audioPlayer: audioPlayer)
        }
        .navigationTitle("Library")
    }
    
    @ViewBuilder
    func destinationView (for category: LibraryCategory) -> some View {
        switch category {
        case .playlists: PlaylistsView()
        case .songs: SongsView()
        case .albums: AlbumsView()
        case .artists: ArtistsView()
        }
    }
}

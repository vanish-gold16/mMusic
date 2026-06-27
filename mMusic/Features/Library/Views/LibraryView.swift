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
    @Environment(AudioPlayer.self) private var audioPlayer

    @State private var selectedCategory: LibraryCategory = .playlists

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                Spacer()
                
                ForEach(LibraryCategory.allCases, id: \.self) { category in
                    NavigationLink(destination: destinationView(for: category)) {
                        HStack {
                            Label(category.rawValue, systemImage: category.icon)
                                .foregroundColor(.orange)
                                .font(.title2)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                                .font(.subheadline)
                        }
                    }
                    
                    Divider()
                    
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
                            .contextMenu() {
                                VStack {
                                    ControlGroup {
                                        Button {
                                            
                                        } label: {
                                            Label("Favourite", systemImage: track.isFavourite ? "star.fill" : "star")
                                        }
                                        
                                        Button {
                                            
                                        } label: {
                                            Label("Share", systemImage: "square.and.arrow.up")
                                        }
                                    }
                                    
                                    Divider()
                                    
                                    Button {
                                        
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    
                                    Divider()
                                    
                                    Button(role: .destructive) {
                                        trackStore.delete(track)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                    
                                    .tint(.red)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
        .onAppear{
            trackStore.load()
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

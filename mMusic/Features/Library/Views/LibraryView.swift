//
//  LibraryView.swift
//  mMusic
//
//  Created by Vanya on 22.06.2026.
//

import SwiftUI

struct LibraryView: View {
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
        }
        .listStyle(.plain)
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

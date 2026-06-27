//
//  RootView.swift
//  mMusic
//
//  Created by Vanya on 22.06.2026.
//

import SwiftUI

struct RootView: View {
    @State private var selected: Tab = .home
    @State private var homePath: NavigationPath = .init()
    @State private var downloadPath: NavigationPath = .init()
    @State private var libraryPath: NavigationPath = .init()
    @State private var searchPath: NavigationPath = .init()
    
    @State private var audioPlayer = AudioPlayer()
    
    var body: some View {
        TabView(selection: tabBinding) {
            SwiftUI.Tab("Home", systemImage: "house", value: Tab.home) {
                HomeTab(path: $homePath)
            }
            SwiftUI.Tab("Download", systemImage: "music.note", value: Tab.download) {
                DownloadTab(path: $downloadPath)
            }
            SwiftUI.Tab("Library", systemImage: "music.note.square.stack", value: Tab.library) {
                LibraryTab(path: $libraryPath)
            }
            SwiftUI.Tab("Search", systemImage: "magnifyingglass", value: Tab.search, role: .search) {
                SearchTab(path: $searchPath)
            }
//            HomeTab(path: $homePath)
//                .tabItem { Label("Home", systemImage: "house") }
//                .tag(Tab.home)
//            DownloadTab(path: $downloadPath)
//                .tabItem { Label("Download", systemImage: "music.note")}
//                .tag(Tab.download)
//            LibraryTab(path: $libraryPath)
//                .tabItem { Label("Library", systemImage: "music.note.square.stack") }
//                .tag(Tab.library)
//            Spacer()
//            SearchTab(path: $searchPath)
//                .tabItem { Label("Search", systemImage: "magnifyingglass", role: .search) }
//                .tag(Tab.search)
        }
        .tabViewBottomAccessory {
            MiniPlayerView(audioPlayer: audioPlayer)
        }
        .environment(audioPlayer)
        .tint(.orange)
    }
    
    private var tabBinding: Binding<Tab> {
        Binding (
            get: { selected },
            set: { new in
                if new == selected { resetNav(for: new) }
                selected = new
            }
        )
    }
    
    private func resetNav(for tab: Tab) {
        switch tab {
        case .home: homePath = NavigationPath()
        case .download: downloadPath = NavigationPath()
        case .library: libraryPath = NavigationPath()
        case .search: searchPath = NavigationPath()
        }
    }
    
}

#Preview {
    RootView()
}

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
    
    var body: some View {
        TabView(selection: tabBinding) {
            HomeTab(path: $homePath)
                .tabItem { Label("Home", systemImage: "house") }
                .tag(Tab.home)
            DownloadTab(path: $downloadPath)
                .tabItem { Label("Download", systemImage: "music.note")}
                .tag(Tab.download)
            LibraryTab(path: $libraryPath)
                .tabItem { Label("Library", systemImage: "music.note.square.stack") }
                .tag(Tab.library)
            Spacer()
            SearchTab(path: $searchPath)
                .tabItem { Label("Search", systemImage: "magnifyingglass") }
                .tag(Tab.search)
        }
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

//
//  mMusicApp.swift
//  mMusic
//
//  Created by Vanya on 22.06.2026.
//

import SwiftUI
import SwiftData

@main
struct mMusicApp: App {
    init() {
        AppSettings.registerDefaults()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: [Track.self, Playlist.self, Album.self, Artist.self, Credit.self, PlayEvent.self])
    }
}

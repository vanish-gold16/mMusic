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
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: Track.self)
    }
}

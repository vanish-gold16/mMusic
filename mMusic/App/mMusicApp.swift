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
        AppNotifications.startHandling()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: [Track.self, Playlist.self, Album.self, Artist.self, Credit.self, PlayEvent.self])
        // iOS будит приложение в фоне, когда сочтёт нужным, — проверить,
        // не вышло ли чего у артистов из библиотеки. Базы здесь нет: радар
        // берёт артистов из своего снимка.
        .backgroundTask(.appRefresh(ReleaseRadar.refreshTaskID)) {
            await ReleaseRadar.shared.checkInBackground()
        }
    }
}

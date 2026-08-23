import Foundation
import SwiftData
import Testing
@testable import mMusic

/// Тесты на ремикс: арифметика тона и границы шкал. Ошибку здесь на слух
/// не поймать — «чуть не тот тон» звучит просто как плохая запись.
@MainActor
struct RemixSettingsTests {

    private let container: ModelContainer

    init() throws {
        container = try ModelContainer(
            for: Track.self, Album.self, Artist.self, Credit.self,
            Playlist.self, TrackPlaylistItem.self, PlayEvent.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    /// Удвоение скорости — ровно октава вверх, половинная — октава вниз.
    @Test func vinylPitchFollowsOctaves() {
        #expect(abs(RemixSettings.pitch(forSpeed: 2) - 12) < 0.001)
        #expect(abs(RemixSettings.pitch(forSpeed: 0.5) + 12) < 0.001)
        #expect(abs(RemixSettings.pitch(forSpeed: 1)) < 0.001)
    }

    @Test func vinylIgnoresOwnPitch() {
        var remix = RemixSettings(speed: 0.5, pitch: 7, isVinyl: true)
        #expect(abs(remix.effectivePitch + 12) < 0.001)

        // Связку сняли — вернулось то, что стоит на ручке.
        remix.isVinyl = false
        #expect(remix.effectivePitch == 7)
    }

    @Test func clampingKeepsValuesInsideScales() {
        let clamped = RemixSettings(speed: 9, pitch: -40, reverb: 300).clamped()

        #expect(clamped.speed == RemixSettings.speedRange.upperBound)
        #expect(clamped.pitch == RemixSettings.pitchRange.lowerBound)
        #expect(clamped.reverb == RemixSettings.reverbRange.upperBound)
    }

    @Test func neutralMeansUntouched() {
        #expect(RemixSettings.neutral.isNeutral)
        // Связка при обычной скорости ничего не меняет — это всё ещё оригинал.
        #expect(RemixSettings(speed: 1, isVinyl: true).isNeutral)
        #expect(!RemixSettings(speed: 0.85, isVinyl: true).isNeutral)
        #expect(!RemixSettings(reverb: 40).isNeutral)
    }

    /// Один и тот же звук набирается и связкой, и руками — пресет должен
    /// подсветиться в обоих случаях.
    @Test func sameSoundMatchesRegardlessOfHowItWasSet() {
        let byVinyl = RemixSettings(speed: 0.5, isVinyl: true)
        let byHand = RemixSettings(speed: 0.5, pitch: -12)

        #expect(byVinyl.sounds(like: byHand))
        #expect(!byVinyl.sounds(like: RemixSettings(speed: 0.5)))
    }

    @Test func presetsStayInsideScales() {
        for preset in RemixSettings.presets {
            #expect(preset.settings.clamped() == preset.settings, "\(preset.name) вышел за шкалу")
        }
    }

    /// Ремикс переживает сохранение: у трека он лежит как обычное поле,
    /// и после перезапуска ручки должны стоять там же.
    @Test func remixSurvivesSaving() throws {
        let context = container.mainContext
        let track = Track(name: "Test", credits: [], genre: .pop, filename: "test.mp3")
        context.insert(track)

        track.remix = RemixSettings(speed: 0.85, pitch: -2, reverb: 45, isVinyl: true)
        try context.save()

        let saved = try context.fetch(FetchDescriptor<Track>()).first
        #expect(saved?.remix == RemixSettings(speed: 0.85, pitch: -2, reverb: 45, isVinyl: true))

        saved?.remix = nil
        try context.save()
        #expect(try context.fetch(FetchDescriptor<Track>()).first?.remix == nil)
    }
}

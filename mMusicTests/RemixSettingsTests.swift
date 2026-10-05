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
        let clamped = RemixSettings(speed: 9, pitch: -40, reverb: 300, muffle: 250, bass: -40, echo: 500).clamped()

        #expect(clamped.speed == RemixSettings.speedRange.upperBound)
        #expect(clamped.pitch == RemixSettings.pitchRange.lowerBound)
        #expect(clamped.reverb == RemixSettings.reverbRange.upperBound)
        #expect(clamped.muffle == RemixSettings.muffleRange.upperBound)
        #expect(clamped.bass == RemixSettings.bassRange.lowerBound)
        #expect(clamped.echo == RemixSettings.echoRange.upperBound)
    }

    @Test func neutralMeansUntouched() {
        #expect(RemixSettings.neutral.isNeutral)
        // Связка при обычной скорости ничего не меняет — это всё ещё оригинал.
        #expect(RemixSettings(speed: 1, isVinyl: true).isNeutral)
        #expect(!RemixSettings(speed: 0.85, isVinyl: true).isNeutral)
        #expect(!RemixSettings(reverb: 40).isNeutral)
        // Новые ручки тоже считаются: иначе лампа REMIX в плеере не загорелась бы
        // у трека, который только приглушили или пустили по кругу.
        #expect(!RemixSettings(muffle: 30).isNeutral)
        #expect(!RemixSettings(bass: -4).isNeutral)
        #expect(!RemixSettings(echo: 20).isNeutral)
        #expect(!RemixSettings(isOrbiting: true).isNeutral)
        #expect(!RemixSettings(isRadio: true).isNeutral)
    }

    /// Ремикс, сохранённый до появления новых ручек: их ключей нет совсем или
    /// они пустые — так выглядят новые колонки в базе после миграции. Старые
    /// ручки должны прочитаться как были, новые — встать в ноль.
    @Test func olderRemixReadsWithNewKnobsAtZero() throws {
        let missing = Data(#"{"speed":0.85,"pitch":-2,"reverb":45,"isVinyl":true}"#.utf8)
        let empty = Data(#"{"speed":0.85,"pitch":-2,"reverb":45,"isVinyl":true,"muffle":null,"bass":null,"echo":null,"isOrbiting":null,"isRadio":null}"#.utf8)
        let expected = RemixSettings(speed: 0.85, pitch: -2, reverb: 45, isVinyl: true)

        #expect(try JSONDecoder().decode(RemixSettings.self, from: missing) == expected)
        #expect(try JSONDecoder().decode(RemixSettings.self, from: empty) == expected)
    }

    /// Глухость идёт по октавам: от 20 кГц на нуле до 250 Гц в конце шкалы,
    /// середина — среднее геометрическое, а не арифметическое.
    @Test func muffleCutoffFollowsOctaves() {
        #expect(abs(RemixSettings(muffle: 0).muffleCutoff - 20_000) < 0.01)
        #expect(abs(RemixSettings(muffle: 100).muffleCutoff - 250) < 0.01)
        #expect(abs(RemixSettings(muffle: 50).muffleCutoff - (20_000.0 * 250).squareRoot()) < 0.01)
    }

    @Test func presetNamesAreUnique() {
        let names = RemixSettings.presets.map(\.name)
        #expect(Set(names).count == names.count)
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

        let remix = RemixSettings(
            speed: 0.85, pitch: -2, reverb: 45, isVinyl: true,
            muffle: 40, bass: 3, echo: 25, isOrbiting: true, isRadio: true
        )
        track.remix = remix
        try context.save()

        let saved = try context.fetch(FetchDescriptor<Track>()).first
        #expect(saved?.remix == remix)

        saved?.remix = nil
        try context.save()
        #expect(try context.fetch(FetchDescriptor<Track>()).first?.remix == nil)
    }
}

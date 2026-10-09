import Foundation

/// Ключи пользовательских настроек и их значения по умолчанию.
enum AppSettings {
    static let pauseOnDisconnect = "pauseOnDisconnect"
    static let resumeAfterInterruption = "resumeAfterInterruption"
    static let playbackRate = "playbackRate"
    static let deleteOriginalAfterImport = "deleteOriginalAfterImport"
    static let appearance = "appearance"
    static let birthdayNotifications = "birthdayNotifications"
    static let releaseNotifications = "releaseNotifications"
    /// Открытый раздел библиотеки и порядок альбомов — чтобы библиотека
    /// открывалась там же, где её оставили. Регистрировать не нужно: значение
    /// по умолчанию задаёт сам `@AppStorage`.
    static let librarySection = "librarySection"
    static let albumSort = "albumSort"

    /// Без регистрации `bool(forKey:)` вернул бы false для ещё не записанного ключа,
    /// и обе настройки стартовали бы выключенными, хотя в интерфейсе выглядят включёнными.
    static func registerDefaults(in defaults: UserDefaults = .standard) {
        defaults.register(defaults: [
            pauseOnDisconnect: true,
            resumeAfterInterruption: true,
            playbackRate: 1.0,
            deleteOriginalAfterImport: true,
            appearance: Appearance.system.rawValue,
            birthdayNotifications: true,
            releaseNotifications: true
        ])
    }
}

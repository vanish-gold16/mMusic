import Foundation

/// Ключи пользовательских настроек и их значения по умолчанию.
enum AppSettings {
    static let pauseOnDisconnect = "pauseOnDisconnect"
    static let resumeAfterInterruption = "resumeAfterInterruption"
    static let playbackRate = "playbackRate"

    /// Без регистрации `bool(forKey:)` вернул бы false для ещё не записанного ключа,
    /// и обе настройки стартовали бы выключенными, хотя в интерфейсе выглядят включёнными.
    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            pauseOnDisconnect: true,
            resumeAfterInterruption: true,
            playbackRate: 1.0
        ])
    }
}

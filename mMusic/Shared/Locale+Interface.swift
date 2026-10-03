import Foundation

extension Locale {

    /// Язык интерфейса. Строки приложения английские, и даты среди них —
    /// тоже: «ОКТЯБРЬ» над «No albums yet» и «Delete» читался бы чужим.
    static let interface = Locale(identifier: "en")
}

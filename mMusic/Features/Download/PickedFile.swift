import Foundation

struct PickedFile: Identifiable {
    let id = UUID()
    let url: URL
    /// Метаданные, добытые не из самого файла — например, из SoundCloud: у скачанного
    /// mp3 тегов может не быть вовсе. Едут вместе с файлом, а не отдельным состоянием
    /// окна импорта: в очереди могут стоять вперемешку файлы и скачанное.
    var preset: AudioMetadata? = nil
}

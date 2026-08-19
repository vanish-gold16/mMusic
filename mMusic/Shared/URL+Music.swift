import Foundation

extension URL {
    /// `artist` == nil, если в имени файла не нашлось разделителя «артист — трек».
    func parseMusic() -> (name: String, artist: String?) {
        let base = deletingPathExtension().lastPathComponent
            .replacingOccurrences(of: "_", with: " ")

        if let range = base.range(of: " — ")        // длинное тире
            ?? base.range(of: " – ")         // среднее тире (en-dash)
            ?? base.range(of: " - ") {
            let artist = String(base[..<range.lowerBound])
            let title = String(base[range.upperBound...])
            return (name: title, artist: artist)
        } else {
            return (name: base, artist: nil)
        }
    }

    /// Разбивает распознанного артиста по запятым: «A, B» → ["A", "B"].
    func parsedArtistNames() -> [String] {
        guard let artist = parseMusic().artist else { return [] }
        return artist
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}

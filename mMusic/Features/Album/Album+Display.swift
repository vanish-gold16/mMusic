import SwiftData
import SwiftUI

/// То, как альбом выглядит снаружи: метка формата, где в нём играющий трек,
/// стороны пластинок. Общее у сетки, экрана альбома и списка его пластинок.
extension Album {

    /// Формат одной меткой: «LP», а у двойного — «2×LP», как на ценнике
    /// в магазине пластинок.
    var formatLabel: String {
        discCount > 1 ? "\(discCount)×\(type.rawValue)" : type.rawValue
    }

    /// Где в альбоме трек: пластинка и номер на ней. nil — трек не отсюда.
    func position(of track: Track?) -> DiscPosition? {
        guard let track, track.album?.persistentModelID == persistentModelID else { return nil }

        let disc = clampedDisc(of: track)
        guard let index = discs[disc].firstIndex(where: { $0.id == track.id }) else { return nil }

        return DiscPosition(disc: disc, track: index)
    }

    /// Номер трека, как на обороте пластинки: «A3», если у пластинки две стороны,
    /// иначе «track 3». У пластинки из одного трека номера нет.
    func recordNumber(of track: Track) -> String? {
        guard let position = position(of: track) else { return nil }

        let tracks = discs[position.disc]
        guard tracks.count > 1 else { return nil }

        let sides = RecordSides.split(tracks, type: type)
        guard sides.count > 1 else { return "track \(position.track + 1)" }

        var start = 0
        for (side, tracksOnSide) in sides.enumerated() {
            if position.track < start + tracksOnSide.count {
                return "\(RecordSides.letter(disc: position.disc, side: side))\(position.track - start + 1)"
            }
            start += tracksOnSide.count
        }
        return nil
    }
}

/// Стороны пластинки: у первой A и B, у второй C и D — как на двойном виниле.
enum RecordSides {

    /// Две стороны: граница там, где их время ближе всего к поровну. Сторона
    /// одна у сингла и у пластинки короче четырёх треков — делить там нечего.
    static func split(_ tracks: [Track], type: Album.AlbumType) -> [[Track]] {
        guard type != .single, tracks.count >= 4 else { return [tracks] }

        let total = tracks.reduce(0) { $0 + $1.duration }

        // Длительности ещё не прочитаны — делим поровну по числу треков.
        guard total > 0 else {
            let middle = (tracks.count + 1) / 2
            return [Array(tracks[..<middle]), Array(tracks[middle...])]
        }

        var best = 1
        var bestDifference = Double.infinity
        var sideA = 0.0

        for split in 1..<tracks.count {
            sideA += tracks[split - 1].duration
            let difference = abs(total - sideA * 2)
            if difference < bestDifference {
                bestDifference = difference
                best = split
            }
        }

        return [Array(tracks[..<best]), Array(tracks[best...])]
    }

    /// Буква стороны `side` пластинки `disc`. Дальше Z — числа: столько
    /// пластинок у альбома не бывает, но и падать из-за этого незачем.
    static func letter(disc: Int, side: Int) -> String {
        let index = disc * 2 + side
        guard index < 26, let scalar = UnicodeScalar(65 + index) else { return "\(index + 1)" }
        return String(Character(scalar))
    }

    /// Сумма уже прочитанных длительностей, в минутах.
    static func minutes(of tracks: [Track]) -> Int {
        Int((tracks.reduce(0) { $0 + $1.duration } / 60).rounded())
    }
}

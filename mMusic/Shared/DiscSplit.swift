import SwiftUI

/// Строка редактора пластинок: трек или граница, с которой начинается
/// следующая пластинка.
enum DiscRow<TrackID: Hashable>: Hashable, Identifiable {
    case track(TrackID)
    /// Номер пластинки, которую граница открывает, — в раскладке до правки.
    /// По нему за границей едет название её пластинки.
    case boundary(Int)

    var id: Self { self }
}

/// Раскладка альбома по пластинкам для редактора — одним плоским списком:
/// треки первой пластинки, граница второй, её треки и так далее.
///
/// Так пластинки не нужен отдельный экран: границу перетаскивают, как трек,
/// и этим решают, где начинается следующая пластинка; трек, перетащенный за
/// границу, переезжает на другую пластинку. Убранная граница сливает свою
/// пластинку с предыдущей — треки при этом никуда не деваются.
///
/// Типы треков здесь нет, только их идентификаторы: раскладку одинаково
/// правят и создание альбома (черновики), и правка (живые треки).
/// SwiftUI — ради `move(fromOffsets:toOffset:)`, того же, что у `onMove`.
struct DiscSplit<TrackID: Hashable> {

    /// Треки по пластинкам. Хотя бы одна пластинка есть всегда.
    private(set) var discs: [[TrackID]]
    /// Названия пластинок, по одному на каждую; пустое — без названия.
    private(set) var titles: [String]

    init(discs: [[TrackID]], titles: [String]) {
        let discs = discs.isEmpty ? [[]] : discs
        self.discs = discs
        self.titles = discs.indices.map { titles.indices.contains($0) ? titles[$0] : "" }
    }

    var rows: [DiscRow<TrackID>] {
        discs.enumerated().flatMap { index, tracks in
            (index == 0 ? [] : [DiscRow<TrackID>.boundary(index)]) + tracks.map { .track($0) }
        }
    }

    /// Номер пластинки (с 1), которую открывает строка-граница `row`.
    func number(ofBoundaryAt row: Int) -> Int {
        rows[..<row].filter { if case .boundary = $0 { true } else { false } }.count + 2
    }

    /// То же, что `onMove` в списке. Пластинка трека после перестановки —
    /// это число границ над ним.
    mutating func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        var rows = rows
        rows.move(fromOffsets: source, toOffset: destination)
        rebuild(from: rows)
    }

    /// Убирает границы среди `offsets`: их треки переходят на предыдущую
    /// пластинку. Треки среди `offsets` не трогает — их убирает тот, кто
    /// знает как (из альбома или из черновика).
    mutating func removeBoundaries(atOffsets offsets: IndexSet) {
        let kept = rows.enumerated().compactMap { index, row -> DiscRow<TrackID>? in
            if case .boundary = row, offsets.contains(index) { return nil }
            return row
        }
        rebuild(from: kept)
    }

    mutating func removeTracks(_ ids: Set<TrackID>) {
        discs = discs.map { $0.filter { !ids.contains($0) } }
    }

    /// Новая пустая пластинка в конце.
    mutating func appendDisc() {
        discs.append([])
        titles.append("")
    }

    mutating func setTitle(_ title: String, ofDisc disc: Int) {
        guard titles.indices.contains(disc) else { return }
        titles[disc] = title
    }

    private mutating func rebuild(from rows: [DiscRow<TrackID>]) {
        var newDiscs: [[TrackID]] = [[]]
        var newTitles = [titles[0]]

        for row in rows {
            switch row {
            case .track(let id):
                newDiscs[newDiscs.count - 1].append(id)
            case .boundary(let disc):
                newDiscs.append([])
                newTitles.append(titles.indices.contains(disc) ? titles[disc] : "")
            }
        }

        discs = newDiscs
        titles = newTitles
    }
}

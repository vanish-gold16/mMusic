import Foundation

/// Решения радара без сети и без файлов: кто в каталоге наш артист и что
/// из пришедшего — новость. Всё здесь чистые функции, их проверяют тесты.
nonisolated enum RadarLogic {

    // MARK: - Опознание

    /// Тёзка из выдачи каталога вместе с названиями его песен и релизов.
    struct Candidate: Sendable {
        let id: Int
        let name: String
        let picture: URL?
        /// Слушатели в каталоге. У Apple их не бывает — там 0.
        let fans: Int
        let titleKeys: Set<String>
        /// Подпись в списке выбора: слушатели у Deezer, жанр у Apple.
        var detail: String = ""
    }

    /// Кем артист из библиотеки оказался в каталоге.
    ///
    /// Имя должно совпасть по ключу — «Ava Max» и «AVA MAX» совпадают,
    /// «Lover» и «Lovers» нет. Из совпавших верим тому, у кого в каталоге
    /// нашлись песни из библиотеки: у тёзки их не будет. Если песен
    /// не нашлось ни у кого, но тёзка один (или один в десять раз известнее
    /// остальных) — скорее всего это он, хотя и не наверняка.
    static func match(_ artist: LibraryArtist, among candidates: [Candidate], now: Date = .now) -> RadarMatch {
        let namesakes = candidates.filter { RadarText.key($0.name) == artist.key }

        let scored = namesakes
            .map { (candidate: $0, overlap: $0.titleKeys.intersection(artist.titleKeys).count) }
            .sorted { ($0.overlap, $0.candidate.fans) > ($1.overlap, $1.candidate.fans) }

        guard let best = scored.first else {
            return RadarMatch(status: .missing, decidedAt: now)
        }

        if best.overlap > 0 {
            return match(best.candidate, status: .confirmed, now: now)
        }

        let runnerUp = scored.dropFirst().first?.candidate.fans ?? 0
        if scored.count == 1 || (best.candidate.fans >= 1000 && best.candidate.fans >= runnerUp * 10) {
            return match(best.candidate, status: .probable, now: now)
        }

        return RadarMatch(status: .missing, decidedAt: now)
    }

    private static func match(_ candidate: Candidate, status: RadarMatch.Status, now: Date) -> RadarMatch {
        RadarMatch(id: candidate.id, name: candidate.name, picture: candidate.picture, status: status, decidedAt: now)
    }

    // MARK: - Что считать новым

    /// Релиз старше двух недель — это каталог, а не новинка: так бывает,
    /// когда лейбл заливает старые альбомы или каталог переиндексирует артиста.
    static let freshDays = 14

    /// Чем кончилось сравнение каталога с тем, что радар уже знал.
    struct Outcome: Sendable {
        /// Номера всего, что теперь известно.
        var known: Set<Int>
        /// Список релизов радара после слияния.
        var releases: [RadarRelease]
        /// Уже вышедшие новинки, о которых надо сообщить сейчас.
        var outNow: [RadarRelease] = []
        /// Анонсы с будущей датой — для них уведомление ставится на день выхода.
        var upcoming: [RadarRelease] = []
    }

    /// Сводит пришедший из каталога список релизов артиста с тем, что радар
    /// уже знал.
    ///
    /// `known == nil` — первое знакомство: всё, что лежит в каталоге, только
    /// запоминается. Свежее за две недели попадает на полку, но молча, — кроме
    /// анонсов: о них человек ещё не мог узнать, и в день выхода они придут.
    ///
    /// Один и тот же релиз может прийти дважды: у двух артистов библиотеки
    /// (их совместный сингл) или из двух каталогов. Тогда он не дублируется,
    /// а дописывает к себе ещё одного артиста.
    static func merge(
        _ incoming: [RadarRelease],
        for artist: LibraryArtist,
        known: Set<Int>?,
        into releases: [RadarRelease],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> Outcome {
        var outcome = Outcome(known: known ?? [], releases: releases)
        let isFirstLook = known == nil
        let today = calendar.startOfDay(for: now)
        let freshFrom = calendar.date(byAdding: .day, value: -freshDays, to: today) ?? today

        for var release in incoming {
            let isNew = outcome.known.insert(release.sourceID).inserted

            guard let day = date(of: release.releaseDay, calendar: calendar) else { continue }
            let isUpcoming = day > today

            if !isNew {
                guard let index = outcome.releases.firstIndex(where: { $0.id == release.id }) else { continue }

                // У анонса обложки часто нет до последних дней — появилась, берём.
                if outcome.releases[index].cover == nil, let cover = release.cover {
                    outcome.releases[index].cover = cover
                }
                // Уже знакомый анонс мог сменить дату — каталог переносит релизы.
                if outcome.releases[index].releaseDay != release.releaseDay,
                   outcome.releases[index].arrivesAt > now {
                    outcome.releases[index].releaseDay = release.releaseDay
                    outcome.releases[index].arrivesAt = isUpcoming ? day : now
                    if isUpcoming { outcome.upcoming.append(outcome.releases[index]) }
                }
                continue
            }

            guard isUpcoming || day >= freshFrom else { continue }
            // Лежит в библиотеке — значит, уже есть, не новость.
            guard !artist.ownedKeys.contains(RadarText.releaseKey(release.title)) else { continue }

            if let index = sameRelease(as: release, day: day, in: outcome.releases, calendar: calendar) {
                if !outcome.releases[index].libraryArtists.contains(artist.name) {
                    outcome.releases[index].libraryArtists.append(artist.name)
                }
                // Свой релиз хоть у одного из них — значит, не фит.
                if !release.isFeature { outcome.releases[index].isFeature = false }
                continue
            }

            release.libraryArtists = [artist.name]
            release.foundAt = now
            release.isQuiet = isFirstLook && !isUpcoming
            // Молчаливый ложится во входящие днём выхода, а не днём знакомства:
            // так история выглядит как была, а не одной кучей «сегодня».
            release.arrivesAt = isUpcoming || release.isQuiet ? day : now

            outcome.releases.append(release)
            if isUpcoming {
                outcome.upcoming.append(release)
            } else if !release.isQuiet {
                outcome.outNow.append(release)
            }
        }

        return outcome
    }

    /// Тот же релиз, уже лежащий в списке: тот же номер — или то же название
    /// с той же датой (±2 дня: каталоги считают день выхода по разным поясам).
    ///
    /// Между каталогами название сравнивается без скобок: Apple дописывает
    /// к нему «(feat. …)», Deezer — нет. Внутри одного каталога скобки
    /// важны: «Loser» и «Loser (Remix)» у Deezer — два разных релиза
    /// с разными номерами.
    private static func sameRelease(as release: RadarRelease, day: Date, in releases: [RadarRelease], calendar: Calendar) -> Int? {
        if let index = releases.firstIndex(where: { $0.id == release.id }) {
            return index
        }

        let key = RadarText.releaseKey(release.title)
        let base = RadarText.baseKey(release.title)

        return releases.firstIndex { other in
            let sameTitle = other.source == release.source
                ? RadarText.releaseKey(other.title) == key
                : RadarText.baseKey(other.title) == base

            guard sameTitle, let otherDay = date(of: other.releaseDay, calendar: calendar) else { return false }
            return abs(otherDay.timeIntervalSince(day)) <= 2 * 86_400 + 3_600
        }
    }

    /// «2026-10-10» → полночь этого дня по местному времени.
    static func date(of releaseDay: String, calendar: Calendar = .current) -> Date? {
        let parts = releaseDay.prefix(10).split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }

    /// Старое уходит из списка: о нём уже сообщили, а номера остаются
    /// в `known` — второй раз оно новостью не станет.
    static func pruned(_ releases: [RadarRelease], now: Date = .now, calendar: Calendar = .current) -> [RadarRelease] {
        guard let cutoff = calendar.date(byAdding: .day, value: -120, to: now) else { return releases }
        return releases.filter { (date(of: $0.releaseDay, calendar: calendar) ?? now) >= cutoff }
    }

    // MARK: - Из ответов каталогов

    static func releases(fromDeezer albums: [DeezerClient.Album], byline: String) -> [RadarRelease] {
        albums.compactMap { album in
            guard let day = album.releaseDate else { return nil }

            let kind: RadarRelease.Kind = switch album.recordType {
            case "single": .single
            case "ep": .ep
            default: .album
            }

            return RadarRelease(
                source: .deezer,
                sourceID: album.id,
                title: album.title,
                kind: kind,
                releaseDay: day,
                cover: album.cover,
                link: album.link,
                byline: byline
            )
        }
    }

    /// Песни артиста у Apple складываются в релизы. Песня, где главный —
    /// кто-то другой, значит фит: релиз чужой.
    static func releases(fromApple songs: [AppleMusicClient.Song], artistID: Int) -> [RadarRelease] {
        var byCollection: [Int: [AppleMusicClient.Song]] = [:]
        for song in songs {
            guard let collection = song.collectionId, !isCompilation(song) else { continue }
            byCollection[collection, default: []].append(song)
        }

        return byCollection.compactMap { id, songs in
            guard let first = songs.first, let title = first.collectionName else { return nil }

            // У альбома с синглами наперёд у песен разные даты: альбом вышел
            // в последнюю из них.
            guard let day = songs.compactMap({ $0.releaseDate.map { String($0.prefix(10)) } }).max() else { return nil }

            let kind: RadarRelease.Kind = if title.hasSuffix(" - Single") {
                .single
            } else if title.hasSuffix(" - EP") {
                .ep
            } else {
                .album
            }

            return RadarRelease(
                source: .apple,
                sourceID: id,
                title: title,
                kind: kind,
                releaseDay: day,
                cover: AppleMusicClient.artwork(first.artworkUrl100),
                link: first.collectionViewUrl,
                byline: first.artistName ?? "",
                isFeature: songs.allSatisfy { $0.artistId != artistID }
            )
        }
    }

    /// Сборники — не релизы артиста: «Today's Hits (DJ Mix)» выходит каждую
    /// неделю, и песня из библиотеки в нём не новость.
    private static func isCompilation(_ song: AppleMusicClient.Song) -> Bool {
        song.collectionArtistName == "Various Artists"
            || song.collectionName?.localizedCaseInsensitiveContains("DJ Mix") == true
    }

    // MARK: - Сводка

    /// Заголовок и текст уведомления о нескольких релизах сразу.
    /// Один релиз — «madk1d» / «летник · single»; несколько — «3 new drops» /
    /// «madk1d — летник, fakemink — Love Of The Game 3 and 1 more».
    static func digest(_ releases: [RadarRelease]) -> (title: String, body: String) {
        if releases.count == 1 {
            let release = releases[0]
            let who = release.isFeature
                ? "\(release.libraryArtists.joined(separator: ", ")) on \(release.byline)"
                : release.byline
            return (who, "\(release.displayTitle) · \(release.kind.label.lowercased())")
        }

        let shown = releases.prefix(3).map { "\($0.libraryArtists.first ?? $0.byline) — \($0.displayTitle)" }
        var body = shown.joined(separator: ", ")
        if releases.count > shown.count {
            body += " and \(releases.count - shown.count) more"
        }

        return ("\(releases.count) new drops", body)
    }
}

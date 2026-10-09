import BackgroundTasks
import Foundation
import Observation
import SwiftData

/// Радар релизов: смотрит, не выпустил ли что-нибудь кто-то из библиотеки.
///
/// Следит за всеми, кто в ней есть, — библиотека и есть список тех, кого
/// слушают. Свои релизы артиста берутся у Deezer: он быстрый, вся библиотека
/// проверяется за полминуты. Фиты — у Apple: там они есть, но Apple
/// отвечает медленно, и этот проход идёт неспешно, пока приложение открыто
/// или играет музыка.
///
/// Сервера нет, поэтому и настоящих пушей нет: бесплатная подпись их не даёт.
/// Приложение проверяет само — при запуске, когда возвращается из фона
/// и когда iOS будит его фоновым обновлением, — и само же ставит себе
/// уведомления. Анонсы с будущей датой ставятся заранее на полночь дня
/// выхода: пятничный дроп придёт, даже если в ту ночь приложение не просыпалось.
@MainActor
@Observable
final class ReleaseRadar {

    static let shared = ReleaseRadar()

    /// Он же записан в Info.plist в `BGTaskSchedulerPermittedIdentifiers`.
    static let refreshTaskID = "mytrofanov.mMusic.releaseRadar"

    private(set) var releases: [RadarRelease] = []
    private(set) var artists: [String: RadarArtist] = [:]
    private(set) var inboxSeenAt: Date = .distantPast
    private(set) var lastCheckAt: Date?
    /// Идёт проход по Deezer — по нему крутится кнопка «проверить».
    private(set) var isChecking = false
    /// Куда открыть приложение: нажали на уведомление.
    var route: RadarRoute?

    /// Снимок библиотеки: кого проверять. Не наблюдается — экраны его не показывают.
    @ObservationIgnored private(set) var library: [LibraryArtist] = []
    @ObservationIgnored private var deezerTask: Task<Void, Never>?
    @ObservationIgnored private var appleTask: Task<Void, Never>?
    /// Найденное, о чём ещё не сообщили: проход копит новинки и сообщает
    /// одной сводкой в конце, а не по уведомлению на каждого артиста.
    @ObservationIgnored private var pendingDigest: [RadarRelease] = []
    @ObservationIgnored private let fileURL: URL

    /// Свой релиз артиста проверяется не чаще, чем раз в столько, — иначе
    /// каждое возвращение в приложение гоняло бы всю библиотеку заново.
    static let deezerInterval: TimeInterval = 3 * 3600
    /// Фиты — реже: проход у Apple медленный.
    static let appleInterval: TimeInterval = 12 * 3600
    /// Не нашёлся — попробуем через неделю: артиста могли залить в каталог.
    static let retryMissingAfter: TimeInterval = 7 * 86_400

    init(fileURL: URL = RadarStore.url) {
        self.fileURL = fileURL
        let state = RadarStore.load(from: fileURL)
        releases = state.releases
        artists = state.artists
        library = state.library
        inboxSeenAt = state.inboxSeenAt
        lastCheckAt = state.lastCheckAt
    }

    // MARK: - Что показывать

    /// Уже пришедшее во входящие, свежее сверху.
    var inbox: [RadarRelease] {
        let now = Date.now
        return audible.filter { $0.arrivesAt <= now }.sorted { $0.arrivesAt > $1.arrivesAt }
    }

    /// Анонсы: выйдут позже, ближайший сверху.
    var upcoming: [RadarRelease] {
        let now = Date.now
        return audible.filter { $0.arrivesAt > now && !$0.isDismissed }.sorted { $0.arrivesAt < $1.arrivesAt }
    }

    var unreadCount: Int {
        let now = Date.now
        return audible.filter { !$0.isQuiet && $0.arrivesAt > inboxSeenAt && $0.arrivesAt <= now }.count
    }

    /// Всё, кроме релизов заглушённых артистов. Заглушить — значит не слышать
    /// о нём вовсе: ни уведомлений, ни полки, ни входящих. Найденное раньше
    /// не стирается и вернётся, если звук включить обратно.
    private var audible: [RadarRelease] {
        releases.filter { !isMuted($0) }
    }

    /// Релиз заглушён, когда заглушены все артисты библиотеки на нём:
    /// совместный сингл с тем, кого слушают, всё равно новость.
    func isMuted(_ release: RadarRelease) -> Bool {
        !release.libraryArtists.isEmpty
            && release.libraryArtists.allSatisfy { artist(named: $0)?.isMuted == true }
    }

    /// Полка новинок на главной: вышедшее за две недели, свежее первым, потом анонсы.
    var shelf: [RadarRelease] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let from = calendar.date(byAdding: .day, value: -RadarLogic.freshDays, to: today) ?? today

        let out = audible
            .filter { !$0.isDismissed && $0.arrivesAt <= .now }
            .filter { (RadarLogic.date(of: $0.releaseDay) ?? .distantPast) >= from }
            .sorted { ($0.releaseDay, $0.foundAt) > ($1.releaseDay, $1.foundAt) }

        return Array((out + upcoming).prefix(16))
    }

    func release(id: String) -> RadarRelease? {
        releases.first { $0.id == id }
    }

    func artist(named name: String) -> RadarArtist? {
        artists[RadarText.key(name)]
    }

    /// Сколько артистов библиотеки опознано хоть в одном каталоге.
    var watchedCount: Int {
        library.filter { artist in
            guard let entry = artists[artist.key], !entry.isMuted else { return false }
            return entry.deezer?.isWatched == true || entry.apple?.isWatched == true
        }.count
    }

    // MARK: - Действия

    func markInboxSeen() {
        inboxSeenAt = .now
        save()
    }

    func dismiss(_ id: String) {
        guard let index = releases.firstIndex(where: { $0.id == id }) else { return }
        releases[index].isDismissed = true
        save()
        Task { await rescheduleUpcoming() }
    }

    /// Заглушённого радар не проверяет, а его анонсы снимаются с расписания.
    func setMuted(_ muted: Bool, artist name: String) {
        update(name) { $0.isMuted = muted }
        Task { await rescheduleUpcoming() }
        // Включили обратно — посмотреть, что вышло, пока он молчал.
        if !muted { check(force: false) }
    }

    /// Выбран руками: с этого каталога радар знакомится заново, молча.
    func pick(_ candidate: RadarLogic.Candidate, on source: RadarRelease.Source, for name: String) {
        let match = RadarMatch(id: candidate.id, name: candidate.name, picture: candidate.picture, status: .picked, decidedAt: .now)
        update(name) { entry in
            switch source {
            case .deezer:
                entry.deezer = match
                entry.knownDeezer = nil
                entry.deezerCheckedAt = nil
            case .apple:
                entry.apple = match
                entry.knownApple = nil
                entry.appleCheckedAt = nil
            }
        }
        check(force: false)
    }

    /// «В этом каталоге его нет» — больше не ищется.
    func reject(on source: RadarRelease.Source, for name: String) {
        let match = RadarMatch(status: .rejected, decidedAt: .now)
        update(name) { entry in
            switch source {
            case .deezer: entry.deezer = match
            case .apple: entry.apple = match
            }
        }
    }

    private func update(_ name: String, _ change: (inout RadarArtist) -> Void) {
        let key = RadarText.key(name)
        var entry = artists[key] ?? RadarArtist(name: name)
        change(&entry)
        artists[key] = entry
        save()
    }

    // MARK: - Проверки

    /// При запуске и при возвращении в приложение: свежий снимок библиотеки
    /// и проверка тех, кого давно не смотрели.
    func refresh(from context: ModelContext) {
        library = RadarLibrary.snapshot(in: context)
        save()
        check(force: false)
    }

    /// `force` — по кнопке: каждого артиста заново, не глядя, когда смотрели.
    func check(force: Bool) {
        if deezerTask == nil {
            deezerTask = Task {
                await sweepDeezer(force: force, deadline: nil)
                deezerTask = nil
            }
        }
        if appleTask == nil {
            appleTask = Task {
                await sweepApple(force: force)
                appleTask = nil
            }
        }
    }

    /// По кнопке и жестом «потянуть вниз»: каждого артиста у Deezer заново —
    /// и дождаться, пока проход кончится. Apple идёт своим темпом дальше.
    func checkNow() async {
        check(force: true)
        await deezerTask?.value
    }

    /// Фоновое обновление: iOS даёт на него около полуминуты. Успеваем Deezer
    /// по самым слушаемым; Apple с его темпом сюда не помещается.
    ///
    /// Время вышло — iOS отменяет задачу, и проход обрывается вместе с ней,
    /// даже если его начало ещё открытое приложение: что успели, уже записано,
    /// остальных проверим в следующий раз.
    func checkInBackground() async {
        defer { scheduleBackgroundRefresh() }

        let task = deezerTask ?? Task { await sweepDeezer(force: false, deadline: .now + .seconds(24)) }
        deezerTask = task
        await withTaskCancellationHandler {
            await task.value
        } onCancel: {
            task.cancel()
        }
        deezerTask = nil
    }

    /// Приложение уходит в фон: сообщить о найденном, не дожидаясь конца
    /// прохода — дальше он может и не продолжиться.
    func flush() {
        save()
        deliverDigest()
        scheduleBackgroundRefresh()
    }

    // MARK: - Deezer

    private func sweepDeezer(force: Bool, deadline: ContinuousClock.Instant?) async {
        isChecking = true
        defer { isChecking = false }

        var finished = true

        for (index, artist) in library.sorted(by: { $0.weight > $1.weight }).enumerated() {
            if Task.isCancelled || deadline.map({ ContinuousClock.now > $0 }) == true {
                finished = false
                break
            }

            let entry = artists[artist.key] ?? RadarArtist(name: artist.name)
            guard !entry.isMuted else { continue }

            var match = entry.deezer
            var known = entry.knownDeezer
            var checkedAt = entry.deezerCheckedAt

            do {
                var albums: [DeezerClient.Album]?

                if needsMatch(match) {
                    let found = try await matchOnDeezer(artist)
                    match = found.match
                    albums = found.albums
                }

                if let match, match.isWatched, let id = match.id,
                   force || isStale(checkedAt, interval: Self.deezerInterval) {
                    let catalog: [DeezerClient.Album]
                    if let albums { catalog = albums } else { catalog = try await DeezerClient.albums(ofArtist: id) }
                    let incoming = RadarLogic.releases(fromDeezer: catalog, byline: match.name ?? artist.name)
                    known = absorb(incoming, for: artist, known: known)
                    checkedAt = .now
                }
            } catch {
                // Сеть пропала или Deezer отказал — остальных проверим в следующий раз.
                if error is CancellationError || (error as? URLError)?.code == .notConnectedToInternet {
                    finished = false
                    break
                }
            }

            commit(artist, startedWith: entry.deezer, at: \.deezer) { current in
                current.deezer = match
                current.knownDeezer = known
                current.deezerCheckedAt = checkedAt
            }
            if index % 10 == 9 { save() }
        }

        if finished { lastCheckAt = .now }
        save()
        deliverDigest()
        await rescheduleUpcoming()
    }

    /// Ищет тёзок и у каждого (до трёх, самых известных) смотрит релизы
    /// и хиты. Релизы того, кто подошёл, возвращаются сразу — с ними же
    /// и знакомство с каталогом, второй раз за ними ходить незачем.
    ///
    /// Не нашлось общих песен среди релизов и хитов — ищем сами песни:
    /// «имя + название» в поиске треков. Это ловит тех, чья песня из библиотеки
    /// лежит на альбоме, а не синглом, и в хиты не попала.
    private func matchOnDeezer(_ artist: LibraryArtist) async throws -> (match: RadarMatch, albums: [DeezerClient.Album]?) {
        let namesakes = try await DeezerClient.searchArtists(named: artist.name)
            .filter { RadarText.key($0.name) == artist.key }
            .sorted { ($0.fans ?? 0) > ($1.fans ?? 0) }
            .prefix(3)

        var candidates: [RadarLogic.Candidate] = []
        var catalogs: [Int: [DeezerClient.Album]] = [:]

        for namesake in namesakes {
            let albums = try await DeezerClient.albums(ofArtist: namesake.id)
            let top = try await DeezerClient.topTitles(ofArtist: namesake.id)
            catalogs[namesake.id] = albums

            let keys = (albums.map(\.title) + top).reduce(into: Set<String>()) { $0.formUnion(RadarText.titleKeys($1)) }
            candidates.append(RadarLogic.Candidate(
                id: namesake.id, name: namesake.name, picture: namesake.picture,
                fans: namesake.fans ?? 0, titleKeys: keys
            ))
        }

        var match = RadarLogic.match(artist, among: candidates)

        if match.status != .confirmed, !candidates.isEmpty {
            let ids = Set(candidates.map(\.id))
            for title in artist.searchTitles.prefix(6) {
                let wanted = RadarText.key(title)
                let tracks = try await DeezerClient.searchTracks("\(artist.name) \(title)")
                // Нужен трек с этим названием и у одного из тёзок — просто
                // любой трек тёзки в выдаче ничего не доказывает.
                guard let id = tracks.lazy
                        .filter({ RadarText.titleKeys($0.title).contains(wanted) })
                        .compactMap({ $0.artist?.id })
                        .first(where: ids.contains),
                      let candidate = candidates.first(where: { $0.id == id }) else { continue }

                match = RadarMatch(id: id, name: candidate.name, picture: candidate.picture, status: .confirmed, decidedAt: .now)
                break
            }
        }

        return (match, match.id.flatMap { catalogs[$0] })
    }

    // MARK: - Apple

    /// Неспешный проход по Apple: по запросу раз в три секунды. Идёт, пока
    /// приложение живо, — а с играющей музыкой оно живо и в фоне.
    private func sweepApple(force: Bool) async {
        let started = Date.now

        for (index, artist) in library.sorted(by: { $0.weight > $1.weight }).enumerated() {
            if Task.isCancelled { break }

            let entry = artists[artist.key] ?? RadarArtist(name: artist.name)
            guard !entry.isMuted else { continue }

            var match = entry.apple
            var known = entry.knownApple
            var checkedAt = entry.appleCheckedAt

            do {
                var songs: [AppleMusicClient.Song]?

                if needsMatch(match) {
                    let found = try await matchOnApple(artist)
                    match = found.match
                    songs = found.songs
                }

                let stale = force
                    ? (checkedAt ?? .distantPast) < started
                    : isStale(checkedAt, interval: Self.appleInterval)

                if let match, match.isWatched, let id = match.id, stale {
                    let catalog: [AppleMusicClient.Song]
                    if let songs { catalog = songs } else { catalog = try await AppleMusicClient.songs(ofArtist: id) }
                    let incoming = RadarLogic.releases(fromApple: catalog, artistID: id)
                    known = absorb(incoming, for: artist, known: known)
                    checkedAt = .now
                }
            } catch {
                if error is CancellationError { break }
            }

            commit(artist, startedWith: entry.apple, at: \.apple) { current in
                current.apple = match
                current.knownApple = known
                current.appleCheckedAt = checkedAt
            }
            if index % 5 == 4 { save() }
        }

        save()
        deliverDigest()
        await rescheduleUpcoming()
    }

    /// У Apple нет числа слушателей, поэтому тёзок смотрим двоих, а не троих:
    /// каждый — ещё три секунды.
    private func matchOnApple(_ artist: LibraryArtist) async throws -> (match: RadarMatch, songs: [AppleMusicClient.Song]?) {
        let namesakes = try await AppleMusicClient.searchArtists(named: artist.name)
            .filter { RadarText.key($0.artistName) == artist.key }
            .prefix(2)

        var candidates: [RadarLogic.Candidate] = []
        var catalogs: [Int: [AppleMusicClient.Song]] = [:]

        for namesake in namesakes {
            let songs = try await AppleMusicClient.songs(ofArtist: namesake.artistId)
            catalogs[namesake.artistId] = songs

            let keys = songs.flatMap { [$0.trackName, $0.collectionName].compactMap { $0 } }
                .reduce(into: Set<String>()) { $0.formUnion(RadarText.titleKeys($1)) }
            candidates.append(RadarLogic.Candidate(
                id: namesake.artistId, name: namesake.artistName, picture: nil, fans: 0, titleKeys: keys
            ))
        }

        let match = RadarLogic.match(artist, among: candidates)
        return (match, match.id.flatMap { catalogs[$0] })
    }

    // MARK: - Общее

    /// Не опознан наверняка — через неделю ещё попытка: артиста могли залить
    /// в каталог, а в библиотеке могли появиться его песни.
    private func needsMatch(_ match: RadarMatch?) -> Bool {
        guard let match else { return true }
        return [.missing, .probable].contains(match.status)
            && Date.now.timeIntervalSince(match.decidedAt) > Self.retryMissingAfter
    }

    /// Записывает итог прохода по одному артисту. Пока шли запросы, оба прохода
    /// работали с тем же артистом, а человек мог выбрать его руками, — поэтому
    /// запись идёт в нынешнюю запись артиста и меняет только своё. А если
    /// за это время сопоставление поменяли руками, итог прохода отбрасывается:
    /// выбор человека важнее.
    private func commit(
        _ artist: LibraryArtist,
        startedWith before: RadarMatch?,
        at keyPath: KeyPath<RadarArtist, RadarMatch?>,
        _ change: (inout RadarArtist) -> Void
    ) {
        var current = artists[artist.key] ?? RadarArtist(name: artist.name)
        guard current[keyPath: keyPath] == before else { return }

        change(&current)
        if artists[artist.key] != current { artists[artist.key] = current }
    }

    private func isStale(_ checkedAt: Date?, interval: TimeInterval) -> Bool {
        guard let checkedAt else { return true }
        return Date.now.timeIntervalSince(checkedAt) > interval
    }

    /// Сводит пришедшее с известным и возвращает новый список номеров.
    private func absorb(_ incoming: [RadarRelease], for artist: LibraryArtist, known: Set<Int>?) -> Set<Int> {
        let outcome = RadarLogic.merge(incoming, for: artist, known: known, into: releases)

        let merged = RadarLogic.pruned(outcome.releases)
        // Присваивать только изменившееся: каждое присваивание будит экраны,
        // а артистов за проход — две сотни.
        if merged != releases { releases = merged }
        pendingDigest += outcome.outNow

        return outcome.known
    }

    private func deliverDigest() {
        let ids = Set(pendingDigest.map(\.id))
        pendingDigest = []

        // К этому моменту релиз могли убрать или он слился с другим — берём
        // его нынешнюю запись, с полным списком артистов.
        let fresh = audible.filter { ids.contains($0.id) && !$0.isDismissed }
        guard !fresh.isEmpty, notificationsEnabled else { return }

        Task { await ReleaseNotifications.post(fresh) }
    }

    private func rescheduleUpcoming() async {
        await ReleaseNotifications.scheduleUpcoming(upcoming.filter { !$0.isQuiet }, enabled: notificationsEnabled)
    }

    private var notificationsEnabled: Bool {
        UserDefaults.standard.bool(forKey: AppSettings.releaseNotifications)
    }

    /// Включили или выключили уведомления в настройках.
    func notificationsSettingChanged() async {
        if !notificationsEnabled {
            pendingDigest = []
        }
        await rescheduleUpcoming()
    }

    /// Просим iOS разбудить нас: через четыре часа или к ближайшей пятничной
    /// полуночи, если она раньше, — по пятницам релизы выходят в 00:00.
    /// iOS решает сама, когда будить, и обещаний не даёт.
    func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Self.refreshTaskID)
        request.earliestBeginDate = Self.nextWakeUp(after: .now)
        try? BGTaskScheduler.shared.submit(request)
    }

    nonisolated static func nextWakeUp(after now: Date, calendar: Calendar = .current) -> Date {
        let regular = now.addingTimeInterval(4 * 3600)
        // Пятница 00:10 — каталогам нужно несколько минут, чтобы выложить.
        let friday = calendar.nextDate(
            after: now,
            matching: DateComponents(hour: 0, minute: 10, weekday: 6),
            matchingPolicy: .nextTime
        )
        return min(regular, friday ?? regular)
    }

    private func save() {
        RadarStore.save(RadarState(
            artists: artists,
            releases: releases,
            library: library,
            inboxSeenAt: inboxSeenAt,
            lastCheckAt: lastCheckAt
        ), to: fileURL)
    }
}

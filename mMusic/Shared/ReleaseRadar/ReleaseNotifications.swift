import Foundation
import UserNotifications

/// Уведомления о релизах — одной сводкой, а не по штуке на каждый.
///
/// Вышедшее сообщается сразу, как нашлось. Анонсы ставятся на полночь дня
/// выхода — тоже сводкой на день: в пятницу в 00:00 приходит одно уведомление
/// обо всём, что вышло этой ночью.
enum ReleaseNotifications {

    /// Под этим ключом в уведомлении лежат номера его релизов — по ним
    /// нажатие открывает входящие или сам релиз.
    nonisolated static let releaseIDsKey = "releaseIDs"

    private static let dayPrefix = "release-day-"
    /// Ожидающих уведомлений у приложения не больше 64, и половину держат
    /// годовщины треков (`BirthdayNotifications.limit`).
    private static let dayLimit = 20

    static func post(_ releases: [RadarRelease]) async {
        let center = UNUserNotificationCenter.current()
        guard await AppNotifications.hasPermission(center) else { return }

        let content = makeContent(for: releases)
        // Обложка первого релиза — картинкой в уведомлении. Не скачалась —
        // придёт без неё.
        if let attachment = await coverAttachment(for: releases.first) {
            content.attachments = [attachment]
        }

        let request = UNNotificationRequest(identifier: "release-\(UUID().uuidString)", content: content, trigger: nil)
        try? await center.add(request)
    }

    /// Переставляет уведомления о днях выхода под нынешние анонсы. Выключено
    /// в настройках — снимает всё и разрешения не просит.
    static func scheduleUpcoming(_ releases: [RadarRelease], enabled: Bool) async {
        let center = UNUserNotificationCenter.current()

        let pending = await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix(dayPrefix) })

        guard enabled, !releases.isEmpty, await AppNotifications.hasPermission(center) else { return }

        let calendar = Calendar.current
        let days = Dictionary(grouping: releases) { calendar.startOfDay(for: $0.arrivesAt) }

        for (day, releases) in days.sorted(by: { $0.key < $1.key }).prefix(dayLimit) {
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: day)
            let request = UNNotificationRequest(
                identifier: dayPrefix + day.formatted(.iso8601.year().month().day()),
                content: makeContent(for: releases),
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            )
            try? await center.add(request)
        }
    }

    private static func makeContent(for releases: [RadarRelease]) -> UNMutableNotificationContent {
        let digest = RadarLogic.digest(releases)

        let content = UNMutableNotificationContent()
        content.title = digest.title
        content.body = digest.body
        content.sound = .default
        // Все релизы — одной стопкой в центре уведомлений, отдельно от годовщин.
        content.threadIdentifier = "releases"
        content.userInfo = [releaseIDsKey: releases.map(\.id)]
        return content
    }

    /// Картинку уведомление берёт только из файла, поэтому обложка сначала
    /// скачивается во временную папку; система забирает файл себе.
    private static func coverAttachment(for release: RadarRelease?) async -> UNNotificationAttachment? {
        guard let url = release?.cover,
              let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }

        let file = URL.temporaryDirectory.appending(path: "\(UUID().uuidString).jpg")
        guard (try? data.write(to: file)) != nil else { return nil }

        return try? UNNotificationAttachment(identifier: "cover", url: file)
    }
}

import Foundation
import UserNotifications

/// Уведомления о годовщинах треков.
///
/// Расставляются одноразово на год вперёд и переписываются при каждом запуске:
/// у системы есть предел на число ожидающих уведомлений, а текст со свежей
/// статистикой всё равно нужно пересобирать.
enum BirthdayNotifications {

    /// По этой приставке свои уведомления отличаются от чужих: снимать нужно
    /// только их, а не всё, что приложение когда-либо поставило.
    private static let prefix = "birthday-"
    /// Предел системы — 64 ожидающих; берём с запасом, годовщин обычно меньше.
    static let limit = 30
    /// Утро следующего дня никому не нужно — праздник должен прийти днём.
    private static let hour = 11

    /// Показывать баннер, даже если приложение открыто: иначе уведомление
    /// молча уходит в центр, и человек узнаёт о нём случайно.
    private final class ForegroundPresenter: NSObject, UNUserNotificationCenterDelegate {
        func userNotificationCenter(
            _ center: UNUserNotificationCenter,
            willPresent notification: UNNotification
        ) async -> UNNotificationPresentationOptions {
            [.banner, .sound, .list]
        }
    }

    private static let presenter = ForegroundPresenter()

    static func startPresentingInForeground() {
        UNUserNotificationCenter.current().delegate = presenter
    }

    /// Переставить уведомления под текущую библиотеку.
    /// Выключенная настройка снимает всё, что мы ставили, и разрешения не просит.
    static func refresh(with birthdays: [TrackBirthday.Upcoming], enabled: Bool) async {
        let center = UNUserNotificationCenter.current()
        await removeScheduled(in: center)

        guard enabled, !birthdays.isEmpty, await hasPermission(center) else { return }

        let calendar = Calendar.current

        for birthday in birthdays {
            var components = calendar.dateComponents([.year, .month, .day], from: birthday.date)
            components.hour = hour

            let content = UNMutableNotificationContent()
            content.title = "🎂 \(birthday.name)"
            content.body = birthday.body
            content.sound = .default

            let request = UNNotificationRequest(
                identifier: prefix + birthday.filename + "-\(components.year ?? 0)",
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            )

            try? await center.add(request)
        }
    }

    private static func removeScheduled(in center: UNUserNotificationCenter) async {
        let pending = await center.pendingNotificationRequests()
        let ours = pending.map(\.identifier).filter { $0.hasPrefix(prefix) }

        center.removePendingNotificationRequests(withIdentifiers: ours)
    }

    /// Разрешение спрашивается один раз и только когда есть что показывать —
    /// просить его на пустом экране первого запуска невежливо.
    private static func hasPermission(_ center: UNUserNotificationCenter) async -> Bool {
        switch await center.notificationSettings().authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        default:
            return false
        }
    }
}

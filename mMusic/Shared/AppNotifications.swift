import Foundation
import UserNotifications

/// То, что у всех уведомлений приложения общее: годовщин треков и релизов.
///
/// Делегат у центра уведомлений один на всё приложение, поэтому он здесь,
/// а не у каждого вида уведомлений свой. И ставить его нужно до того, как
/// приложение закончит запускаться: нажатие на уведомление может само
/// и запустить приложение, и тогда делегат должен уже быть на месте.
enum AppNotifications {

    private final class Delegate: NSObject, UNUserNotificationCenterDelegate {

        /// Показывать баннер, даже если приложение открыто: иначе уведомление
        /// молча уходит в центр, и человек узнаёт о нём случайно.
        func userNotificationCenter(
            _ center: UNUserNotificationCenter,
            willPresent notification: UNNotification
        ) async -> UNNotificationPresentationOptions {
            [.banner, .sound, .list]
        }

        /// Нажали на уведомление о релизах — один релиз открывается сам,
        /// несколько — входящими.
        func userNotificationCenter(
            _ center: UNUserNotificationCenter,
            didReceive response: UNNotificationResponse
        ) async {
            let userInfo = response.notification.request.content.userInfo
            guard let ids = userInfo[ReleaseNotifications.releaseIDsKey] as? [String], !ids.isEmpty else { return }

            ReleaseRadar.shared.route = ids.count == 1 ? .release(ids[0]) : .inbox
        }
    }

    private static let delegate = Delegate()

    static func startHandling() {
        UNUserNotificationCenter.current().delegate = delegate
    }

    /// Разрешение спрашивается один раз и только когда есть что показывать —
    /// просить его на пустом экране первого запуска невежливо.
    static func hasPermission(_ center: UNUserNotificationCenter) async -> Bool {
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

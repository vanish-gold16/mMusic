import Observation
import SwiftUI
import UIKit

/// Короткая плашка поверх интерфейса: «положил в плейлист», «уже там лежит»,
/// «играет дальше». Заменяет собой алерты на подтверждениях, которые ничего
/// не спрашивают: у алерта нужно нажать «ОК», а такому сообщению это ни к чему.
struct Toast: Identifiable, Equatable {

    /// Смысл сообщения — от него зависят цвет значка и отдача в палец.
    enum Tone {
        /// Получилось.
        case done
        /// Получилось не всё: дубли, пропуски.
        case notice
        /// Что-то убрали.
        case removed

        var color: Color {
            switch self {
            case .done: .green
            case .notice: .orange
            case .removed: .secondary
            }
        }

        /// Отдача в палец подтверждает действие быстрее, чем глаз читает текст.
        @MainActor func play() {
            switch self {
            case .done:
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            case .notice:
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
            case .removed:
                UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
            }
        }
    }

    let id = UUID()
    let message: String
    let systemImage: String
    let tone: Tone
}

/// Кто показывает плашки. Один на всё приложение и лежит в environment: действие
/// случается где угодно — в меню строки, в листе, в плеере, — а плашка всегда одна
/// и в одном месте экрана.
@MainActor
@Observable
final class ToastCenter {

    private(set) var current: Toast?

    /// Задача, которая погасит плашку. Хранится, чтобы новый тост мог отменить
    /// её таймер: иначе прошлый погасил бы новую плашку раньше срока.
    @ObservationIgnored private var hideTask: Task<Void, Never>?

    func show(_ message: String, systemImage: String, tone: Toast.Tone = .done) {
        current = Toast(message: message, systemImage: systemImage, tone: tone)
        tone.play()

        hideTask?.cancel()
        hideTask = Task {
            try? await Task.sleep(for: .seconds(2.4))
            guard !Task.isCancelled else { return }
            current = nil
        }
    }

    func hide() {
        hideTask?.cancel()
        current = nil
    }
}

/// Готовые формулировки для действий, которые случаются в разных местах.
/// Собраны здесь, чтобы «Play next» из альбома и из строки трека говорили
/// одно и то же одними словами.
extension ToastCenter {

    func addedToPlaylist(added: Int, skipped: Int, playlist: String) {
        if skipped == 0 {
            show(
                added == 1 ? "Added to \(playlist)" : "\(added) tracks added to \(playlist)",
                systemImage: "text.badge.plus"
            )
        } else if added == 0 {
            show(
                skipped == 1 ? "Already in \(playlist)" : "All \(skipped) tracks are already there",
                systemImage: "checkmark.circle",
                tone: .notice
            )
        } else {
            show("\(added) added, \(skipped) already there", systemImage: "text.badge.plus", tone: .notice)
        }
    }

    func enqueuedNext(_ count: Int) {
        show(
            count == 1 ? "Plays next" : "\(count) tracks play next",
            systemImage: "text.line.first.and.arrowtriangle.forward"
        )
    }

    func enqueuedLast(_ count: Int) {
        show(
            count == 1 ? "Added to the end" : "\(count) tracks added to the end",
            systemImage: "text.line.last.and.arrowtriangle.forward"
        )
    }

    func removed(_ what: String) {
        show(what, systemImage: "minus.circle", tone: .removed)
    }
}

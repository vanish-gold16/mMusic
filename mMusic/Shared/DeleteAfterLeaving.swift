import Foundation

/// Удаление записи, чей экран сейчас открыт: альбом из меню его же страницы,
/// артист со своей. Сначала уходим с экрана, а запись удаляем, когда он уже
/// уехал: пока идёт анимация, экран ещё рисуется и читает поля записи,
/// а поля удалённой записи SwiftData читать не даёт — может и упасть.
///
/// `leave` пуст — экрана записи на виду нет (строка в списке), удаляем сразу.
func deleteAfterLeaving(_ leave: (() -> Void)?, delete: @escaping () -> Void) {
    guard let leave else {
        delete()
        return
    }

    leave()
    Task {
        try? await Task.sleep(for: .seconds(0.6))
        delete()
    }
}

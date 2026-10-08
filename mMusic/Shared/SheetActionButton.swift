import SwiftUI

/// Что делает кнопка листа. Слово точное, а не системное «cancel» на всё подряд:
/// по нему видно, потеряется ли что-нибудь.
enum SheetAction {
    /// Закрыть — ничего не теряется: правки здесь сохраняются сразу.
    case close
    /// Готово — правки уже на месте, лист закрывается.
    case done
    /// Сохранить набранное и закрыть.
    case save
    /// Выбросить черновик: новый альбом, новый плейлист, правку текста.
    case scrap
    /// Пропустить этот файл — откроется следующий из пачки.
    case skip

    var title: String {
        switch self {
        case .close: "Close"
        case .done: "Done"
        case .save: "Save"
        case .scrap: "Scrap"
        case .skip: "Skip"
        }
    }

    /// Главное действие листа: с ним лист заканчивают, а не бросают.
    var isPrimary: Bool {
        self == .done || self == .save
    }
}

/// Кнопка листа на языке деки: подпись разреженными заглавными, как «TEXT · REMIX»
/// под клавишами плеера, а у главного действия горит лампа цветом страницы —
/// как у «пуска» на деке. Второстепенная — тише и без лампы.
struct SheetActionButton: View {

    let action: SheetAction
    let perform: () -> Void

    init(_ action: SheetAction, perform: @escaping () -> Void) {
        self.action = action
        self.perform = perform
    }

    var body: some View {
        Button(action: perform) {
            HStack(spacing: 6) {
                if action.isPrimary {
                    // Свечение — размытой копией: тени нужен цвет, а цвет
                    // страницы здесь известен только как `.tint`.
                    Circle()
                        .fill(.tint)
                        .frame(width: 5, height: 5)
                        .background {
                            Circle()
                                .fill(.tint)
                                .frame(width: 7, height: 7)
                                .blur(radius: 3)
                        }
                }

                Text(action.title.uppercased())
                    .font(.caption2)
                    .fontWeight(.bold)
                    .tracking(1.2)
            }
            // `Color.primary`, а не `.primary`: в панели навигации кнопка красит
            // подпись в цвет страницы, и иерархический `.primary` стал бы им же.
            // Цветом страницы здесь горит только лампа.
            .foregroundStyle(action.isPrimary ? Color.primary : Color.secondary)
            .padding(.horizontal, 4)
            .contentShape(Rectangle())
        }
        .accessibilityLabel(action.title)
    }
}

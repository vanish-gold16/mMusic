import SwiftUI

/// Сама плашка: значок, текст и стекло вокруг.
struct ToastView: View {

    let toast: Toast

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: toast.systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(toast.tone.color)

            Text(toast.message)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .glassEffect(.regular, in: .capsule)
        // Тень отрывает плашку от того, что под ней: без неё на светлом фоне
        // стекло сливается с содержимым и читается как часть экрана.
        .shadow(color: .black.opacity(0.18), radius: 14, y: 6)
        .padding(.horizontal, 24)
    }
}

extension View {

    /// Плашка живёт над всем интерфейсом сразу, поэтому вешается один раз в корне.
    ///
    /// `ZStack` вокруг нужен ради анимации: она объявлена внутри оверлея, а не на
    /// всём экране — иначе появление плашки анимировало бы заодно и всё остальное,
    /// что в этот момент менялось.
    func toastOverlay(_ center: ToastCenter) -> some View {
        overlay(alignment: .top) {
            ZStack {
                if let toast = center.current {
                    ToastView(toast: toast)
                        .onTapGesture { center.hide() }
                        .transition(.move(edge: .top).combined(with: .opacity))
                        // Небольшой отступ от «острова»: вплотную плашка читается
                        // как часть системной панели, а не как ответ приложения.
                        .padding(.top, 6)
                }
            }
            .animation(.spring(response: 0.42, dampingFraction: 0.82), value: center.current)
        }
    }
}

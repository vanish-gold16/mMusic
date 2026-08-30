import SwiftUI

/// Плашка «сколько времени вы провели с артистом»: минуты крупно, всё остальное —
/// мелкой строкой под ними.
struct ArtistTimeCard: View {

    let listening: ArtistListening

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "headphones")
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 44, height: 44)
                .background(Color.accentColor.opacity(0.12), in: Circle())
                // Значок ничего не сообщает сверх текста рядом, а VoiceOver
                // читает его как «Audiobook».
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text("TIME TOGETHER")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .tracking(1.2)
                    .foregroundStyle(.secondary)

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(listening.minutes.formatted())
                        .font(.system(.title, design: .rounded))
                        .bold()
                        .monospacedDigit()

                    Text(listening.minutes == 1 ? "minute" : "minutes")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Text(details)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .glassEffect()
    }

    /// Часы и месяц первой встречи. Часы дублируют минуты намеренно:
    /// «1 240 minutes» само по себе уже не читается как время. Запусков здесь
    /// нет — их считает строка под именем артиста.
    private var details: String {
        var parts: [String] = []

        if let long = listening.hoursAndMinutes { parts.append(long) }

        if let first = listening.firstPlayedAt {
            parts.append("since \(first.formatted(.dateTime.month(.abbreviated).year()))")
        }

        return parts.joined(separator: " • ")
    }
}

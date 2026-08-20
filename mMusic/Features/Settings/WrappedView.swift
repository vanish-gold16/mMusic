import SwiftData
import SwiftUI

/// Итоги года. Крупные цифры моноширинно и почти без украшений —
/// сама статистика здесь и есть содержание.
struct WrappedView: View {

    @Query private var events: [PlayEvent]

    @State private var year = Calendar.current.component(.year, from: .now)

    private var availableYears: [Int] {
        let years = WrappedSummary.years(in: events)
        return years.isEmpty ? [Calendar.current.component(.year, from: .now)] : years
    }

    private var summary: WrappedSummary {
        WrappedSummary.make(from: events, year: year)
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 28) {
                if availableYears.count > 1 {
                    Picker("Year", selection: $year) {
                        ForEach(availableYears, id: \.self) { year in
                            Text(String(year)).tag(year)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                }

                if summary.plays == 0 {
                    LibraryEmptyState(text: "Nothing played in \(String(year)) yet")
                } else {
                    headline
                    list("Top tracks", entries: summary.topTracks)
                    list("Top artists", entries: summary.topArtists)
                    list("Top genres", entries: summary.topGenres)
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("\(String(year)) in music")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Открываем на последнем годе, где что-то слушали, а не на календарном.
            if let latest = availableYears.first, summary.plays == 0 { year = latest }
        }
    }

    private var headline: some View {
        VStack(alignment: .leading, spacing: 20) {
            bigNumber("\(summary.totalHours)", unit: summary.totalHours == 1 ? "hour" : "hours")

            HStack(spacing: 32) {
                smallNumber("\(summary.plays)", label: "plays")
                smallNumber("\(summary.activeDays)", label: "days")
                if let month = summary.busiestMonth {
                    smallNumber(String(month.name.prefix(3)), label: "busiest")
                }
            }
        }
        .padding(.horizontal)
    }

    private func bigNumber(_ value: String, unit: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(value)
                .font(.system(size: 72, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.tint)
            Text(unit)
                .font(.title3)
                .foregroundStyle(.secondary)
        }
    }

    private func smallNumber(_ value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.title2)
                .bold()
                .monospacedDigit()
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func list(_ title: String, entries: [WrappedSummary.Entry]) -> some View {
        if !entries.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(title)

                ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                    HStack(spacing: 14) {
                        Text("\(index + 1)")
                            .font(.subheadline)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(width: 20, alignment: .trailing)

                        Text(entry.name)
                            .lineLimit(1)

                        Spacer()

                        Text("\(Int(entry.seconds / 60)) min")
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
}

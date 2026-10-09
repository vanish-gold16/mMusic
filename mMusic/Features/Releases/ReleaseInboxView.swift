import SwiftUI

/// Входящие радара — всё, о чём он сообщал, по дням, свежее сверху,
/// а над ними анонсы. Открываются колокольчиком на главной и нажатием
/// на уведомление о нескольких релизах сразу.
struct ReleaseInboxView: View {

    @Environment(ReleaseRadar.self) private var radar
    @Environment(AudioPlayer.self) private var audioPlayer

    /// Когда входящие открывали до этого раза. Снимается при входе, до того
    /// как отметить всё прочитанным: точки у новых должны гореть весь визит,
    /// а не погаснуть в первый же кадр.
    @State private var seenBefore: Date?

    private struct Day: Identifiable {
        let date: Date
        let releases: [RadarRelease]
        var id: Date { date }
    }

    private var days: [Day] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: radar.inbox) { calendar.startOfDay(for: $0.arrivesAt) }
        return grouped
            .map { Day(date: $0.key, releases: $0.value) }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        let days = days
        let upcoming = radar.upcoming

        ScrollView {
            LazyVStack(alignment: .leading, spacing: 28) {
                header

                if !upcoming.isEmpty {
                    section(title: "COMING SOON", releases: upcoming)
                }

                ForEach(days) { day in
                    section(title: Self.title(of: day.date), releases: day.releases)
                }

                if days.isEmpty && upcoming.isEmpty {
                    emptyState
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .refreshable {
            await radar.checkNow()
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await radar.checkNow() }
                } label: {
                    if radar.isChecking {
                        ProgressView()
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .disabled(radar.isChecking)
                .accessibilityLabel("Check now")
            }
        }
        .onAppear {
            if seenBefore == nil { seenBefore = radar.inboxSeenAt }
            radar.markInboxSeen()
        }
    }

    // MARK: - Части

    /// «Drops» крупно и паспорт радара: за сколькими следит и когда смотрел.
    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Drops")
                .font(.system(size: 44, weight: .heavy).width(.compressed))

            Text(passport)
                .font(.caption2)
                .fontWeight(.semibold)
                .tracking(1.2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
    }

    private var passport: String {
        var parts = ["watching \(radar.watchedCount) artists"]

        if radar.isChecking {
            parts.append("checking…")
        } else if let checked = radar.lastCheckAt {
            parts.append("checked " + checked.formatted(Date.RelativeFormatStyle(presentation: .named).locale(.interface)))
        }

        return parts.joined(separator: "  ·  ").uppercased()
    }

    private func section(title: String, releases: [RadarRelease]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            CrateDivider(title: title, detail: releases.count == 1 ? "1 DROP" : "\(releases.count) DROPS", size: 22)
                .padding(.horizontal)

            ForEach(releases) { release in
                NavigationLink(value: RadarRoute.release(release.id)) {
                    InboxRow(release: release, isUnread: isUnread(release), accent: audioPlayer.accent)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Nothing new yet")
                .font(.headline)
            Text("The radar watches every artist in your library on Deezer and Apple Music. When one of them drops something — features too — it lands here.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
    }

    /// Новое — пришедшее с прошлого раза. Анонс ещё не пришёл, он не новый.
    private func isUnread(_ release: RadarRelease) -> Bool {
        guard let seenBefore else { return false }
        return !release.isQuiet && release.arrivesAt > seenBefore && release.arrivesAt <= .now
    }

    /// «TODAY», «YESTERDAY», дальше — «FRI OCT 3».
    static func title(of day: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return "TODAY" }
        if calendar.isDateInYesterday(day) { return "YESTERDAY" }
        return day.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().locale(.interface)).uppercased()
    }
}

/// Строка входящих: обложка, название, кто и когда. Новое помечено точкой.
private struct InboxRow: View {

    let release: RadarRelease
    let isUnread: Bool
    let accent: Color

    var body: some View {
        HStack(spacing: 12) {
            RemoteCover(url: release.cover, pixels: 170, cornerRadius: 3)
                .frame(width: 56, height: 56)

            VStack(alignment: .leading, spacing: 2) {
                Text(release.displayTitle)
                    .font(.system(size: 19, weight: .heavy).width(.compressed))
                    .lineLimit(1)

                Text(ReleaseCaption.who(release))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(ReleaseCaption.dayAndKind(release))
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .tracking(1.2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if isUnread {
                Circle()
                    .fill(accent)
                    .frame(width: 8, height: 8)
                    .accessibilityLabel("New")
            }
        }
        .padding(.horizontal)
        .contentShape(Rectangle())
    }
}

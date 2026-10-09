import SwiftUI

/// Полка новых поступлений на главной: что вышло у артистов из библиотеки
/// за последние две недели, а в конце — анонсы. Запечатанные пластинки
/// в ряд, как в магазине у кассы.
struct NewReleasesShelf: View {

    @Environment(ReleaseRadar.self) private var radar
    @Environment(AudioPlayer.self) private var audioPlayer

    let releases: [RadarRelease]

    private var detail: String {
        releases.count == 1 ? "1 DROP" : "\(releases.count) DROPS"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            CrateDivider(title: "NEW IN STORE", detail: detail, size: 22)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 18) {
                    ForEach(releases) { release in
                        NavigationLink(value: RadarRoute.release(release.id)) {
                            ShelfItem(release: release, accent: audioPlayer.accent)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            menu(for: release)
                        }
                    }
                }
                .padding(.horizontal)
                // Наклейка заходит за верхний край обложки — место под неё.
                .padding(.top, 12)
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
        }
    }

    @ViewBuilder
    private func menu(for release: RadarRelease) -> some View {
        if let link = release.link {
            Link(destination: link) {
                Label("Open in \(release.source.title)", systemImage: "arrow.up.right")
            }
        }
        Button {
            radar.dismiss(release.id)
        } label: {
            Label("Not interested", systemImage: "hand.thumbsdown")
        }
    }
}

/// Одна пластинка на полке: конверт, название, кто и когда.
private struct ShelfItem: View {

    let release: RadarRelease
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ReleaseSleeve(release: release, accent: accent)

            VStack(alignment: .leading, spacing: 2) {
                Text(release.displayTitle)
                    .font(.system(size: 17, weight: .heavy).width(.compressed))
                    .lineLimit(2)

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
                    .padding(.top, 2)
            }
        }
        .frame(width: 140)
        .contentShape(Rectangle())
    }
}

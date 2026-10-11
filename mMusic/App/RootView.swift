//
//  RootView.swift
//  mMusic
//
//  Created by Vanya on 22.06.2026.
//

import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    /// Треки, у которых длительность ещё не прочитана. Запрос сам сужается по мере
    /// заполнения, поэтому `task(id:)` ниже перезапускается ровно тогда, когда работа появилась —
    /// и после импорта, и после первого запуска с новым полем.
    @Query(filter: #Predicate<Track> { $0.duration == 0 }) private var tracksNeedingDuration: [Track]

    /// То же самое для формы волны — считается один раз и живёт в модели.
    @Query(filter: #Predicate<Track> { $0.waveform == nil }) private var tracksNeedingWaveform: [Track]
    
    @State private var selected: Tab = .home
    @State private var homePath: NavigationPath = .init()
    @State private var libraryPath: NavigationPath = .init()
    @State private var searchPath: NavigationPath = .init()
    
    @AppStorage(AppSettings.appearance) private var appearance = Appearance.system.rawValue
    @AppStorage(AppSettings.birthdayNotifications) private var birthdayNotifications = true
    @AppStorage(AppSettings.releaseNotifications) private var releaseNotifications = true

    @State private var audioPlayer = AudioPlayer()
    @State private var isPlayerPresented = false

    /// Общая на всё приложение «плашка о сделанном» — см. `ToastCenter`.
    @State private var toasts = ToastCenter()

    /// Радар один на всё приложение: его же будит фоновое обновление,
    /// где никакого интерфейса нет.
    @State private var radar = ReleaseRadar.shared

    @Namespace private var playerNamespace
    
    var body: some View {
        ZStack {
            tabs

            if isPlayerPresented {
                PlayerView(
                    audioPlayer: audioPlayer,
                    namespace: playerNamespace,
                    isPresented: $isPlayerPresented
                )
                .ignoresSafeArea(edges: .bottom)
                .zIndex(1)
            }
        }
        // Плашка поверх всего, включая раскрытый плеер: она сообщает о том,
        // что только что произошло, и прятаться за экранами не должна.
        .toastOverlay(toasts)
        .environment(audioPlayer)
        .environment(toasts)
        .environment(radar)
        .task {
            // Плеер живёт в @State и своего контекста не имеет — отдаём ему рабочий.
            audioPlayer.modelContext = modelContext

            guard let lastTrack = UserDefaults.standard.string(forKey: "lastTrack") else {
                return
            }
            let queueFilenames = UserDefaults.standard.stringArray(forKey: "queue") ?? [lastTrack]
            let descriptor = FetchDescriptor<Track>(
                predicate: #Predicate { queueFilenames.contains($0.filename) }
            )
            guard let tracks = try? modelContext.fetch(descriptor), !tracks.isEmpty else {
                return
            }
            let orderedTracks = queueFilenames.compactMap { filename in
                tracks.first { $0.filename == filename }
            }

            audioPlayer.restore(orderedTracks, current: lastTrack)
        }
        // Перезапускается и при смене настройки: выключили — уведомления снимаются.
        .task(id: birthdayNotifications) {
            await scheduleBirthdays()
        }
        .task(id: releaseNotifications) {
            await radar.notificationsSettingChanged()
        }
        // Нажатие на уведомление о релизах: на главную и сразу к нему.
        // `task(id:)`, а не `onChange`: уведомление могло само запустить
        // приложение, и маршрут тогда уже лежит к первому кадру.
        .task(id: radar.route) {
            guard let route = radar.route else { return }
            radar.route = nil
            selected = .home
            homePath = NavigationPath()
            homePath.append(route)
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            switch phase {
            case .active:
                // Библиотека менялась только здесь, в приложении, — снимок
                // для фоновой проверки обновляется при каждом возвращении.
                radar.refresh(from: modelContext)
            case .background:
                radar.flush()
            default:
                break
            }
        }
        .task {
            // Разовая починка номеров: у собранной раньше библиотеки нумерация
            // треков в альбомах могла съехать на единицу. Проход дешёвый и
            // молчаливый — в исправной библиотеке он ничего не меняет.
            AlbumNumbering.repair(in: modelContext)
        }
        .task {
            await TrackDurationLoader.remeasureOnce(in: modelContext)
        }
        .task(id: tracksNeedingDuration.count) {
            await TrackDurationLoader.fill(tracksNeedingDuration)
        }
        .task(id: tracksNeedingWaveform.count) {
            await TrackWaveformLoader.fill(tracksNeedingWaveform)
        }
        .tint(audioPlayer.accent)
        .animation(.easeInOut(duration: 0.6), value: audioPlayer.accent)
        .preferredColorScheme(Appearance(rawValue: appearance)?.colorScheme)
    }

    private var tabs: some View {
        TabView(selection: tabBinding) {
            SwiftUI.Tab("Home", systemImage: "house", value: Tab.home) {
                HomeTab(path: $homePath)
            }
            SwiftUI.Tab("Library", systemImage: "music.note.square.stack", value: Tab.library) {
                LibraryTab(path: $libraryPath)
            }
            SwiftUI.Tab("Search", systemImage: "magnifyingglass", value: Tab.search, role: .search) {
                SearchTab(path: $searchPath)
            }
        }
        .tabViewBottomAccessory {
            MiniPlayerView(
                audioPlayer: audioPlayer,
                namespace: playerNamespace,
                isPlayerPresented: $isPlayerPresented,
                onOpen: open
            )
        }
    }

    private var tabBinding: Binding<Tab> {
        Binding (
            get: { selected },
            set: { new in
                if new == selected { resetNav(for: new) }
                selected = new
            }
        )
    }
    
    /// Треки берутся разовой выборкой, а не `@Query`: расписание уведомлений
    /// нужно один раз на запуск, а живое наблюдение за всей библиотекой
    /// пересобирало бы корневой экран на каждое изменение.
    private func scheduleBirthdays() async {
        let tracks = (try? modelContext.fetch(FetchDescriptor<Track>())) ?? []
        let upcoming = TrackBirthday.upcoming(
            in: tracks,
            listened: TrackBirthday.listened(in: modelContext),
            limit: BirthdayNotifications.limit
        )

        await BirthdayNotifications.refresh(with: upcoming, enabled: birthdayNotifications)
    }

    /// Переход из мини-плеера — в стопку той вкладки, что сейчас открыта.
    private func open(_ route: MusicRoute) {
        switch selected {
        case .home: homePath.append(route)
        case .library: libraryPath.append(route)
        case .search: searchPath.append(route)
        }
    }

    private func resetNav(for tab: Tab) {
        switch tab {
        case .home: homePath = NavigationPath()
        case .library: libraryPath = NavigationPath()
        case .search: searchPath = NavigationPath()
        }
    }
    
}

#Preview {
    RootView()
}

//
//  ContentView.swift
//  Marlin DVR TV
//
//  Created on 2026-09-05.
//  Pass 5: the root — Home (no rail) or a screen inside the rail.
//  Pass 9: the one `RemoteHold` for the whole app lives here, with the window-level press
//  recognizer in the background; every screen reads it from the environment.
//  Pass 139: the `marlindvr://` deep links land here (`onOpenURL`) — a section, a live channel, a recording or
//  a notify (`DeepLink.swift`) — because the screen and the play request both live here. The notify banner's
//  window is installed from the background, beside the hold detector.
//

import SwiftUI

struct ContentView: View {
    let api: APIClient
    let session: ClientSession
    let home: HomeModel
    /// Pass 13: one WeatherKit read behind both the Home glance and the Weather screen.
    let weather: WeatherModel
    /// Pass 63: Search's query and results outlive its screen, which `ScreenShell` rebuilds
    /// on every visit.
    let search: GuideSearchModel
    /// Pass 72: and so does the Guide's chosen collection.
    let collections: GuideCollectionsModel
    @State private var screen: Destination? = nil
    @State private var playRequest: PlayRequest? = nil
    @State private var hold = RemoteHold()
    /// Pass 139: the banner `marlindvr://notify` draws and every failed link speaks through, and the commands a
    /// link gives a Player that is already up.
    @State private var banner = NotifyBanner()
    @State private var router = DeepLinkRouter()

    var body: some View {
        ZStack {
            Nocturne.bg
            if screen != nil {
                ScreenShell(screen: $screen, clientName: session.displayName, api: api, weather: weather, search: search, collections: collections) { request in
                    playRequest = request
                }
            } else {
                HomeView(model: home, weather: weather) { destination in
                    if destination.isBuiltNow {
                        screen = destination
                    }
                    // Settings: present as drawn, inert (DECISIONS.md). Radio went live in
                    // Pass 19 and reaches its screen through `isBuiltNow` above.
                }
            }
        }
        .foregroundStyle(Nocturne.text)
        .ignoresSafeArea()
        .environment(hold)
        .background { RemoteHoldDetector(hold: hold).frame(width: 1, height: 1) }
        .background { NotifyBannerWindow(banner: banner).frame(width: 1, height: 1) }
        .onOpenURL { open($0) }
        // The press recognizer is on the window, so it would still fire while the Player is
        // up; the screens underneath must not act on it.
        .onChange(of: playRequest?.id) { _, id in hold.suspended = id != nil }
        // Sweep 3: the Player over everything; dismissing it stops its session.
        .fullScreenCover(item: $playRequest) { request in
            PlayerScreen(request: request, api: api, clientName: session.displayName, router: router) {
                playRequest = nil
            }
            // Menu is handled by the Player itself (stop, then dismiss) rather than by the
            // system's cover dismissal, which also reached the screen underneath.
            .interactiveDismissDisabled(true)
        }
    }

    /// Pass 139: a `marlindvr://` link — from Home Assistant's Apple TV integration, or anything else that opens
    /// URLs on this Apple TV. A play link while the Player is up is handed to the Player to swap in place; a
    /// section link closes the Player first (owner's B-a); whatever cannot be followed is said on the banner and
    /// nothing else changes (owner's C-a).
    private func open(_ url: URL) {
        print("[deeplink] \(url.absoluteString)")
        let link: DeepLink
        do {
            link = try DeepLink.parse(url)
        } catch {
            banner.show("\(error)")
            return
        }
        switch link {
        case .notify(let text):
            banner.show(text)
        case .section(let destination):
            if playRequest != nil { router.send(.close) }
            screen = destination
            print("[deeplink] section → \(destination?.rawValue ?? "home")")
        case .live, .recording:
            Task {
                do {
                    let request = try await link.resolvePlay(api: api)
                    if playRequest != nil {
                        print("[deeplink] Player up — swapping in \(request.title)")
                        router.send(.play(request))
                    } else {
                        print("[deeplink] starting \(request.title)")
                        playRequest = request
                    }
                } catch {
                    banner.show("\(error)")
                }
            }
        }
    }
}

#Preview {
    let api = APIClient()
    ContentView(api: api, session: ClientSession(api: api), home: HomeModel(api: api), weather: WeatherModel(), search: GuideSearchModel(api: api), collections: GuideCollectionsModel(api: api))
}

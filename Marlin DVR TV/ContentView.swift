//
//  ContentView.swift
//  Marlin DVR TV
//
//  Created on 2026-09-05.
//  Pass 5: the root — Home (no rail) or a screen inside the rail.
//  Pass 9: the one `RemoteHold` for the whole app lives here, with the window-level press
//  recognizer in the background; every screen reads it from the environment.
//

import SwiftUI

struct ContentView: View {
    let api: APIClient
    let session: ClientSession
    let home: HomeModel
    @State private var screen: Destination? = nil
    @State private var playRequest: PlayRequest? = nil
    @State private var hold = RemoteHold()

    var body: some View {
        ZStack {
            Nocturne.bg
            if screen != nil {
                ScreenShell(screen: $screen, clientName: session.displayName, api: api) { request in
                    playRequest = request
                }
            } else {
                HomeView(model: home) { destination in
                    if destination.isBuiltNow {
                        screen = destination
                    }
                    // Favorites, Weather, Radio, Settings: present as drawn, inert (DECISIONS.md).
                }
            }
        }
        .foregroundStyle(Nocturne.text)
        .ignoresSafeArea()
        .environment(hold)
        .background { RemoteHoldDetector(hold: hold).frame(width: 1, height: 1) }
        // The press recognizer is on the window, so it would still fire while the Player is
        // up; the screens underneath must not act on it.
        .onChange(of: playRequest?.id) { _, id in hold.suspended = id != nil }
        // Sweep 3: the Player over everything; dismissing it stops its session.
        .fullScreenCover(item: $playRequest) { request in
            PlayerScreen(request: request, api: api, clientName: session.displayName) {
                playRequest = nil
            }
            // Menu is handled by the Player itself (stop, then dismiss) rather than by the
            // system's cover dismissal, which also reached the screen underneath.
            .interactiveDismissDisabled(true)
        }
    }
}

#Preview {
    let api = APIClient()
    ContentView(api: api, session: ClientSession(api: api), home: HomeModel(api: api))
}

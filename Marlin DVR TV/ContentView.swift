//
//  ContentView.swift
//  Marlin DVR TV
//
//  Created on 2026-09-05.
//  Pass 5: the root — Home (no rail) or a screen inside the rail.
//

import SwiftUI

struct ContentView: View {
    let session: ClientSession
    let home: HomeModel
    @State private var screen: Destination? = nil

    var body: some View {
        ZStack {
            Nocturne.bg
            if screen != nil {
                ScreenShell(screen: $screen, clientName: session.displayName)
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
    }
}

#Preview {
    let api = APIClient()
    ContentView(session: ClientSession(api: api), home: HomeModel(api: api))
}

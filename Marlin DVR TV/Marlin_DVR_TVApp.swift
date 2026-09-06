//
//  Marlin_DVR_TVApp.swift
//  Marlin DVR TV
//
//  Created on 2026-09-05.
//  Pass 5: one API client, the client session (register/ping on every launch), Home's model.
//

import SwiftUI

@main
struct Marlin_DVR_TVApp: App {
    private let api: APIClient
    @State private var session: ClientSession
    @State private var home: HomeModel

    init() {
        let api = APIClient()
        self.api = api
        _session = State(initialValue: ClientSession(api: api))
        _home = State(initialValue: HomeModel(api: api))
    }

    var body: some Scene {
        WindowGroup {
            ContentView(api: api, session: session, home: home)
                .task { await session.start() }
        }
    }
}

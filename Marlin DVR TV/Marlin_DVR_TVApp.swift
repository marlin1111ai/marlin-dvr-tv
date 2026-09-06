//
//  Marlin_DVR_TVApp.swift
//  Marlin DVR TV
//
//  Created on 2026-09-05.
//  Pass 5: one API client, the client session (register/ping on every launch), Home's model.
//  Pass 13: one WeatherModel too — Home's glance and the Weather screen share it, so
//  WeatherKit is read once and the location prompt is shown once.
//

import SwiftUI

@main
struct Marlin_DVR_TVApp: App {
    private let api: APIClient
    @State private var session: ClientSession
    @State private var home: HomeModel
    @State private var weather = WeatherModel()

    init() {
        let api = APIClient()
        self.api = api
        _session = State(initialValue: ClientSession(api: api))
        _home = State(initialValue: HomeModel(api: api))
    }

    var body: some Scene {
        WindowGroup {
            ContentView(api: api, session: session, home: home, weather: weather)
                .task { await session.start() }
        }
    }
}

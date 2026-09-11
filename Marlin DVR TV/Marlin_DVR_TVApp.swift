//
//  Marlin_DVR_TVApp.swift
//  Marlin DVR TV
//
//  Created on 2026-09-05.
//  Pass 5: one API client, the client session (register/ping on every launch), Home's model.
//  Pass 13: one WeatherModel too — Home's glance and the Weather screen share it, so
//  WeatherKit is read once and the location prompt is shown once.
//  Pass 63: one GuideSearchModel, so a search survives leaving the Search screen and coming
//  back to it (`ScreenShell` rebuilds its content on every visit).
//

import SwiftUI

@main
struct Marlin_DVR_TVApp: App {
    private let api: APIClient
    @State private var session: ClientSession
    @State private var home: HomeModel
    @State private var weather = WeatherModel()
    @State private var search: GuideSearchModel

    init() {
        let api = APIClient()
        self.api = api
        _session = State(initialValue: ClientSession(api: api))
        _home = State(initialValue: HomeModel(api: api))
        _search = State(initialValue: GuideSearchModel(api: api))
    }

    var body: some Scene {
        WindowGroup {
            ContentView(api: api, session: session, home: home, weather: weather, search: search)
                .task { await session.start() }
        }
    }
}

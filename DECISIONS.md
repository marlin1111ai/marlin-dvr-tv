# DECISIONS — Marlin DVR TV

## 2026-09-05

- Name: Marlin DVR TV.
- Repo: `marlin1111ai/marlin-dvr-tv`, Public, SSH remote (`git@github.com:marlin1111ai/marlin-dvr-tv.git`).
- Folder: `~/Xcode/Marlin DVR TV`.
- Platform: tvOS + SwiftUI, built in Xcode on the Mac.
- The server repo (`marlin1111ai/marlin-dvr`) is read-only reference via a local clone at `~/Xcode/marlin-dvr-reference` and is never edited from this project.
- Server changes, if ever needed, are raised as decisions for the marlin-dvr project.
- Rules (the same as marlin-dvr): recon before build; scope lock; no installs without owner authorization; separate push gate for code the owner tests; nothing force-pushed ever; no secrets in the repo, logs, or reports.
- Deployment target stays tvOS 18.0. Both Apple TVs run tvOS 26.6 (owner, 2026-09-05).
- Playback: the app plays video via HLS output from the Marlin DVR server (contract: HLS-CLIENT-API.md in marlin-dvr, server 1.1.0). Raised in the marlin-dvr project; built there in Passes 14–19.

## 2026-09-05 (design)

- Approved UI design: design/ ("Marlin DVR TV.dc.html", Claude Design export ATV-DVR.zip, Nocturne design system). Read-only, never edited; this project's screens are built to it.
- Variants chosen by the owner: 1b left rail navigation; 2a tile-grid Home (launcher, no rail on Home); 3a comfortable guide (8 rows, 2-hour window, forward-only from the current half hour); 4a poster 2:3 shelf cards.
- In scope now: Home, On Now, Guide (with the airing sheet: Record Now, Series Pass, Watch live), On Later, Recordings (shelves + show detail), Cameras, Player (states 6a–6h). Designed but future, not to be built until the owner says so: Favorites, Weather (WeatherKit), Radio, Settings.
- Facts of the design the app implements itself: resume position kept per Apple TV; DRM channels hidden from lists; the client name shown in the UI is the name this Apple TV registered under.

## 2026-09-05 (sweep 1)

- Build plan: the four sweeps of the Pass 4 report §4, in that order. Pass 5 is sweep 1 (foundation, rail, Home).
- Type and icons: the system font (San Francisco) at the design's sizes and weights, and SF Symbols mapped to the design's Phosphor icons. Nothing bundled.
- Server base URL: a single constant, http://192.168.1.250:8090 (no Settings screen yet).
- Plain HTTP: the App Transport Security exception is NSAllowsLocalNetworking, verified on the Apple TV in Pass 5. Not NSAllowsArbitraryLoads; if the device refuses the connection that is a stop-and-report, not a switch.
- Client id persists in UserDefaults. The client registers with name = the Apple TV's device name, app = "Marlin DVR TV" + the app version, type = "Apple TV", os = the tvOS version. Ping on every launch; re-register on a 404.
- Future screens (Favorites, Weather, Radio, Settings): tiles and rail entries present as drawn, inert. The Home weather glance is omitted until Weather is built.
- Home greeting name: the fixed string "Marlin".

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
- Client name: each Apple TV is renamed once by the owner on the server's Clients page; the app shows the name the server holds. No device-name entitlement.

## 2026-09-06 (sweep 2)

- Owner acceptance: sweep 2 tested on Home Theater 2026-09-06, all screens work.
- Guide click behaviour (owner, 2026-09-06): clicking a program that is airing now plays it immediately; the airing sheet opens on click only for programs that have not started. Press-and-hold on a current cell opens the sheet (record/pass). Built in sweep 3 with the Player.
- Live pause in the first minute: AVPlayer will not pause a live HLS stream until its seekable window is ~60 s (Pass 7B). The app handles Select itself while the window is short — pauses and holds the position — and defers to AVPlayer's own handling once the window is long enough. Owner decision 1a.
- Owner acceptance: sweep 3 (Player, incl. Pass 7C live pause) tested on Home Theater 2026-09-06 — live pause from the first second, resume from the pause point, recording resume, camera: all pass.

## 2026-09-06 (sweep 4 + fixes)

- Owner acceptance: Passes 8, 9, 10 and 10B tested on Home Theater 2026-09-06 — all accepted. Pushed together in Pass 11.
- Episode menu (owner, 2026-09-06): Mark unwatched and the recording Favorite flag are dropped. Click and hold an episode offers **Keep** and **Delete**, and nothing else.
- Channel favourites (owner, 2026-09-06): a channel is favourited by click-and-hold on its cell in the Guide's left column (`PUT /api/sources/{id}/lineup/{guid}` with `favorite`). There is no favourite control on the airing sheet.
- "Watch live" appears on the airing sheet only while the programme is airing at the current time. A live session plays what is on now (stream.go:214-218), so the button is meaningless on a future airing.
- When a show already has a series pass, the sheet offers **Edit series pass** instead of "Record the series". Whether a pass exists is read from `GET /api/passes` (matched on seriesId, falling back to title as the server does); the server's 409 is never shown raw.
- Favorites screen is built (owner, 2026-09-06): the rail's Favorites entry lists the server's favourite channels with what is on now, and a click plays the channel live.
- Manage DVR is built and lives in the **bottom slot of the rail** (owner, 2026-09-06): storage, Scheduled Recordings (with Cancel recording and Manage pass), Your Passes (the pass editor), and Trash (Restore per row, Empty Trash behind a confirm). The design's rail carries no settings-area entry of its own — Settings is a Home tile only — so the bottom of the rail is that slot.
- Weather, Radio and Settings stay parked: present as drawn and inert until the owner says otherwise.

## 2026-09-06 (Pass 13 — Weather and radar)

- **Radar is IN**, as an addition to the approved design (owner, 2026-09-06). The design draws no radar and no map anywhere (Pass 12 §1.1); this is a deliberate addition to it.
- **The radar view is built to the app's look, not designed first** — the same route as Manage DVR and Favorites (COLD-START.md, Pass 10: "Neither screen is in the approved design; both are built to the app's look").
- **The daily list is 5 rows** — the count the design ships (`wxDaily`, dc:1390-1394) — not the render hint's 7 (dc:742) and not WeatherKit's 10. This settles Pass 12 Open Question 2.
- **Location: one-shot `requestLocation` with the system prompt, cached after the first grant.** tvOS has no continuous updates (`startUpdatingLocation` is `API_UNAVAILABLE(tvos)`). This settles Pass 12 Open Question 3.
- **Tile source: whatever step 1 finds.** Step 1 read the owner's iPhone weather app and **found none** — its Maps tab is a "Coming soon" placeholder (`Marlin Weather/MapsView.swift:5-7`). The radar view is built and works; it has no source to draw, and says so on screen. A provider is the owner's to name (Pass 13 Open Question 1).
- **WeatherKit is not enabled for `com.marlin1111.MarlinDVRTV`** (Pass 13 step 2, a stop-and-report). The app signs with the team wildcard profile, which carries no `com.apple.developer.weatherkit`, and on the Apple TV every WeatherKit call fails with `xpcConnectionFailed … com.apple.weatherkit.authservice … Sandbox restriction`. Pass 13 was forbidden to add, request or work around the entitlement, and did not. The Weather screen and the Home glance are built and reachable; both print that sentence instead of data until the capability is enabled.
- **The place name is the town and state only** ("Fallston, MD"), read from `CLPlacemark.locality` + `.administrativeArea`. MapKit's tvOS 26 replacement `MKReverseGeocodingRequest` returns the **street address of the house** in its `shortAddress`, which is neither what the design draws nor something to put on a television, so it is not used.

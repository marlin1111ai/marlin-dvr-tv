# Pass 5 — Sweep 1: foundation, rail, Home (code; separate push gate) — 2026-09-05

The first code pass: the foundation named in the Pass 4 report §4 sweep 1, the rail of frame 1b and Home of frame 2a, built to `design/Marlin DVR TV.dc.html` and the Nocturne tokens. Built with both COLD-START lines, run on the tvOS simulator and on the "Home Theater" Apple TV, with the evidence in §6. **Committed locally only; nothing was pushed** — the owner tests on the Apple TV first and authorises the push.

Network use in this pass, all against `http://192.168.1.250:8090`: GET `/api/status`, `/api/channels`, `/api/clients`, `/api/logs`, and the app's own GETs (`/api/channels`, `/api/guide/now`, `/api/schedule`, `/api/library`, `/api/cameras`) plus `POST /api/clients/register` (once from the simulator, once from Home Theater) and `POST /api/clients/{id}/ping` (once from the simulator). No play session, no PUT, no DELETE, no record, no settings. Nothing installed on the Mac; no packages; no bundled fonts or icons.

Citation keys: `dc:NNN` = a line of `design/Marlin DVR TV.dc.html`; `Pass 4 §n` = `reports/2026-09-05-pass4-design-and-build-recon.md`; `file:line` = `cmd/marlin-dvr/` in the reference clone at `eef49e8`; `contract §n` = `HLS-CLIENT-API.md`.

## 1. Decisions recorded (step 1)

`DECISIONS.md` gained `## 2026-09-05 (sweep 1)` with seven bullets: the four-sweep build plan (this is sweep 1); system font and SF Symbols, nothing bundled; the single base URL constant; `NSAllowsLocalNetworking` verified on the device, never switched to arbitrary loads on my own; the client id in UserDefaults and the register fields; future screens present as drawn and inert with the Home weather glance omitted; the fixed greeting name "Marlin". Nothing else in the file changed.

## 2. App Transport Security (step 2)

- `Info.plist` (new, at the project root, 287 bytes): one key, `NSAppTransportSecurity` → `{NSAllowsLocalNetworking: true}`. `plutil -lint` OK.
- `Marlin DVR TV.xcodeproj/project.pbxproj`: one line added to each of the target's Debug and Release configurations, `INFOPLIST_FILE = Info.plist;`. `GENERATE_INFOPLIST_FILE = YES` stays, so Xcode merges the file's key into the generated plist. No other setting changed (`git diff` shows the two added lines only).
- Why the file sits at the root and not in `Marlin DVR TV/`: the sources folder is a file-system-synchronized group (`PBXFileSystemSynchronizedRootGroup`, pbxproj line 14), which adds every file in it to the target's resources; an `Info.plist` there failed the build with `Multiple commands produce …/Marlin DVR TV.app/Info.plist` (the first build attempt, log `build-sim-scheme.log` in the session scratchpad). Excluding it would have meant adding a membership-exception set to the project; placing it outside the synchronized folder needed only the one setting.
- Verified in the built product: `plutil -extract NSAppTransportSecurity json -o - "…/Debug-appletvsimulator/Marlin DVR TV.app/Info.plist"` → `{"NSAllowsLocalNetworking":true}`. Verified on the device: see §6.4 — the register POST and five GETs from Home Theater answered 200.

## 3. What was built, file by file (steps 3–5)

All new files are in `Marlin DVR TV/` and were picked up by the synchronized group; no target membership was edited. Line counts by `wc -l`.

| File | Step | What it is |
|---|---|---|
| `Theme.swift` (117 lines) | 4 | `Nocturne`: bg `#161826`, surface `#232532`, text `#e9e9ed`, accent `#9184d9`, divider (text at 16%), section; the accent steps 200/300/600/700/900 and neutral steps 100–900 that frames 1b and 2a use (`_ds/…/styles.css`); radii 4/8/14; the `--space-*` scale; `Layout` (60 pt vertical and 80 pt horizontal margins, rail 372 pt expanded and 180 pt collapsed, 56 pt content clearance — `dc:33-35`, `dc:58`, `dc:74`, `dc:180`); `TextSize` (23 floor, 26, 29 body, 31, 38, 52, 60); `Focus` (4 pt ring, 6 pt lift, black-70% shadow — `dc:1122`). `Color(hex:)`, `Color(hexString:)` for the server's `logoBg`, and `Font.nocturne(size, weight)` on the system font. |
| `ServerAPI.swift` (104) | 3 | `ServerConfig.baseURL` = `http://192.168.1.250:8090` (owner decision) and `hostLabel` for the rail footer; `resolve(_:)` turns a server-relative path or provider URL into an absolute URL (Pass 2 §5 item 3). `APIError` with `kind` (`http(status)`, `transport`, `decoding`, `badResponse`), the server's plain-text `message`, and the path. `APIClient` with `get` and `post`: JSON decode; a non-2xx answer becomes `APIError.http` carrying the body text (the server answers errors with `http.Error`, Pass 2); no retries, no caching beyond URLSession's defaults. |
| `Models.swift` (307) | 3 | `Decodable` shapes with the server's JSON keys: `MergedChannel` + `ChannelsResponse` (sources.go:103-122); `Program` (guide.go:18-38); `GuideNowItem` + `GuideNowResponse` (guide.go:671-676; the embedded channel is decoded from the same container); `GuideBlock`, `GuideRow`, `GuideTimeSlot`, `GuideResponse` (guide.go:550-563, 661-662); `LaterItem`, `LaterSection`, `LaterResponse` (guide.go:699-708); `Job`, `ScheduleGroup`, `ScheduleResponse` (passes.go:53-77, 858-861, 878); `ShowSummary`, `LibrarySection`, `LibraryRoot`, `LibraryResponse` (library.go:369-378, 88-94, 460-467); `Episode` (the server's `episodeView`, library.go:35-49, 68-79, 486-500), `ShowInfo`, `ShowResponse` (library.go:623-639); `Camera`, `CamerasResponse` (cameras.go:23-39, 288); `ClientRecord` (the server's `clientView`, clients.go:14-27, 179-187); `PlaySession` and `PlayInfo` (stream.go:295, 455-491) as models only. Go `time.Time` fields are kept as strings. |
| `ChannelFilter.swift` (108) | 3 | The DRM rule: `playable` on arrays of channels, on-now items, guide rows and jobs drops `drm == true`. Typed calls on `APIClient` — `channels`, `onNow`, `guide`, `later`, `schedule`, `library`, `show(id:)`, `cameras` — apply it, so no caller sees a DRM channel. |
| `ServerImage.swift` (63) | 3 | `ServerImage`: `AsyncImage` on the resolved URL, the fallback view while loading, when the path is empty, or on failure. `InitialsTile`: the channel initials on the `logoBg` colour (frame 1b card, `dc:88`). `ChannelLogo`: the provider logo with the initials tile as fallback. |
| `ClientSession.swift` (102) | 3 | `@Observable ClientSession`: id under `UserDefaults` key `marlinClientId`; `start()` pings `POST /api/clients/{id}/ping` with `{app, os, type}` when an id is stored, registers via `POST /api/clients/register` with `{name: UIDevice.current.name, app: "Marlin DVR TV " + CFBundleShortVersionString, type: "Apple TV", os: "tvOS " + systemVersion}` when there is none or the ping answers 404 (clients.go:262-266; contract §1); a transport failure keeps the id and does not register. `displayName` is the registered name for the rail footer. Prints one `[client]` line per outcome. |
| `Destination.swift` (105) | 5 | The ten destinations; `railOrder` (nine, frame 1b `dc:1133-1137`) and `homeTiles` (nine, frame 2a `dc:1353-1362`); labels; SF Symbols for the Phosphor icons (`house`, `star`, `tv`, `square.grid.2x2`, `clock`, `film`, `video`, `cloud.sun`, `radio`; tile On Now `play.circle`, Settings `slider.horizontal.3`); tile tints from the design data; `isBuiltNow` (On Now, Guide, On Later, Recordings, Cameras); static sub-lines for the inert tiles. |
| `RailView.swift` (170) | 5 | `ShellFocus` (`rail(Destination)` or `content`); `BareButtonStyle` (draws only the label so the design's focus treatment is the only one); `RailView`: brand bar + "Marlin", the nine items, the footer with the registered name and `192.168.1.250:8090` (`dc:69-72`), 372 pt with labels when `expanded`, 180 pt icon strip otherwise, the surface gradient and the 1 pt divider (`dc:58`, `dc:180`), animated; `RailItem`: active = accent 14% fill, accent-700 hairline, accent-200 ink; focused = 4 pt accent ring, accent 16% fill, text ink; otherwise neutral-500 (`dc:1138-1149`). |
| `HomeView.swift` (233) | 5 | `@Observable HomeModel`: loads the five sub-lines concurrently, each endpoint once, `unavailable` on failure, `…` while loading. `HomeView`: the accent-900 radial wash (`dc:121`), the tv glyph, greeting by hour at 60 pt light, "Marlin" at 38 pt medium, the date-and-time line updating every minute ("Saturday, September 5 · 11:27 PM", `dc:132`), an empty 520 pt slot where the weather glance goes, and three rows of three `HomeTile`s (`dc:146-158`): tinted gradient, icon box, 38 pt label, 26 pt sub-line; focused tile = 4 pt accent ring, 6 pt lift, ambient shadow (`dc:1366-1367`). Default focus on Guide. Selecting a built-now tile opens its screen; the four inert tiles do nothing. |
| `ScreenShell.swift` (75) | 5 | `ScreenShell`: the rail beside the content with the design's margins (`dc:74`); the rail is expanded while a rail item has focus and collapsed while the content has it; default focus in the content; Menu (`onExitCommand`) returns to Home (frame 3c footer, `dc:353`). `PlaceholderScreen`: the screen's title at 52 pt and one line saying sweep 2 fills it. |
| `ContentView.swift` (rewritten, 36) | 5 | The root: Home when no screen is chosen, otherwise the shell; `ignoresSafeArea` so the design's 60/80 pt margins are applied exactly once. |
| `Marlin_DVR_TVApp.swift` (rewritten, 28) | 3, 5 | One `APIClient`, the `ClientSession` and `HomeModel`; `.task { await session.start() }` on the root, so every launch pings (or registers). |

Not built, by the scope lock: any sweep-2 content, the Player, server writes beyond register/ping, Top Shelf or icon artwork, behaviour for Favorites/Weather/Radio/Settings, caching, retries. Nothing in `Assets.xcassets` changed.

## 4. Design tokens carried (step 4)

From `design/_ds/nocturne-…/styles.css` and `_ds_manifest.json`: the role colours, the ramp steps used by frames 1b and 2a, the radii and the spacing scale. From the design page header (`dc:33-35`): 1920 × 1080 at 1×, 60/80 pt margins, 29 pt body, 23 pt floor, one focused element with a 4 pt accent ring, a lift and an ambient shadow. Frame-specific sizes (rail widths, 56 pt content clearance, 34/36 pt icons, 38/52/60 pt headings, the tile gradient formula `color-mix(tint 55%, bg)`) are taken from the frames' inline styles and cited in the code. The system font stands in for Inter and SF Symbols for Phosphor (owner decision).

## 5. Screens (step 5)

- **Rail (1b):** nine destinations in the design's order; labels shown while focus is in the rail; icon strip while focus is in the content; not shown on Home. Home in the rail returns to Home; On Now, Guide, On Later, Recordings and Cameras switch the placeholder; Favorites, Weather and Radio are inert.
- **Home (2a):** greeting, "Marlin", date and time, nine tiles. Live sub-lines: Guide = playable channel count; On Now = programs count after the DRM filter; On Later = `/api/schedule` `count`; Recordings = `/api/library` `recordings` + "N recording now" from schedule jobs with `status == "Recording"`; Cameras = `/api/cameras` `online` of `count`. The four inert tiles carry a wording sub-line, not a number (no fabricated data). Selecting one of the five built-now tiles opens the titled placeholder in the rail shell.

## 6. Test evidence (step 6)

### 6.1 Builds — both COLD-START lines

```
$ xcodebuild -project "Marlin DVR TV.xcodeproj" -scheme "Marlin DVR TV" -destination 'generic/platform=tvOS Simulator' build
(exit 0)
767: … appintentsmetadataprocessor[…] warning: Metadata extraction skipped. No AppIntents.framework dependency found.
802: ** BUILD SUCCEEDED **

$ xcodebuild -project "Marlin DVR TV.xcodeproj" -target "Marlin DVR TV" -sdk appletvsimulator -configuration Debug build
(exit 0)
714: … appintentsmetadataprocessor[…] warning: Metadata extraction skipped. No AppIntents.framework dependency found.
735: warning: ONLY_ACTIVE_ARCH=YES requested with multiple ARCHS and no active architecture could be computed; building for all applicable architectures
736: ** BUILD SUCCEEDED **
```

No Swift errors or warnings; the two warnings are Xcode's (AppIntents metadata, and the target/SDK form's architecture note). The first attempt of line 1 failed on the Info.plist location (§2) and was fixed before these runs.

Device build (Home Theater; signing is automatic with the project's team; the certificate holder's name is left as printed):

```
$ xcodebuild -project "Marlin DVR TV.xcodeproj" -scheme "Marlin DVR TV" -destination 'platform=tvOS,name=Home Theater' -allowProvisioningUpdates build
(exit 0)
452:     Signing Identity:     "Apple Development: wayne Coburn (K876F53J4H)"
453:     Provisioning Profile: "tvOS Team Provisioning Profile: *"
488: ** BUILD SUCCEEDED **
```

### 6.2 Simulator — install, launch, register; relaunch, ping

Simulator: Apple TV 4K (3rd generation), tvOS 26.5, booted with `xcrun simctl boot`. Install and first launch with the console captured:

```
$ xcrun simctl install booted ".../Debug-appletvsimulator/Marlin DVR TV.app"
installed
$ xcrun simctl launch --console-pty booted com.marlin1111.MarlinDVRTV
[client] registered: id=cmtp93dxwb8c6f8 name=Apple TV 4K (3rd generation) app=Marlin DVR TV 1.0 type=Apple TV os=tvOS 26.5 ip=192.168.1.10
```

Terminate and relaunch (the id is now in UserDefaults):

```
$ xcrun simctl terminate booted com.marlin1111.MarlinDVRTV
$ xcrun simctl launch --console-pty booted com.marlin1111.MarlinDVRTV
[client] ping ok: id=cmtp93dxwb8c6f8 name=Apple TV 4K (3rd generation) app=Marlin DVR TV 1.0 type=Apple TV os=tvOS 26.5 ip=192.168.1.10
```

### 6.3 Screenshots (simulator, `xcrun simctl io booted screenshot`, downscaled from 3840×2160 to 1920×1080 with `sips -Z 1920`)

Key presses were sent to the Simulator window with `osascript` (`System Events` key codes: Return = select, Left, Escape = Menu).

- `reports/assets/pass5/sim-home.png` — Home after launch: "Good evening / Marlin", "Saturday, September 5 · 11:27 PM", the nine tiles with live sub-lines: **45 channels live**, **45 programs live**, **0 upcoming**, **3 recordings · 0 recording now**, **1 of 1 online**; Favorites "Favorite channels", Weather "Local weather", Radio "Stations", Settings "Server, tuners, storage"; Guide focused (accent ring, lift, shadow).
- `reports/assets/pass5/sim-rail-collapsed.png` — after Select on Guide: the placeholder "Guide" screen with the rail collapsed to the 180 pt icon strip, the Guide icon marked active.
- `reports/assets/pass5/sim-rail-expanded.png` — after Left: focus moved into the rail (the focus engine landed on Recordings, the nearest item), the rail expanded to 372 pt with labels, Guide still marked active, the footer showing the registered name "Apple TV 4K (3rd generation)" and `192.168.1.250:8090`.
- `reports/assets/pass5/sim-home-after-menu.png` — after Escape (Menu): back on Home.

### 6.4 Home Theater — install, launch, and the server's view

```
$ xcrun devicectl device install app --device [REDACTED] ".../Debug-appletvos/Marlin DVR TV.app"
App installed:
• bundleID: com.marlin1111.MarlinDVRTV
• installationURL: file:///private/var/containers/Bundle/Application/[REDACTED]/Marlin%20DVR%20TV.app/
$ xcrun devicectl device process launch --device [REDACTED] com.marlin1111.MarlinDVRTV
Launched application with com.marlin1111.MarlinDVRTV bundle identifier.
$ xcrun devicectl device info details --device [REDACTED] | grep -E 'name:|productType|osVersionNumber'
    • productType: AppleTV14,1
    • name: Home Theater
    • osVersionNumber: 26.6
```

Server log lines received via `GET /api/logs?since=1266` (the app's traffic from the device at 192.168.1.30; the simulator's traffic comes from the Mac at 192.168.1.10):

```
seq=1265 23:27:06.837 INFO [SYS]  client registered: Apple TV 4K (3rd generation) (Apple TV) from 192.168.1.10
seq=1266 23:27:06.837 INFO [HTTP] POST /api/clients/register 200
seq=1268 23:27:06.896 INFO [HTTP] GET /api/guide/now 200
seq=1279 23:28:37.140 INFO [SYS]  client registered: Apple TV (Apple TV) from 192.168.1.30
seq=1280 23:28:37.140 INFO [HTTP] POST /api/clients/register 200
seq=1281 23:28:37.152 INFO [HTTP] GET /api/cameras 200
seq=1282 23:28:37.154 INFO [HTTP] GET /api/guide/now 200
seq=1283 23:28:37.154 INFO [HTTP] GET /api/schedule 200
seq=1284 23:28:37.154 INFO [HTTP] GET /api/library 200
seq=1285 23:28:37.154 INFO [HTTP] GET /api/channels 200
```

`GET /api/clients` afterwards (the two Apple TV rows; nine pre-existing browser rows omitted):

```
count 11, online 2
id=cmtp95bma18e6ad name='Apple TV'                    app='Marlin DVR TV 1.0' type='Apple TV' os='tvOS 26.6' ip=192.168.1.30 online=True location=Local lastSeen=now
id=cmtp93dxwb8c6f8 name='Apple TV 4K (3rd generation)' app='Marlin DVR TV 1.0' type='Apple TV' os='tvOS 26.5' ip=192.168.1.10 online=True location=Local lastSeen=1 min ago
```

Reading: the plain-HTTP connection from the Apple TV works under `NSAllowsLocalNetworking` (the POST and the five GETs answered 200, and the client row records the device's LAN address). The app is left installed and was left running on Home Theater for the owner's test. **Finding:** the device registered as **"Apple TV"**, not "Home Theater". `UIDevice.current.name` returns the model name on current tvOS unless the app carries the user-assigned-device-name entitlement, which Apple grants on request; the device's real name is visible to the Mac (`devicectl` above) but not to the app. Recorded as Open Question 1; not changed on my own.

### 6.5 The DRM count

`GET /api/channels` (a read, the same call the app makes), summarised by hand from the JSON:

```
count field: 50   sources: ['HDFX-4K (10A75953)', 'Philo']
total 50, drm 5, non-drm 45
antenna source (HDFX-4K): 21 channels, 5 with drm=true → 16 playable
  DRM: 103.1 KYW-TV, 110.1 WCAU-TV, 129.1 WTXFDT, 157.1 WPSG, 165.1 WUVP-DT
Philo source: 29 channels, none DRM
```

The Home tile reads **45 channels live** (`sim-home.png`), i.e. 50 minus the 5 DRM channels; the "16 expected of 21" holds for the antenna source alone. The On Now tile shows 45 programs for the same reason. Whether the tile should count all sources or the antenna only is Open Question 2.

## Open Questions

1. **Registered name.** The Apple TV registered as "Apple TV" because `UIDevice.current.name` is the model name without the `com.apple.developer.device-information.user-assigned-device-name` entitlement (an Apple-approved capability, and a project/entitlements change). Options: request the entitlement; let the owner rename the client on the server's Clients page (`PUT /api/clients/{id}`, which the app then shows in its rail footer); or a name entered in a future Settings screen. Which?
2. **Guide tile count.** The design says "16 channels live" and "16 playable channels · 5 DRM channels hidden" (`dc:37`), which matches the antenna source alone; the server also serves 29 Philo channels, so the app shows 45. All sources, or antenna only, for the tile (and later for On Now and the Guide)?
3. **Inert tile sub-lines.** The design draws "6 favorite channels", "72° · clear now", "6 stations"; the app shows wording without numbers ("Favorite channels", "Local weather", "Stations") so nothing is fabricated. Keep, or show the live favourites count (`/api/channels?filter=Favorites`) now?
4. **"0 recording now".** The Recordings sub-line always carries the count, as specified; with nothing recording it reads "3 recordings · 0 recording now". Drop the clause when it is zero?
5. **Clock slot.** The weather glance was omitted, but its 520 pt slot is kept so the clock sits where the design places it. Confirm, or let the clock move right.
6. **Ping body.** The ping sends `{app, os, type}` so the Clients page follows app-version updates; the server treats the body as optional (clients.go:262-285). Keep?
7. **COLD-START.md** still says "What is NOT built: the app" and points "Next step" at the sweeps; no step in this pass named it, so it was left. Update it in the push pass?
8. **Rail focus entry.** Moving Left from the content lands on the geometrically nearest rail item (Recordings in the screenshot), not the active one. The design does not say which; acceptable?
9. **Home reload.** Returning to Home re-runs the five requests (SwiftUI re-creates the view); harmless and no caching was asked for, but it doubles the requests per visit. Leave until sweep 2?
10. **Screenshots on the device** cannot be captured from the Mac; the device evidence is the server's log and client row plus the owner's own look at Home Theater. Sufficient for the push gate?

## SCOPE CHECK — every file created or touched

| Path | Step |
|---|---|
| `DECISIONS.md` — `## 2026-09-05 (sweep 1)` appended | 1 |
| `Info.plist` (new, project root) — `NSAppTransportSecurity` only | 2 |
| `Marlin DVR TV.xcodeproj/project.pbxproj` — `INFOPLIST_FILE = Info.plist;` in Debug and Release | 2 |
| `Marlin DVR TV/ServerAPI.swift`, `Models.swift`, `ChannelFilter.swift`, `ServerImage.swift`, `ClientSession.swift` (new) | 3 |
| `Marlin DVR TV/Theme.swift` (new) | 4 |
| `Marlin DVR TV/Destination.swift`, `RailView.swift`, `HomeView.swift`, `ScreenShell.swift` (new) | 5 |
| `Marlin DVR TV/ContentView.swift`, `Marlin_DVR_TVApp.swift` (rewritten) | 3, 5 |
| `reports/assets/pass5/sim-home.png`, `sim-rail-collapsed.png`, `sim-rail-expanded.png`, `sim-home-after-menu.png` (new) | 6 |
| `reports/2026-09-05-pass5-sweep1-foundation.md` (this file) | deliverable |
| `build/` (ignored by `.gitignore`) — output of the target/SDK build line | 6, not committed |
| Local commit "Pass 5: sweep 1 — foundation, rail, Home"; **no push** | deliverable |

Outside the repo: DerivedData under `~/Library/Developer/Xcode` (build products), the app installed on the booted simulator and on Home Theater, and one client row each on the server (register is an allowed POST). `COLD-START.md`, `Assets.xcassets`, the scheme and every other build setting are untouched. No other folder under `~/Xcode` was written; the reference clone and `design/` were only read. No request went to the Unraid host beyond port 8090, marlinpc, the HDHomeRun or the UNAS4Pro share. Nothing installed; no packages; no third-party code.

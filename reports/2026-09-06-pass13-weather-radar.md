# Pass 13 — Weather screen + radar — 2026-09-06

Two of this pass's eight steps hit a wall that is the owner's to clear, and neither is papered
over anywhere in the code or on screen:

1. **Step 1 found no radar tile source.** The owner's iPhone weather app has never had one —
   its Maps tab is a "Coming soon" placeholder. The decision "tile source: whatever step 1
   finds" therefore resolves to nothing, and naming a provider was explicitly out of scope.
2. **Step 2's stop-and-report fired: WeatherKit is not enabled for `com.marlin1111.MarlinDVRTV`.**
   Every forecast call on the Apple TV fails with a sandbox denial. No entitlement was added,
   requested or worked around, and no substitute data source was used.

Everything else was built and tested on the owner's Apple TV. **The consequence to be clear
about: because WeatherKit will not answer, the Weather screen and the Home glance have never
been seen with data on them.** Their code is written, their layout follows frame 5f and frame
2a field by field, and both are reachable — but the populated screen is unproven, and that is
stated again in the evidence section and in COLD-START.md rather than glossed.

**Citation keys.** `dc:NNN` = line NNN of `design/Marlin DVR TV.dc.html` (read-only, never
edited). `SDK` = the installed `AppleTVOS26.5.sdk`. `MW:` = a file in the owner's
`~/Xcode/Marlin Weather`, read once for step 1 and never written to.

---

## 1. Where the radar tiles come from (step 1)

### 1.1 The answer: nowhere. There is no radar tile source in that project.

The owner's iPhone weather app is `~/Xcode/Marlin Weather` (the same project Pass 1 copied its
build settings from — `reports/2026-09-05-pass1-plumbing.md:5`). It was read read-only; nothing
in it was written, built or run. Its whole radar story is a placeholder, quoted verbatim:

> `MW: Marlin Weather/MapsView.swift:5-7`
> ```
> //  Phase 2: reserved tab. Future radar / precipitation maps. Per the design,
> //  this stays in the tab bar but shows a "Coming soon" empty state to read
> //  as a reserved, future feature.
> ```

The view itself (`MapsView.swift:12-37`, the whole file is 41 lines) is an SF Symbol, the words
`Radar & Maps`, the line `Live precipitation radar and storm tracking are coming to Marlin
Weather soon.` and a `Coming soon` pill. There is no map, no tile overlay and no request. Its
design handoff says the same:

> `MW: design_handoff_marlin_weather/README.md:117`
> ```
> **Purpose:** Future radar / precipitation maps. Keep the tab in the bar but show an empty
> state: map SF Symbol, "Radar & Maps", subtitle about live precipitation radar coming soon,
> and a "Coming soon" pill. Tab item is slightly dimmed to read as reserved.
> ```

**Method, so this is checkable.** Two greps over the whole project (64 files):
`grep -rn -i "radar|tile|{z}/{x}/{y}|MKTileOverlay|rainviewer|openweather|nowcoast|noaa|iem|mesonet"`
— every hit is either the design system's UI "tiles" (the 2-column card grid) or the placeholder
above. And `grep -rn "https\?://"` over every `.swift`, `.plist`, `.json`, `.md`, `.entitlements`
and `.pbxproj` returns **four lines**, counted by hand:

| File:line | URL | What it is |
|---|---|---|
| `MW: Marlin Weather/Tempest/TempestProvider.swift:19` | `https://swd.weatherflow.com/swd/rest` | WeatherFlow Tempest — the owner's backyard station |
| `MW: Marlin Weather/Forecast/TempestForecastProvider.swift:18` | the same base | the same service |
| `MW: Marlin Weather/ConnectTempestView.swift:87` | `https://tempestwx.com/settings/tokens` | a link for the owner to fetch their own token |
| `MW: Marlin Weather/Marlin Weather.entitlements:2` | the Apple DTD | the plist doctype, not a service |

So the only two services that project talks to are **Apple WeatherKit** and **WeatherFlow
Tempest**. Neither serves radar tiles. Its git history agrees: `git log --all -S"radar"` returns
only the two commits that added the placeholder (`041b84e` Phase 1, `bb9805b` Phase 2), and its
own README lists "Maps placeholder" as build phase 8 with no provider named.

### 1.2 The requested fields, answered

| Asked for | Answer |
|---|---|
| Provider | **None.** No radar provider exists in that project. |
| URL template | **None.** No `{z}/{x}/{y}` template, and no tile URL of any shape, appears anywhere in it. |
| Tile scheme | **N/A** — there are no tiles. |
| Key or credential required | **N/A for radar.** The one credentialed service there is Tempest, which needs a personal access token; it is a station API, not a tile service. |
| Licence or terms | **None recorded**, because there is no source to record terms for. |

### 1.3 The credential rule was kept

Tempest's token is a real credential. It is stored in the iOS Keychain in that project
(`MW: Marlin Weather/Tempest/TempestKeychain.swift:5-7` — "The token lives ONLY here, in the
iOS Keychain — never in UserDefaults, never in a file, never logged, never committed"). **No
token value was read, and nothing from that project's Keychain, entitlements or configuration
was copied into this repository — not into code, not into a config file, not into this report.**
The only thing this pass took from it is the fact quoted above: that there is no radar source.

### 1.4 Was that "free and clean"?

There was nothing to be free or clean, so the honest answer is that the question is still open.
Nothing was chosen, nothing was fetched, and no request left this Mac for any weather host other
than Apple's. Picking a provider is Open Question 1.

---

## 2. WeatherKit availability — STOP AND REPORT (step 2)

**WeatherKit is not enabled for this app's bundle id.** Four pieces of evidence, from the
weakest to the decisive one.

**a. No App ID profile for this bundle id exists on this Mac.** All five profiles in
`~/Library/Developer/Xcode/UserData/Provisioning Profiles` were decoded. Three carry
`com.apple.developer.weatherkit`, and none of the three is this app:

| Profile name | application-identifier | weatherkit |
|---|---|---|
| `iOS Team Provisioning Profile: com.marlin1111.MarlinWeather` | `…MarlinWeather` | **yes** |
| `tvOS Team Provisioning Profile: com.marlin.dvr` | `…com.marlin.dvr` | **yes** |
| `tvOS Team Provisioning Profile: com.marlin.MarlinDVRGo` | `…MarlinDVRGo` | **yes** |
| `tvOS Team Provisioning Profile: *` | `<team>.*` | no |
| `iOS Team Provisioning Profile: *` | `<team>.*` | no |

(Team identifiers masked. The owner has enabled WeatherKit on three other App IDs, including two
tvOS ones — but not on `com.marlin1111.MarlinDVRTV`.)

**b. The app has no entitlements file and none was created.** `find . -name "*.entitlements"`
over the repo returns nothing, and `project.pbxproj` has no `CODE_SIGN_ENTITLEMENTS`.

**c. The device build I made this pass is signed without it.** Read off the binary, not assumed:

```
$ codesign -d --entitlements - --xml "build/dd-device/…/Marlin DVR TV.app"
{
  "application-identifier"              => "<team>.com.marlin1111.MarlinDVRTV"
  "com.apple.developer.team-identifier"  => "<team>"
  "get-task-allow"                       => true
}
$ security cms -D -i ".../embedded.mobileprovision" | grep Name
  "Name" => "tvOS Team Provisioning Profile: *"
```

Three keys, no `com.apple.developer.weatherkit`, signed with the team **wildcard** profile.

**d. The live request on the Apple TV, which is what step 2 actually asked for.** Run on Home
Theater (Apple TV 4K 3rd gen, tvOS 26.6), console captured:

```
[client] ping ok: id=… name=Apple TV app=Marlin DVR TV 1.0 type=Apple TV os=tvOS 26.6
[weather] WeatherKit: xpcConnectionFailed(Error Domain=NSCocoaErrorDomain Code=4099
  "The connection to service named com.apple.weatherkit.authservice was invalidated:
   Connection init failed at lookup with error 159 - Sandbox restriction.")
```

A **sandbox restriction on the WeatherKit auth service** is the missing-entitlement signature:
without `com.apple.developer.weatherkit` the app's sandbox may not look that service up. The same
sentence is on screen in `reports/assets/pass13/atv-03-weather-weatherkit-blocked.png`.

**What was not done, deliberately.** No entitlements file was created, no capability was added to
the target, nothing was requested from the developer portal, the bundle id was not changed to one
of the three that already have the capability, and no other forecast provider was substituted —
each of those is forbidden by step 2 and by the scope lock.

**What unblocks it** (the owner's to do, stated so it is actionable, not proposed as work for me):
enable **WeatherKit** on the App ID `com.marlin1111.MarlinDVRTV` in the Apple Developer portal —
Xcode cannot do this for you; the capability is marked `"canRequestFromPortal": false` in Xcode's
own portal table (Pass 12 §4.4) — and then add the WeatherKit capability to the target in Xcode,
which writes the entitlements file and re-provisions. Nothing else in this pass's code needs to
change when that happens.

**One honest limit.** All four pieces of evidence are read from this Mac and this device. Whether
an App ID for `com.marlin1111.MarlinDVRTV` exists at the portal at all, with or without the
capability, cannot be read from here without signing in to it, which this pass did not do.

---

## 3. What was built

Seven new files, six touched. Every file is in the SCOPE CHECK table at the end, mapped to the
step that required it.

### 3a. Location — one shot, cached, and never silent (step 3)

`Marlin DVR TV/WeatherLocation.swift` (231 lines).

- `requestWhenInUseAuthorization()` then a single `requestLocation()`. `startUpdatingLocation`
  is `API_UNAVAILABLE(tvos)` (`SDK: CLLocationManager.h:585`), so there is no continuous option
  and none is attempted.
- The fix is cached as JSON in `UserDefaults` under `marlinWeatherFix`. A cached fix
  short-circuits `start()` entirely: no prompt, no request. **Proven** — the prompt appeared once
  after a fresh install and on no launch since (the UI test's `00-no-location-prompt` screenshot
  on every later run).
- `NSLocationWhenInUseUsageDescription` was added to `Info.plist` — the prompt does not appear at
  all without it. It is a purpose string, not an entitlement or capability.
- **Every failure has a sentence.** `State` is `idle / asking / ready(fix) / declined /
  failed(String)`. Declined prints where to change it (Settings → General → Privacy & Security →
  Location Services → Marlin DVR TV) and offers **Try again**. A 25-second timeout exists because
  tvOS can leave `requestLocation` outstanding with no callback at all, which would otherwise hang
  the screen on "Finding this Apple TV's location…" for ever. **There is no hard-coded place
  anywhere in the file.** `grep -n "Towson|Fallston|39\.[0-9]|latitude: 3"` over it returns three
  lines and all three are *comments* quoting the design's own example ("Towson, Maryland",
  `dc:707`); no place name and no coordinate is compiled into the app.
- The place name is `CLPlacemark.locality` + `.administrativeArea` only — see §5, where this
  changed for a reason worth reading.

### 3b. The WeatherKit read (steps 2, 4, 5)

`Marlin DVR TV/WeatherModel.swift` (203 lines). One `@Observable` model, created once in
`Marlin_DVR_TVApp` and shared by Home and the Weather screen, so WeatherKit is asked once and the
location prompt happens once. `WeatherService.shared.weather(for:)` and `.attribution`, run
concurrently. `Phase` is `idle / locating / loading / ready / noLocation(String) / failed(String)`.
On failure it stores WeatherKit's own error text and shows it; there is no second provider in the
file and no cached-last-good fallback.

`WeatherFormat` holds the design's number formats in one place: `81°`, `62%`, `8 mph SW`,
`Partly Cloudy`, `Now` / `3 PM`, `Today` / `Saturday`.

### 3c. The Weather screen, frame 5f (step 4)

`Marlin DVR TV/WeatherScreen.swift` (395 lines). Every element the design draws, in its place, at
its size and colour, with its WeatherKit source:

| dc | Element | Source |
|---|---|---|
| `706` | `Weather`, 52 pt medium | — |
| `707` | `Fallston, MD · updated 2:38 PM` | `CLPlacemark` + `currentWeather.metadata.date` |
| `709` | `From this Apple TV's location, not the server`, right-aligned | — |
| `714` | condition glyph, 104 pt accent-200 | `currentWeather.symbolName` (an SF Symbol name) |
| `716` | `81°`, 112 pt light | `currentWeather.temperature` |
| `717` | `Partly cloudy · feels like 84°`, 31 pt | `condition.description`, `apparentTemperature` |
| `718` | `H 83° · L 66° · humidity 62% · wind 8 mph SW` | today's `DayWeather` high/low, `humidity`, `wind` |
| `721-727` | the alert card | `weatherAlerts` — see the caveat below |
| `730-739` | **8** hourly columns between two dividers | `hourlyForecast`, from the current hour |
| `741-753` | **5** daily rows with the high/low range bar | `dailyForecast`, bar scaled to the list's min/max (`dc:1396-1401`) |
| `754-758` | the Apple Weather attribution footer | `WeatherAttribution.serviceName` + `legalPageURL` |

Counts are the owner's decision: **8 hourly** (the design ships 8, `dc:1379-1386`) and **5 daily**
(the design ships 5, `dc:1390-1394`) — not the `hint-placeholder-count="7"` of `dc:742`, and not
WeatherKit's 10.

**Two places where the design asks for something WeatherKit does not have**, reported rather than
invented:

- **The alert card's body.** `dc:726` draws a paragraph ("Storms may reach the Baltimore metro
  after 6 PM…"). WeatherKit's `WeatherAlert` is `detailsURL, source, summary, region, severity,
  metadata` and nothing else (`SDK: WeatherKit.swiftinterface:1235-1241`) — there is no long
  description on any platform. The card draws `summary` as the headline and
  `severity · source · region` as the second line. **No sentence was written for it.**
- **`tap for sources`** (`dc:757`). tvOS has no browser to tap through to, so the footer prints
  the attribution's own `legalPageURL` host and path as text instead of a control.

Frame 5f draws its focus ring on the first daily row (`dc:1402-1403`), so the daily rows are
focusable and the first takes focus when data arrives. Selecting a row does nothing — the design
gives it no action.

### 3d. The Home weather glance, frame 2a (step 5)

`Marlin DVR TV/HomeWeatherGlance.swift` (110 lines). DECISIONS.md 2026-09-05 (sweep 1) said the
glance was "omitted until Weather is built" and Pass 5 held its 520 pt slot open with a
`Color.clear`; that spacer is gone and the card is in its place. Its four lines are `dc:134`,
`137-138`, `140`, `141`, fed by the same `WeatherModel`. When there is no data the slot prints one
short line ("Apple Weather did not answer — open Weather") so the clock stays where the design
puts it and no number is invented.

Weather also went live as a destination: `Destination.isBuiltNow` now includes `.weather`, the
rail entry and the Home tile open the screen, and `ScreenShell` routes to it. Radio and Settings
are untouched and still inert.

### 3e. The radar (step 6)

`Marlin DVR TV/RadarScreen.swift` (325 lines) + `Marlin DVR TV/RadarSource.swift` (79 lines).
Built to the app's look, as the owner directed.

- **`MKMapView` in `UIViewRepresentable`** — SwiftUI's `Map` has no raster-tile content type at
  all (Pass 12 §3b), so this is the only path.
- **`MKTileOverlay` + `MKTileOverlayRenderer`**, one overlay per frame, added at
  `MKOverlayLevel.aboveLabels` over a muted `MKStandardMapConfiguration` with points of interest
  excluded.
- **An animated loop over the frames with the frame time shown** — a `Task` steps the index every
  550 ms and holds 1.4 s on the newest frame; the visible frame is chosen by
  `MKOverlayRenderer.alpha`, the one primitive with no platform restriction. MapKit has no
  frame-sequence API of any kind, so all of this is app code. The chrome shows the frame's own
  time, `frame N of M`, and a tick per frame with the current one lit.
- **Flat and north-up**, because tvOS gives no choice: `rotateEnabled`, `pitchEnabled` and
  `showsCompass` are `API_UNAVAILABLE(tvos)` (`SDK: MKMapView.h:145, 146, 152`). They are not
  referenced — referencing them would not compile.
- **Reachable from the Weather screen** by a `Radar` entry in its header. Menu returns to Weather.
- **It says so when there is nothing to draw.** With no source configured it prints, over the map,
  exactly why — naming the file and line in the owner's own project that step 1 read. Not an empty
  map presented as working.

`RadarSource` is the single place a provider plugs in: `frames()` returns `[RadarFrame]`
(a URL template and a time each) and `RadarScreen` needs no change when it starts returning some.
It returns `[]` today because step 1 found nothing, and this pass was forbidden to choose one.

---

## 4. Evidence — my own, hands-on, on the owner's Apple TV

Everything below was run this pass. Where something could not be tested, it says so.

### 4.1 The build under test is the build that was tested

```
$ xcodebuild -project "Marlin DVR TV.xcodeproj" -scheme "Marlin DVR TV" \
    -destination 'platform=tvOS,name=Home Theater' -derivedDataPath build/dd-device \
    -allowProvisioningUpdates build
** BUILD SUCCEEDED **
```

Clean: no errors and no warnings from any file this pass added or touched. The one warning in the
target is pre-existing and in a file Pass 13 never opened
(`GuideScreen.swift:336` — "call to main actor-isolated static method 'channelFocusID' in a
synchronous nonisolated context"). The simulator build is clean too. Each device run **installed
that build first** (`xcrun devicectl device install app`) and then ran; the final run at
18:10:28 is the code as committed, after the last source change.

### 4.2 The device harness

`Marlin DVR TVUITests/WeatherRadarUITests.swift` (120 lines) drives the **real Siri Remote** via
`XCUIRemote` on Home Theater — the same route Passes 9 and 10B used. It is an evidence harness for
this pass, not a standing test, and it makes no server write and no WeatherKit call of its own.

```
$ xcodebuild … -destination 'platform=tvOS,name=Home Theater' -allowProvisioningUpdates test \
    -only-testing:"Marlin DVR TVUITests/WeatherRadarUITests"
Test Case '-[WeatherRadarUITests testWeatherScreenAndRadarOnTheDevice]' passed (76.467 seconds).
** TEST SUCCEEDED **
```

### 4.3 What is proven on the Apple TV

| # | Claim | Evidence |
|---|---|---|
| 1 | The **location prompt** appears, with this app's purpose string | `atv-01-location-prompt.png` — "Allow 'Marlin DVR TV' to use your location?" over Home |
| 2 | The **fix comes back** and is this Apple TV's, not the server's | the header reads a real coordinate for the owner's area, and later `Fallston, MD` |
| 3 | The prompt is **not shown again** | every run after the first reports `00-no-location-prompt`; the fix is read from `UserDefaults` |
| 4 | The **place name** resolves to the design's town-and-state form | `atv-04-weather-place-resolved.png` — `Weather   Fallston, MD` |
| 5 | **Weather is reachable** from the Home tile and the rail, and Menu leaves it | the test navigates Home tile → Weather and asserts the screen's own text |
| 6 | **WeatherKit is blocked**, and the screen says so instead of going blank | `atv-03-weather-weatherkit-blocked.png` — the sandbox error, and a **Try again** button |
| 7 | The **Home glance slot** is filled and speaks when there is no data | `atv-02-home-glance.png` — "Apple Weather did not answer — open Weather", clock unmoved |
| 8 | **Radar is reachable** from Weather, and Menu returns to Weather | the test asserts both directions |
| 9 | **`MKMapView` renders on the Apple TV** — the step 6 stop condition | `atv-05-radar-no-source.png` — a live Apple Maps base map centred on the owner's location |
| 10 | The radar **says so when there are no frames** | the same screenshot: "No radar frames to show." with the reason |
| 11 | **`MKTileOverlayRenderer` composites raster tiles over that map** — the other half of the step 6 stop condition | `atv-06-radar-tiles-composite-diagnostic.png` |
| 12 | The **frame loop swaps frames and the frame time follows** | `atv-07-…-frame3` (5:57 PM, tick 3, cyan) → `atv-08-…-frame1` (5:47 PM, tick 1, red) |

Claims 11 and 12 needed tiles, and step 1 left none. They were proven with a **temporary
diagnostic that generated tile bytes locally, in-process, with no network request and no
provider**, using `MKTileOverlay.loadTile(at:result:)` — MapKit's documented seam for supplying
tile data from anywhere (`SDK: MKTileOverlay.h:46`). It was a throwaway file plus two small edits;
**all of it was reverted before committing** (`grep -rn "Diagnostic\|diagnostic://" "Marlin DVR TV/"`
→ nothing). The two screenshots are labelled `-diagnostic` so no one mistakes them for real radar.

### 4.4 What is NOT proven, plainly

- **The Weather screen with data on it has never been seen.** No current conditions, no alert
  card, no hourly strip, no daily rows with their range bars, no attribution footer. WeatherKit
  refuses before any of it renders. What was traced instead: each field is bound to the WeatherKit
  member named in the §3c table, all of which Pass 12 verified exist on tvOS at the app's 18.0
  target; the layout compiles and the screen's chrome, focus and navigation all render on the
  device. That is not the same as having seen it, and it is not claimed to be.
- **The Home glance card with data on it has never been seen** — same cause, same status.
- **No real radar tile has ever been fetched.** The tile pipeline is proven with locally drawn
  bytes; an actual provider's URL template, projection, zoom range, HTTP status handling, rate
  limits and cache headers are all untested because there is no provider.
- **Remote pan and zoom on the map are untested.** `isZoomEnabled` and `isScrollEnabled` are set
  and neither is restricted on tvOS, but step 6 does not ask for panning and the harness does not
  press the touch surface on the map, so nothing is claimed.
- **The alert card has never been drawn**, blocked with everything else, and would in any case
  need a live alert in the owner's area.
- **The second Apple TV (Master Bedroom) was not touched.** Only Home Theater.

### 4.5 What went wrong on the way, and what it cost

Recorded because the fixes are in the shipped code and the owner may hit the symptoms again.

1. **My own test denied the location.** An early revision pressed Down twice while the system
   prompt was up, which lands on **Don't Allow**, and tvOS cached the denial. Recovering it meant
   uninstalling the app (which clears the grant) and reinstalling. The harness now walks *up* to
   the prompt's caption first and then down exactly twice, and says so in a comment, so it cannot
   drift onto the wrong button.
2. **The Radar entry could not be reached with the remote.** The button sits at the right-hand end
   of the header and the content below it is left-aligned, so the focus engine found nothing
   overlapping above it. Fixed with `.focusSection()` on the header — the same fix the episode
   list needed in Pass 8.
3. **The frame loop stopped advancing.** Calling `setNeedsDisplay()` on *every* renderer each step
   made MapKit re-request the tiles of all of them — measured on the Apple TV at roughly 470 tile
   loads a second — which starved the main actor so the loop task never got to run. `show(index:)`
   now touches only the two renderers that actually change. **Note for whoever adds a real source:
   a frame going from alpha 0 to 1 still makes MapKit re-request that frame's tiles, so each loop
   cycle re-fetches. With a URL template those go through `URLSession`'s shared HTTP cache, so
   whether it is acceptable depends on the provider's cache headers and rate limits — see Open
   Question 3.**
4. **The place line showed the owner's street address.** MapKit's tvOS 26 replacement for
   CLGeocoder, `MKReverseGeocodingRequest`, hands back an `MKAddress` of two opaque strings with no
   town or state field of its own (`SDK: MKAddress.h:20-21`), and on this Apple TV its
   `shortAddress` came back as **`3305 Fallston Rd, Fallston`** — the house. That is neither what
   `dc:707` draws nor something to put on a television. The place name now comes from
   `CLPlacemark`'s structured `locality` + `administrativeArea` and **nothing finer than a town is
   ever displayed**; if neither resolves, the header shows the coordinates rather than a street.
5. **The place name did not appear at all at first**, because the model copied it once at load
   time and reverse geocoding finishes later. `WeatherModel.place` is now a live read of the fix.

---

## 5. Notebook (step 7)

- `COLD-START.md` "What is built" gained a **Pass 12** paragraph and a **Pass 13** paragraph.
- `COLD-START.md` "What is NOT built": Weather removed from the parked list (Radio and Settings
  stay), and a new **"Built but blocked on the owner"** block naming the two blockers so nobody
  later reads "Weather is built" as "Weather shows weather". The standing-candidates line dropped
  Weather too.
- `DECISIONS.md` gained `## 2026-09-06 (Pass 13 — Weather and radar)` with the owner's four
  decisions (radar is in; radar built to the app's look; 5 daily rows; one-shot cached location),
  plus what step 1 and step 2 found and the place-name rule.

What happened only. No proposals and no recommendations were written into either file; the
questions are all below.

---

## Open Questions

1. **Which radar tile source?** This is the blocking one for step 6. Step 1 found none, and
   choosing a provider was out of scope. What is needed is a `{z}/{x}/{y}` URL template in
   spherical mercator (EPSG:3857), a way to list the available frames with their times, and the
   licence terms. Three things worth deciding at the same time: whether it may cost money or need
   an account (this pass will not put a credential in this repo under any circumstance); that it
   must be **HTTPS**, because the app's ATS is `NSAllowsLocalNetworking` only, so a plain-HTTP tile
   host would be blocked and would need an ATS change the owner has not authorised; and that it is
   the app's first outbound request to a host outside the LAN.
2. **WeatherKit on the App ID.** §2 says exactly what to enable and where. Until then the Weather
   screen and the Home glance are honest, reachable and empty. Should a later pass re-run this
   pass's harness once it is on, to photograph the populated screen and confirm every field?
3. **Tile re-fetch on every loop cycle** (§4.5 item 3). Measurable only against a real source.
   If the provider's headers turn out not to cache well, the fix is a small byte cache inside an
   `MKTileOverlay` subclass — which is close enough to "offline cache" that this pass left it
   alone rather than build it uninvited.
4. **Units are Fahrenheit and miles per hour**, because that is what frame 5f draws (`dc:718`,
   `1379-1394`). They are not read from the device's locale. Keep, or follow the system setting?
5. **The alert card's second line** is `severity · source · region` because WeatherKit has no long
   description (§3c). Accept, or drop the second line and let the card be one headline?
6. **`tap for sources`** (`dc:757`) is printed as the legal page's address rather than made
   tappable, since tvOS has no browser. Fine, or should the footer just say "Apple Weather"?
7. **The Home Weather tile still reads `Local weather`**, not the design's `72° · clear now`
   (`dc:1360`). No step named it, so it was left alone; it is now feasible. This is the same
   question as `reports/2026-09-05-pass5-sweep1-foundation.md` Open Question 3.
8. **The daily rows are focusable but do nothing** when selected, matching the focus ring the
   design draws on the first row (`dc:1402-1403`). Keep, or should a row open something?
9. **Refresh.** The forecast is read once when Weather or Home first needs it, and not again;
   "updated 2:38 PM" is WeatherKit's own timestamp, not this app's. Should it refresh on a timer or
   when the screen is re-entered?
10. **The one-shot fix never expires.** If the Apple TV moves house, the cached coordinate is
    stale for ever and there is no way to clear it from inside the app (short of deleting the app).
    Should Weather offer a "use this Apple TV's location again" action, or should the fix age out?

---

## SCOPE CHECK

| File | Created / touched / read | Step that required it |
|---|---|---|
| `Marlin DVR TV/WeatherLocation.swift` (231) | **created** | 3 |
| `Marlin DVR TV/WeatherModel.swift` (203) | **created** | 2, 4, 5 |
| `Marlin DVR TV/WeatherScreen.swift` (395) | **created** | 4 (and the Radar entry, 6) |
| `Marlin DVR TV/HomeWeatherGlance.swift` (110) | **created** | 5 |
| `Marlin DVR TV/RadarSource.swift` (79) | **created** | 1, 6 |
| `Marlin DVR TV/RadarScreen.swift` (325) | **created** | 6 |
| `Marlin DVR TVUITests/WeatherRadarUITests.swift` (120) | **created** | 8 (evidence) |
| `Marlin DVR TV/Destination.swift` | touched — `.weather` is `isBuiltNow` | 4 |
| `Marlin DVR TV/ScreenShell.swift` | touched — routes `.weather`, carries the `WeatherModel` | 4 |
| `Marlin DVR TV/ContentView.swift` | touched — holds and passes the `WeatherModel` | 4, 5 |
| `Marlin DVR TV/Marlin_DVR_TVApp.swift` | touched — creates the one `WeatherModel` | 4, 5 |
| `Marlin DVR TV/HomeView.swift` | touched — the glance replaces Pass 5's empty 520 pt spacer | 5 |
| `Info.plist` | touched — `NSLocationWhenInUseUsageDescription` added (a purpose string; the prompt does not appear without it) | 3 |
| `COLD-START.md` | touched — Pass 12 and Pass 13 lines, Weather out of the parked list, the blocked block | 7 |
| `DECISIONS.md` | touched — `## 2026-09-06 (Pass 13 — Weather and radar)` | 7 |
| `reports/2026-09-06-pass13-weather-radar.md` | **created** — this file | 8 |
| `reports/assets/pass13/*.png` (8 files) | **created** — device screenshots, downscaled to 1920 wide | 8 |
| `Marlin DVR TV/_Pass13TileDiagnostic.swift` | created **and deleted** — the throwaway local-tile diagnostic of §4.3; not committed | 6 (stop condition) |
| `~/Xcode/Marlin Weather` (64 files) | **read only**, step 1 only | 1 |
| `design/Marlin DVR TV.dc.html` | read only | 4, 5 |
| `COLD-START.md`, `DECISIONS.md`, `reports/2026-09-06-pass12-weather-recon.md` | read first, before anything else | preamble |
| `SDK` — MapKit, WeatherKit, CoreLocation headers and `.swiftinterface` | read only | 3, 4, 6 |
| `~/Library/Developer/Xcode/UserData/Provisioning Profiles` (5 files) | read only | 2 |
| `build/`, `<session scratchpad>` | build output and working screenshots, **git-ignored / outside the repo** | 8 |

**Not created, not changed, not installed:** no entitlement or entitlements file, no capability,
no build-setting change, no dependency, no package, no bundle-id change, no ATS change, no second
tile source or provider fallback, no offline cache, no change to `design/`, and no change to any
screen built in Passes 5–11 beyond the six wiring edits listed above. Nothing outside
`~/Xcode/Marlin DVR TV` was written. **No request was sent to 192.168.1.250, 192.168.1.245,
192.168.1.105, the UNAS4Pro share, or any third-party weather host**; the only network traffic
this pass caused is the app's usual DVR client ping, Apple's own WeatherKit and reverse-geocoding
calls from the device, and MapKit's base-map tiles.

**Secret scan before commit.** Every file this pass adds or changes was grepped for `token`,
`secret`, `password`, `bearer`, `api[-_]key`, `ssh-rsa`, `BEGIN … PRIVATE KEY`, the Apple team
identifier pattern, the device UDID, and the two Tempest hostnames. **No matches.** Team
identifiers are masked in this report; no device id, client id, UDID or credential appears in it.

## Push gate

Committed locally with descriptive messages and **not pushed**, per the pass's separate push gate.
The owner tests on Home Theater; the push is approved after that.

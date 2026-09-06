# Pass 12 — Weather screen recon (read-only) — 2026-09-06

Read-only. No Swift file, asset, entitlement, `Info.plist` entry or build setting was
written or changed; nothing was installed; no dependency was added; `design/` was read and
not touched; no request was sent to any LAN host. The only network use in this pass is the
`git fetch` / `git push` of this report (§ SCOPE CHECK). One file was created: this report.

`COLD-START.md`, `DECISIONS.md` and `reports/2026-09-05-pass4-design-and-build-recon.md`
were read first; §2 quotes what they already settle rather than re-deriving it.

**Citation keys**

- `dc:NNN` = line NNN of `design/Marlin DVR TV.dc.html` (read-only; 1,411 lines,
  `wc -l`). Frame ids (`2a`, `5f`) are the design's own.
- `SDK` = `/Applications/Xcode.app/Contents/Developer/Platforms/AppleTVOS.platform/Developer/SDKs/AppleTVOS26.5.sdk`
  (`xcodebuild -showsdks` → `tvOS 26.5  -sdk appletvos26.5`; Xcode 26.6, build 17F113).
  Where a claim is checked against the simulator SDK as well, that is
  `AppleTVSimulator.platform/.../AppleTVSimulator26.5.sdk`.
- `file:line` = a header or `.swiftinterface` inside `SDK`, quoted verbatim.
- The app's deployment target is `TVOS_DEPLOYMENT_TARGET = 18.0`
  (`Marlin DVR TV.xcodeproj/project.pbxproj:250` and `:305`, verified by hand this pass).
  Every "available on tvOS 18.0" claim below means the SDK annotation names a tvOS version
  **at or below 18.0**.

---

## 1. What the approved design draws (step 1)

### 1.1 There is a Weather screen, and it draws no radar and no map

The design **does** draw a full Weather screen: frame `5f`, `dc:690`–`dc:762`, a single
1920×1080 board carrying `data-screen-label="Weather"` (`dc:695`). Its section caption is,
verbatim:

> `Weather — Apple WeatherKit on the device, no server involvement` — `dc:693`

**No radar element and no map element is drawn anywhere in the design.** Evidence, by hand:
`grep -n -i "radar\|\bmap\b\|mapkit\|precip\|tile layer\|overlay" "design/Marlin DVR TV.dc.html"`
returns 22 lines, and every one of them is the JavaScript `Array.prototype.map` call in the
data block (`dc:1124`, `1128`, `1138`, `1144`, `1183`, `1199`, `1235`, `1242`, `1260`,
`1271`, `1280`, `1289`, `1300`, `1306`, `1312`, `1330`, `1342`, `1363`, `1374`, `1396`,
`1397`, `1399`). There is no `radar`, no `MapKit`, no image slot, no `<canvas>`, no tile
source and no animation control anywhere in frame `5f` or in any other frame. The word
"radar" does not occur in the file at all.

### 1.2 Frame 5f — every field the Weather screen draws

Layout: the standard 1b left rail as a 180 pt icon strip pinned left
(`aside`, `dc:698`–`dc:703`), content inset `padding:60px 80px 60px 236px` (`dc:697`), an
accent-900 radial wash at `78% -12%` (`dc:696`). The rail is bound to
`railWeather` (`dc:700`), which is `railAt(7)` (`dc:1351`) — index 7 of the nine-entry
`nav` array (`dc:1133`–`dc:1137`), i.e. the **Weather** entry is the active one. (The
`hint-placeholder-count="8"` on `dc:700` is a render hint only; it differs per frame —
7, 8 and 9 appear at `dc:182`, `dc:700`, `dc:774` — and does not govern the item count.)

Content, top to bottom:

| # | Element | Every field, quoted as the design writes it | dc |
|---|---|---|---|
| 1 | Screen title | `Weather` (52 px, heading, weight 500) | `dc:706` |
| 2 | Place + freshness | `Towson, Maryland · updated 2:38 PM` (26 px, neutral-500) | `dc:707` |
| 3 | Source note, right-aligned | `From this Apple TV's location, not the server` (23 px, neutral-600) | `dc:709` |
| 4 | Current condition glyph | Phosphor `ph-cloud-sun`, 104 px, accent-200 | `dc:714` |
| 5 | Current temperature | `81°` (112 px, heading, weight 300) | `dc:716` |
| 6 | Condition + apparent temp | `Partly cloudy · feels like 84°` (31 px, neutral-300) | `dc:717` |
| 7 | Today's detail line | `H 83° · L 66° · humidity 62% · wind 8 mph SW` (26 px, neutral-500) | `dc:718` |
| 8 | Alert card — headline | `ph-warning` glyph in `#d6a94e` + `Severe thunderstorm watch until 9:00 PM` (29 px, neutral-100) | `dc:721`–`dc:724` |
| 9 | Alert card — body | `Storms may reach the Baltimore metro after 6 PM. Antenna reception can drop during heavy rain — recordings on 2.1, 11.1, 13.1 and 45.1 may be affected.` (26 px, neutral-400) | `dc:726` |
| 10 | Hourly strip (one column each) | hour label (26 px) · condition glyph (44 px) · temperature (31 px) · chance of precipitation (23 px, accent-300) | `dc:730`–`dc:739` |
| 11 | Daily row (one row each) | day name (29 px, 240 pt column) · condition glyph (34 px) · chance of precipitation (23 px, accent-300, 80 pt) · low (29 px, 80 pt, right-aligned) · high/low range bar (8 pt tall, accent-600→accent-300 gradient, offset and width scaled to the min/max of the whole list) · high (29 px, 80 pt) | `dc:741`–`dc:753` |
| 12 | Attribution footer | `ph-apple-logo` glyph + `Weather` + `· data and attribution required by WeatherKit · tap for sources` (23 px, neutral-500/600) | `dc:754`–`dc:758` |

**How many days, how many hours.** The design ships sample data for both lists:

- **Hourly: 8 entries** (`wxHourly` entries, `dc:1379`–`dc:1386`; the array runs `dc:1378`–`dc:1387`) — `3 PM`, `4 PM`, `5 PM`, `6 PM`,
  `7 PM`, `8 PM`, `9 PM`, `10 PM`. Counted by hand from the array. The `sc-for` at `dc:731`
  also carries `hint-placeholder-count="8"`, matching.
- **Daily: 5 rows** (`wxDaily` rows, `dc:1390`–`dc:1394`; the array runs `dc:1389`–`dc:1395`) — `Today`, `Saturday`, `Sunday`,
  `Monday`, `Tuesday`. Counted by hand from the array. **The `sc-for` at `dc:742` carries
  `hint-placeholder-count="7"`, which disagrees with the five rows of data.** Both numbers
  are reported here as read; the design does not resolve which is meant (Open Question 2).

**Focus treatment.** The only focus ring drawn on this screen is on the **first daily row**:
`shadow: i === 0 ? "0 0 0 4px var(--color-accent), 0 26px 64px rgba(0,0,0,.7)" : "none"` with
`fbg: i === 0 ? "color-mix(in srgb, var(--color-accent) 10%, var(--color-surface))"`
(`dc:1402`–`dc:1403`), rendered through `d.fbg` / `d.shadow` at `dc:743`. Nothing else on
frame `5f` is drawn focused, and the design draws **no button, pill or control** of any kind
on the screen — the "`tap for sources`" of `dc:757` is plain text inside the attribution
line, not a control.

### 1.3 The Home weather glance (frame 2a)

Frame `2a`'s caption names it: `Tile grid — greeting, clock, weather glance, eight destinations`
(`dc:118`). The glance is a fixed **520 pt** card (`width:520px`, surface background,
`radius-md`, `shadow-sm`, `padding:24px 30px`) sitting at the right end of the Home header
row (`dc:133`–`dc:143`). Fields, all four of them:

| Element | Quoted label | dc |
|---|---|---|
| Condition glyph | Phosphor `ph-cloud-moon`, 58 px, neutral-300 | `dc:134` |
| Temperature | `72°` (52 px, heading, weight 500) | `dc:137` |
| Condition | `Clear` (29 px, neutral-300) | `dc:138` |
| Today line | `H 78° · L 58° · 10% rain today` (23 px, neutral-400) | `dc:140` |
| Detail + attribution | `Feels 72° · humidity 54% · Apple WeatherKit` (23 px, neutral-600) | `dc:141` |

No forecast, no map, no radar on the glance. It is a single card, not a list.

### 1.4 The rail entry and the Home tile

- **Rail entry:** `["Weather","ph-cloud-sun"]` — index 7 of the nine-entry `nav`
  (`dc:1136`). Label `Weather`, Phosphor icon `ph-cloud-sun`. No sub-line in the rail.
- **Home tile:** `["Weather","ph-cloud-sun","72° · clear now","#245c66"]` (`dc:1360`) —
  label `Weather`, icon `ph-cloud-sun`, sub-line `72° · clear now`, tile tint `#245c66`.
  Drawn as one of nine tiles by the `sc-for` at `dc:147`–`dc:157`, inside the 3×3 grid at `dc:146`–`dc:158`.

### 1.5 Summary of what the design asks for

Four weather elements exist in the design: the **Weather screen** (`5f`), the **Home
glance** (`2a`, `dc:133`–`dc:143`), the **Home tile** (`dc:1360`) and the **rail entry**
(`dc:1136`). All four are a text-and-glyph treatment of WeatherKit values. **A radar or map
element appears in none of them.**

---

## 2. Everything the notebook records about Weather (step 2)

Method: `grep -n -i "weather"` over `COLD-START.md`, `DECISIONS.md` and every file in
`reports/` (`reports/*.md`, 12 files — this report excluded). **34 matching lines**, counted by hand from the grep
output. All 34 are reproduced below verbatim — no paraphrase, nothing dropped. Long lines
are quoted whole.

### 2.1 `COLD-START.md` (2 lines)

> **:67** — `The future screens **Weather, Radio and Settings**: present as drawn and inert, parked until the owner says otherwise (DECISIONS.md 2026-09-06 sweep 4 + fixes).`

> **:85** — `Standing candidates, should the owner want them: the three untested-live paths above; the parked screens (Weather, Radio, Settings); and the Open Questions of `reports/2026-09-06-pass9-sweep4-fixes.md`, `reports/2026-09-06-pass10-favorites-and-manage.md` and the earlier recon reports.`

### 2.2 `DECISIONS.md` (3 lines)

> **:19** — `- In scope now: Home, On Now, Guide (with the airing sheet: Record Now, Series Pass, Watch live), On Later, Recordings (shelves + show detail), Cameras, Player (states 6a–6h). Designed but future, not to be built until the owner says so: Favorites, Weather (WeatherKit), Radio, Settings.`

> **:29** — `- Future screens (Favorites, Weather, Radio, Settings): tiles and rail entries present as drawn, inert. The Home weather glance is omitted until Weather is built.`

> **:49** — `- Weather, Radio and Settings stay parked: present as drawn and inert until the owner says otherwise.`

### 2.3 `reports/2026-09-05-pass2-server-recon.md` (3 lines)

> **:325** — `- Sidebar item ids are fixed by the server: `home, onnow, guide, onlater, recordings, cameras (hidden by default), weather, search, clients, settings (locked)` with Phosphor icon class names (`ph-house`, …) (clients.go:47-60). `PUT` keeps only ids the server knows, honours order, ignores `hidden` on locked items, and stores the collections list as sent; `{reset: true}` clears to defaults (clients.go:427-449). `GET` merges in any default items missing from a saved layout and returns the real collections with their channel counts in the client's order (clients.go:355-398).`

> **:326** — `- `weather` and `search` are sidebar entries only; no server endpoint backs them.`

> **:377** — `5. The Customize sidebar ids are the web UI's screens (`home, onnow, guide, onlater, recordings, cameras, weather, search, clients, settings`). Should the tvOS app honour that per-client layout, and which of those screens is it expected to have?`

### 2.4 `reports/2026-09-05-pass4-design-and-build-recon.md` (7 lines)

> **:52** — `| 5f | Weather | dc:690 | future — not read for recon |`

> **:79** — `| Nine destinations with Phosphor icons: Home, Favorites, On Now, Guide, On Later, Recordings, Cameras, Weather, Radio (1b · rail items) | Fixed in the design's data; not read from the server. The server's per-client sidebar (`GET /api/clients/{id}/ui`) has a different set: `home, onnow, guide, onlater, recordings, cameras (hidden by default), weather, search, clients, settings (locked)` — no `favorites`, no `radio` | dc:1133-1137; clients.go:47-60; Pass 2 §2.12 |`

> **:87** — `Elements: greeting "Good evening" and the name "Marlin" (dc:128-129); date and clock (dc:132); weather glance card marked "Apple WeatherKit" (dc:133-143); nine tiles with a subtitle each, the first focused (data dc:1353-1368). No rail.`

> **:93** — `| Weather glance card | WeatherKit on the device — future per DECISIONS; no server endpoint | dc:141; DECISIONS |`

> **:100** — `| Weather tile "72° · clear now", Radio tile "6 stations", Settings tile | No server endpoint (Weather/Radio/Settings are future) | DECISIONS; Open Question 1 |`

> **:232** — `| Weather glance and tile subtitle | 2a · dc:133-143, 1360 | WeatherKit, future; no server endpoint | DECISIONS |`

> **:316** — `1. **Home tiles for future destinations** (2a · dc:1359-1362): Favorites, Weather, Radio and Settings tiles, and the weather glance card, appear on the chosen Home. Until those screens exist, are the tiles hidden, inert, or shown with a "later" state?`

### 2.5 `reports/2026-09-05-pass5-sweep1-foundation.md` (7 lines)

> **:11** — ``DECISIONS.md` gained `## 2026-09-05 (sweep 1)` with seven bullets: the four-sweep build plan (this is sweep 1); system font and SF Symbols, nothing bundled; the single base URL constant; `NSAllowsLocalNetworking` verified on the device, never switched to arbitrary loads on my own; the client id in UserDefaults and the register fields; future screens present as drawn and inert with the Home weather glance omitted; the fixed greeting name "Marlin". Nothing else in the file changed.`

> **:34** — `| `HomeView.swift` (233) | 5 | `@Observable HomeModel`: loads the five sub-lines concurrently, each endpoint once, `unavailable` on failure, `…` while loading. `HomeView`: the accent-900 radial wash (`dc:121`), the tv glyph, greeting by hour at 60 pt light, "Marlin" at 38 pt medium, the date-and-time line updating every minute ("Saturday, September 5 · 11:27 PM", `dc:132`), an empty 520 pt slot where the weather glance goes, and three rows of three `HomeTile`s (`dc:146-158`): tinted gradient, icon box, 38 pt label, 26 pt sub-line; focused tile = 4 pt accent ring, 6 pt lift, ambient shadow (`dc:1366-1367`). Default focus on Guide. Selecting a built-now tile opens its screen; the four inert tiles do nothing. |`

> **:39** — `Not built, by the scope lock: any sweep-2 content, the Player, server writes beyond register/ping, Top Shelf or icon artwork, behaviour for Favorites/Weather/Radio/Settings, caching, retries. Nothing in `Assets.xcassets` changed.`

> **:47** — `- **Rail (1b):** nine destinations in the design's order; labels shown while focus is in the rail; icon strip while focus is in the content; not shown on Home. Home in the rail returns to Home; On Now, Guide, On Later, Recordings and Cameras switch the placeholder; Favorites, Weather and Radio are inert.`

> **:102** — `- `reports/assets/pass5/sim-home.png` — Home after launch: "Good evening / Marlin", "Saturday, September 5 · 11:27 PM", the nine tiles with live sub-lines: **45 channels live**, **45 programs live**, **0 upcoming**, **3 recordings · 0 recording now**, **1 of 1 online**; Favorites "Favorite channels", Weather "Local weather", Radio "Stations", Settings "Server, tuners, storage"; Guide focused (accent ring, lift, shadow).`

> **:165** — `3. **Inert tile sub-lines.** The design draws "6 favorite channels", "72° · clear now", "6 stations"; the app shows wording without numbers ("Favorite channels", "Local weather", "Stations") so nothing is fabricated. Keep, or show the live favourites count (`/api/channels?filter=Favorites`) now?`

> **:167** — `5. **Clock slot.** The weather glance was omitted, but its 520 pt slot is kept so the clock sits where the design places it. Confirm, or let the clock move right.`

### 2.6 `reports/2026-09-06-pass10b-manage-in-rail.md` (1 line)

> **:75** — `     Recordings, Cameras, Weather, Radio, Manage DVR          (each one asserted to have focus)`

### 2.7 `reports/2026-09-06-pass11-acceptance-and-push.md` (1 line)

> **:26** — `- **Weather, Radio and Settings stay parked**: present as drawn and inert.`

### 2.8 Matches that are not about the Weather screen (10 lines, listed so nothing is silently dropped)

Seven lines in `reports/2026-09-05-pass1-plumbing.md` match "weather" because they name the
owner's **separate iOS project "Marlin Weather"**, which Pass 1 copied project settings from.
Three lines in `reports/2026-09-06-pass8-sweep4-writes.md` match because of the channel
callsign `ACCUWEATHER`. Neither set says anything about this app's Weather screen. Quoted
verbatim, except that the Apple Developer team identifier in `pass1:17` and `pass1:41` is
masked here as `C87…7Z` under the evidence rule; the unmasked value is already in those two
committed lines and in `project.pbxproj`.

> `reports/2026-09-05-pass1-plumbing.md`
> **:5** — `- Xcode project `Marlin DVR TV.xcodeproj` at `~/Xcode/Marlin DVR TV`: one tvOS App target, SwiftUI, Swift, written to match Xcode 26.6's tvOS App template settings and the layout of the owner's Marlin Weather project (file-system-synchronized source group, shared scheme, generated Info.plist).`
> **:17** — `- Development team: `C87…7Z` (from Marlin Weather / Marlin Radio / HDHR Signal Strength)`
> **:41** — `- Team and organization prefix read from `Marlin Weather.xcodeproj/project.pbxproj`: `DEVELOPMENT_TEAM = C87…7Z`, `PRODUCT_BUNDLE_IDENTIFIER = com.marlin1111.MarlinWeather`.`
> **:91** — `2. Deployment target was set to tvOS 18.0, mirroring Marlin Weather's iOS 18.0 with the 26.5 SDK. Xcode's template default would have been 26.5 (latest). Which tvOS versions the owner's Apple TVs run is unknown.`
> **:92** — `3. Bundle id `com.marlin1111.MarlinDVRTV` follows the Marlin Weather pattern (`com.marlin1111.MarlinWeather`). Xcode's template would have produced `com.marlin1111.Marlin-DVR-TV`. The other projects use different prefixes (`com.marlinradio.app`, `com.marlin.HDHRSignalStrength`, `com.marlin.downloader`).`
> **:93** — `4. The target carries the four Swift settings Xcode 26's template adds (`SWIFT_APPROACHABLE_CONCURRENCY`, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, `SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY`, `STRING_CATALOG_GENERATE_SYMBOLS`). Marlin Weather's project file does not have them.`
> **:94** — `5. A shared scheme (`xcshareddata/xcschemes/Marlin DVR TV.xcscheme`) was written so `xcodebuild -scheme` works from a fresh clone; Xcode itself would have created a user scheme under gitignored `xcuserdata`. Marlin Weather also has a shared scheme.`

> `reports/2026-09-06-pass8-sweep4-writes.md`
> **:210** — `existing override (9028 ACCUWEATHER, `philo:6903`):`
> **:213** — `before  GET /api/sources/philo/lineup   → 6903 hidden False favorite False, mapped 9028/ACCUWEATHER`
> **:227** — `        lineup row 6903                 → hidden False favorite False, mapped 9028/ACCUWEATHER`

### 2.9 What the notebook does and does not settle

It settles that Weather is designed, parked, and to be fed by WeatherKit on the device with
no server endpoint behind it (`DECISIONS.md:19`, `:29`; `pass2:326`; `pass4:93`), that the
Home glance is deliberately omitted with its 520 pt slot held open (`DECISIONS.md:29`;
`pass5:34`, `:167`), and that Pass 4 explicitly did **not** read frame 5f
(`pass4:52` — "`future — not read for recon`"). **The notebook records nothing at all about
radar, a map, MapKit, or any weather data provider other than WeatherKit.**

---

## 3. tvOS capability — radar (step 3)

All three answers are read from the installed SDK. Where a claim rests on a linker stub, the
stub is named. Nothing was compiled or run; no code was written to reach any of these
answers.

### 3a. Displaying a map at all — **AVAILABLE**

**UIKit `MKMapView`: available since tvOS 9.2.**

> `SDK/System/Library/Frameworks/MapKit.framework/Headers/MKMapView.h:71-73`
> ```
> #if TARGET_OS_IPHONE
> NS_CLASS_AVAILABLE(NA, 3_0) __TVOS_AVAILABLE(9_2) API_UNAVAILABLE(watchos)
> @interface MKMapView : UIView <NSCoding>
> ```

The class body is compiled on tvOS: `MKMapView.h:10` guards it with `MK_SUPPORTS_VIEW_CLASSES`,
defined at `MKFoundation.h:19` as `(__has_include(<UIKit/UIView.h>) || !TARGET_OS_IPHONE)` —
true on tvOS, where UIKit is present. The umbrella header imports it unconditionally for tvOS
(`MapKit.h:52-54`, guarded only by `__has_include(<MapKit/MKMapView.h>)`, and that header is
present in the tvOS SDK). `MapKit.apinotes` (359 lines) contains no `tvos` or `Unavailable`
entry that would override this.

The class actually ships in the tvOS binary, not just the headers. `MapKit.tbd` declares
`targets: [ arm64-tvos, arm64e-tvos ]` and exports the Objective-C classes `MKMapView`,
`MKMapCamera`, `MKOverlayRenderer`, `MKTileOverlay`, `MKTileOverlayRenderer` and
`MKMapSnapshotter` — 272 Objective-C classes in its `objc-classes` list, counted by hand
from the stub. The same is true of the simulator SDK
(`targets: [ x86_64-tvos-simulator, arm64-tvos-simulator ]`).

**SwiftUI `Map`: available since tvOS 14.0.**

> `SDK/System/Library/Frameworks/_MapKit_SwiftUI.framework/Modules/_MapKit_SwiftUI.swiftmodule/arm64-apple-tvos.swiftinterface:407-408`
> ```
> @available(iOS 14.0, tvOS 14.0, macOS 11.0, watchOS 7.0, *)
> @_Concurrency.MainActor @preconcurrency public struct Map<Content> : SwiftUICore.View where Content : SwiftUICore.View {
> ```

**Named restrictions on tvOS 18.0** (each cited):

| Restricted | Annotation | Where |
|---|---|---|
| `rotateEnabled` | `API_UNAVAILABLE(tvos, watchos)` | `MKMapView.h:145` |
| `pitchEnabled` | `API_UNAVAILABLE(tvos, watchos)` | `MKMapView.h:146` |
| `showsCompass` | `API_UNAVAILABLE(tvos, watchos)` | `MKMapView.h:152` |
| `showsZoomControls`, `showsPitchControl` | `API_UNAVAILABLE(ios, watchos, tvos)` | `MKMapView.h:150-151` |
| `MKUserTrackingModeFollowWithHeading` | `API_UNAVAILABLE(macos) API_UNAVAILABLE(tvos)` | `MKMapView.h:57` |
| `selectableMapFeatures`, `mapView:didSelectAnnotation:` | `API_UNAVAILABLE(macos, tvos, watchos)` | `MKMapView.h:88, 293-294` |
| `mapView:selectionAccessoryForAnnotation:` | inside `#if !TARGET_OS_WATCH && !TARGET_OS_TV`, plus `API_UNAVAILABLE(watchos, tvos)` | `MKMapView.h:296-311` |
| SwiftUI `MapPitchSlider` (`:138`), `MapItemDetailSelectionAccessoryStyle` (`:152`), `SelectedMarker` (`:242`), `SelectedUserAnnotation` (`:329`), `MapSelectableContentView` (`:473`), `MapZoomStepper` (`:736`), `MapLocationCompass` (`:1042`) | `@available(tvOS, unavailable)` on each | `_MapKit_SwiftUI…swiftinterface` |
| SwiftUI modifiers `mapFeatureSelectionContent` (`:578`), `mapFeatureSelectionDisabled` (`:878`), `mapItemDetailSheet` (`:917`), and the `Map` initialisers taking a selection binding (`:453`) | `@available(tvOS, unavailable)` on the enclosing extension | `_MapKit_SwiftUI…swiftinterface:450, 575, 875, 915` |

**Not restricted on tvOS:** `zoomEnabled` and `scrollEnabled` carry no platform annotation at
all (`MKMapView.h:142-143`), so both are declared available; `camera`, `cameraZoomRange` and
`cameraBoundary` are `tvos(9.2)` / `tvos(13.0)` (`MKMapView.h:119-126`); `preferredConfiguration`
is `tvos(16.0)` (`MKMapView.h:85`), with `MKStandardMapConfiguration` and
`MKImageryMapConfiguration` both `tvos(16.0)`
(`MKStandardMapConfiguration.h:20`, `MKImageryMapConfiguration.h:13`).
`MKMapSnapshotter` is `tvos(9.2)` (`MKMapSnapshotter.h:17`). On the SwiftUI side
`MapPitchToggle` (`:113`), `MapCompass` (`:599`), `MapScaleView` (`:506`) and
`MapUserLocationButton` (`:940`) are all `tvOS 17.0`, and `MapSelection` is `tvOS 18.0`
(`:855`) — checked because a plain reading of "no compass on tvOS" would be wrong for the
SwiftUI overlay.

### 3b. Overlaying custom raster image tiles on that map — **AVAILABLE (UIKit only)**

**`MKTileOverlay`, the raster-tile data source: available since tvOS 9.2.**

> `SDK/.../MapKit.framework/Headers/MKTileOverlay.h:13-17`
> ```
> // MKTileOverlay represents a data source for raster image tiles in the spherical mercator projection (EPSG:3857).
> NS_CLASS_AVAILABLE(10_9, 7_0) __TVOS_AVAILABLE(9_2) API_UNAVAILABLE(watchos)
> @interface MKTileOverlay : NSObject <MKOverlay>
>
> - (instancetype)initWithURLTemplate:(nullable NSString *)URLTemplate NS_DESIGNATED_INITIALIZER; // URL template is a string where the substrings "{x}", "{y}", "{z}", and "{scale}" are replaced with values from a tile path to create a URL to load. …
> ```

The whole class is unconditioned on tvOS: `tileSize` (default 256×256, `:19`),
`geometryFlipped` (`:21`), `minimumZ` / `maximumZ` (`:24-25`), `canReplaceMapContent`
(`:29`), and the two subclass hooks `URLForTilePath:` (`:43`) and
`loadTileAtPath:result:` (`:46`) — the latter being the seam for supplying tile bytes from
anywhere rather than a URL template.

**`MKTileOverlayRenderer`, which draws them: available since tvOS 9.2.**

> `SDK/.../MapKit.framework/Headers/MKTileOverlayRenderer.h:14-19`
> ```
> NS_CLASS_AVAILABLE(10_9, 7_0) __TVOS_AVAILABLE(9_2) API_UNAVAILABLE(watchos)
> @interface MKTileOverlayRenderer : MKOverlayRenderer
>
> - (instancetype)initWithTileOverlay:(MKTileOverlay *)overlay;
>
> - (void)reloadData;
> ```

Its base class `MKOverlayRenderer` is `__TVOS_AVAILABLE(9_2)` (`MKOverlayRenderer.h:14`) and
carries `alpha` (`:48`), `setNeedsDisplay` (`:41`) and
`setNeedsDisplayInMapRect:zoomScale:` (`:45`) with no platform restriction;
`blendMode` is `tvos(16.0)` (`:52`).

**The plumbing that attaches one to a map is available on tvOS 9.2** — every call is
annotated `tvos(9.2)` in `MKMapView.h`: `addOverlay:level:` (`:219`), `addOverlays:level:`
(`:220`), `removeOverlay:` (`:222`), `insertOverlay:atIndex:level:` (`:225`),
`insertOverlay:aboveOverlay:` / `belowOverlay:` (`:227-228`),
`exchangeOverlay:withOverlay:` (`:230`), `rendererForOverlay:` (`:236`), the delegate
callback `mapView:rendererForOverlay:` (`:323`) and `mapView:didAddOverlayRenderers:`
(`:324`). `MKOverlayLevel` (`AboveRoads` / `AboveLabels`) is `tvos(9.2)`
(`MKMapView.h:42-46`).

**The named restriction: SwiftUI's `Map` cannot do this on any platform in this SDK.**
The SwiftUI overlay is 1,128 lines and the string `tile` does not appear in it once; the only
match for `overlay` is `mapOverlayLevel(level:)` (`:1035`), which positions vector content.
Its complete `MapContent` vocabulary is `Marker` (`:179`), `Annotation` (`:613`),
`UserAnnotation` (`:306`), `MapCircle` (`:882`), `MapPolygon` (`:492`), `MapPolyline`
(`:949`), plus the plumbing types `EmptyMapContent`, `AnyMapContent`, `TupleMapContent`.
There is no raster-tile content type. So **raster tiles require the UIKit `MKMapView`**,
hosted in SwiftUI via `UIViewRepresentable` — which is itself available:

> `SDK/System/Library/Frameworks/SwiftUI.framework/Modules/SwiftUI.swiftmodule/arm64-apple-tvos.swiftinterface:20991-20994`
> ```
> @available(iOS 13.0, tvOS 13.0, *)
> @available(macOS, unavailable)
> @available(watchOS, unavailable)
> @preconcurrency @_Concurrency.MainActor public protocol UIViewRepresentable : SwiftUICore.View where Self.Body == Swift.Never {
> ```

### 3c. Animating a sequence of such tile frames — **AVAILABLE WITH A NAMED RESTRICTION**

**The restriction: MapKit on tvOS 18.0 has no frame-sequence, time-dimension or tile-animation
API at all.** Verified by hand: `grep -rn -i "animat"` across all 88 tvOS MapKit headers (the `Headers` directory holds 88
`.h` files plus `MapKit.apinotes`),
with the `animated:` method parameters excluded, returns six lines, and every one is about
annotation views — `MKAnnotationViewDragStateDragging` (`MKAnnotationView.h:28`),
`animatesDrop` (`MKPinAnnotationView.h:47`), `animatesWhenAdded`
(`MKMarkerAnnotationView.h:39`) and three comments about animating annotation views into place
(`MKMapView.h:206, 281, 282`). Nothing about overlays, tiles or time.

**What is available, and therefore what an animation would have to be assembled from** — each
piece annotated for tvOS 9.2 or unrestricted:

- Stack one `MKTileOverlay` + `MKTileOverlayRenderer` per frame and cross-fade them with
  `MKOverlayRenderer.alpha` (`MKOverlayRenderer.h:48`, no platform annotation).
- Or swap the visible frame with `exchangeOverlay:withOverlay:` (`MKMapView.h:230`,
  `tvos(9.2)`) or `removeOverlay:` + `addOverlay:level:` (`:222`, `:219`, both `tvos(9.2)`).
- Or hold one overlay and repoint it, subclassing `loadTileAtPath:result:`
  (`MKTileOverlay.h:46`) to return the current frame's bytes and calling
  `MKTileOverlayRenderer.reloadData` (`MKTileOverlayRenderer.h:19`) per step.
- The clock is `Foundation`/Swift concurrency, not MapKit.

So the answer is: **the parts are all available on tvOS 18.0; the assembled behaviour is not
an API Apple provides.** It is application code over available primitives.

### 3d. What this rules in and out

Nothing in (a), (b) or (c) is unavailable on tvOS. A tile-based radar overlay on a real map
is **not** ruled out by the platform. What the SDK does rule out, specifically:

- A radar overlay written in **pure SwiftUI `Map`** — there is no tile content type (§3b).
  `MKMapView` + `UIViewRepresentable` is the only path.
- **Map rotation, pitch, a compass and zoom controls** (§3a table) — a tvOS radar map is a
  flat, north-up, pan-and-zoom view, and any pitch or rotation affordance in a future design
  would have to be dropped.
- **Turn-key frame animation** (§3c) — the loop, the frame cache and the cross-fade are all
  app code.

**The honest limit of this evidence.** Every claim above is read from headers, `.swiftinterface`
files and linker stubs in the installed SDK. Whether `MKMapView` renders correctly, accepts
Siri Remote pan/zoom, and composites a tile overlay at 1920×1080 on the owner's actual Apple TV
is **not proven by this pass**, because proving it requires writing and running code, which is
out of scope here (see the STOP rule and Open Question 4).

---

## 4. tvOS capability — WeatherKit (step 4)

Not called, no entitlement added, no capability enabled — read only.

### 4.1 Present, and available at the app's deployment target

`WeatherKit.framework` is present in the installed tvOS SDK
(`SDK/System/Library/Frameworks/WeatherKit.framework`) and in the simulator SDK. It ships a
Swift module built for tvOS, not just headers:

- `…/WeatherKit.framework/Modules/WeatherKit.swiftmodule/arm64-apple-tvos.swiftinterface`
  and `arm64e-apple-tvos.swiftinterface` (1,300 lines each).
- Its module flags line reads
  `-target arm64-apple-tvos26.5 … -library-level api … -module-name WeatherKit`
  (`arm64-apple-tvos.swiftinterface:3`).
- `WeatherKit.tbd:3` declares `targets: [ arm64-tvos, arm64e-tvos ]`.
- The simulator interface is `-target arm64-apple-tvos26.5-simulator`.

The entry point is annotated **tvOS 16.0**, i.e. available at the app's tvOS 18.0 target:

> `arm64-apple-tvos.swiftinterface:999-1006`
> ```
> @available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
> final public class WeatherService : @unchecked Swift.Sendable {
>   public static let shared: WeatherKit.WeatherService
>   final public var attribution: WeatherKit.WeatherAttribution {
>     get async throws
>   }
>   convenience public init()
>   final public func weather(for location: _LocationEssentials.CLLocation) async throws -> WeatherKit.Weather
> ```

### 4.2 What it exposes on tvOS 18.0

The tvOS interface carries the full WeatherKit surface — 1 public class, 40 top-level
public structs and 7 top-level public enums (plus 5 enums nested inside them), counted by
hand from the interface. The top-level result:

> `arm64-apple-tvos.swiftinterface:691-697`
> ```
> public struct Weather {
>   public var currentWeather: WeatherKit.CurrentWeather
>   public var minuteForecast: WeatherKit.Forecast<WeatherKit.MinuteWeather>?
>   public var hourlyForecast: WeatherKit.Forecast<WeatherKit.HourWeather>
>   public var dailyForecast: WeatherKit.Forecast<WeatherKit.DayWeather>
>   public var weatherAlerts: [WeatherKit.WeatherAlert]?
>   public var availability: WeatherKit.WeatherAvailability
> }
> ```

Every field frame `5f` and the Home glance draw has a counterpart, all at tvOS 16.0 unless
noted:

| Design element (§1) | WeatherKit member | Interface line | tvOS |
|---|---|---|---|
| `81°`, `72°` | `CurrentWeather.temperature` | `:1195` | 16.0 |
| `feels like 84°`, `Feels 72°` | `CurrentWeather.apparentTemperature` | `:1196` | 16.0 |
| `Partly cloudy`, `Clear` | `CurrentWeather.condition` (`WeatherCondition`) | `:1186` | 16.0 |
| condition glyph | `CurrentWeather.symbolName` (an SF Symbol name) | `:1187` | 16.0 |
| `humidity 62%`, `humidity 54%` | `CurrentWeather.humidity` | `:1189` | 16.0 |
| `wind 8 mph SW` | `CurrentWeather.wind` → `Wind.speed`, `Wind.compassDirection` | `:1199`, `:935-938` | 16.0 |
| `H 83° · L 66°`, `H 78° · L 58°` | `DayWeather.highTemperature` / `.lowTemperature` | `:79`, `:82` | 16.0 |
| daily `pop`, `10% rain today` | `DayWeather.precipitationChance` | `:90` | 16.0 |
| daily day name | `DayWeather.date` | `:76` | 16.0 |
| daily glyph | `DayWeather.symbolName` | `:78` | 16.0 |
| hourly `3 PM` … | `HourWeather.date` | `:287` | 16.0 |
| hourly temp | `HourWeather.temperature` | `:303` | 16.0 |
| hourly glyph | `HourWeather.symbolName` | `:292` | 16.0 |
| hourly `pop` | `HourWeather.precipitationChance` | `:297` | 16.0 |
| `Severe thunderstorm watch until 9:00 PM` + body | `WeatherAlert.summary`, `.severity`, `.source`, `.region`, `.detailsURL` | `:1235-1241` | 16.0 |
| `updated 2:38 PM` | `WeatherMetadata` (via `CurrentWeather.metadata`, `:1200`) | `:1200` | 16.0 |
| ` Weather · … tap for sources` | `WeatherAttribution.serviceName`, `.legalPageURL`, `.squareMarkURL`, `.combinedMarkDarkURL`, `.combinedMarkLightURL`, and `.legalAttributionText` (tvOS 16.4, `:465-468`) | `:444-468` | 16.0 |

Also present on tvOS: `Weather.minuteForecast` (`MinuteWeather`, `:56`),
`WeatherAvailability.minuteAvailability` / `.alertAvailability` with
`AvailabilityKind` = `available / temporarilyUnavailable / unsupported / unknown`
(`:24-38`), `Forecast<Element>` as a `RandomAccessCollection` (`:783`), and the
tvOS 18.0-only additions — `dailyStatistics`, `hourlyStatistics`, `monthlyStatistics`,
`dailySummary` and the variadic
`weather(for:including:)` (all `@available(iOS 18.0, macOS 15.0, tvOS 18.0, …)`,
`:1013-1036`), plus `DayWeather.precipitationAmountByType` (`:112`),
`highTemperatureTime` / `lowTemperatureTime` (`:81`, `:84`) and
`CurrentWeather.cloudCoverByAltitude` (`:1185`).

Deprecations that matter at tvOS 18.0, quoted:

> `:106-110`
> ```
> @available(tvOS, introduced: 16.0, deprecated: 18.0, message: "Use precipitationAmountByType")
> public var snowfallAmount: Foundation.Measurement<Foundation.UnitLength>
> ```
> and `:91-96` — `precipitationAmount`, same deprecation, `@backDeployed(before: … tvOS 16.4 …)`.

### 4.3 WeatherKit exposes no radar, no tiles, no imagery — on tvOS or anywhere

`grep -n -i "radar\|tile\|imagery\|\bmap\b"` over the 1,300-line tvOS interface returns three
lines, all of them the generic type `Percentiles<Dimension>` (`:738`, `:742`, `:994`). There
is no radar product, no tile URL, no image API. **WeatherKit cannot supply the radar picture;
it supplies numbers and SF Symbol names only.**

### 4.4 What using it would require (reported, not done)

- **An entitlement.** Xcode's own portal capability table lists WeatherKit with
  `"profileKey": "com.apple.developer.weatherkit"`, `"valueType": "BOOLEAN"`,
  `"isRequiredInPlist": true`, and `"supportedProductTypes"` including
  `com.apple.product-type.application`. Its `supportedSDKs` list contains `TV_OS` explicitly.
  It also carries `"canRequestFromPortal": false` and `"enabledByDefault": false`, i.e. the
  capability has to be enabled on the App ID rather than requested automatically.
  Source: `/Applications/Xcode.app/Contents/SharedFrameworks/DVTPortal.framework/Versions/A/Resources/DVTPortalCachedPortalCapabilities.json`,
  record `data[185]`, `id: "WEATHERKIT"`.
  **Nothing was added — the project has no entitlements file and none was created.**
- **A `CLLocation`.** Every `WeatherService` call takes
  `for location: _LocationEssentials.CLLocation` (`:1006-1036`); the interface imports
  `CoreLocation` (`:5`). On tvOS the location API is narrower than on iOS, and the design's
  `From this Apple TV's location, not the server` (`dc:709`) runs into it:
  - `- (void)requestLocation` — `API_AVAILABLE(ios(9.0), macos(10.14))`, **no tvOS
    restriction** → available (`CoreLocation.framework/Headers/CLLocationManager.h:617`).
  - `- (void)requestWhenInUseAuthorization` — `API_AVAILABLE(ios(8.0), macos(10.15))`, no
    tvOS restriction → available (`CLLocationManager.h:475`).
  - `- (void)startUpdatingLocation` — `API_AVAILABLE(watchos(3.0)) API_UNAVAILABLE(tvos)`
    → **unavailable on tvOS** (`CLLocationManager.h:585`).
  - `- (void)requestAlwaysAuthorization` — `API_UNAVAILABLE(tvos, visionos)`
    → **unavailable on tvOS** (`CLLocationManager.h:515`).

  So a tvOS app gets **one-shot, when-in-use location only**, never continuous updates. That
  is enough for a weather screen, but the design's "updated 2:38 PM" would come from a
  refresh the app schedules itself, not from location callbacks. (Raised as Open Question 3.)

---

## Open Questions

1. **The design draws no radar.** Frame `5f` is a text-and-glyph forecast: current
   conditions, one alert card, 8 hourly columns, 5 daily rows, an attribution line. There is
   no map, no radar, no image slot anywhere in `design/` (§1.1). This pass was asked what is
   possible; it was not asked to add anything. Does the owner want radar **added** to the
   Weather screen — which is a change to what the approved design draws — or is frame `5f`
   as drawn the target?
2. **Five daily rows or seven?** `wxDaily` has 5 entries (`dc:1390-1394`) while the `sc-for`
   that renders them says `hint-placeholder-count="7"` (`dc:742`). WeatherKit's
   `dailyForecast` returns ten days. How many days should the screen show?
3. **Where does "Towson, Maryland" come from?** The design says
   `From this Apple TV's location, not the server` (`dc:709`), and WeatherKit needs a
   `CLLocation`. On tvOS that means `requestWhenInUseAuthorization` + `requestLocation` —
   a one-shot fix with a system prompt, no continuous updates (§4.4). Alternatives not
   evaluated here: a location the owner sets once, or one derived from the server's channel
   lineup. Which does the owner want? A decision is needed before any of this is built.
4. **Runtime proof of the map is missing and cannot be got in this pass.** §3 is header
   evidence. Confirming that `MKMapView` renders, pans with the Siri Remote and composites a
   tile overlay on the owner's Apple TV needs a throwaway build — writing code, which this
   pass forbids. Should a later pass do a minimal, disposable spike purely to prove or
   disprove it before any Weather work is planned?
5. **A radar picture has to come from somewhere, and WeatherKit is not it** (§4.3). Any radar
   would mean tiles from a third-party source, i.e. a new outbound dependency and a network
   request to a host outside the LAN — and the app's ATS today is only
   `NSAllowsLocalNetworking` (`Info.plist`). Choosing or evaluating a provider was explicitly
   out of scope, so nothing is proposed here; the owner would have to decide the source
   before anything can be designed against it.
6. **`COLD-START.md` and `DECISIONS.md` were deliberately not updated.** Step 5 named only
   this report as writable, and the scope lock says nothing else gets changed. If the owner
   wants the notebook to carry a Pass 12 line, that is a one-line follow-up.
7. **Still open from earlier passes, unanswered and touching Weather:** whether the tvOS app
   should honour the server's per-client sidebar layout, which includes a `weather` id backed
   by no endpoint (`pass2:377`, `pass2:326`); whether the Home Weather tile should show
   `72° · clear now` as designed once real data exists (`pass5:165`); and whether the empty
   520 pt glance slot on Home stays or the clock moves right (`pass5:167`).

---

## SCOPE CHECK

| File | Created / touched / read | Step that required it |
|---|---|---|
| `reports/2026-09-06-pass12-weather-recon.md` | **created** (the only file created or changed in the repo) | 5 |
| `COLD-START.md` | read only | preamble, 2 |
| `DECISIONS.md` | read only | preamble, 2 |
| `reports/*.md` (12 files, this report excluded) | read only | preamble, 2 |
| `design/Marlin DVR TV.dc.html` | read only | 1 |
| `design/` (14 files, inventory listed only) | read only | 1 |
| `Marlin DVR TV.xcodeproj/project.pbxproj` | read only (deployment target) | 3, 4 |
| `Info.plist` | read only (ATS state, Open Question 5) | Open Questions |
| `Marlin DVR TV/*.swift` (37 files, grep only) | read only | 1.5 context |
| `…/AppleTVOS26.5.sdk` — MapKit headers, `MapKit.tbd`, `MapKit.apinotes` | read only | 3 |
| `…/AppleTVOS26.5.sdk` — `_MapKit_SwiftUI` + `SwiftUI` `.swiftinterface` | read only | 3 |
| `…/AppleTVOS26.5.sdk` — `WeatherKit.swiftinterface`, `WeatherKit.tbd` | read only | 4 |
| `…/AppleTVOS26.5.sdk` — `CoreLocation/CLLocationManager.h` | read only | 4.4 |
| `…/AppleTVSimulator26.5.sdk` — MapKit + WeatherKit stubs/headers | read only | 3, 4 (parity) |
| `Xcode.app/…/DVTPortalCachedPortalCapabilities.json` | read only | 4.4 |
| `<session scratchpad>/weather-lines.txt` | created **outside the repo**, not committed | 2 (grep output, quoted from) |

**Not created, not changed, not installed:** no Swift file, no asset, no entitlement or
entitlements file, no `Info.plist` key, no build setting, no dependency, no capability, no
Weather stub or scaffold of any kind. `design/` was not modified. Nothing outside
`~/Xcode/Marlin DVR TV` was written. No request was sent to 192.168.1.250, 192.168.1.245,
192.168.1.105, the UNAS4Pro share, or any weather API. The only network use is the
`git fetch` / `git push` of this commit.

**Secret scan before commit:** the report was grepped for `token`, `secret`, `password`,
`Bearer`, `api[-_]key`, `ssh-rsa` and `BEGIN .* PRIVATE KEY` — the only matches are the two
lines of this paragraph naming the patterns. The Apple Developer
team identifier that appears in two quoted Pass 1 lines is masked as `C87…7Z` (§2.8); no
device id, UDID, client id or credential appears anywhere in this file.

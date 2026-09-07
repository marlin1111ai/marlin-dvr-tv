# Pass 22 — WeatherKit enabled: sign, entitle, and prove the Weather screen — 2026-09-06

**Real weather is on the Apple TV.** The App ID the owner registered carries WeatherKit, the
target is entitled, the app signs against that App ID instead of the team wildcard, and Pass 13's
`xpcConnectionFailed … com.apple.weatherkit.authservice … Sandbox restriction` is gone. Both
screens Pass 13 built and never saw — the Weather screen (frame 5f) and the Home glance
(frame 2a) — were photographed **populated** on Home Theater, driven by the real Siri Remote.

Populating them revealed three defects, all fixed and re-proven on the device: the current
conditions line was cut mid-word, the Weather screen's content never took focus so the remote was
stuck in the rail, and the Home glance read "**Apple Apple** Weather" and was cut. One field is
still unseen and is named rather than glossed: **the alert card**, because no alert is in force
here and WeatherKit's `WeatherAlert` cannot be constructed by an app.

**Citation keys.** `dc:NNN` = line NNN of `design/Marlin DVR TV.dc.html` (read-only, never
edited). `SDK` = the installed `AppleTVOS26.5.sdk`. Team identifiers are masked as `<team>`
throughout; no credential, token, device identifier or account detail is in this report, in the
code or in any log this pass wrote.

---

## 1. The App ID, confirmed before anything changed (step 1)

### 1.1 What was on this Mac before

Five provisioning profiles, decoded by hand this pass from
`~/Library/Developer/Xcode/UserData/Provisioning Profiles`. **None of them was for this app:**

| Profile name | application-identifier | carries `com.apple.developer.weatherkit` |
|---|---|---|
| `tvOS Team Provisioning Profile: com.marlin.dvr` | `<team>.com.marlin.dvr` | yes |
| `iOS Team Provisioning Profile: com.marlin1111.MarlinWeather` | `<team>.com.marlin1111.MarlinWeather` | yes |
| `tvOS Team Provisioning Profile: com.marlin.MarlinDVRGo` | `<team>.com.marlin.MarlinDVRGo` | yes |
| `tvOS Team Provisioning Profile: *` | `<team>.*` | no |
| `iOS Team Provisioning Profile: *` | `<team>.*` | no |

And the app was signed with the wildcard, read off the binary rather than assumed:

```
$ codesign -d --entitlements - "build/dd-device/…/Marlin DVR TV.app"
  application-identifier             <team>.com.marlin1111.MarlinDVRTV
  com.apple.developer.team-identifier <team>
  get-task-allow                     true
$ security cms -D -i ".../embedded.mobileprovision" | plutil -extract Name raw -o - -
  tvOS Team Provisioning Profile: *
```

Three keys, no WeatherKit, wildcard profile — exactly the state Pass 13 reported.

### 1.2 How the App ID was confirmed, without touching the repo

The portal cannot be read from this Mac without signing in to it, and this pass did not: there is
no App Store Connect API key on the machine (`~/.appstoreconnect/private_keys` and `~/private_keys`
do not exist) and Xcode caches no App ID list (`grep` over `com.apple.dt.Xcode`'s preferences and
caches for the bundle id returns nothing). So the App ID was confirmed the only way available —
**by asking Apple** — and it was asked in a way that left the repository untouched:

```
$ xcodebuild -project "Marlin DVR TV.xcodeproj" -scheme "Marlin DVR TV" \
    -destination 'platform=tvOS,name=Home Theater' \
    -derivedDataPath <scratchpad>/dd-probe \
    -allowProvisioningUpdates \
    CODE_SIGN_ENTITLEMENTS=<scratchpad>/probe.entitlements build
** BUILD SUCCEEDED **
```

The entitlements file and the derived data were both outside the project, passed as a build-setting
override; no file in the repo was created or edited by this step, so if Apple had said no there
would have been nothing to undo.

Apple answered with a **new** profile, which was decoded by hand:

| Field | Value |
|---|---|
| `Name` | `tvOS Team Provisioning Profile: com.marlin1111.MarlinDVRTV` |
| `AppIDName` | **`Marlin DVR TV`** |
| `application-identifier` | `<team>.com.marlin1111.MarlinDVRTV` — explicit, not `<team>.*` |
| `com.apple.developer.weatherkit` | **`true`** |
| `CreationDate` / `ExpirationDate` | 2026-09-07T03:40:41Z / 2027-09-07T03:40:41Z |

### 1.3 Why that proves the owner enabled it, and not Xcode

Xcode registers App IDs on its own and can turn on some capabilities while doing it. **WeatherKit
is not one of them.** Xcode's own cached portal capability table says so, read by hand this pass
rather than inherited from Pass 12:

> `/Applications/Xcode.app/Contents/SharedFrameworks/DVTPortal.framework/Versions/A/Resources/DVTPortalCachedPortalCapabilities.json`, entry `data[185]`
> ```
> "description": "WeatherKit provides current and forecasted weather information.",
> "canRequestFromPortal": false,
> "entitlements": [ { "name": "WeatherKit", "profileKey": "com.apple.developer.weatherkit", … } ]
> ```

A profile that comes back carrying `com.apple.developer.weatherkit` can therefore only have come
from an App ID on which a person ticked WeatherKit. The App ID's name seals it: it is
**"Marlin DVR TV"**, the description the owner said they typed — not the `XC com marlin1111
MarlinDVRTV` shape Xcode generates when it registers one itself.

**The honest limit.** What was read is Apple's answer to Xcode, not the portal page. Nobody signed
in to `developer.apple.com` from here, and this pass created, modified and requested no App ID and
no capability. The one thing it did cause Apple to create is a **development provisioning profile
for this app's own App ID**, which is what step 2 needs and nothing wider.

---

## 2. What changed in signing (step 2)

Two files in the repo. Nothing else — not the bundle id, not the deployment target, not the
signing style, not `Info.plist`, not the test target.

### 2a. `Marlin DVR TV.entitlements` — new, 8 lines, one key

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.developer.weatherkit</key>
	<true/>
</dict>
</plist>
```

It sits at the repo root beside `Info.plist`, which is where this project already keeps the
target's plists, and like `Info.plist` it has no `PBXFileReference` — the project's two source
folders are `PBXFileSystemSynchronizedRootGroup`s and the plists live outside them deliberately,
so nothing can sweep them into a Copy Resources phase. Xcode's Signing & Capabilities pane reads
the capability from this file.

### 2b. `Marlin DVR TV.xcodeproj/project.pbxproj` — two lines

```diff
@@ app target, Debug (config DA…B7) @@
+				CODE_SIGN_ENTITLEMENTS = "Marlin DVR TV.entitlements";
 				CODE_SIGN_STYLE = Automatic;
@@ app target, Release (config DA…B8) @@
+				CODE_SIGN_ENTITLEMENTS = "Marlin DVR TV.entitlements";
 				CODE_SIGN_STYLE = Automatic;
```

That is the entire diff of the file: `git diff --stat` reports **2 insertions, 0 deletions**.
The `Marlin DVR TVUITests` configurations (DA…D7, DA…D8) were **not** touched; that target keeps
its own bundle id `com.marlin1111.MarlinDVRTV.UITests` and still signs with the team wildcard,
which is correct — it needs no capability.

### 2c. Provisioning — nothing pinned in the project

`CODE_SIGN_STYLE` stays `Automatic` and no `PROVISIONING_PROFILE_SPECIFIER` was added. Once the
entitlement existed, automatic signing chose the explicit profile by itself. The profile file
lives on the Mac (`~/Library/Developer/Xcode/UserData/Provisioning Profiles/`), never in the repo.

### 2d. What the built app carries now

Read off the binary that was installed on Home Theater, not asserted:

```
$ codesign -d --entitlements - "build/dd-device/…/Marlin DVR TV.app"
  application-identifier              <team>.com.marlin1111.MarlinDVRTV
  com.apple.developer.team-identifier <team>
  com.apple.developer.weatherkit      true          ← new
  get-task-allow                      true
$ security cms -D -i ".../embedded.mobileprovision" | plutil -extract Name raw -o - -
  tvOS Team Provisioning Profile: com.marlin1111.MarlinDVRTV        ← was "…: *"
```

### 2e. What deliberately did not change

| Thing | Value, verified this pass |
|---|---|
| `PRODUCT_BUNDLE_IDENTIFIER` | `com.marlin1111.MarlinDVRTV` (unchanged) |
| `TVOS_DEPLOYMENT_TARGET` | `18.0`, in all four configurations (unchanged) |
| `CODE_SIGN_STYLE` | `Automatic` (unchanged) |
| `DEVELOPMENT_TEAM` | unchanged |
| `Info.plist` | untouched — **no ATS change was needed and none was made** |
| Any other App ID, profile or certificate | untouched. Nothing was read from, written to or requested for `MarlinWeather`, `com.marlin.dvr`, `MarlinDVRGo` or the XC wildcards beyond decoding the profile files already on this Mac. |

---

## 3. WeatherKit answers on Home Theater (step 3)

**Pass 13, same device, same app:**

```
[client] ping ok: id=… name=Apple TV app=Marlin DVR TV 1.0 type=Apple TV os=tvOS 26.6
[weather] WeatherKit: xpcConnectionFailed(Error Domain=NSCocoaErrorDomain Code=4099
  "The connection to service named com.apple.weatherkit.authservice was invalidated:
   Connection init failed at lookup with error 159 - Sandbox restriction.")
```

**Pass 22, the build committed by this pass, launched with the console attached:**

```
$ xcrun devicectl device process launch --device <Home Theater> --console --terminate-existing \
    com.marlin1111.MarlinDVRTV
Launched application with com.marlin1111.MarlinDVRTV bundle identifier.
[hold] press recognizer installed on the window
[client] ping ok: id=… name=Apple TV app=Marlin DVR TV 1.0 type=Apple TV os=tvOS 26.6 ip=…
```

`grep -c '\[weather\]'` over that capture: **0**. `WeatherModel` prints only on failure
(`WeatherModel.swift`, the `catch` in `run()`), so the sandbox denial is the line that is missing,
and the positive half of the proof is §4 and §5 — the numbers on the screen, which can only have
come from WeatherKit.

**The build under test is the build in this commit.** Every device run of this pass built,
installed and ran in one `xcodebuild … test` invocation against `platform=tvOS,name=Home Theater`;
the last one finished at 23:56 with the app binary stamped 23:55, after the final source change
and after the diagnostic of §4.7 was reverted. Build output: `** BUILD SUCCEEDED **`, and the only
warning in the target is the pre-existing `GuideScreen.swift:336` one that Pass 13 also recorded —
nothing this pass touched warns.

---

## 4. The Weather screen, populated — field by field against frame 5f (step 4)

`reports/assets/pass22/atv-02-weather-populated.png`. Every string below was also printed out of
the device's own accessibility tree by the harness, so the report quotes what the Apple TV drew.

| dc | Field the design draws | What rendered on Home Theater | Verdict |
|---|---|---|---|
| `706` | `Weather`, 52 pt medium | `Weather` | correct |
| `707` | `Towson, Maryland · updated 2:38 PM` | `Fallston, MD · updated 11:51 PM` | correct — the town-and-state rule of Pass 13, and the time is WeatherKit's `metadata.date` (it read 11:43 PM on an earlier run and advanced), not when the app asked |
| `709` | `From this Apple TV's location, not the server` | the same, right-aligned | correct |
| `714` | condition glyph, 104 pt accent-200 | `moon.stars` at 104 pt in accent-200 | correct — it was a clear night; the symbol is WeatherKit's own `symbolName` |
| `716` | `81°`, 112 pt light | `64°` | correct |
| `717` | `Partly cloudy · feels like 84°` | `Clear · feels like 61°` | correct |
| `718` | `H 83° · L 66° · humidity 62% · wind 8 mph SW` | `H 78° · L 61° · humidity 71% · wind 5 mph NNE` | **was cut** — "wind 5 mph N…" — fixed, §4.5 |
| `721-727` | the alert card | **nothing** — no alert is in force here | **unseen with real data**, §4.7 |
| `730-739` | 8 hourly columns between two dividers | **8**: 12 AM 64°, 1 AM 63°, 2 AM 62°, 3 AM 61°, 4 AM 60°, 5 AM 59°, 6 AM 59°, 7 AM 59°, each with its glyph, between both dividers | correct, counted on the screen |
| `741-753` | 5 daily rows with the range bar | **5**: Today 61°–78° (6%), Tomorrow 59°–78°, Tuesday 57°–81°, Wednesday 62°–85°, Thursday 67°–87° (43%) | correct, counted on the screen — see §4.3 for the bars and §4.6 for "Tomorrow" |
| `754-758` | the Apple Weather footer | `[apple logo] Apple Weather · data and attribution required by WeatherKit · weatherkit.apple.com/legal-attribution.html` | correct |
| `1402-1403` | the focus ring on the first daily row | **nothing had focus in the content at all** | **was wrong** — fixed, §4.5 |

### 4.1 The chance-of-rain rule, seen working

The design leaves the chance blank when there is none (`pop:""`, dc:1379-1380, 1391). On the
screen the hourly strip shows no chance on any of the eight columns (a clear night), and the daily
list shows `6%` on Today and `43%` on Thursday with the other three blank — so the empty case and
the populated case were both observed, in both strips.

### 4.2 The hourly strip has no "Now" column, and that is right

`WeatherFormat.hourLabel` labels the current hour "Now". It did not appear: at 11:51 PM the
current hour's entry is more than 30 minutes old, and the screen drops those, so the strip starts
at the next clock hour. **The design does the same** — frame 5f's strip is 3 PM → 10 PM with no
"Now" anywhere (dc:1379-1386) — so what rendered matches the design and nothing was changed.
Between :00 and :29 past the hour the first column will read "Now" instead; that half of the
behaviour was not observed this pass.

### 4.3 The range bars

Scaled across the whole list, as the design does (dc:1396-1401): the list's own minimum is 57°
(Tuesday) and maximum 87° (Thursday), and each bar starts at `(low − 57) / 30` and spans
`(high − low) / 30` of the track. Measured off the screenshot, Today's bar starts about an eighth
in and ends about two-thirds across — `(61−57)/30 = 13 %` to `(78−57)/30 = 70 %` — and Thursday's
runs from a third to the full width. Gradient, track colour and the 8 pt height are the design's.

### 4.4 What was already right and needed nothing

Spacing between the header, the current block, the two dividers and the daily list; the hourly
columns dividing the width evenly; the daily row columns (240 pt day, 44 pt glyph, 80 pt chance,
80 pt low, bar, 80 pt high) all lining up with real numbers in them; the attribution pinned to the
bottom; nothing wrapping, overflowing or overlapping anywhere on the screen. The rail is beside it
as frame 5f draws it, and collapses to icons when focus is in the content.

### 4.5 The two defects this pass found on the Weather screen, and the fixes

**(a) The current-conditions detail line was cut: "H 78° · L 61° · humidity 71% · wind 5 mph N…"**
(`atv-06-before-detail-line-cut-and-focus-in-the-rail.png`).

Cause: the row is an `HStack` of the current block and the alert card, and when there is no alert
its slot is still a `maxWidth: .infinity` placeholder. SwiftUI proposes half the row to each, and
half was about ten points short of the sentence. The design has no such symmetry — the alert card
is the flexible half (`flex:1; min-width:0`, dc:721) and the current block is not — so the fix is
one line, `.layoutPriority(1)` on the current block. The line now renders whole, **with and
without the alert card present** (§4.7 proves the second case).

**(b) The screen's content never took focus, so the remote was stuck in the rail.**

Pass 13 focused the first daily row from `onChange(of: model.phase)` when the phase became
`.ready`. But Home and the Weather screen share one `WeatherModel` — that is deliberate, so
WeatherKit is asked once — and Home has already made the read, so by the time the screen opens the
phase is *already* `.ready` and the change never happens. Nothing in the content asked for focus,
the rail kept it, and pressing Down walked down the rail instead of the daily list
(`atv-06-…png`: the ring is on the rail, not on Today). Before this pass the bug could not exist:
the phase was always `.failed`, and the error panel's **Try again** button took focus from
`onAppear`.

Fixed by asking for the first daily row in `.task` too, when the model is already ready. Frame 5f
draws the ring exactly there (dc:1402-1403). Proven on the device: `atv-02-weather-populated.png`
shows **Today** ringed the moment the screen opens, walking down moves through the daily rows
(`atv-03-weather-daily-list-walked.png`), and walking back up reaches the Radar entry in the
header (`atv-04-radar-reachable-from-the-daily-list.png`) — which is only possible if focus was in
the content, so the harness asserts it.

### 4.6 One deviation from the design left alone, on purpose

The second daily row says **"Tomorrow"**; the design says a weekday name (dc:1391, "Saturday",
which is the day after its "Today"). The string comes from `TimeFormat.relativeDay`, which the
Guide, On Later and Recordings all use; changing it would change those screens, which this pass
has no licence to touch. Recorded in DECISIONS.md and left as it is.

### 4.7 The alert card — still unseen, and what was done instead

**No alert is in force for this location**, so `weatherAlerts` is empty and the card did not draw.
It cannot be staged with a real value either: `WeatherKit.WeatherAlert` has no public initializer
(`SDK: WeatherKit.swiftinterface:1235-1241` — six `public var`s and nothing else; the only `init`
on it is `init(from decoder:)`).

So the card's **layout** was checked with a disclosed temporary diagnostic: the view's alert branch
was fed two literal strings of the shape WeatherKit actually returns — an NWS-style summary
("Severe Thunderstorm Warning issued September 6 at 8:14PM EDT until September 6 at 9:00PM EDT by
NWS Baltimore/Washington") and `severity · source · region`. It fetched nothing and invented no
weather. Result (`atv-05-alert-card-staged-diagnostic.png`): the card sits top-right in its slot,
the summary wraps cleanly onto three lines beside the warning glyph, the second line sits under it,
and the surface, radius, hairline and padding are the design's. **And the current block beside it
kept its full width** — "wind 5 mph NNE" complete — which is the case §4.5(a)'s fix most needed to
be checked against.

**The diagnostic is not in the build.** It was reverted before committing;
`grep -rn "DIAGNOSTIC\|stagedAlert" "Marlin DVR TV/"` returns nothing, and its screenshot carries
`-diagnostic` in the filename so nobody mistakes it for a real alert. What is still true is that
**the card has never been drawn from a real WeatherKit alert**, and that stays open (Open
Question 1).

---

## 5. The Home glance, populated — field by field against frame 2a (step 5)

`reports/assets/pass22/atv-01-home-glance-populated.png`.

| dc | Field the design draws | What rendered | Verdict |
|---|---|---|---|
| `134` | condition glyph, 58 pt neutral-300 | `moon.stars` at 58 pt neutral-300 | correct |
| `137` | `72°`, 52 pt medium | `64°` | correct |
| `138` | `Clear`, 29 pt neutral-300 | `Clear` | correct |
| `140` | `H 78° · L 58° · 10% rain today`, 23 pt | `H 78° · L 61° · 6% rain today` | correct |
| `141` | `Feels 72° · humidity 54% · Apple WeatherKit`, 23 pt | `Feels 61° · humidity 71% · Apple Weather` | **was wrong twice** — fixed, §5.1 |
| `133` | the 520 pt card, top-right of Home's header | 520 pt, in its slot, clock unmoved | correct |

The card fills the slot Pass 5 held open with a `Color.clear`, and the greeting, the name and the
clock line all sit exactly where they sat before it filled — confirmed by capturing Home before
and after opening Weather (`atv-01-…`, and the return trip).

### 5.1 The defect this pass found on the glance, and the fix

Before (`atv-07-before-home-glance-apple-apple.png`), the fourth line read:

```
Feels 62° · humidity 71% · Apple Apple…
```

(62° there and 61° after: the apparent temperature fell by a degree over the eight minutes between
the two runs. Nothing in the fix touches a number.)

Two things wrong at once.

**"Apple Apple".** `WeatherAttribution.serviceName` is already `"Apple Weather"`, and the card
prefixed a word "Apple" of its own — Pass 13 wrote that assuming the service name would be
"Weather", which could not be checked with WeatherKit refusing. The prefix is gone; the service
name is printed as WeatherKit gives it.

**And it was cut anyway.** Even the shorter, correct sentence did not fit. The card is 520 pt with
30 pt of padding a side; the glyph's box took 72 and the trailing spacer took about 30 more from
the text column, leaving roughly 306 pt for a line that needs 337 pt at the smallest size the card
allows (measured with the system font at 23 pt and at the 0.8 minimum scale: 406.4 pt and
337.4 pt). Two changes, both toward the design rather than away from it:

- the text column takes its width before the spacer (`.layoutPriority(1)`), which is what the
  design's flex row does — the column is its last child (dc:135) and the leftover simply stays at
  the end;
- the glyph's box is the design's **58 pt** (dc:134) instead of 72, giving the sentence the 14 pt
  it was short.

After: `Feels 61° · humidity 71% · Apple Weather`, whole, no ellipsis
(`atv-01-home-glance-populated.png`). **No field was removed or shortened to make it fit.**

### 5.2 What was already right

The glyph, the temperature and the condition on one baseline; the four lines' sizes and colours;
the surface, radius and shadow; the card's width and its place in the header; and the second line
fitting with real numbers in it. Home's other nine tiles were captured in the same screenshots and
are unchanged — Guide 83, On Now 83, On Later 6, Recordings 5 · 0, Cameras 1 of 1, Favorites 4,
Radio 2 stations, Weather and Settings on their static lines.

---

## 6. Evidence — hands-on, on the owner's Apple TV (step 6)

### 6.1 The harness

`Marlin DVR TVUITests/WeatherKitEnabledUITests.swift` (131 lines) — Pass 22's evidence harness,
not a standing test, the same route Passes 9, 10B, 13, 19 and 20 took: `XCUIRemote` driving the
**real Siri Remote** on Home Theater. It makes no server write and asks WeatherKit for nothing of
its own; it presses buttons, photographs the screen, and prints every string in the app's
accessibility tree so this report can quote the device rather than the source.

```
$ xcodebuild -project "Marlin DVR TV.xcodeproj" -scheme "Marlin DVR TV" \
    -destination 'platform=tvOS,name=Home Theater' -allowProvisioningUpdates test \
    -only-testing:"Marlin DVR TVUITests/WeatherKitEnabledUITests"
Test Case '-[…WeatherKitEnabledUITests testBothScreensPopulatedOnTheDevice]' passed (39.207 seconds).
** TEST SUCCEEDED **
```

It fails if either screen does not fill: it waits for the glance's "Feels …" line and for the
Weather screen's attribution line, and asserts both, so a green run *is* the claim that WeatherKit
answered. It ran green five times this pass — once before the fixes, once after each of the two rounds of
fixes, once with the alert-card diagnostic of §4.7 in place, and once more on the committed code.

### 6.2 The screenshots

| File | What it shows |
|---|---|
| `atv-01-home-glance-populated.png` | Home with the glance card filled: 64°, Clear, `H 78° · L 61° · 6% rain today`, `Feels 61° · humidity 71% · Apple Weather` — all four lines whole |
| `atv-02-weather-populated.png` | the Weather screen with every field of frame 5f drawn, and **Today** carrying the focus ring |
| `atv-03-weather-daily-list-walked.png` | the daily list walked with the remote — the ring on the third row |
| `atv-04-radar-reachable-from-the-daily-list.png` | walking back up reaches the Radar entry, which proves focus was in the content |
| `atv-05-alert-card-staged-diagnostic.png` | the alert card's **layout** with staged strings — reverted, and labelled `-diagnostic`; note the detail line beside it is whole |
| `atv-06-before-detail-line-cut-and-focus-in-the-rail.png` | before the fixes: "wind 5 mph N…" and the focus ring in the rail |
| `atv-07-before-home-glance-apple-apple.png` | before the fix: "Feels 62° · humidity 71% · Apple Apple…" |

### 6.3 What is proven, and what is not

| # | Claim | How |
|---|---|---|
| 1 | The App ID exists and carries WeatherKit | Apple returned a profile for it with the entitlement, and Xcode cannot enable that capability itself (§1.2, §1.3) |
| 2 | The app signs against it, not the wildcard | `codesign -d --entitlements` and the embedded profile's name, read off the installed binary (§2d) |
| 3 | The sandbox denial is gone | zero `[weather]` lines in the device console for the committed build (§3) |
| 4 | The Weather screen draws real data | `atv-02`, and the 53 strings the screen drew, read out of the device's tree (§4) |
| 5 | The Home glance draws real data | `atv-01`, and the 25 strings Home drew, read out of the device's tree (§5) |
| 6 | The three defects are fixed | before-and-after screenshots from the same device, same night (§4.5, §5.1) |
| 7 | Focus reaches the content and the header | the harness asserts the Radar entry takes focus after walking up out of the list |
| — | **The alert card with a real alert** | **not proven.** No alert is in force; the type cannot be constructed. Layout only, with a reverted diagnostic (§4.7) |
| — | **The "Now" hourly column** | **not observed** — it only appears in the first half of an hour (§4.2) |
| — | **A WeatherKit failure after the entitlement** | **not observed and not staged.** The error paths (`noLocation`, `failed`, **Try again**) were exercised in Pass 13 and were not re-run here |
| — | **The radar** | untouched this pass — out of scope. It was not opened, and `RadarScreen.swift` and `RadarSource.swift` were not edited |
| — | **The second Apple TV (Master Bedroom)** | not touched. Only Home Theater |

### 6.4 What went wrong on the way

Nothing failed. The one thing worth recording is that the first device run of this pass was made
*before* any fix, deliberately, so the defects would be photographed as they shipped rather than
described after the fact — which is where `atv-06` and `atv-07` come from.

---

## 7. Notebook (step 7)

- `COLD-START.md` "What is built" gained a **Pass 22** paragraph.
- `COLD-START.md` "What is NOT built": the **"Built but blocked on the owner"** block is now
  empty of blockers and says so — the radar's rate was closed by Pass 16 and WeatherKit by this
  pass — with the alert card named as the one thing still unseen.
- `COLD-START.md` "Next step" records that Pass 22 is committed and **not pushed**, and the
  harness list gained `WeatherKitEnabledUITests` with its command line.
- `DECISIONS.md` gained `## 2026-09-06 (Pass 22 — WeatherKit enabled, and both weather screens
  populated)`: the App ID and how it was confirmed, exactly what moved the signing, the three
  fixes, the alert card's status, the "Now" column and the "Tomorrow" deviation.

What happened only. No proposals were written into either file; the questions are all below.

---

## Open Questions

1. **The alert card has still never been drawn from a real alert.** Everything around it is
   proven and its layout holds with content in it, but the real thing needs an alert in force in
   the owner's area. There is nothing to do until weather provides one; the honest options are to
   wait and photograph it when it happens, or to accept the staged-layout evidence. Nothing in
   the code is waiting on this.
2. **The "Now" hourly column was not observed.** It renders only when the screen is opened in the
   first half of a clock hour. Worth a look next time someone is on that screen before :30 — and
   worth deciding whether it should exist at all, since the design draws eight clock hours and no
   "Now".
3. **"Tomorrow" versus a weekday name on the second daily row** (§4.6). Fixing it means changing
   `TimeFormat.relativeDay`, which the Guide, On Later and Recordings share, so it is an
   app-wide wording decision rather than a Weather one.
4. **The Weather screen never refreshes while it is open.** `WeatherModel.load()` is idempotent
   for the life of the app process, so the "updated …" time and every number are from the read
   made at launch; leaving the screen and coming back does not re-read either. The radar refreshes
   itself every five minutes (Pass 15) and the weather does not. Not a defect against anything the
   design draws, which is why nothing was changed, but it is a difference the owner may not expect.
5. **Selecting a daily row does nothing** — Pass 13 recorded that the design gives it no action,
   and now that the rows take focus on arrival it is more visible. Whether a focused row that does
   nothing on Select is right is the owner's call.
6. **Release builds are entitled but unexercised.** `CODE_SIGN_ENTITLEMENTS` went into both
   configurations; only Debug was built and run this pass.

---

## SCOPE CHECK

Every file this pass created or changed, and the step that required it. `git status` shows these
and nothing else.

| File | Change | Step |
|---|---|---|
| `Marlin DVR TV.entitlements` | **new** (8 lines) — the one key `com.apple.developer.weatherkit` | 2 |
| `Marlin DVR TV.xcodeproj/project.pbxproj` | +2 lines — `CODE_SIGN_ENTITLEMENTS` in the app target's Debug and Release configurations. Nothing else in the file | 2 |
| `Marlin DVR TV/WeatherScreen.swift` | +11 lines — `.layoutPriority(1)` on the current block, and the first daily row asked for in `.task`; both with the reason in a comment | 4 |
| `Marlin DVR TV/HomeWeatherGlance.swift` | +16/−3 lines — the glyph box 72 → 58, `.layoutPriority(1)` on the text column, and the duplicated "Apple" removed | 5 |
| `Marlin DVR TVUITests/WeatherKitEnabledUITests.swift` | **new** (131 lines) — the device evidence harness | 3, 4, 5, 6 |
| `reports/assets/pass22/*.png` | **new** — 7 screenshots from Home Theater | 6 |
| `COLD-START.md` | the Pass 22 paragraph, the blocker block, the next-step line, the harness command | 7 |
| `DECISIONS.md` | the Pass 22 section | 7 |
| `reports/2026-09-06-pass22-weatherkit.md` | **new** — this report | 8 |

**Not touched, and checked:** `design/` (read only — `git status` shows it clean);
`RadarScreen.swift` and `RadarSource.swift`; every Radio, Guide, On Now, On Later, Recordings,
Cameras, Favorites, Player and Manage DVR file; `Info.plist` (no ATS change); `Destination.swift`
and the parked Settings screen; the `Marlin DVR TVUITests` build configurations; the Marlin DVR
server and every host on the do-not-touch list — the app talked to `192.168.1.250:8090` only as it
always does when Home loads its tiles, and this pass sent it nothing of its own.

**Secrets:** scanned before committing. No token, password, key, device identifier or account
detail is in the code, the report or any committed file; the team identifier is masked as
`<team>` everywhere it appears here, and the signing identity and profile UUIDs are not quoted.

**Push gate:** committed locally, **not pushed**, as this pass required. The owner tests on Home
Theater and the push is approved after that.

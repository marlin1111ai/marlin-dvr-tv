# Pass 20 — Pass 19 pushed, and the Home Radio count — 2026-09-06

Two things. Pass 19 is on `origin main`, verified three ways. And the Home Radio tile carries the
server's station count — **"2 stations"** — in place of the static word it had shown since Pass 5.

The Home change is committed locally and **not pushed**; the push gate stands until the owner has
tested it on Home Theater.

No station was added, edited, reordered or deleted. `design/`, `Info.plist`, `project.pbxproj` and
every other screen are untouched, and so is every other Home tile. The only requests this pass made
to `192.168.1.250` were the app's own reads.

---

## 1. Step 1 — the push, and how it was verified

Before: a clean working tree, `HEAD` two commits ahead of `origin/main`, and `origin/main` an
ancestor of `HEAD` (so a fast-forward, with nothing to rebase and nothing to amend).

```
git merge-base --is-ancestor origin/main HEAD   → yes
git rev-list --count HEAD..origin/main          → 0
```

Pushed. Then **fetched again and read the SHA from three independent places**, rather than trusting
what `git push` printed:

| Reading | SHA |
|---|---|
| `git rev-parse HEAD` | `dc28aec90f9eeb60fd183cf47b8ca68e8d740c26` |
| `git rev-parse origin/main` | `dc28aec90f9eeb60fd183cf47b8ca68e8d740c26` |
| `git ls-remote origin main` | `dc28aec90f9eeb60fd183cf47b8ca68e8d740c26` |

All three equal. The two commits are on `origin/main` in order and unaltered:

```
dc28aec  Pass 19: the notebook, and the report with the step 6 findings
2a3b43b  Pass 19: the Radio screen, playing on the Apple TV
3aa6ebe  Pass 18: radio recon (read-only)
```

`3aa6ebe` is still an ancestor of `origin/main`, so no history was rewritten, and the reflog shows
six plain `commit:` entries and no rebase, amend or reset. Range pushed: `3aa6ebe..dc28aec`.

---

## 2. Steps 2 and 3 — what the tiles say

### 2.1 What the other tiles say, read out of the code and then off the screen

Every counted tile puts **the number first, then a lowercase noun**. Verbatim from
`HomeView.swift`, and beside it what each actually drew on Home Theater during this pass:

| Tile | The format string | On the device, 2026-09-06 |
|---|---|---|
| Guide | `"\(list.count) channels live"` | `83 channels live` |
| On Now | `"\(items.count) programs live"` | `83 programs live` |
| On Later | `"\(response.count) upcoming"` | `6 upcoming` |
| Recordings | `"\(response.recordings) recordings · \(recordingNow) recording now"` | `5 recordings · 0 recording now` |
| Cameras | `"\(response.online) of \(response.count) online"` | `1 of 1 online` |
| Favorites | `"\(favourites) favourite channel\(favourites == 1 ? "" : "s")"`, or `"None yet"` at zero | `4 favourite channels` |
| Weather | static | `Local weather` |
| Settings | static | `Server, tuners, storage` |

Two things about that set are worth stating because they decided the wording:

* **Favorites is the only tile that pluralises**, and it does it with
  `channel\(n == 1 ? "" : "s")`. That is the house idiom for a countable noun.
* Every failing read sets the tile to the single word `"unavailable"`.

### 2.2 What the Radio tile says now

**`2 stations`** — and `1 station` if the owner ever has one:

```swift
subtitles[.radio] = count > 0 ? "\(count) station\(count == 1 ? "" : "s")" : nil
```

Number first, lowercase noun, pluralised exactly as Favorites pluralises. It agrees with three
things that already existed and were not invented for this pass: the design's own sub-line for this
tile, `"6 stations"` (`dc:1361`); the Radio screen's own header, which has read
`"2 stations · audio only, no tuner needed"` since Pass 19; and the shape of every other counted
tile above.

`count` is **the endpoint's own `count` field** (`radio.go:87`, `len` of the station slice), as the
step required — not the length of the decoded array.

### 2.3 How Home reads it

`HomeModel.load()` had five `async let` requests and five `do`/`catch` blocks. It now has six of
each. The sixth is the same shape as the other five — one request, no retries, its own catch — so
**no restructuring was needed** and the stop-and-report condition did not fire:

```swift
async let radio = api.radio()
…
do {
    let count = try await radio.count
    subtitles[.radio] = count > 0 ? "\(count) station\(count == 1 ? "" : "s")" : nil
} catch {
    subtitles[.radio] = nil
    print("[home] radio: \(error)")
}
```

One other line had to change, and it is the reason the tile could never have shown a number before:

```diff
 func subtitle(for destination: Destination) -> String {
-    if let s = destination.staticTileSubtitle { return s }
-    return subtitles[destination] ?? "…"
+    if let loaded = subtitles[destination] { return loaded }
+    if let s = destination.staticTileSubtitle { return s }
+    return "…"
 }
```

The static line used to win unconditionally, so `subtitles[.radio]` would have been set and never
read. A loaded value now wins and the static line is the fallback. **Weather and Settings are
unaffected** — neither ever gets a loaded value, so both take the same branch they always took.
This is asserted on the device, not assumed (§4.2).

The whole change is `+26/−2` in `HomeView.swift` and `+4/−3` in `Destination.swift`, the latter
being one stale doc comment.

---

## 3. Step 4 — what happens when there is no count

Two states, one outcome: **the tile reads "Stations"**, exactly as it has since Pass 5.

| | What is drawn | What is *not* drawn |
|---|---|---|
| The list is empty (`count == 0`) | `Stations` | `0 stations` |
| The server does not answer | `Stations` | `unavailable`, which is what every other tile says |
| A read fails after an earlier one succeeded | `Stations` | `2 stations` kept from before |

That third row is the one worth spelling out. `HomeModel` is created once in
`Marlin_DVR_TVApp` and outlives the Home screen, which re-runs `load()` on every return to it. So
the failure paths **clear** the key (`subtitles[.radio] = nil`) rather than simply not setting it —
otherwise a count from a healthy read would sit on the tile under a server that had since gone
away. Clearing it is what makes the fallback honest rather than merely usual.

Radio diverging from "unavailable" is deliberate and is what the step asked for: the tile has a
sensible thing to say without a number, and the other eight do not.

---

## 4. Hands-on test evidence

Home Theater, Apple TV 4K (3rd generation), tvOS 26.6 build 23L773, 2026-09-06. The harness reads
each tile's own accessibility label — a Home tile's label is `"<name>, <sub-line>"` — so every
assertion below is on text the app actually drew.

### 4.1 The count

`reports/assets/pass20/atv-01-home-radio-count.png`. All nine labels, captured in one go and
printed by the test:

```
Guide, 83 channels live          On Now, 83 programs live     On Later, 6 upcoming
Recordings, 5 recordings · 0 recording now
Cameras, 1 of 1 online           Favorites, 4 favourite channels
Weather, Local weather           Radio, 2 stations            Settings, Server, tuners, storage
```

The Radio sub-line was asserted three ways: that it is no longer `Stations`, that it matches
`^[0-9]+ stations?$` — the shape, not just the value — and that it equals `2 stations`, the count
the owner's server actually holds.

### 4.2 That nothing else moved

`atv-01` again, and a second test that checks each of the other eight against the shape it has had
since the pass that built it (`^[0-9]+ channels live$`, `^[0-9]+ of [0-9]+ online$`,
`^(None yet|[0-9]+ favourite channels?)$`, and so on), plus that Home still draws nine tiles. All
eight matched. A changed format anywhere on Home would have failed this.

### 4.3 The two fallbacks

Proven with a **disclosed temporary switch** in `HomeModel` that is not in the committed build. It
staged the two states from the UI test's launch environment; it wrote nothing to the server, and
"unreachable" was measured against a dead port on the Apple TV itself (`127.0.0.1:9`) so no other
host was touched.

| Staged | Screenshot | The Radio tile read |
|---|---|---|
| Empty list | `atv-02-empty-list-falls-back-diagnostic.png` | `Stations` |
| Server does not answer | `atv-03-unreachable-falls-back-diagnostic.png` | `Stations` |

Both screenshots show **every other tile still carrying its real count** — `83 channels live`,
`5 recordings · 1 recording now`, `4 favourite channels`. That is the useful detail: only the radio
read was diverted, so the fallback is the Radio tile's own behaviour and not a picture of a Home
screen that failed to load.

### 4.4 Proof this is the build that was made

The temporary switch was removed, the two tests that depended on it were removed from the harness,
the app was rebuilt, and the remaining two tests re-run on the device:

```
testNoOtherHomeTileChanged             passed (9.2 s)
testRadioTileShowsTheServerStationCount passed (4.6 s)
** TEST SUCCEEDED **
```

with the same nine labels, `Radio, 2 stations` among them. The device binary changed between the
two runs, which is what a fresh install looks like:

| | `Marlin DVR TV.debug.dylib` sha256 | size | built |
|---|---|---:|---|
| diagnostic build | `7f6ddce6…d1b73c9e` | 10,597,440 B | 23:04 |
| shipping build | `6b76088b…b60c8d8b` | 10,595,088 B | 23:07 |

A clean build from an empty derived-data directory emits **two warnings and neither is from a file
this pass touched** — both are the same pre-existing line, `GuideScreen.swift:336:34`, unchanged
since before Pass 19.

**Not tested, and not claimed:** the singular `1 station`. The owner has two stations and this pass
was forbidden to add or remove one, so the singular branch was read but never rendered. It is the
same `\(n == 1 ? "" : "s")` idiom the Favorites tile has used since Pass 10.

---

## Open Questions

1. **Home reads the count once, when it appears.** If the owner adds a station on the DVR's Radio
   page while Home is on screen, the tile keeps the old number until the user leaves Home and comes
   back. That is true of all six reads and is not new, but Radio is the tile most likely to change
   from outside the app.
2. **The singular has never been drawn.** `1 station` is one branch of a ternary that has not run
   on a device. It would take the owner having exactly one station.
3. **A sixth request on every Home appearance.** Home now makes six concurrent requests instead of
   five. Nothing measured whether that is noticeable; the endpoint answered in 2.7 ms when Pass 18
   timed it, and the tile filled in well inside the wait the other five already impose. But no
   before/after timing of Home's load was taken.
4. **Radio is the only tile that hides a failure.** The other eight say "unavailable" when their
   read fails; Radio says "Stations", which is indistinguishable from a healthy list. That is the
   owner's decision and it reads better, but it does mean a broken `/api/radio` is invisible from
   Home. It is visible on the Radio screen itself, which says so plainly (Pass 19).
5. **`count` is trusted over the array.** The step said to use the `count` field, and the app does.
   If the server ever returned a `count` that disagreed with `stations`, Home would draw one number
   and the Radio screen — which counts the array — would draw another. The handler builds both from
   the same slice (`radio.go:87`), so they cannot disagree today.

---

## SCOPE CHECK

Every file this pass touched, and the step that required it. Verified by hand against
`git status --short` and `git diff --numstat` in this session.

| Path | Access | Step that required it |
|---|---|---|
| `COLD-START.md` | read, **written** | READ FIRST; 5 |
| `DECISIONS.md` | read, **written** | READ FIRST; 5 |
| `reports/2026-09-06-pass19-radio.md` | read | READ FIRST |
| `reports/2026-09-06-pass18-radio-recon.md` | read | READ FIRST (`count` is the handler's `len`, radio.go:87) |
| `git push origin main`, `git fetch`, `git ls-remote` | **pushed**, then read | 1 |
| `Marlin DVR TV/HomeView.swift` | edited — the sixth read, the count, the fallback, the precedence flip, the header comment (`+26/−2`) | 2, 3, 4 |
| `Marlin DVR TV/Destination.swift` | edited — one stale doc comment on `staticTileSubtitle` (`+4/−3`); **no tile's text, icon or tint changed** | 2 |
| `Marlin DVR TVUITests/HomeRadioCountUITests.swift` | **new**, 106 lines | the evidence rules, and 3's "do not change any other tile" |
| `reports/assets/pass20/` (3 screenshots) | **new** | 6 |
| `reports/2026-09-06-pass20-home-radio-count.md` | **new** | 6 |
| `design/Marlin DVR TV.dc.html` | read only, never written | 3 (the design's own "6 stations", dc:1361) |
| `Marlin DVR TV/RadioStation.swift` | read | 2 (`APIClient.radio()` and `RadioResponse.count`, both built in Pass 19) |
| `http://192.168.1.250:8090/api/radio` | GET, by the app | 2 |

**Not touched:** every other Home tile and every other screen; every other folder under `~/Xcode`;
the Marlin DVR server, its data and its repo (the reference clone was not fetched this pass);
marlinpc; the HDHomeRun; the UNAS4Pro share; `design/`; `Info.plist`;
`Marlin DVR TV.xcodeproj/project.pbxproj`; WeatherKit and the Weather data path; the parked Settings
screen; the Pass 19 screensaver and background-audio questions; and every other Open Question from
Passes 13–19.

**Nothing was installed and no dependency was added.** A secrets scan over every file written this
pass found no credential, token or device id.

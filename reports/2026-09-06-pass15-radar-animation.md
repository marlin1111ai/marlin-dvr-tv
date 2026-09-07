# Pass 15 — radar animation, refresh, and the testmanagerd crash — 2026-09-06

The radar animates. Pass 13's loop is fixed, it runs over everything NOAA offers, and it
refreshes itself every five minutes. The Pass 14 crash is diagnosed and is not the app.

**And there is a stop-and-report.** The only mechanism that repaints on tvOS also makes MapKit
re-fetch every tile on every step: the radar screen, simply sitting open, makes **about 2,300
requests a minute** to NOAA. During this pass's testing **NOAA answered HTTP 403**, the app said
so on screen, and per step 4 I stopped load-testing rather than tuning around it. The fix — a
small in-memory store of tiles already fetched — was explicitly out of scope, so it is Open
Question 1 with the measurements attached rather than something I built uninvited.

Nothing is pushed. `68b05b5` (Pass 14) is still local and unpushed, as instructed.

---

## 1. Step 2 first — the "Lost connection to testmanagerd" deaths

Diagnosed **before** any of step 1's changes went in, as the task required: the only edit in the
build under test was `frameCount` back to 6 (the condition the deaths occurred under) plus a
read-only memory probe drawn on screen. The loop was Pass 13's, untouched.

### 1.1 Not memory

`os_proc_available_memory()` and `task_vm_info.phys_footprint`, on screen, sampled every six
seconds for two minutes on the six-frame radar:

```
t=6s    frame 3 of 6 · req 293 ok 293 · mem 433 MB · headroom 1664 MB
t=120s  frame 5 of 6 · req 293 ok 293 · mem 433 MB · headroom 1664 MB
```

**Flat.** 433 MB used with 1.66 GB of headroom, unchanged across the whole run
(`atv-07-memory-flat-six-frame-radar.png`). A jetsam kill is ruled out.

### 1.2 Not request load

`req 293` at six seconds and `req 293` at two minutes — **no tile traffic at all** during the
loop. Under Pass 13's alpha mechanism the tiles load once and are never re-requested. Ruled out.

### 1.3 Not reproducible, and not an app crash

Five consecutive runs, each about three minutes on the six-frame radar:

| Run | Condition | Result |
|---|---|---|
| 1 | two-minute dwell, memory probe | passed (181.9 s) |
| 2 | repeat | passed (183.7 s) |
| 3 | repeat | passed (183.1 s) |
| 4 | repeat | passed (183.7 s) |
| 5 | **with a second debug session attached** (`devicectl … --console`), the one environmental difference present at Pass 14's first death | passed (188.2 s) |

No crash report appeared on the Mac (`~/Library/Logs/CrashReporter/MobileDevice`, empty for this
app), and the app never died in any run.

### 1.4 What it is

```
$ xcrun devicectl device info details --device …
  • transportType: localNetwork
  • tunnelTransportProtocol: tcp
  • tunnelState: connected
```

The Mac reaches the Apple TV **over Wi-Fi**. "Lost connection to testmanagerd" is what XCTest
prints when that link stops answering, and a wireless test transport is the ordinary cause.

**Verdict: the test harness, not the app. Nothing was changed for it**, as step 2 directs.

**The honest limit.** I could not reproduce it on demand, so I cannot name a single root cause
with certainty — I can only say what it is *not* (memory, load, an app crash) and what the
remaining explanation is. It did recur once more during this pass, on a run over heavy radar
echo (§2.2), which is consistent with a busier link rather than with anything in the app.

---

## 2. Step 1 — fixing the repaint

### 2.1 What was tried, and what each cost

Four mechanisms, all measured on Home Theater over the same live storm system so the comparison
is like-for-like:

| # | Mechanism | Repaints? | Tile requests |
|---|---|---|---|
| 0 | `alpha` + `setNeedsDisplay()` — Pass 13/14 | **No** | ~0 after the first load |
| 1 | `alpha` + `setNeedsDisplayInMapRect:` | **No** | ~0 |
| 2 | `exchangeOverlay(_:with:)` | **No** | 24 total, then flat |
| 3 | **`removeOverlay` + `addOverlay`** | **Yes** | ~24 per step → ~2,300/min |

- **Attempt 1** (`atv-03-…-draws-nothing.png`): frame 6 of 6 over Minnesota with heavy echo,
  nothing drawn. Invalidating a map rect rather than the whole renderer changes nothing.
- **Attempt 2** (`atv-04-…-frame1-image-frozen.png`, `atv-05-…-frame6-same-image.png`): the
  chrome advanced from "frame 1 of 6 · 7:32 PM" to "frame 6 of 6 · 8:06 PM" — thirty-four
  minutes apart — and **the radar pixels were byte-identical**. `exchangeOverlay` swaps the
  overlay in the map's list without rebuilding what is drawn. It is, though, the one mechanism
  that *preserves* the tiles: requests stayed at 24 and never moved.
- **Attempt 3** works. Exactly one frame's overlay is attached; a step removes it and adds the
  next, which is what makes MapKit ask for a renderer and draw. Verified by hashing the map area
  of successive screenshots — `70e0c0bcbb33` at t=10 s versus `4785389b6724` at t=40 s, and
  visibly different weather in `atv-01` and `atv-02`.

### 2.2 The cost, measured

Requests were counted in `loadTile` and classified by round-trip time (a NOAA fetch measured
150–250 ms this pass; under 30 ms did not leave the device).

```
attempt 3, 512 pt tiles, 18 frames, Pass 13's 550 ms step:
  t=10s   req   ... net ...  local 0
  t=40s   req 1,632  net 1,629  local 0   ·  net 2327/min
```

**≈2,300 network requests a minute**, essentially none served from cache. The arithmetic
matches: ~24 tiles per step × ~87 steps a minute.

Two things were tried to bring that down and neither worked:

- **Sizing the system HTTP cache.** NOAA sends `cache-control: max-age=43200` on every tile, so
  in principle a repeat request should never leave the device. `URLCache.shared` was set to
  64 MB in memory (nothing on disk) — result: `req 1,312 net 1,202 local 110`, **8 %** served
  locally, still 1,640/min. MapKit's own tile loader largely bypasses the shared cache. Reverted.
- **Pinning the zoom to one level** (`minimumZ = maximumZ = 7`), to stop MapKit fetching coarse
  placeholder levels. Result: **`req 0`** and a blank radar — the map needs a level the overlay
  then refuses to serve. Reverted.

### 2.3 `frameCount` unpinned

Pass 14 pinned it at 1 because the loop would not repaint; that pin and its explanatory comment
are gone. The loop now runs over whatever NOAA's catalog holds. Counted by hand this pass for
the Apple TV's own region: **17 scans spanning 112 minutes**, 355–483 s apart (mean 419 s). The
constant is now a cap of 24, a guard rather than a target; the device showed "frame 17 of 17"
and "frame 14 of 18" on different runs as NOAA's window moved.

---

## 3. Step 3 — refresh while the view is open

`RadarModel.startRefreshing(near:)` re-reads NOAA's frame list every **five minutes**.

**Why five.** NOAA's scans arrived 355–483 s apart, mean 419 s. Five minutes (300 s) is inside
the shortest of those gaps, so the newest scan reaches the screen within about a minute of NOAA
publishing it, and the cost is one catalog request per interval — negligible beside the tile
traffic of §2.2. A refresh that returns the same frame list changes nothing; a refresh that
fails leaves the frames already on screen alone rather than blanking the view on a hiccup.

**Stopped when the view is not up.** The task is cancelled in `RadarModel.stop()`, which
`RadarScreen` calls from `.onDisappear` (`RadarScreen.swift:187`) alongside the loop task. There
is no polling behind another screen and no timer that survives a back out.

---

## 4. Step 4 — the rate, and NOAA's 403

### 4.1 The measured rate

**≈2,300 network requests a minute** with the radar at rest on screen (§2.2). That is the number
the task asked for. It is a product of the repaint mechanism, not of the frame count or the
refresh: requests ≈ tiles-per-step × steps-per-minute, and neither factor depends on how many
frames are in the loop.

### 4.2 NOAA answered HTTP 403 — STOP AND REPORT

While measuring a variant with 1024 pt tiles (which asks NOAA for 2048 × 2048 images), the
service began refusing:

> **The radar source did not answer.**
> The radar source could not be reached: NOAA's radar service answered HTTP 403.

— on screen on the Apple TV, `atv-06-noaa-http-403-shown-on-screen.png`.

Per step 4 I stopped and diagnosed rather than retrying around it. Single requests from the Mac,
spaced, immediately afterwards:

| Request | Result |
|---|---|
| service metadata (`?f=pjson`) | **HTTP 200**, 10,674 B |
| the app's spatial catalog query | **HTTP 200**, 17 features |
| `exportImage` 2048 × 2048 | **HTTP 200**, **1,055,504 B**, 0.96 s |
| `exportImage` 1024 × 1024 | **HTTP 200**, 265,976 B, 0.42 s |

So the request shapes are valid and the block was not a malformed-request rejection. A 2048 px
tile is **over a megabyte and takes a second** — four times the payload of the 512 pt tiles Pass
14 shipped — and at ~24 tiles a step that is roughly half a gigabyte a minute. The 403 is
consistent with NOAA shedding load, and it appeared exactly when the per-request size went up on
top of an already high request rate.

**Action taken:** the 1024 pt tile size was reverted to Pass 14's proven 512, and **no further
load testing was run against NOAA**. One short verification run confirmed the committed build
renders and animates.

**What I did not do:** tune the loop's pace to sneak under the limit. I do not know where the
limit is, finding it would mean more load against a service that had just refused, and step 4
calls that retrying around a stop.

---

## 5. Step 5 — failure behaviour

Unchanged, and — unusually — **proven live this pass** rather than only traced. The 403 above is
exactly the case step 5 describes: the source refused, and the view said so on screen naming
what failed, over the map, with no silent fallback and no frozen picture presented as working
(`atv-06`). The other paths (`unreachable`, `no frames`, `tiles listed but not drawing`) are
unchanged from Pass 14 and still code-traced only.

---

## 6. Evidence

### 6.1 The build under test is the build that was tested

```
$ xcodebuild … -destination 'platform=tvOS,name=Home Theater' -allowProvisioningUpdates build
** BUILD SUCCEEDED **
```

No errors and no warnings from any file this pass touched; the one warning in the target is
pre-existing in `GuideScreen.swift:336`, a file Pass 15 never opened. Every device run installed
the freshly built app first (`xcrun devicectl device install app`). The final verification run at
**20:39:46** used the binary built at **20:39:17**, after the last source change.

### 6.2 What is proven on Home Theater

| Claim | Evidence |
|---|---|
| The radar **animates** — successive frames draw different real NOAA imagery | `atv-01` / `atv-02`, and map-area hashes `70e0c0bcbb33` ≠ `4785389b6724` |
| `alpha` + `setNeedsDisplayInMapRect:` does not repaint | `atv-03` — frame 6 of 6 over heavy echo, nothing drawn |
| `exchangeOverlay` does not repaint | `atv-04` / `atv-05` — 34 minutes apart, identical pixels |
| The loop runs over NOAA's full window | "frame 17 of 17", "frame 14 of 18" on the device |
| The request rate is ~2,300/min | on-screen counters, `req 1,632 net 1,629 local 0 · net 2327/min` |
| NOAA can and did refuse | `atv-06`, HTTP 403 shown on screen |
| Memory is flat on the six-frame radar | `atv-07`, 433 MB / 1,664 MB headroom over two minutes |
| The committed build runs at the owner's location | `atv-08`, "8:34 PM · frame 17 of 17 · NOAA / NWS MRMS base reflectivity" |

`atv-01` through `atv-06` were taken with a **disclosed diagnostic**: the map pointed at
44.0 N 94.5 W, where the weather was, instead of the Apple TV's own location, plus counters drawn
on screen. **Every pixel of radar in every screenshot came from NOAA** — nothing was generated
locally. All of it is reverted: `grep -rn "PASS15-PROBE\|MemoryProbe"` over `Marlin DVR TV/`
returns nothing.

### 6.3 What is not proven

- **That the animation is smooth.** At Pass 13's 550 ms step each frame is still painting when
  the next replaces it, so frames appear partly drawn (visible in `atv-08`'s sibling shots). The
  loop is correct; the pace and the fetch cost are not matched. Changing the pace would have
  meant more load testing against a service that had just returned 403.
- **Where NOAA's limit actually is.** One 403 is not a threshold.
- **That the five-minute refresh fires.** The longest dwell on the radar this pass was three
  minutes, so the timer's *cancellation* is code-traced through `stop()` and its *firing* has
  never been observed. Named here rather than claimed.
- **The out-of-coverage and tile-failure messages** remain unseen, as in Pass 14.
- **WeatherKit** is still not enabled; out of scope for this pass.

---

## 7. Notebook

- `COLD-START.md` "What is built" gained a **Pass 15** paragraph, including the measured request
  rate and the 403. The blocked item that read "The radar loop" now reads "A radar loop that does
  not hammer NOAA" — the animation works; the traffic is what is unresolved.
- `DECISIONS.md` gained `## 2026-09-06 (Pass 15 — radar animation and refresh)` with the two
  owner decisions, the mechanism and the three that failed, the refresh interval and why, the
  measured rate and the 403, and the testmanagerd verdict.

What happened only.

---

## Open Questions

1. **The request rate, and the in-memory frame store that would fix it.** *What it is:* keep the
   bytes of tiles already fetched for the frames in the current loop — about 24 tiles × ~130 KB
   ≈ 3 MB per frame — and serve them from `loadTile` instead of going back to NOAA. *Why it seems
   needed:* attaching and detaching is the only mechanism that repaints, and it discards the
   renderer's tiles every step; that is where all 2,300 requests a minute come from. *What breaks
   without it:* NOAA returns 403 under the load, as it did this pass, and the radar shows an
   error instead of weather. It was out of scope here ("no offline tile cache"), and it is not an
   offline cache — it would be memory only, bounded by the frame count, and gone when the view
   closes. **Until it exists, the radar is best not left running for long stretches.**
2. **The loop's pace.** 550 ms per step is Pass 13's, chosen before tiles came over a network.
   Frames now do not finish painting before they are replaced, and the pace is also the direct
   multiplier on the request rate. A slower step would improve both. Not changed here: the pass
   forbids speed controls, and re-measuring would have meant more load on NOAA after the 403.
3. **Is `minimumZ = 3` costing requests?** ~24 tiles a step is far more than the ~4 the viewport
   needs, which suggests MapKit is fetching coarse placeholder levels too. Raising `minimumZ`
   would cut that, but pinning it to a single level blanked the radar (§2.2) and finding the
   right floor needs load testing.
4. **The testmanagerd drops.** Diagnosed as the wireless test transport (§1.4) and left alone as
   instructed, but never reproduced on demand. If it starts happening during the owner's own use
   — not under test — that would change the answer, and is worth knowing.
5. **A refresh replaces the whole frame list**, which resets the loop to the newest frame. Once
   per five minutes that is a visible jump. Acceptable, or should the loop keep its position?

---

## SCOPE CHECK

| File | Created / touched / read | Step that required it |
|---|---|---|
| `Marlin DVR TV/RadarScreen.swift` | touched — the attach/detach repaint in `Coordinator`, the five-minute refresh task, its cancellation in `stop()` | 1, 3 |
| `Marlin DVR TV/RadarSource.swift` | touched — `frameCount` unpinned and its Pass 14 comment removed | 1 |
| `COLD-START.md` | touched — Pass 15 paragraph; the blocked item reworded | 6 |
| `DECISIONS.md` | touched — `## 2026-09-06 (Pass 15 — radar animation and refresh)` | 6 |
| `reports/2026-09-06-pass15-radar-animation.md` | **created** — this file | 7 |
| `reports/assets/pass15/*.png` (8 files) | **created** — device screenshots | 7 |
| `Marlin DVR TV/_Pass15MemoryProbe.swift` | created **and deleted** — the memory probe of §1.1; not committed | 2 |
| `Marlin DVR TVUITests/WeatherRadarUITests.swift` | dwell time varied for the measurements, then **restored with `git checkout`**; unchanged in the commit | 2, 4 |
| `mapservices.weather.noaa.gov` | read only — service metadata, catalog queries, `exportImage` | 2, 4 |
| `COLD-START.md`, `DECISIONS.md`, the Pass 13 and Pass 14 reports | read first, before anything else | preamble |
| `AppleTVOS26.5.sdk` — `MKOverlayRenderer.h`, `MKMapView.h` | read only | 1 |
| `build/`, `<session scratchpad>` | build output and working images, **git-ignored / outside the repo** | 2, 4 |

**Not created, not changed, not installed:** no tile cache of any kind, no second tile source or
provider fallback, no playback controls (no scrubber, no play/pause, no speed control), no new
dependency, no entitlement or capability, no WeatherKit or Weather-screen change, no change to
`design/`, to the parked Radio and Settings screens, or to any screen built in Passes 5–14 other
than the radar view. `URLCache.shared` was sized during a probe and that probe was reverted, so
the committed build touches no global networking state. Nothing outside `~/Xcode/Marlin DVR TV`
was written and no other folder under `~/Xcode` was read. No request was sent to 192.168.1.250,
192.168.1.245, 192.168.1.105 or the UNAS4Pro share beyond the app's usual DVR client ping.

**Temporary diagnostics, all reverted before the commit:** the memory probe file; the map
re-centred on 44.0 N 94.5 W; tile counters, network/local classification, a request-rate line and
a renderer counter drawn on screen; `frameCount` at 6; `minimumZ`/`maximumZ` pinned to 7;
`tileSize` at 1024; a 64 MB `URLCache.shared`. `grep -rn "PASS15-PROBE\|MemoryProbe"` over
`Marlin DVR TV/` returns nothing.

**Secret scan before commit.** Every file this pass adds or changes was grepped for `token`,
`secret`, `password`, `bearer`, `api[-_]key`, `apikey`, `ssh-rsa`, `BEGIN … PRIVATE KEY`, the
Apple team identifier pattern and the device UDID. **No matches.** NOAA's service takes no
credential, so there is none to leak.

## Push gate

Committed locally and **nothing pushed** — neither Pass 15 nor Pass 14's `68b05b5`, which is
still awaiting the owner's test. The owner tests the animated radar on Home Theater and Passes 14
and 15 go up together after that.

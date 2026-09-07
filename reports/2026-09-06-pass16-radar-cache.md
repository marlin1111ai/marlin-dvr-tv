# Pass 16 — push 14 and 15, then the radar tile cache — 2026-09-06

Passes 14 and 15 are on `origin main`. The radar's traffic problem is solved: the loop now
redraws from memory instead of re-downloading, and NOAA answered every single request this pass
— **no 403, no tile failures, nothing throttled**.

| | Pass 15 | Pass 16 |
|---|---|---|
| Requests a minute, radar open | **2,327** | **53** over eight minutes; **~5 at rest** |
| Tiles served from memory | none | 18,456 of 18,888 — **97.7 %** |
| NOAA's answer under load | **HTTP 403** | every request answered, `fail 0` throughout |

---

## 1. Push (step 1)

`68b05b5` and `9dcc135` went to `origin main` as a fast-forward. Verified **after** a fresh
`git fetch`, three independent ways, never from the push command's own output:

```
$ git rev-parse HEAD          9dcc1358581644ba9343d1970b61798d11c1c554
$ git rev-parse origin/main   9dcc1358581644ba9343d1970b61798d11c1c554
$ git ls-remote origin main   9dcc1358581644ba9343d1970b61798d11c1c554   refs/heads/main
$ git rev-list --left-right --count origin/main...HEAD   → behind 0  ahead 0
$ git branch -r --contains 68b05b5 → origin/main
$ git branch -r --contains 9dcc135 → origin/main
```

The push printed `71b88d3..9dcc135  main -> main` — two dots, no leading `+`, a fast-forward.
Both SHAs are byte-identical to what they were before the push, so **nothing was rebased or
amended**, and `git reflog show origin/main` records it as an ordinary `update by push`.

---

## 2. The tile store (step 2)

`RadarTileStore` in `RadarSource.swift`. What it promises is deliberately small:

- **In memory only.** No file is written; nothing survives the app.
- **Nothing survives the view.** `RadarModel.stop()` calls `removeAll()`, and `RadarScreen`
  calls `stop()` from `.onDisappear` — backing out of the radar frees every byte.
- **Keyed by the whole tile URL**, which carries NOAA's own `time=` for that scan. A cached tile
  is therefore always exactly the tile for the frame being drawn (see step 6).
- **Only successes are kept.** An error or an empty body is never stored.
- **Bounded** at 96 MB, trimmed oldest-first, and pruned on refresh: `keepOnly(frames:)` drops
  the tiles of scans that have rolled out of NOAA's window.

### 2.1 Memory, measured on the device

Read from the app itself (`task_vm_info.phys_footprint`, `os_proc_available_memory()`) and from
the store's own byte count, drawn on screen:

| Moment | Store | App footprint | Headroom |
|---|---|---|---|
| 30 s in, 17 frames | **41 MB / 408 tiles** | 492 MB | 1,605 MB |
| 8 min in, 18 frames | **43 MB / 432 tiles** | 497 MB | 1,600 MB |

**Roughly 2.4 MB per frame** — 432 tiles across 18 frames is 24 tiles a frame at about 100 KB
each. The task's estimate was "roughly 3 MB per frame"; the measurement is a little under it.

### 2.2 What happens when the frame count is large

Pass 15 saw 17 scans; this pass saw NOAA's window grow to 18 mid-run. At 2.4 MB a frame:

- **18 frames → 43 MB**, measured.
- **24 frames** — `RadarSource.frameCount`, the cap — would be about **58 MB**, still inside the
  96 MB budget, and the app sat at 497 MB with 1.6 GB of headroom while holding 43 MB.
- Past the budget the store trims oldest-first, so the loop's older frames would start re-fetching
  rather than the app growing. It cannot run away.

The frame count is NOAA's to set: the store follows it and prunes what rolls out.

---

## 3. The result (step 3)

Measured the same way Pass 15 measured 2,327 — counters in `loadTile`, drawn on screen, read off
photographs of the Apple TV.

| | Pass 15 (no store) | Pass 16 (store) |
|---|---|---|
| At rest on the radar screen | **2,327 requests/min** | **53/min** cumulative over 8 minutes |
| Steady state after the frames load | 2,327/min, indefinitely | **~5/min** — one frame's tiles per five-minute refresh |
| Tiles from memory | 0 | **18,456** of 18,888 |
| NOAA's answer | **HTTP 403** | every request answered |

The eight-minute run: `noaa 432 store 18456 · 53/min · cache 43 MB / 432 tiles`
(`atv-03-…`). 408 of those 432 requests happened in the first cycle; the other 24 were the new
frame the refresh brought in. **After the first cycle the loop makes no requests at all** —
`noaa` sat at 408 from 30 s to 270 s while the loop ran continuously.

**NOAA stayed happy.** `fail 0` on every screenshot in every run of this pass, no 403, nothing
throttled. The step 3 stop condition was never reached.

---

## 4. The frame pace (step 4)

**Chosen: 900 ms a step, with a 2,200 ms hold on the newest frame** (was 550 / 1,400).

### The evidence it was chosen on

**Rendering is no longer what sets the pace.** Pass 15's complaint — frames still painting when
the next replaced them — was network latency, and the store removed it. Sampled every second for
twenty-five seconds at 550 ms (a 1 s sample against a 550 ms step lands at varied phases):
**twenty-five of twenty-five fully painted, none partial** (`atv-04-…`). Even six seconds into a
cold start, with the store still filling, the frame on screen was complete (`atv-05-…`).

**So the pace was chosen for the one burst left on NOAA.** The first cycle still has to fetch
each frame once — about 432 tiles — and the pace decides how tightly that is packed:

| Step | Cold cycle | Peak rate during it |
|---|---|---|
| 550 ms | ~10 s | **2,389 requests/min** |
| **900 ms** | ~17 s | **1,426 requests/min** |

Both measured on the device. 2,389/min is the same shape of load that drew the 403 in Pass 15;
900 ms spreads the identical 432 requests over a longer window and cuts the peak by 40 %.

**And it reads better.** Eighteen scans is about two hours of weather. Two hours in a seventeen-
second cycle lets the eye follow a storm; ten seconds is a blink. The hold is kept in proportion
so the loop rests on "now".

Verified at the new pace: thirty one-second samples, twenty-nine distinct successive images (the
loop running), and frames fully painted (`atv-06-…`).

**No controls were added** — no scrubber, no play/pause, no speed control. The pace is two
constants.

---

## 5. The refresh, seen to fire (step 5)

Pass 15 never observed it; the longest dwell was three minutes. This pass sat on the radar for
**eight minutes** and caught it at the five-minute mark:

| | t = 270 s | t = 330 s |
|---|---|---|
| Frames | `frame 17 of **17**` | `frame 2 of **18**` |
| NOAA requests | `noaa 408` | `noaa 432` — **+24, exactly one frame's tiles** |
| Store | `41 MB / 408 tiles` | `43 MB / 432 tiles` |

`atv-01-…` and `atv-02-…`. Three independent things moved together: the frame count, the request
count by precisely one frame's worth, and the store. **The frame list and the displayed timestamp
both advance** — the newest scan at t=270 was 8:48 PM; after the refresh the list carried a newer
one and the tick strip gained a tick.

---

## 6. Failure behaviour (step 6)

Unchanged, and the store is built so it cannot mask a failure:

- **Only successes are stored.** `loadTile` writes to the store only on a non-empty, error-free
  response, so a failed tile stays failed, `tilesFailed` still counts it, and the "frames listed
  but not drawing" watcher still fires.
- **A cached tile can never be stale relative to its label.** The key is the full tile URL, which
  contains `time=<that scan's validtime>`. A hit is by construction the same picture the app
  would have downloaded for the frame whose timestamp is on screen. Different scan → different
  URL → different key → miss.
- **A refresh prunes.** Scans that roll out of NOAA's window have their tiles dropped rather than
  lingering.
- **A failed refresh changes nothing on screen** — the frames already loaded keep running, which
  is Pass 15's behaviour and is not a silent fallback: the loop is still showing real scans with
  their own real timestamps.

`fail 0` on every measurement this pass, so the failure paths were not exercised live here. They
remain as Pass 15 left them.

---

## 7. Evidence

### 7.1 The build under test is the build that was tested

```
$ xcodebuild … -destination 'platform=tvOS,name=Home Theater' -allowProvisioningUpdates build
** BUILD SUCCEEDED **
```

No errors and no warnings from any file this pass touched; the one warning in the target is
pre-existing in `GuideScreen.swift:336`, a file Pass 16 never opened. Every device run installed
the freshly built app first. The final run at **21:13:47** used the binary built at **21:13:29**,
after the last source change.

The harness is the same remote-driven `WeatherRadarUITests`, pressing the real Siri Remote. It is
**unchanged in the commit** — the dwell times were varied for the measurements and then restored
with `git checkout`.

### 7.2 What is proven on Home Theater

| Claim | Evidence |
|---|---|
| Requests fell from 2,327/min to 53/min, ~5/min at rest | `atv-03-…`, `noaa 432 store 18456 · 53/min` |
| The store holds 43 MB / 432 tiles, ~2.4 MB a frame | on-screen store counters, three runs |
| The app has ample headroom while holding it | 497 MB used, 1,600 MB free |
| NOAA answered everything | `fail 0` on every screenshot; no 403 |
| The five-minute refresh fires and advances the list | `atv-01-…` / `atv-02-…`, 17 → 18 frames, +24 requests |
| Frames render fully at 550 ms with the store | `atv-04-…`, 25 of 25 samples complete |
| The cold cycle is complete within six seconds | `atv-05-…` |
| Frames render fully at the retuned 900 ms | `atv-06-…`, 30 samples |
| The committed build runs at the owner's location | `atv-07-…` |

`atv-01` through `atv-06` were taken with a **disclosed diagnostic**: the map pointed at
44.0 N 94.5 W, where the weather was, instead of the Apple TV's own location, plus store, request
and memory counters drawn on screen. **Every pixel of radar came from NOAA** — nothing was
generated locally. All of it is reverted: `grep -rn "PASS16-PROBE\|Pass16Probe"` over
`Marlin DVR TV/` and `Marlin DVR TVUITests/` returns nothing.

### 7.3 What is not proven

- **The store under a rolling window.** NOAA's window *grew* 17 → 18 during the run; no scan
  rolled out, so `keepOnly(frames:)` has never actually dropped anything. It is code-traced.
- **The 96 MB budget's trim path.** The store peaked at 43 MB, so the eviction loop never ran.
- **Behaviour past 24 frames.** `frameCount` caps there and NOAA offered 18.
- **The failure paths**, including the "cache must not mask a failure" guarantee. `fail 0`
  everywhere this pass, so the reasoning in §6 rests on the code, not on an observed failure.
- **A second refresh.** One was observed; the run ended at eight minutes.
- **WeatherKit** is still not enabled; out of scope.

---

## 8. Notebook (step 7)

- `COLD-START.md` "What is built" gained a **Pass 16** paragraph with the before/after rates, the
  measured memory, the retuned pace and the observed refresh. The "A radar loop that does not
  hammer NOAA" entry under *Built but blocked on the owner* is closed out — the store answered it.
- `DECISIONS.md` gained `## 2026-09-06 (Pass 16 — the radar tile cache)`: the owner's acceptance
  of the animated radar and the push, the cache decision and what it guarantees, the measured
  numbers, the retuned pace and why, and the observed refresh.

What happened only.

---

## Open Questions

1. **The store has never had to evict or prune.** The budget's trim path and
   `keepOnly(frames:)` are both unexercised because NOAA's window grew rather than rolled and the
   store peaked at 43 MB against a 96 MB budget. Worth watching over a longer session; nothing
   suggests they are wrong, but neither has run.
2. **The cold burst is still ~1,400 requests a minute for about seventeen seconds.** It is one
   time per visit and NOAA took it without complaint, but it is the largest load the app makes.
   Fetching the newest frame first and the older ones lazily would flatten it — not built, not
   asked for.
3. **Backing out and re-entering the radar refetches everything.** The store dies with the view
   by design ("nothing surviving the view"), so a viewer who leaves and returns pays the cold
   cycle again. That is exactly what was specified; flagged only so the cost is visible.
4. **900 ms is my choice, not a measured optimum.** The evidence rules out rendering as the
   constraint and quantifies the burst trade-off, but where the loop reads best is a matter of
   taste and the owner may want it faster or slower.
5. **The refresh resets the loop to the newest frame**, so once every five minutes the animation
   jumps. Carried over from Pass 15 Open Question 5, still unaddressed.

---

## SCOPE CHECK

| File | Created / touched / read | Step that required it |
|---|---|---|
| *(git)* `origin main` ← `68b05b5`, `9dcc135` | **pushed**, verified by fetch + `rev-parse` + `ls-remote` + `branch --contains` | 1 |
| `Marlin DVR TV/RadarSource.swift` | touched — `RadarTileStore`, the store lookup and write in `loadTile`, the shared instance and its counters | 2, 3, 6 |
| `Marlin DVR TV/RadarScreen.swift` | touched — the store emptied in `stop()`, pruned on refresh, and the retuned pace constants | 2, 4, 6 |
| `COLD-START.md` | touched — Pass 16 paragraph; the blocked entry closed | 7 |
| `DECISIONS.md` | touched — `## 2026-09-06 (Pass 16 — the radar tile cache)` | 7 |
| `reports/2026-09-06-pass16-radar-cache.md` | **created** — this file | 8 |
| `reports/assets/pass16/*.png` (7 files) | **created** — device screenshots | 8 |
| `Marlin DVR TV/_Pass16Probe.swift` | created **and deleted** — the on-screen measurement probe; not committed | 2, 3, 4 |
| `Marlin DVR TVUITests/WeatherRadarUITests.swift` | dwell times varied for the measurements, then **restored with `git checkout`**; unchanged in the commit | 3, 4, 5 |
| `mapservices.weather.noaa.gov` | read only — one catalog query per refresh, plus tiles | 3 |
| `COLD-START.md`, `DECISIONS.md`, the Pass 14 and Pass 15 reports | read first, before anything else | preamble |
| `build/`, `<session scratchpad>` | build output and working images, **git-ignored / outside the repo** | 3, 4 |

**Not created, not changed, not installed:** no disk cache and nothing persisted — the store is a
dictionary in memory, emptied on disappear; no prefetch of frames the loop has not reached; no
second tile source or provider fallback; no playback controls; no new dependency; no entitlement
or capability; no WeatherKit or Weather-screen change; nothing touching the testmanagerd drops;
no change to `design/`, to the parked Radio and Settings screens, or to any screen built in
Passes 5–15 other than the radar view. Nothing outside `~/Xcode/Marlin DVR TV` was written and no
other folder under `~/Xcode` was read. No request was sent to 192.168.1.250, 192.168.1.245,
192.168.1.105 or the UNAS4Pro share beyond the app's usual DVR client ping.

**Temporary diagnostics, all reverted before the commit:** the probe file; the map re-centred on
44.0 N 94.5 W; store, request-rate, failure and memory counters drawn on screen; the UI test's
dwell times. `grep -rn "PASS16-PROBE\|Pass16Probe"` returns nothing.

**Secret scan before commit.** Every file this pass adds or changes was grepped for `token`,
`secret`, `password`, `bearer`, `api[-_]key`, `apikey`, `ssh-rsa`, `BEGIN … PRIVATE KEY`, the
Apple team identifier pattern and the device UDID. **No matches.** NOAA's service takes no
credential, so there is none to leak.

## Push gate

Step 1's push is done and verified. Steps 2–8 are committed locally and **not pushed**, per the
pass's gate. The owner tests the cached, retuned radar on Home Theater.

# Pass 120 — REVIEW.md's twelve SWEEP items built

**Date:** 2026-09-24 (00:30–02:30 EDT)
**Built on:** `8e68d019561b023f32e0d77b0e7422f453039414` (Pass 119). **One commit, not pushed** — the owner
tests on Home Theater first.

**What this pass did not do.** It did not touch the bedroom Apple TV, and it sent **no write of any kind** to
the Marlin DVR server. Every request it made is a GET, apart from what the app itself sends during a run:
each launch's ping and one live play session. Nothing was installed on this Mac. The only install anywhere is
the one every test run makes: the run put this pass's app build, and its UI-test runner, on Home Theater.
marlin-dvr was not cloned or read. `design/`, `icon-source/`, `REVIEW.md` and every existing report are unchanged. So are the five
files the four STANDALONE items live in: `GuideScreen.swift`, `ScreenShell.swift`, `RailView.swift`,
`PlayerModel.swift` and `PlayerHost.swift`. **No UI test was run unfiltered.**

**Line numbers** below are at this pass's commit. `file:line` citations drift, and comments and reports are
never rewritten (COLD-START.md:81).

---

## 1. Step 1 — the state before anything changed

`git fetch origin`, then `git rev-parse main`, `git rev-parse origin/main` and `git ls-remote origin main`
all read **`8e68d019561b023f32e0d77b0e7422f453039414`**.
`git rev-list --left-right --count main...origin/main` was `0 0`. `git status --porcelain` showed only
`?? icon-source/`. **No stop condition.**

---

## 2. The owner's answers of 2026-09-24 — "aa"

As this pass's prompt relays them:

1. **The sort and the order are as Pass 119 laid them out.** This sweep comes first. G, S5, S6 and S11 follow,
   each as its own pass, and the owner tests each one before the next.
2. **S13 includes the Player info panel's line** (`PlayerInfoPanel.swift:203` at Pass 119). This keeps Pass
   108's rule that each panel button does what the airing sheet's control does.

---

## 3. What was built, item by item

Every item is labelled **run** (measured on Home Theater in this pass's one run, §5), **traced** (reasoned
from the code, not measured), or both where the run covered only part of it.

### S1 — a UI-test harness runs only when it is named

- **Built** in `Marlin DVR TV.xcodeproj/xcshareddata/xcschemes/Marlin DVR TV.xcscheme:34-35` and `:43-44`.
  - The scheme's one `TestableReference` stays `skipped = "NO"`.
  - It gains `useTestSelectionWhitelist = "YES"` and an empty `<SelectedTests>`, so none of its tests is
    selected.
  - ⌘U, or `xcodebuild test` with no `-only-testing`, executes no test.
  - Every recorded `-only-testing` command still runs the class it names.
  - A harness added later is not selected either until it is named.
  - Neither `project.pbxproj` nor any harness changed for S1.
- **The named route: run.** The enumeration in §7 and the run in §5 both prove it.
- **The unnamed route: proven without running, not measured** (§7).
- **⌘U pressed in the Xcode app: traced.** The app reads the same scheme test plan, and ⌘U was not pressed.
- **On Home Theater: not visible.**

### S2 — ShowDetailSeriesPassUITests stops before its Select when its focus check fails

- **Built** in `Marlin DVR TVUITests/ShowDetailSeriesPassUITests.swift:246-254`. The soft check before the
  Select is now `guard focusSeriesButton(editLabel) else { XCTFail(…); return }`. If focus is not on "Edit
  series pass", the method ends before any Select. Only the test target changed.
- **Traced.** Reaching the stop branch needs the owner's pass deleted, or a server fault. The harness's happy
  path was not run (§4).
- **On Home Theater: not visible.**

### S4 — with Location off for the app, the saved position is not used

- **Built** in `Marlin DVR TV/WeatherLocation.swift`.
  - `start()` (`:98-110`) reads the authorization before the cache. On Never or restricted it removes
    `marlinWeatherFix` (`dropCache()`, `:88-90`) and finishes `.declined`.
  - The authorization callback's Never/restricted branch drops the fix too (`:162-164`).
  - Cache-first is kept when the app is allowed, and when authorization is not yet determined
    (DECISIONS.md:56).
  - Weather, Home's glance and Radar already read the location's state, so nothing else changed.
- **Run: the regression only.** With location allowed, Home's glance drew weather from the saved fix, with no
  prompt (§5, test1).
- **Traced:**
  - Never and restricted themselves, and the Settings round trip, which has never been recorded on tvOS 26.6;
  - that the key is actually removed;
  - that no WeatherKit, geocoder or NOAA request goes out (there is no network capture);
  - a withdrawal mid-session.
- **How the owner can see it:**
  1. In tvOS Settings → General → Privacy & Security → Location Services → Marlin DVR TV, choose **Never**.
  2. Relaunch the app. Home's glance reads "Weather needs this Apple TV's location — open Weather", Weather
     reads "No location, so no weather.", and Radar reads "No location, so no radar."
  3. Setting it back to While Using fills the glance again with no prompt (traced).
  - **Do not delete or reinstall the app to recover.** That wipes the client id, and the next launch registers
    again, which is a server write.

### S7 — an empty Scheduled Recordings or Your Passes keeps something focusable

- **Built** in `Marlin DVR TV/ScheduleManageView.swift` and `Marlin DVR TV/PassesManageView.swift`. This is
  Trash's rule (`TrashManageView.swift:56-69`), which is unchanged.
  - The empty sentence is `.focusable()` and holds the `"empty"` focus id: Schedule `:122-134`, Passes
    `:76-87`.
  - It is disabled while an overlay is up, as the rows are.
  - Every focus request that could find no row falls back to it: Schedule `:51`, `:77`, `:84`; Passes `:39`,
    `:50`.
  - Closing an airing puts focus back on its row if a re-read has not removed it, else on the first row, else
    on the sentence (`rowOrFallback`, Schedule `:100-106`, used at `:58` and `:91`). Pausing the last pass
    from Manage pass can empty the list.
- **Run: the non-empty path.** Each list opened on its first row, and Menu returned to the hub. Trash behaved
  as before (§5, test1).
- **Traced: every empty path.** No list can be emptied without writes. It rests on Pass 33's measurement of
  the same trap, and of the same fix in Trash.
- **How the owner can see it:** only when a list is empty. With nothing booked, open Scheduled Recordings and
  press Menu: he lands on Manage DVR, not the Apple TV Home screen. **Not visible today**, with 12 bookings
  and 12 passes.

### S8 — a failed passes, storage or schedule read shows an error, not an empty list

- **Built** in `Marlin DVR TV/ManageDVRScreen.swift`. `TrashManageView.swift` is byte-identical.
  - Three errors of their own sit beside `trashError`: `systemError`, `scheduleError` and `passesError`
    (`:42-48`).
  - Each is set, and cleared by the next good read, in the catches that already existed (`:64-107`). There is
    **no new read, timer or retry**, so Pass 106's A5 stands.
  - The hub's rows read "could not read" as Trash's does (`:216-224`).
  - The hub shows one error line per failed list (`:204-209`).
  - The storage card says "Could not read the disk space — …" instead of "Reading the server…"
    (`:243`, `:256-260`).
  - In the lists, the S7 sentence becomes the error: Schedule `:127-128`, Passes `:79-80`.
  - The subtitles read "could not read": Schedule `:163`, Passes `:107`.
- **Run: the success path.** No false error showed on the hub or in either list, and the disk figures were
  drawn (§5, test1).
- **Traced:** every failure branch, and the clear after a later good read.
- **On Home Theater: not visible** while the server answers. It shows only if the server cannot be reached
  when Manage DVR opens.

### S9 — a Keep or Delete on a show's page also updates what the countdown plays from

- **Built** in `Marlin DVR TV/ShowDetailScreen.swift:81-89`.
  - `apply()` rebuilds `detail` around the edited `episodes`, using `ShowResponse`'s memberwise initializer.
    So `play(_:from:)` hands the Player the list as it is after the write, and `PlayRequest.nextEpisode`
    picks from that list.
  - `Models.swift` was not touched for S9. `PlayRequest.id` was not touched.
- **Traced.** It needs a Delete and a playback to the end.
- **How the owner can see it:**
  1. On a show's page, click and hold a newer episode, then Delete.
  2. Without leaving the page, play the next-older episode to its end.
  3. The countdown offers the next surviving episode, not the deleted one.
  - These are real writes. The Delete puts the recording in Trash; restore it from Manage DVR → Trash.
    Playing to the end marks it watched on both Apple TVs.

### S10 — "+" and ";" in titles reach the server intact

- **Built:**
  - `Marlin DVR TV/ServerAPI.swift:28-43` adds `URLComponents.setServerQueryItems`. It sets `queryItems`,
    then percent-encodes the literal "+" and ";" that `URLComponents` leaves in values.
  - It is used in `url(_:query:)` at `:121`, so every `APIClient` read carries it. That includes Search's
    `find` and whole-title `search`, whose calls in `ChannelFilter.swift` needed no change.
  - It is used in `AiringSheet.artPath` (`AiringSheet.swift:43`), the show-poster path that On Later's
    fallback, Your Passes and the Player's Starting screen also use.
  - It is used in Trash's poster path (`Models.swift:459`).
  - It is used in On Later's `u=` and `title=` (`OnLaterScreen.swift:79-80`).
  - The Guide's logo escaper (`GuideChannelTile.artFeedPath`) was not moved or touched.
- **Run.** "Tiki" typed in Search, and the "Tiki + Tierney" row opened its airing sheet (§5, test2). The
  server's answers to the old and new bytes are in §6.
- **Traced:**
  - ";" — no title in tonight's guide has one;
  - On Later;
  - the posters, and Trash;
  - `u=`.
- **How the owner can see it:** Search → type "Tiki" → pick "Tiki + Tierney". The airing sheet opens. Before
  this pass it said "The server no longer lists that airing." "The NFL Today +" and "College Football
  Today+" behave the same way.

### S12 — across a programme change, the info panel follows the new airing

- **Built** in `Marlin DVR TV/PlayerInfoPanel.swift`.
  - The `.task(id: program?.end)` is gone.
  - The end-of-airing reload is `followTheAiring()` (`:517-531`), called inside the panel's own `.task`
    after its first read (`:238`). Nothing is keyed on `program` any more, so the reload's own
    `program = airing` can no longer cancel the pass and schedule reads under it.
  - The wait (`end + 2 s`, else 30 s) is unchanged, and so are the message clearing and the post-reload
    focus.
  - It still stops when a re-read brings back no airing, or the same one.
  - `loaded`, `firstFocusID`, the write mirrors and Pass 109's close paths are untouched.
- **Run.** HISTORY was played live and the panel was opened at 02:04:20 on "Pawn Stars: Best Of" with "Add to
  pass". Held open past 02:06:02, it read "Pawn Stars", "Edit pass", and "◆ Series pass · 1 recording
  scheduled · new episodes" at 02:06:12 (§5, test4).
- **Traced:**
  - the booking half — no airing at that boundary was booked;
  - a read failure at the boundary;
  - a second boundary in a row;
  - the pre-fix self-cancel itself.
- **How the owner can see it:** on a live channel, open the panel with a click down a minute before a
  programme ends, and leave it up. When the next show starts, the title changes. If that show has a series
  pass, the button reads "Edit pass" and the gold "◆ Series pass" line appears. HISTORY at 02:06 tonight is
  one such change: "Pawn Stars: Best Of" to "Pawn Stars".

### S13 — after a write, the airing sheet (and the info panel) drops a booking that is gone

- **Built:**
  - `Marlin DVR TV/AiringSheet.swift:150-153` — the delete re-read keeps no `?? job`.
  - `AiringSheet.swift:171-175` — the re-read on open keeps no `?? selection.job`.
  - On a failed read, every host already hands back its previous copy: `GuideScreen.swift:284-290`,
    `GuideSearchScreen.swift:172-178`, `OnLaterScreen.swift:292-298`. The hosts are unchanged. So the old
    copy is kept exactly when the read fails.
  - `record()` and `recordSeries()` keep their `?? job`, and Stop still has none.
  - The owner's widening: `Marlin DVR TV/PlayerInfoPanel.swift:203-212`. The panel's delete re-read keeps its
    old booking only when the read throws, through a new throwing `readScheduleJob` (`:500-504`).
    `scheduleJob` (`:491-498`) is unchanged for its other callers: the first read, Record and Add to pass.
- **Traced.** It needs a pass created and deleted, or a booking cancelled from another client.
- **How the owner can see it:** these are real writes on his DVR.
  1. In the Guide, open an upcoming airing flagged New of a show with no pass, and press Record the series.
     The chip reads "● Scheduled".
  2. Press Edit series pass, then Delete this pass. The sheet now shows "Record this airing", not
     "● Scheduled".
  3. The same from the Player's info panel on live TV: Edit pass → Delete, and the panel shows "Record".

### S14 — Favorites reloads the way On Now does

- **Built** in `Marlin DVR TV/FavoritesScreen.swift:92-107`. This is On Now's loop
  (`OnNowScreen.swift:167-179`): `load()` again every 60 s for as long as the screen exists, with focus set on
  the first pass only. `ContentView.swift` and `ScreenShell.swift` are untouched.
- **Run** (§5, test4):
  - **In place:** DISCOVERY's and AHC's rows changed 39 s after their 02:00 turnover, with focus unmoved on
    HISTORY through 16 samples.
  - **After a Player round trip across HISTORY's 02:06 turnover:** the HISTORY row read "Pawn Stars, ends
    3:03 AM" at 02:06:39.
  - The "next pick's Starting screen" check was not made. The row is what a pick hands the Player.
- **Traced:** a failed read during a reload, and a focused favourite removed behind the Player.
- **How the owner can see it:** leave Favorites open across the top or bottom of an hour. Within a minute each
  row's programme and "ends …" line change, and focus stays put. Or watch a favourite past the end of its
  programme and press Menu: the row now shows what is on.

### S15 — a camera card keeps its previous picture until the new one has loaded

- **Built** in `Marlin DVR TV/CamerasScreen.swift`.
  - `CameraCard` keeps `lastSnapshot` (`:124-127`) and draws its own `AsyncImage` (`:168-212`).
  - The new snapshot shows once it has loaded. The last one shows while the new one loads, for a camera
    that is online.
  - Today's placeholder shows on the first load, for an offline camera, and on a failure. A failure also
    forgets the last picture.
  - The `Color.clear` overlay sizing is kept (Pass 6), and so are the Button, the focus, the 45 s loop and
    the `?v=` query.
  - `ServerImage.swift` and its 14 other callers are unchanged.
- **Run: the offline path only.** Cow Cam was offline, and its card showed today's "no snapshot" (§5, test3).
- **Traced:** the kept picture itself, a failing snapshot, and several cameras.
- **How the owner can see it:** when Cow Cam is back online, stay on Cameras for a minute or two. At each 45 s
  refresh, when "Snapshot age" returns to 0 s, the picture stays up and then changes. It no longer flashes to
  a dark "snapshot.jpg" panel.

### S16 — a failed or timed-out first location request can be retried

- **Built** in `Marlin DVR TV/WeatherLocation.swift`.
  - `requested` is cleared when a request fails (`:188`) and when the 25 s timeout fires (`:145`). So "Try
    again" sends a new one. A fix never clears it.
  - The doc comment is at `:64-66`.
  - The recorded 25 s timeout is kept.
  - The outstanding request is not stopped at the timeout, so a late fix is still cached.
- **Traced.** A failed first request cannot be produced on Home Theater on demand. No tvOS simulator runtime
  is installed.
- **On Home Theater: not visible.** It holds a saved fix, so the path is only reached on a fresh install.

---

## 4. Where the build departed from Pass 119's report

- **S1 — the report's option A breaks every recorded run command. Measured, so it was not used.** With the
  testable marked `skipped = "YES"`, `xcodebuild build-for-testing` wrote a run spec (`.xctestrun`) with
  **`"TestConfigurations" => []`**. It did so both with no filter and with
  `-only-testing:"Marlin DVR TVUITests/HomeRadioCountUITests"`. A skipped testable is not in the auto-created
  test plan at all, so a named class has nothing to run from. The build used instead is in the same one file
  (§3, S1). It keeps the target in the scheme and selects none of its tests
  (`useTestSelectionWhitelist = "YES"` with an empty `<SelectedTests>`).
- **S2 — the optional run of Pass 103's harness was not made, because it cannot pass today.** Its no-pass
  show, *Hitler's DNA*, is now the seventh show in `GET /api/library?limit=20`. The Recordings shelves draw
  six (`limit: 6`, COLD-START.md:101), so the harness's shelf walk cannot reach it. The pass show still holds
  its pass (`GET /api/passes`). Running the harness would have tested navigation, not the guard.
- **S12 — the run used the one boundary tonight's lineup offered.** `GET /api/guide` over the next four hours
  found one no-tuner boundary where the pass state changes: 6044 HISTORY (Philo) at 02:06:00. "Pawn Stars:
  Best Of" (01:05–02:06) matches no pass. "Pawn Stars" (02:06–03:03) matches the "Pawn Stars" pass by its
  `seriesId`, `title:pawn stars` (`AiringSheet.matchingPass`, `AiringSheet.swift:345-355`). No airing at
  that boundary is booked (the earliest booking is 06:00), so the booking half of S12 stays traced.
- **S15 — the camera was offline, so the kept picture could not be shown.** `GET /api/cameras` answered
  `count 1, online 0` for "Cow Cam", and the server's log reported it offline once a minute ("No route to
  host") all night.
- **The server is now marlin-dvr 1.11.1.** `GET /api/status` answered 1.11.1 on 2026-09-24. The notebook's
  last reading was 1.10.0 (2026-09-19). This is recorded as a fact. What 1.11.x changed was not read, because
  nothing in this sweep depends on it. S10's server behaviour was measured against the running 1.11.1 (§6).

---

## 5. The one run

```
xcodebuild -project "Marlin DVR TV.xcodeproj" -scheme "Marlin DVR TV" \
  -destination 'platform=tvOS,name=Home Theater' -allowProvisioningUpdates \
  -derivedDataPath build/p120 test -only-testing:"Marlin DVR TVUITests/Pass120SweepUITests"
```

- **One invocation**, started by a script at 01:40:00 and ended at 02:06:58 (exit 0). The start time was
  chosen so that test4 met tonight's two boundaries.
- **`** TEST SUCCEEDED **` — "Executed 4 tests, with 0 failures".** The result bundle is
  `build/p120/Logs/Test/Test-Marlin DVR TV-2026.09.24_01-40-02--0400.xcresult` (Home Theater, tvOS 26.6).
  Its summary reads: 4 tests, 4 passed, 0 failed, 0 skipped.
- **The build it ran is this pass's working tree**, the one committed. The run installed it on Home Theater.
- Screenshots are in `reports/assets/pass120/`, exported from the bundle and converted to JPEG.

**The app's own traffic, from `GET /api/logs` (client ids replaced):**

```
13316 01:40:08.458 INFO HTTP POST /api/clients/<client id>/ping 200     test1 launch (harness "launched" 01:40:09)
13357 01:41:14.509 INFO HTTP POST /api/clients/<client id>/ping 200     test2 launch (01:41:15)
13375 01:42:03.836 INFO HTTP POST /api/clients/<client id>/ping 200     test3 launch (01:42:04)
13385 01:42:19.989 INFO HTTP POST /api/clients/<client id>/ping 200     test4 launch (01:42:20)
13434 02:04:11.180 INFO TRS  session … created: ch6044 HISTORY (live, transcode) for D/S Apple TV
13435 02:04:11.180 INFO HTTP POST /api/play/sessions 200
13602 02:06:13.376 INFO HTTP DELETE /api/play/sessions/<sid> 200
13603 02:06:14.246 INFO TRS  session … ended after 2m: stop requested by D/S Apple TV; 152.68 MB served; …
```

- All four pings come from **one client id**. It is compared, not printed.
- **Between 01:40 and 02:07 the server logged no other non-GET request.** No record, pass, schedule, library
  or lineup write went out. Everything else in that window is GETs, the library scanner, and the art cache.

**Another client was at work earlier, and its write is not this pass's.** At 01:02:05 a different client id
pinged, played two recordings of *The Food That Built America* (sessions "for Apple TV"), and at 01:07:29 sent
`PUT /api/library/recordings/<id>`. That write moved S4 E5, "Clash of the Coffee", to Trash. It is the one
item test1 found in Trash ("Trashed today at 1:07 AM"). This pass sent nothing at that hour. Its only device
action before 01:40 was the 00:52 enumeration (§7), which launched no app.

**What each method showed.** The lines are the harness's own log, `[pass120 …]`, quoted from the run.

**test1 — S4 (regression) and S7/S8, passed in 67 s.**
- **S4:** `01:40:13 S4 glance: detail line "Feels 46° · humidity 80% · Apple Weather"; needs-location sentence
  false`. The glance drew weather from the saved fix, with no prompt (`01-s4-home-glance.jpg`).
- **S8, the hub:** `Scheduled Recordings, 12 scheduled` · `Your Passes, 12 passes` · `Trash, 1 in trash · 1.73
  GB`, and the storage card read `823.27 GB used · 28.30 TB free of 29.10 TB`. There was no "could not read",
  no error line, and focus was on Scheduled Recordings (`02-s8-hub.jpg`).
- **S7:**
  - Scheduled Recordings opened with focus on its first row, `11 News Today, QUEUED, 11.1 WBAL-DT ·
    6:00am–7:00am`, and no error. Menu returned to the hub, with focus on Scheduled Recordings (`03-…jpg`).
  - Your Passes opened on `Hazardous History With Henry Winkler, …`. Menu went back to the hub, with focus on
    Your Passes (`04-…jpg`).
  - Trash opened with focus on its one row, and Menu went back to the hub.
  - Nothing inside any list was selected.

**test2 — S10, passed in 49 s.**
- "Tiki" typed. `S10 rows for "Tiki": ["Tiki + Tierney, 6196 CBSSPORTS · Mon 3:00 PM · 3h 0m", … Tue …, …
  Wed …]`.
- The first row was selected. `S10 sheet true; "no longer lists" false; text ["CB", "NEW", "LIVE", "6196 ·
  CBSSPORTS · HD", "Tiki + Tierney", "Monday 3:00 – 6:00 PM", …]; focus Record this airing`
  (`05-s10-tiki-tierney-sheet.jpg`).
- Menu closed the sheet, and focus returned to the row. Record this airing was never pressed.
- The server's log shows the poster lookup for the title arriving whole: `01:41:55 ART TMDB miss: "Tiki +
  Tierney"`.

**test3 — S15, passed in 16 s, offline path only.**
- `S15 camera online false`. The card read `no snapshot, Offline, Cow Cam, …` (today's placeholder for an
  offline camera, unchanged).
- The kept picture could not be shown.

**test4 — S14 and S12, passed in 1478 s** (a 965 s wait on Home first).
- **S14, in place:**
  - Favorites opened at 01:58:43 with focus on `6044 · HISTORY, ★, HD, Pawn Stars: Best Of, ends 2:06 AM`.
    The DISCOVERY row read `… How to Catch a Dirtbag, ends 2:00 AM`, and AHC `… Blood Feuds, ends 2:00 AM`
    (`06-s14-favorites-0158.jpg`).
  - Sampled every ~10 s, the rows stayed as they were until **02:00:39.455, when DISCOVERY read `ends 3:01 AM`
    and AHC `ends 3:00 AM`**. That is 39 s after the turnover (`07-s14-favorites-0200.jpg`).
  - Focus was on HISTORY in all 16 samples (`focus moved false`).
- **S12:**
  - 02:04:12 — HISTORY playing live, on Philo, which holds no tuner.
  - A click down opened the panel. `02:04:20 … title Pawn Stars: Best Of · series Add to pass · record Record ·
    passLine - · focus Record` (`08-s12-panel-0204.jpg`).
  - The panel was held open, nothing pressed.
  - `02:06:12 … title changed true; title Pawn Stars · series Edit pass · record Record · passLine ◆ Series
    pass · 1 recording scheduled · new episodes · focus Record` (`09-s12-panel-0206.jpg`).
  - **The panel followed the new airing and read the new show's pass.** The pre-fix code, by trace (Pass 119
    §3), keeps "Add to pass" here.
  - Menu closed the panel, and Menu again closed the Player.
- **S14, after the round trip:**
  - 02:06:14 — back on Favorites, focus on HISTORY, the row still `Pawn Stars: Best Of, ends 2:06 AM`.
  - At **02:06:39** it read **`Pawn Stars, ends 3:03 AM`**. The loop had carried on behind the Player's
    cover, and focus stayed on the row (`10-s14-favorites-after-the-player.jpg`).

**What the run cannot prove.** It shows each fix's visible behaviour at the moments sampled, not the absence of
the bug at every moment. For S12, a pre-fix build was not run against the same boundary; the "before" is
Pass 119's trace.

---

## 6. S10 — the bytes, and the server's answers

**The builders' bytes were measured outside the project**, as Pass 86 did. A scratch Swift file on macOS
reproduced `URLComponents.queryItems` and the new `setServerQueryItems`. Its output was decoded with Go 1.26.3's
`url.ParseQuery`, the parser behind the server's `r.URL.Query()` (Pass 119 §4). The scratch files were
deleted afterwards.

| Title | Bytes before | Go reads | Bytes after | Go reads |
|---|---|---|---|---|
| `A + B` | `title=A%20+%20B` | `A   B` | `title=A%20%2B%20B` | `A + B` |
| `A;B` | `title=A;B` | *(pair dropped)* | `title=A%3BB` | `A;B` |
| `C++; D` | `title=C++;%20D` | *(pair dropped)* | `title=C%2B%2B%3B%20D` | `C++; D` |
| `Law & Order: SVU` | `title=Law%20%26%20Order:%20SVU` | unchanged, intact | same | intact |
| `Q=1?#x` | `title=Q%3D1?%23x` | unchanged, intact | same | intact |
| `Café 50% off` | `title=Caf%C3%A9%2050%25%20off` | unchanged, intact | same | intact |

On Later's pair, `u=https://x.example/a;b+c.png?s=1&t=2` with `title=A + B;C`, decodes intact in both values
after the change.

**The running server, read directly (GET only):**
- `GET /api/guide/find?q=%2B` listed 9 airings with a "+" in the title, among them "Tiki + Tierney" on 6196
  CBSSPORTS.
- `GET /api/guide/find?q=%3B` listed none, so the ";" half cannot be run today.
- `GET /api/guide/search?title=Tiki%20+%20Tierney` (the old bytes) answered **0 matches**.
- `GET /api/guide/search?title=Tiki%20%2B%20Tierney` (the new bytes) answered **3 matches**.

---

## 7. S1 — an unnamed run, proven without running it

**What an unnamed run executes is fixed before any test starts.** `xcodebuild test` builds a run spec from the
scheme's test plan and then executes that spec. ⌘U in Xcode does the same. So the unnamed case can be read
off the spec, without running anything.

**The spec, read without running anything.** Under this pass's scheme, `xcodebuild build-for-testing` with no
filter wrote a run spec whose one test target has an empty list of the tests to run:

```
"TestConfigurations" => [
  ...
      "BlueprintName" => "Marlin DVR TVUITests"
      ...
      "OnlyTestIdentifiers" => [
      ]
```

**What an empty list means.** `man xcodebuild.xctestrun` defines `OnlyTestIdentifiers` as "An array of test
identifiers that xcodebuild should include in the test run. **All other tests will be excluded from the test
run.**" An empty array includes nothing and excludes every test.

**The named route, measured by enumeration only.** This command was run on Home Theater:

```
xcodebuild … test -only-testing:"Marlin DVR TVUITests/Pass120SweepUITests/test3_CameraCardsKeepThePicture" -enumerate-tests …
```

- It returned **`enabledTests`: that one method**.
- **`disabledTests`: the other 73 methods of the 24 classes**, including every harness that writes:
  DeleteRefresh, StopRecording, CommercialSkip (7), ManageDVR (2) and TrashRestore.
- It took 8 s (00:52:41–00:52:49).
- The server's log has **no launch ping** in that window. Its last line before the enumeration was at
  00:52:16. So the app was never launched, and no test executed.

The run itself (§5) is the second proof of the named route: the named class executed.

**Not done, and why.** An unnamed `-enumerate-tests` on Home Theater would have given xcodebuild's own list
for the unnamed case directly. It was not made. It would have launched the UI-test runner with the bundle
unfiltered, and this pass's rule is never to do that. The generic `tvOS` destination cannot stand in for it.
There xcodebuild answers only "Tests must be run on a concrete device" and lists the target without its
tests. **So S1's unnamed case is proven from the run spec and its documented meaning. It is not measured.**

---

## 8. Records this pass changes

Recorded forward and not edited, as Pass 119's §3 (d) listed them:

- **S4** — `reports/2026-09-06-pass13-weather-radar.md:179-180` (Pass 13): *"A cached fix short-circuits
  `start()` entirely: no prompt, no request."* This no longer holds when the app's location is Never or
  restricted. Then the fix is dropped and the screens say they have no location. The proven half, no prompt
  after the first grant, is kept. DECISIONS.md:56 stands.
- **S13** — DECISIONS.md:356-357 (Pass 32): *"The `?? job` fallback the sheet's other writes use is
  deliberately absent here"*.
  - Stop still has no fallback.
  - The delete re-read and the re-read on open no longer have one either.
  - `record()` and `recordSeries()` keep theirs, so "the sheet's other writes" is still true of those two.
  - Because the owner widened S13 to the panel, **Pass 108's mirror records stay true**:
    DECISIONS.md:2530-2532, :2556 and COLD-START.md:65. The panel's delete re-read now does what the sheet's
    does.
- **S14** — Pass 108's foreman call, accepted with the pass as a whole ("all good"). It is recorded at
  DECISIONS.md:2537, *"screens underneath show a change made from the panel the next time they are opened"*,
  and in COLD-START.md:65 and `reports/2026-09-16-pass108-player-info-panel.md:309`. **For Favorites it now
  reads "within about a minute"**, possibly while the Player is still up. The Guide is unchanged.
- **S7** — COLD-START.md:67 gains two lists under DECISIONS.md:407-409's rule ("A screen must always have
  something focusable…"). The rule itself is applied, not changed.

---

## 9. The server reads this pass made

Every request below is a GET to `http://192.168.1.250:8090/`, made with `curl` from this Mac to plan the run
and to check its results. None of them is logged by the server with its query string (`main.go:181`, `:189`,
Pass 119 §4):

- `/api/status`;
- `/api/guide/find?q=%2B` and `?q=%3B`;
- `/api/guide/search?title=…`, once with the old bytes and once with the new, for "Tiki + Tierney" and "The
  NFL Today +";
- `/api/passes`, `/api/schedule`, `/api/channels`, `/api/cameras` (parsed down to name and online state), and
  `/api/library` and `?limit=6` / `?limit=20`;
- `/api/guide?slots=8` and `?slots=16`;
- `/api/logs`.

`GET /api/settings` was not read. The app's own traffic in the run is in §5.

---

## Open questions

**None.** The one question Pass 119 left — S13 and the info panel — was answered by the owner on 2026-09-24
and built as he answered it.

## What I am least sure of

1. **S1's unnamed case is proven, not measured.** It rests on the run spec xcodebuild wrote, with
   `OnlyTestIdentifiers` empty, and on what `man xcodebuild.xctestrun` says that means. No unnamed run or
   unnamed enumeration was made. ⌘U pressed in the Xcode app reads the same scheme test plan. It was not
   pressed, and the app could rewrite the scheme's empty `<SelectedTests>` when it next saves the scheme.
2. **S15 has never drawn a kept picture.** The camera was offline, so two things are traced only: that
   `AsyncImage` goes back to loading when its URL changes, and that the success branch's `.onAppear` records
   every new picture. The code follows SwiftUI's documented phases.
3. **S4's Settings round trip has never been recorded on tvOS 26.6.** Nor has whether tvOS relaunches the app
   when its location permission changes. Only the allowed path ran.

---

## SCOPE CHECK

| File | Step | Item | Change |
|---|---|---|---|
| `Marlin DVR TV.xcodeproj/xcshareddata/xcschemes/Marlin DVR TV.xcscheme` | 2 | S1 | the testable selects no test (`useTestSelectionWhitelist`, empty `<SelectedTests>`) |
| `Marlin DVR TVUITests/ShowDetailSeriesPassUITests.swift` | 2 | S2 | a `guard` before the Select |
| `Marlin DVR TV/WeatherLocation.swift` | 2 | S4, S16 | authorization before the cache; `dropCache()`; `requested` cleared on failure and timeout |
| `Marlin DVR TV/ManageDVRScreen.swift` | 2 | S8 | three read errors, the hub's rows and lines, the storage card |
| `Marlin DVR TV/ScheduleManageView.swift` | 2 | S7, S8 | focusable empty sentence and fallbacks; the error in its place; subtitle |
| `Marlin DVR TV/PassesManageView.swift` | 2 | S7, S8 | the same |
| `Marlin DVR TV/ShowDetailScreen.swift` | 2 | S9 | `apply()` rewrites `detail` |
| `Marlin DVR TV/ServerAPI.swift` | 2 | S10 | `URLComponents.setServerQueryItems`, used in `url(_:query:)` |
| `Marlin DVR TV/AiringSheet.swift` | 2 | S10, S13 | the poster query; the two re-reads without a stale fallback |
| `Marlin DVR TV/Models.swift` | 2 | S10 | Trash's poster query |
| `Marlin DVR TV/OnLaterScreen.swift` | 2 | S10 | the feed-art query |
| `Marlin DVR TV/PlayerInfoPanel.swift` | 2 | S12, S13 | `followTheAiring()` in the panel's task; the delete re-read through `readScheduleJob` |
| `Marlin DVR TV/FavoritesScreen.swift` | 2 | S14 | On Now's 60 s loop |
| `Marlin DVR TV/CamerasScreen.swift` | 2 | S15 | `CameraCard` keeps its last picture |
| `Marlin DVR TVUITests/Pass120SweepUITests.swift` | Verify | S4, S7, S8, S10, S12, S14, S15 | new — the one run's harness, which the pass allows |
| `DECISIONS.md` | 3 | — | the Pass 120 entry appended |
| `COLD-START.md` | 3 | — | the server line; the Weather, Manage DVR, show detail, Search, On Later, airing sheet, Player, Favorites and Cameras lines; the evidence-harness line; *Next step*, with Pass 119's paragraph kept beneath it, labelled |
| `reports/2026-09-24-pass120-sweep-built.md` | 3 | — | new — this report |
| `reports/assets/pass120/` (10 `.jpg`, 1.8 MB) | 3 | S4, S7, S8, S10, S12, S14 | new — the run's screenshots, exported from its result bundle |

**Nothing else was changed:**
- The files Pass 119 named as *possible* and not needed were left alone: `ChannelFilter.swift`,
  `ServerImage.swift`, `ResumeStore.swift`, `ContentView.swift`, `GuideCollections.swift`, and `Models.swift`
  for S9. `Models.swift` changed for S10 only.
- The STANDALONE items' five files are byte-identical: `GuideScreen.swift`, `ScreenShell.swift`,
  `RailView.swift`, `PlayerModel.swift` and `PlayerHost.swift`.
- `COLD-START-HISTORY.md` is untouched. As in Pass 119, the superseded *Next step* paragraphs stay in
  `COLD-START.md` under a label, rather than moving there by Pass 89's rule.
- `COLD-START.md`'s *Open questions* still reads "None", which is true again.
- `project.pbxproj` is unchanged. The UI-test target is a synchronised folder, so the new harness needed no
  project edit.

**Scratch.** The S10 probe (Swift and Go) and the S1 probe builds (`build/p120-s1-unnamed`,
`build/p120-s1-named`) were deleted after this report was written. `build/p120`, the run's DerivedData, stays,
and `build/` is git-ignored.

## Pushed vs local

**Local only.** One commit on `main`, one ahead of `origin/main` (`8e68d01`). Nothing was pushed: the owner
tests on Home Theater first.

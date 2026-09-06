# Pass 10B — Manage DVR moves to the rail (owner fix) — 2026-09-06

Pass 10 put the way into the management area on the Recordings screen. The owner wants it in
the rail instead. That is all this pass does: the row is gone, a tenth rail entry opens the
same screen, and nothing else changed. **Committed locally only; nothing was pushed** — the
push carries Passes 8, 9, 10 and 10B together after the owner's test.

No request was made to the Marlin DVR server by this pass beyond the reads the app makes on
its own when a screen opens. **No server write of any kind.**

---

## 1. Step 1 — the row is off Recordings

`RecordingsScreen.swift` is frame 5b again: the `manageRow` view, the `managing` state, the
`ManageDVRScreen` branch and the Menu special case are gone, and the focus fallbacks are back
to `"loading"` from `"manage"`. The screen's header comment records where the entry went.

Evidence: `11-recordings-row-removed.jpg` — the shelves start straight after the header — and
two assertions in the UI test, one on the row's title and one on its subtitle, so a leftover
would fail even if it were drawn differently:

```
XCTAssertFalse(app.staticTexts["Manage DVR"].exists)
XCTAssertFalse(app.staticTexts["Scheduled recordings, series passes, trash and storage"].exists)
```

## 2. Step 2 — Manage DVR in the rail, at the bottom

**Where the design puts it.** The design's rail data (`nav`, dc:1133-1137) lists nine entries
and **Settings is not among them** — Settings exists only as a Home tile (`tiles`,
dc:1353-1368). So there is no settings-area slot in the rail to sit next to; the bottom of the
rail is the slot, below Radio. That is where it went.

- `Destination.swift`: a tenth case, `manage`, label "Manage DVR", appended to `railOrder`
  and included in `isBuiltNow`. Its rail icon is `slider.horizontal.3` — the settings-area
  symbol, and the same one the Pass 10 Recordings row used, so it reads as the same thing it
  was. `tileTint` gets a case only because the switch must be exhaustive; it is never drawn,
  because Manage DVR is not a Home tile.
- `ScreenShell.swift`: `case .manage: ManageDVRScreen(api: api, onLeave: leave)`. The screen
  itself is untouched — same file, same contents, same `onLeave` contract the other screens
  use (Menu at its top level returns to Home).

Evidence: `12-rail-with-manage-dvr.jpg` — ten entries, Manage DVR last, in the rail's own
style — and `13-manage-opened-from-rail.jpg`, the screen open with the rail's bottom icon
active and its contents exactly as Pass 10 left them (Storage · 1 scheduled · 1 pass ·
1 in trash).

**One thing had to change to match the rail's look.** "Manage DVR" is the first rail label
long enough to wrap in the 372 pt expanded rail, and it drew on two lines while every other
entry is one. `RailView.swift`'s label now carries `.lineLimit(1)` with a 0.8 minimum scale
factor; the nine shorter labels are unaffected. This is a one-line change to the rail's text
rendering, not to its layout, order or icons.

## 3. Step 3 — Home is untouched

Pass 10 never added a Manage DVR tile to Home, and this pass adds none: `homeTiles` is the
design's nine, unchanged. Asserted rather than assumed
(`XCTAssertFalse(app.staticTexts["Manage DVR"].exists)` while Home is on screen) and shown in
`10-home-unchanged.jpg`.

## 4. Step 4 — verified hands-on in the Simulator

Driven with `XCUIRemote` through a new UI test (`RailManageUITests.swift`, 97 lines) rather
than synthetic key presses: during Pass 10 the Mac's keyboard focus was repeatedly taken by
other applications, which made that route unreliable. The test asserts on what the app draws
and attaches a screenshot at each step; it makes no server write.

```
Test Case 'RailManageUITests.testManageDVRLivesInTheRailAndNotOnRecordings' passed (40.842 s)
   ✓ Home shows no Manage DVR tile
   ✓ Recordings shows neither the row's title nor its subtitle
   ✓ the rail holds a "Manage DVR" entry
   ✓ walking down from Home hits, in order: Favorites, On Now, Guide, On Later,
     Recordings, Cameras, Weather, Radio, Manage DVR          (each one asserted to have focus)
   ✓ selecting it opens Manage DVR: "Storage", "Scheduled Recordings", "Your Passes", "Trash"
   ✓ from inside Manage DVR the rail still walks back up to Home
```

The downward walk is the top-to-bottom focus check step 4 asks for, and it is asserted entry
by entry, so a break anywhere in the rail names the entry it stopped at.

**Found while testing, and not a regression:** entering the rail from a screen lands focus on
the entry nearest the content, not on the current screen's entry — from Recordings it lands on
On Later (`12-rail-with-manage-dvr.jpg` shows On Later focused while Recordings is active).
That is pre-existing rail behaviour from Pass 5, unchanged by this pass; the first version of
the test assumed otherwise and was corrected, not the app.

## 5. Step 5 — installed on Home Theater

Installed and launched at 15:13:32 (`devicectl … install app` →
`installationURL: …/Marlin DVR TV.app/`, `process launch` → "Launched application"), and the
server logged the check-in: `Apple TV | 192.168.1.30 | Marlin DVR TV 1.0 | online True | now`.
It is left installed and running.

---

## SCOPE CHECK — every file created or touched

| Path | Step |
|---|---|
| `Marlin DVR TV/RecordingsScreen.swift` — the Manage DVR row, its state and its Menu case removed; focus fallbacks restored | 1 |
| `Marlin DVR TV/Destination.swift` — the `manage` case, its label and icon, `railOrder`, `isBuiltNow`; `homeTiles` deliberately unchanged | 2, 3 |
| `Marlin DVR TV/ScreenShell.swift` — routes `.manage` to the unchanged `ManageDVRScreen` | 2 |
| `Marlin DVR TV/RailView.swift` — rail labels kept to one line | 2 (matching the rail's look) |
| `Marlin DVR TVUITests/RailManageUITests.swift` (new, 97) | 4 |
| `reports/assets/pass10b/*.jpg` (4 files, 532 KB) | 4 |
| `COLD-START.md` — the one sentence that said Manage DVR is "reached from a new row at the top of Recordings", corrected, plus a Pass 10B line and the next-step wording. A factual correction to the notebook every pass reads first, not a feature | deliverable |
| `reports/2026-09-06-pass10b-manage-in-rail.md` (this file) | deliverable |
| Local commit "Pass 10B: Manage DVR moves from Recordings to the rail"; **no push** | deliverable |

Nothing else was written. In particular the Manage DVR screen itself is untouched:
`ManageDVRScreen.swift`, `ScheduleManageView.swift`, `PassesManageView.swift`,
`TrashManageView.swift` and `EditSeriesPassScreen.swift` are byte-for-byte as Pass 10 left
them, as are `FavoritesScreen.swift`, `HomeView.swift`, `DECISIONS.md`, `Info.plist`, the
project file, `Assets.xcassets`, `design/` and every other Swift file. `COLD-START.md` was
corrected where it described the old entry point, and nowhere else.

Outside the repo: DerivedData, and the app on the Simulator and on Home Theater. The reference
clone and `design/` were only read. No server write; no request beyond port 8090; none to
marlinpc, the HDHomeRun directly, or the UNAS4Pro share. Nothing installed on the Mac; no
packages; no third-party code.

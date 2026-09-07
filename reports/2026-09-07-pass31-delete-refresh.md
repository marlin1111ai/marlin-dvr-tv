# Pass 31 — a deleted recording leaves the Recordings list without leaving the screen

**2026-09-07.** Owner defect, from testing on Home Theater: press and hold a recording, delete it,
back out to the Recordings screen — and the deleted recording is still listed. Leaving Recordings
altogether and coming back shows the correct list. The server-side delete works; the screen is
showing stale data.

Fixed, and proven on Home Theater with the real Siri Remote. Committed locally, **not pushed** —
the owner tests first.

---

## 1. Step 1 — the read-only findings

### 1.1 How the Recordings screen loads its list, and when it reloads

`RecordingsModel.load()` (`RecordingsScreen.swift:33-42`) is the only read: one
`GET /api/library?limit=6` through `APIClient.library(limit:)` (`ChannelFilter.swift:77-81`),
whose answer it keeps whole in `library: LibraryResponse?`.

It is called from exactly one place — the `.task` at `RecordingsScreen.swift:68` — and **there was
no other reload of any kind**: no timer, no `onAppear`, no `onChange`, nothing after a write. On
Now (60 s) and Cameras (45 s) have periodic reloads; Recordings never had one.

The `.task` is attached to the `Group` at `RecordingsScreen.swift:61-67`, which is the *whole* body:

```swift
Group {
    if let selected { ShowDetailScreen(...) } else { shelves }
}
.task { await model.load() ... }
```

So opening show detail does **not** end that task and does not start a new one — `selected` merely
swaps which branch of the same Group renders. `onExitCommand` (`:73-81`) sets `selected = nil` and
re-renders `shelves` from the `library` that was read when the screen first opened.

**That is the whole defect.** The shelves are a snapshot taken once, and backing out of show detail
redraws that snapshot.

Leaving Recordings works for the opposite reason: `ScreenShell` puts `.id(current)` on the content
(`ScreenShell.swift:51`), so changing rail entry gives SwiftUI a new identity, tears the screen
down, and the rebuilt one runs its `.task` again.

### 1.2 What the delete action calls, and what the server answers

The hold menu is `EpisodeActionsMenu`; its Delete row sends `.trash(true)`
(`EpisodeActionsMenu.swift:60-65`) through `APIClient.updateRecording(id:flag:)`
(`ServerWrites.swift:200-209`):

```
PUT /api/library/recordings/{id}   {"trash": true}
```

The answer is decoded as `RecordingUpdate` (`ServerWrites.swift:98-116`) — either the updated
`episodeView`, or `{ok, deleted}` in the one case where the server's "Remove Items From Trash
After" is "Immediately" and the file went at once. `EpisodeActionsMenu.write` (`:93-111`) maps both
to "this episode leaves the visible list", and `ShowDetailModel.apply` (`ShowDetailScreen.swift:53-60`)
removes it from `episodes`, which is why show detail was always right and only the shelves were wrong.

**Confirmed on this server, from the run itself (§3.3): the delete is a soft delete.** The file is
still on disk — `roots[0].files` stayed at 5 across the delete — and the recording is now in the
trash with `exists: true`. The server answered with the episode, not `{ok, deleted}`. No
`GET /api/settings` read was made (not authorised this pass); this is measured from the library and
show endpoints instead.

### 1.3 Delete moves it to the trash — so what should the list show afterwards?

This was the question the brief asked to settle before changing anything, because it decides the
target behaviour. The answer: **whatever `GET /api/library` says**, re-read.

The shelves cannot be corrected locally, and this is why the fix is a re-read rather than an edit
of the array in memory:

- a card's episode count and its "n new" badge are `ShowSummary.count` / `.unwatched`
  (`Models.swift:198-207`), both the server's;
- which shelf a show sits on, and in what order, is the server's (`recently-watched`,
  `recently-updated`, `recently-added`);
- the header line is `lib.shows` and `lib.recordings` (`RecordingsScreen.swift:84-87`);
- and `limit: 6` means one delete can pull a **seventh** show into a shelf that was full — a show
  whose data the client has never seen.

None of that is derivable from the single `episodeView` the server hands back.

**One expectation from the notebook turned out to be wrong, and it matters to the owner.** Pass 8
Open Question 11 recorded that a show whose last episode is trashed "stays in the library index
with 0 visible episodes until the trash expires". On this server today it does **not**: after the
delete, `shows` went `1 → 0` and all three sections went empty, at `limit=6` and at `limit=500`
alike. So the card disappears outright rather than lingering at "0 episodes". That is better than
expected, and §4.1 records the consequence it has for the Trash screen.

---

## 2. What changed

Two files, one behaviour: **show detail tells the shelves when it has changed the library, and the
shelves re-read it immediately.**

### `ShowDetailScreen.swift`

A new `onLibraryChanged: () -> Void` (`:85`, `:92-97`), fired from the menu's `onApplied` handler
(`:118`) — the point at which the server has already accepted the write and answered.

### `RecordingsScreen.swift`

`ShowDetailScreen` is handed `onLibraryChanged: reloadShelves` (`:63`), and `reloadShelves`
(`:158-168`) re-reads the library.

It fires **while show detail is still on top**, not on the way back. By the time the owner presses
Menu the fresh library is already in place, so the shelves are correct on their first frame rather
than correcting themselves a moment later. The read is ~3 ms on this network, so the window is not
one the remote can beat.

Focus is repaired only in the one case that needs it — the card that had focus is gone:

```swift
guard selected == nil, let current = focused, current != "loading",
      !cardIDs.contains(current) else { return }
```

The `let current = focused` is deliberate. When the remote is in the rail this screen's `focused` is
nil, the guard returns, and the reload cannot pull focus out of the rail — the property Pass 25
measured for On Now's and Cameras' timed reloads, kept here.

The callback fires for **Keep** as well as Delete. Both are writes the server accepts against the
library these shelves are drawn from; refreshing after either is the same statement, and Keep is in
the same menu.

---

## 3. Device evidence — Home Theater, the real Siri Remote

`Marlin DVR TVUITests/DeleteRefreshUITests.swift` (new, 178). It drives the physical Apple TV
(`Apple TV 4K (3rd generation)`, tvOS 26.6, build 23L773), walks the Home grid to Recordings, opens
the show, crosses into the episode list, holds Select for 1.2 s, presses Delete, and reads the
screen at each step.

```
xcodebuild -project "Marlin DVR TV.xcodeproj" -scheme "Marlin DVR TV" \
  -destination 'platform=tvOS,name=Home Theater' -allowProvisioningUpdates test \
  -only-testing:"Marlin DVR TVUITests/DeleteRefreshUITests"
```

**`** TEST SUCCEEDED **`, 1 test, 0 failures, 49.9 s, 11:11:47–11:12:37.**

### 3.1 What the screen showed

| Screenshot | What it shows |
|---|---|
| `01-shelves-before-the-delete.png` | Header **"1 shows · 5 recordings"**. Recently Updated and Recently Added each carry the *Hazardous History With Henry Winkler* card, **"1 episode"**, badge **"1 new"** |
| `02-show-detail-before-the-delete.png` | The show, one episode row, S2 E20 "Surviving the '70s" |
| `03-episode-menu-on-delete.png` | The hold menu open, focus walked from Keep to **Delete — "Moves to the trash"** |
| `04-show-detail-after-the-delete.png` | The episode row gone; the summary line reads **"0 episodes · 0 unwatched · Zero KB"** |
| `05-shelves-after-backing-out.png` | **The card is gone.** Header **"0 shows · 5 recordings"**; all three shelves read "Nothing yet." |
| `06-shelves-on-a-fresh-entry.png` | The same screen reached the old way — out to Home, back into Recordings |

All six are in `reports/assets/pass31/`.

### 3.2 The two assertions that are the pass

**The defect is gone.** `XCTAssertNotEqual(afterBackOut, before)` passed: the shelves reached by
backing out are no longer the library as it stood before the delete. Before the fix this is the
comparison that would have failed, because the two were the same snapshot.

**And the refresh agrees with the server, not merely with itself.** `XCTAssertEqual(afterBackOut.sorted(),
reEntered.sorted())` passed — the shelves reached by backing out carry the same text as the shelves
reached by leaving Recordings and coming back, which is the path the owner reported as correct.

The screenshots make that stronger than the text comparison does: **`05` and `06` are byte-identical**,
MD5 `c275a271a41795557dc9e747a2002d45` both. Backing out and re-entering produce the same screen
pixel for pixel.

```
$ md5 05-shelves-after-backing-out.png 06-shelves-on-a-fresh-entry.png
MD5 (05-shelves-after-backing-out.png) = c275a271a41795557dc9e747a2002d45
MD5 (06-shelves-on-a-fresh-entry.png) = c275a271a41795557dc9e747a2002d45
```

### 3.3 The server, read directly before and after

| | Before (11:09) | After (11:13) |
|---|---|---|
| `/api/library` `shows` | 1 | **0** |
| `/api/library` `recordings` | 5 | 5 |
| `roots[0].files` | 5 | **5 — the file is still on disk** |
| `recently-updated` / `recently-added` | the show, `count 1`, `unwatched 1` | **empty** |
| `shows/hazardous-…` visible | `count 1`, `trashCount 0`, `6007a13f0b46 trash=false` | `count 0`, **`trashCount 1`** |
| `shows/hazardous-…?trash=1` | empty | **`6007a13f0b46 trash=true exists=true 1.86 GB`** |

The one write this pass made is that delete, which the owner authorised for this test. **It was not
restored** (owner, 2026-09-07 — "whether it sits in trash or is gone entirely is fine either way"),
and `POST /api/library/trash/empty` was never sent.

---

## 4. What this leaves behind

### 4.1 The trashed recording is not reachable from the app's Trash screen

Not a regression from this pass, and out of its scope to fix, but it follows directly from §1.3 and
should not be discovered by accident.

`ManageModel.refreshTrash` (`ManageDVRScreen.swift:75-89`) collects show ids from
`GET /api/library?limit=500`'s section items and then asks each of those shows for its trashed
episodes — "the library has no trash endpoint of its own" (`TrashManageView.swift:5-7`). The library
now answers **zero shows**, so the loop has nothing to ask, and Manage DVR → Trash will read
"The trash is empty" while the server holds `6007a13f0b46`, 1.86 GB, `trash=true`.

So this recording cannot be restored from the Apple TV. It is still visible and restorable in the
server's own web UI. Deleting the *last* episode of a show is the case that triggers this; deleting
one of several leaves the show in the library and the trash row appears normally, which is what
Pass 10 observed.

### 4.2 Smaller things, named rather than fixed

- **The header's second number is a file count, not an episode count.** "0 shows · 5 recordings"
  after the delete is not a contradiction: `recordings` is `roots[0].files`, the file count of
  `/mnt/unas4pro/DVR`, and a soft delete leaves the file there. It moved from 5 to 5.
- **With the library empty, focus lands in the rail rather than the content.** `firstCardID` is nil,
  and `"loading"` has no focusable view once `model.loaded` is true, so tvOS moves focus to the rail
  and Pass 25's restore puts it on Recordings. It is the same on a fresh entry — screenshots `05`
  and `06` are identical — so it is the empty screen's behaviour, not something this fix introduced.
- **Home's Recordings tile** also counts from `/api/library`. It was not touched (scope lock) and
  needs nothing: `HomeModel` reloads on every return to Home (`HomeView.swift:96`, `:132`).
- **The console lines from the run were not retained** — the build output was tailed and the
  `[pass31 …]` timeline was not written to a file. Nothing rests on it: every claim above is carried
  by a screenshot, an assertion that passed, or a server read taken from this Mac.

---

## 5. SCOPE CHECK — every file touched, and the step that required it

| File | What happened to it | Step |
|---|---|---|
| `Marlin DVR TV/RecordingsScreen.swift` | **modified** — `onLibraryChanged:` wired at `:63`, new `cardIDs` and `reloadShelves()` at `:144-168`, header note | 2 |
| `Marlin DVR TV/ShowDetailScreen.swift` | **modified** — `onLibraryChanged` property and init parameter, one call in `onApplied`, header note | 2 |
| `Marlin DVR TVUITests/DeleteRefreshUITests.swift` | **new** — the device harness, kept as this pass's evidence | 3 |
| `reports/2026-09-07-pass31-delete-refresh.md` | **new** — this report | deliverable |
| `reports/assets/pass31/*.png` | **new** — the six screenshots the run attached | 3 |
| `COLD-START.md`, `DECISIONS.md` | **modified** — the standing notebook record of the pass | project rule |
| `build/**` | build output and the result bundle; git-ignored, never committed | 2, 3 |

**Not done, as scoped:** no change to any other screen's refresh behaviour — On Now, Cameras, the
Guide, Favorites, On Later, Home, Manage DVR and Radio are untouched by diff; no work on Restore or
Empty Trash, and neither was ever sent; no change to playback; **no new UI** — nothing was added to,
removed from or restyled on any screen, and the only visible difference is that the shelves hold
newer data. `GET /api/settings` was not read (not authorised). The one server write is the delete
the brief called for. Nothing in `design/`, the reference clone, or on any host outside this folder
was read or written; Unraid, marlinpc, the HDHomeRun and the UNAS4Pro share were not touched, and
the only server traffic was library and show reads plus that one `PUT`.

**Git: committed locally, not pushed** — the owner tests first.

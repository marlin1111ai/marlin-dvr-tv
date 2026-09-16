# Pass 91 — "Continue watching" replaces the Recordings screen's "Recently watched" shelf

2026-09-16. Built, committed, **NOT pushed**. One run on Home Theater.

---

## 0. Result, in one paragraph

The Recordings screen no longer draws the server's **"Recently Watched"** shelf. In its place and
in its position it draws **"Continue watching"** — the recordings **this Apple TV** has an
unfinished saved position on, newest position first, straight out of `ResumeStore`. On Home
Theater that is **five cards**, and the shelf was photographed with them (§5). The two shelves
below it are the server's and are untouched; show detail, the Pass 31 re-read after a write, the
click-and-hold Keep/Delete, the Pass 47 card geometry and the Player are all unchanged. The app
target diff is **two files** and **no new server route, no new dependency, no change to
`ResumeStore`'s stored format, no Player change**.

---

## 1. Step 1 — the SHA and the tree

`git fetch`, then, before anything was changed:

```
HEAD:        92a477071df7058942fe3895bd77166e50c3af00
main:        92a477071df7058942fe3895bd77166e50c3af00
origin/main: 92a477071df7058942fe3895bd77166e50c3af00
git ls-remote origin main
  92a477071df7058942fe3895bd77166e50c3af00	refs/heads/main
branch: main
git status --porcelain
  ?? icon-source/
```

**Pass 89's verified push SHA is `92a4770`.** All three reads agree and the only untracked path is
`icon-source/`, which Pass 51–55 left in place deliberately. Nothing else was dirty, so the pass
proceeded.

---

## 2. Step 2 — the trace, taken before anything was changed

All `file:line` below are at `92a4770`. They will drift; this project does not rewrite them
(DECISIONS.md, 2026-09-09 (Pass 56)).

### 2.1 How `RecordingsModel` builds the shelves from `GET /api/library`

| What | Where |
|---|---|
| The model holds the whole decoded response and nothing derived | `RecordingsScreen.swift:25` `private(set) var library: LibraryResponse?` |
| The one read | `RecordingsScreen.swift:35` `library = try await api.library(limit: 6)` |
| The wrapper, and the only place the path is written | `ChannelFilter.swift:118-122` → `GET /api/library?limit=6` |
| The response type | `Models.swift:349-357` `LibraryResponse { sections, shows, recordings, roots, scannedAt, scanning, configured }` |
| A shelf | `Models.swift:334-339` `LibrarySection { key, label, items, total }`, with `:335` naming the three keys `recently-watched \| recently-updated \| recently-added` |
| A card's data | `Models.swift:323-332` `ShowSummary { id, title, count, unwatched, art, lastAdded, lastUpdated, lastWatched }` |
| The shelves are drawn straight from `sections`, in the server's order, never sorted or filtered | `RecordingsScreen.swift:103` `ForEach(model.library?.sections ?? [], id: \.key)` |
| The heading is the server's `label`, unaltered | `RecordingsScreen.swift:105` |
| An empty section draws "Nothing yet." at 60 pt tall | `RecordingsScreen.swift:108-112` |
| A row's cards are the server's `items`, in the server's order | `RecordingsScreen.swift:116` |
| A card's focus id | `RecordingsScreen.swift:117` `"\(section.key):\(show.id)"` |
| The card itself | `RecordingsScreen.swift:121` `PosterCard(show:focused:)`, defined `:187-226` (Pass 47 geometry) |
| Select opens show detail for that show | `RecordingsScreen.swift:119` `selected = show` |
| The header counts | `RecordingsScreen.swift:84-87`, `lib.shows` and `lib.recordings` verbatim |
| `load()`'s callers: the screen's `.task`, and Pass 31's post-write re-read | `RecordingsScreen.swift:68` and `:158-168` |
| Focus helpers that enumerate the cards | `RecordingsScreen.swift:139-142` `firstCardID`, `:145-148` `cardIDs` |

Nothing between the wire and the screen transforms a shelf. `RecordingsScreen` is the **only**
consumer of `sections` in the app (`grep` over the app target: `HomeView.swift:39` calls
`api.library()` but reads only the counts).

### 2.2 Where "Recently watched" comes from — the server's, wholly

**The name and the membership are both the server's.** The app contributes neither:

- the **key** `recently-watched` and the **label** `"Recently Watched"` are fields of the server's
  own section object (`Models.swift:334-339`); the app draws `section.label` at
  `RecordingsScreen.swift:105` and has no string of its own for any shelf;
- the **membership** is the server's `items` array, drawn in the server's order at `:116`;
- the **position** is the server's — it is `sections[0]`, and the app iterates the array as given.

Measured against the live server on 2026-09-16 (`GET /api/library?limit=6`, HTTP 200):

```
SECTION recently-watched | Recently Watched | total 1 | items 1
SECTION recently-updated | Recently Updated | total 4 | items 4
SECTION recently-added   | Recently Added   | total 4 | items 4
shows 4  recordings 12
```

Its one member is `history-s-greatest-mysteries`, selected by the server's `lastWatched`
(`2026-09-08T21:07:22…`) — a **server-side** watched mark, which the screen's own subtitle already
tells the owner is **shared with the other Apple TV**. It is also **per show**, not per recording.
That is the whole reason the replacement is not a rename: a resume position is per Apple TV and
per recording, so the shelf had to be rebuilt, not relabelled.

### 2.3 `ResumeStore` — what it is keyed by and what it stores

`ResumeStore.swift` at `92a4770`, whole:

| Fact | Where |
|---|---|
| Storage is `UserDefaults.standard` — hence **per Apple TV**, which is the approved design fact (DECISIONS.md, 2026-09-05 (design)) | `ResumeStore.swift:22`, `:29`, `:34` |
| The key is `"marlinResume." + recordingID` | `:19` prefix, `:22`/`:29`/`:34` the concatenation |
| The value is JSON of `Entry { position: Double, duration: Double, savedAt: Date }` | `:13-17`, encoded `:28`, decoded `:23` |
| There is **no index** — no list of keys, no show, no title, no art | the whole file; `entry(for:)` `:21-24` is the only read, and it needs the id already |
| The existing "is there a resume?" bar is `position > 5` | `:41`, inside `latest(among:)` |
| The label the UI shows | `:49-53` `label(for:)` → `"22 min in"` |

**Can a saved position be matched to a recording id?** Yes, trivially: *the key is the recording
id*. `String(key.dropFirst("marlinResume.".count))` is the whole of it.

**Can it be matched to a show without a new server call? No — measured, not assumed.**

- `GET /api/library` answers **shows** and carries **no recording id at all** (`ShowSummary`,
  `Models.swift:323-332`). There is nothing in the shelves' own read to join against.
- The recording id is an opaque 12-hex token (`ef4d2419605d`, `5328bb632e76`) with no show in it.
- There is **no per-recording read on this server**. Probed on 1.8.2 on 2026-09-16, GET only:

```
/api/library/recordings/cac7c08639ec    HTTP 404
/api/library/recordings/cac7c08639ec/   HTTP 404
/api/library/recording/cac7c08639ec     HTTP 404
/api/library/recordings                 HTTP 404
/api/recordings                         HTTP 404
```

  (`PUT /api/library/recordings/{id}` exists and is the Keep/Delete write; there is no `GET`.)
- The **only** route from a recording id to its show is `GET /api/library/shows/{id}`
  (`ChannelFilter.swift:126-128`), whose `ShowResponse.episodes` carries `id`, `showId`, `season`,
  `episode`, `episodeTitle` (`Models.swift:360-389`, `:398-409`). That is the read **show detail
  already makes** (`ShowDetailScreen.swift:40`).

So the shelf costs the shows' reads on top of the library read. **No new route** — it is an
existing endpoint this app already calls — and **nothing new stored**.

**Step 2's STOP condition was not met.** The store can be read the way the shelf needs *without
any change to the stored format*: `UserDefaults.standard.dictionaryRepresentation()` hands back the
standard domain's keys, and filtering them on the existing `"marlinResume."` prefix enumerates
exactly what `save` already writes. Nothing is added to an `Entry`, no index is written, no
migration exists. The pass therefore went on to step 3.

### 2.4 How a position is cleared when a recording finishes

**Cleared in exactly one place:** `PlayerModel.playedToEnd()`, `PlayerModel.swift:628-644` —
`ResumeStore.clear(recordingID: episode.id)` at **`:641`**, after `sessions.markWatched(…)` at
`:635`. `ResumeStore.clear` itself is `ResumeStore.swift:33-35`, a `removeObject`.

So **the store's own record of "finished" is the absence of an entry.** The second guard is in the
writer: `saveResume()` (`PlayerModel.swift:819-824`) returns without writing when
`duration > 0, position >= duration - 3` (**`:822`**) — it will not park a position in the last
three seconds.

For completeness, every writer, since the shelf's freshness depends on them:

| When | Where |
|---|---|
| Every 10 s while playing and not paused | `PlayerModel.swift:261-262` |
| On pause | `:282` |
| On the session expiring | `:620` |
| On dismissal / backgrounding / switching request | `:793` |
| On `restart(at:)` — **unconditionally**, which is why the shelf keeps its own end-of-file test | `:748` |

`restart(at:)` is the one path that can leave an entry at the very end, so the shelf re-applies
`saveResume`'s own three-second test rather than trusting the absence of an entry alone.

---

## 3. Steps 3–5 — what was built

Two files in the app target. `git diff --numstat`: `RecordingsScreen.swift` **+153 / −7**,
`ResumeStore.swift` **+47 / −1**.

### 3.1 `ResumeStore.swift` — reading the store, adding nothing to it

- **`saved() -> [(id: String, entry: Entry)]`** — every saved position on this Apple TV, newest
  first. It walks `UserDefaults.standard.dictionaryRepresentation()`, keeps keys with the existing
  `marlinResume.` prefix, decodes the existing `Entry`, and drops the prefix to recover the
  recording id. A key that will not decode is skipped rather than failing the shelf.
- **`isResumable(_:)`** — `entry.position > 5`. This is **not new**: it is the expression that was
  inline at `:41` in `latest(among:)`, which decides whether frame 5d draws
  "Resume S9 E11 · 22 min in". `latest(among:)` now calls it, so the shelf and show detail agree
  about what a resume position is **by construction** instead of by two copies of `> 5`. Behaviour
  is identical; the device run proves it (§5: the same recording carries the same words on both
  screens).
- **`isFinished(_:)`** — `duration > 0 && position >= duration - 3`, deliberately `saveResume`'s own
  test. It says nothing about the server's `watched` flag; see §3.4.

**Nothing about the stored format changed.** `Entry` has the same three fields, `save` and `clear`
are byte-identical, and an entry written by the build now on the bedroom Apple TV is read
unchanged.

### 3.2 `RecordingsScreen.swift` — the model

- **`ContinueItem`** — one card: the `Episode`, the `ShowSummary` it belongs to, and the `Entry`.
  Its `line` is the card's second line: `"S6 E17 · 40 min in"`, or `"<episode title> · 12 min in"`
  when the recording has no season/episode, or just `"12 min in"` when it has neither. (Hitler's
  DNA is S0 E0 with an empty episode title on this server, so the third branch is live — see §5.)
- **`RecordingsModel.continueWatching: [ContinueItem]`**, filled by `loadContinueWatching()` at the
  end of the existing `load()`. So it is refreshed by **both** of `load()`'s callers — the screen's
  `.task` and Pass 31's post-write re-read — and by nothing else.
- The resolver: take `ResumeStore.saved()`, keep the entries that are resumable and not finished,
  and if there are none **return without making a single request**. Otherwise walk the distinct
  shows `GET /api/library` answered with, read each with the existing
  `GET /api/library/shows/{id}`, and claim any episode whose id is wanted, **stopping the moment
  the last one is claimed**. Sort by `savedAt`, newest first.
- A show read that fails is logged and skipped; the shelf is shorter, not broken.
- A recording that is **trashed**, or whose show is past `limit: 6`, is never found and so never
  drawn — the shelf cannot invent a card.

Measured cost on the device, from the server's own log (§5.3): **1 `GET /api/library` + 4
`GET /api/library/shows/{id}`**, 00:50:58.942 → 00:50:59.013, i.e. **about 70 ms for the whole
screen**. Four, not three, because the last wanted position belongs to the last show walked.

### 3.3 `RecordingsScreen.swift` — the screen

- `serverSections` filters out the section whose **`key`** is `recently-watched`. The match is on
  the key (`Models.swift:335`) and never on the label, which is display text.
- `continueShelf` draws the heading `"Continue watching"` in the **same** `.nocturne(34, .medium)`
  / `Nocturne.text` as a server shelf's heading, the **same** `VStack(spacing: 18)`, the **same**
  horizontal `ScrollView` with `HStack(spacing: 30)` and `.padding(.vertical, 44)` /
  `.padding(.horizontal, 40)`, and the **same `PosterCard`**.
- It is drawn **first**, where the server's `sections[0]` was, then the two remaining server
  shelves in the server's order.
- Select sets `selected = item.show` — the same destination a server shelf's card has, so show
  detail is reached unchanged and then offers its own Resume line from the same store.
- **Step 4:** `if !model.continueWatching.isEmpty { continueShelf }`. With no cards there is no
  heading, no "Nothing yet." line and no empty row; the `VStack`'s 22 pt spacing simply closes up
  and "Recently Updated" is the first thing under the header.
- `firstCardID` prefers the first Continue watching card, so `defaultFocus` lands there; `cardIDs`
  includes the shelf's ids and **excludes** the undrawn `recently-watched` section's, so Pass 31's
  focus repair can never decide that focus is on a card that is not on screen.
- `PosterCard` gained two parameters **with defaults** — `subtitle: String? = nil` and
  `badge: Bool = true`. Called as before, it draws exactly as Pass 47 left it: same
  252×344 → 296×404 box, same 22 pt lift, same ring, same shadow, same 26 pt / 23 pt type. The
  Continue watching cards pass `subtitle:` (a recording has no episode count) and `badge: false`
  (a "n new" count belongs to a show).

### 3.4 The one judgement call inside step 3, and why it went the way it did

**"Not finished" is decided by this Apple TV's store, not by the server's `watched` flag.** A card
appears when an entry exists, clears `position > 5`, and is not inside the last three seconds. It
does **not** consult `Episode.watched`.

The reason is that `watched` is a **server** flag, shared with the other Apple TV — the Recordings
header says so in as many words — whereas the shelf the owner asked for is per Apple TV. Filtering
on `watched` would mean the *other* Apple TV finishing a recording emptied this one's shelf, which
is the opposite of what the pass asks for.

This is live on the device right now and is worth the owner's eye: **History's Greatest Mysteries
S4 E14 is `watched: true` on the server** (Pass 40 played it to its end) **and still carries a
15-minute position on Home Theater** (Pass 42's runs, and his own since). It is on the shelf. If he
would rather a server-watched recording dropped off, that is a one-line change and §7 carries it as
an open question.

---

## 4. The one thing that went wrong, and what it was

**The first device run failed one assertion — and the screen was right, the harness was wrong.**

The harness asserted that show detail's Resume line was among `app.staticTexts`. It is not: the
Resume line is a **`Button`** (`ShowDetailScreen.swift:176-182`), and a tvOS button's own text is
not exposed as a separate static text. "Play newest" and "Series pass" were missing from that same
dump for the same reason, which is what identified it. No diagnosis by guesswork was needed — the
screenshot the harness had already taken shows **`Resume S6 E17 · 40 min in`** drawn on the
screen, matching the card's `S6 E17 · 40 min in` exactly.

The assertion was moved to `app.buttons` and the run repeated: **TEST SUCCEEDED**. That is
**two device runs in this pass**, disclosed here; the second made no server write either, and the
two runs' screenshots are **byte-identical** (`md5 54c34042…` and `bda0b364…` for the two PNGs),
so the screens did not move between them. The committed harness is the one that passed.

---

## 5. Step 6 — the verification, on Home Theater

### 5.1 The run

```
xcodebuild -project "Marlin DVR TV.xcodeproj" -scheme "Marlin DVR TV" \
  -destination 'platform=tvOS,name=Home Theater' -allowProvisioningUpdates \
  -derivedDataPath build/p91 test -only-testing:"Marlin DVR TVUITests/ContinueWatchingUITests"
```

`build/p91` is git-ignored (`.gitignore:4:build/`). The passing bundle is
`build/p91/Logs/Test/Test-Marlin DVR TV-2026.09.16_00-50-42--0400.xcresult`.
**TEST SUCCEEDED, 26.574 s**, 2026-09-16 00:50:42–00:51:15. Home Theater now runs this build.

`ContinueWatchingUITests` is an **evidence harness, not a standing test**: it needs the physical
Apple TV, the real remote, and at least one unfinished saved position in that Apple TV's own
`UserDefaults` — a simulator has none and would draw no shelf at all. **It makes no server write**;
§5.3 proves that from the server's side.

### 5.2 The transcript

```
[pass91 00:50:57.778] Home focus is Guide; walking to Recordings
[pass91 00:51:04.056] shelves: ["Recordings", "4 shows · 12 recordings",
  "Watched and keep flags are shared with the other Apple TV",
  "Continue watching", "Recently Updated", "Recently Added",
  "The Proof Is Out There", "S6 E17 · 40 min in",
  "The Proof Is Out There", "S6 E16 · 14 min in",
  "History's Greatest Mysteries", "S4 E14 · 15 min in",
  "History's Greatest Mysteries", "S7 E20 · 1 min in",
  "Hitler's DNA", "12 min in",
  "4 new", "The Proof Is Out There", "4 episodes", … ]
[pass91 00:51:04.520] focus: The Proof Is Out There, S6 E17 · 40 min in
[pass91 00:51:04.808] saved positions on the shelf: ["S6 E17 · 40 min in", "S6 E16 · 14 min in",
  "S4 E14 · 15 min in", "S7 E20 · 1 min in", "12 min in"]
[pass91 00:51:04.907] selecting The Proof Is Out There, S6 E17 · 40 min in
[pass91 00:51:10.096] show detail buttons: [… "Resume S6 E17 · 40 min in", "Play newest",
  "Series pass", …]
[pass91 00:51:13.879] back on the shelves, focus is The Proof Is Out There, S6 E17 · 40 min in
** TEST SUCCEEDED **
```

What that shows, assertion by assertion:

1. **"Continue watching" is drawn** and **"Recently Watched" is nowhere on the screen** — the
   string is absent from the whole dump, while "Recently Updated" and "Recently Added" are both
   present.
2. **It is in the first shelf's place** — its index precedes both of theirs.
3. **Every card carries a position**, five of them.
4. **Focus opens on the first card**, so the shelf really is the first shelf.
5. **Selecting it reaches show detail**, whose Resume line reads the same entry in the same words.
6. **Menu returns to the shelves** with focus on the same card.

### 5.3 What the run asked the server for, and what it wrote

From `GET /api/logs`, seq 7357–7469 across both runs (113 new lines). **Every non-GET line in the
whole window is the app's own launch ping:**

```
7362 00:48:57.164 INFO HTTP POST /api/clients/<redacted>/ping 200
7416 00:50:49.352 INFO HTTP POST /api/clients/<redacted>/ping 200
```

No `PUT`, no `DELETE`, no `PATCH`, nothing to `/api/library`, `/api/schedule`, `/api/passes`,
`/api/play` or the trash. Nothing was played, deleted, trashed, kept or scheduled, and no
`GET /api/settings` was read.

The passing run's reads for the Recordings screen:

```
7423 00:50:58.942 GET /api/library                                    200
7424 00:50:58.969 GET /api/library/shows/history-s-greatest-mysteries 200
7432 00:50:58.998 GET /api/library/shows/the-proof-is-out-there       200
7434 00:50:59.007 GET /api/library/shows/the-food-that-built-america  200
7435 00:50:59.013 GET /api/library/shows/hitler-s-dna                 200
```

— the library read the screen always made, plus one show read each for the four shows it answered
with, in ~70 ms. (`7442` is show detail's own read, which the screen already made before this
pass.)

### 5.4 The five recordings, their saved positions, and that each is unfinished

The position column is `ResumeStore`'s own value as the card rendered it
(`ResumeStore.label(for:)`). The length column is the server's, read with `GET
/api/library/shows/{id}` on 2026-09-16 — the app's own `Entry.duration` is not drawn anywhere, so
the server's length is the independent yardstick.

| # | Recording | id | Saved position | Recording length | Unfinished? |
|---|---|---|---|---|---|
| 1 | The Proof Is Out There **S6 E17** "First UFO Film, Alien Mummy…" | `ef4d2419605d` | **40 min in** | 1 hr 10 min | **yes** — 57 % in, 30 min left |
| 2 | The Proof Is Out There **S6 E16** "Hellfire Vs. UFO…" | `dd5f3e4a6778` | **14 min in** | 1 hr 11 min | **yes** — 20 % in |
| 3 | History's Greatest Mysteries **S4 E14** "Who Is D.B. Cooper?" | `5328bb632e76` | **15 min in** | 43 min | **yes** — 35 % in (`watched: true` server-side; see §3.4) |
| 4 | History's Greatest Mysteries **S7 E20** "The Hunt for Osama bin Laden…" | `cac7c08639ec` | **1 min in** | 8 min | **yes** — 13 % in |
| 5 | **Hitler's DNA** (S0 E0, no episode title on this server) | `d9a4f5c76696` | **12 min in** | 1 hr 42 min | **yes** — 12 % in |

Not one is within three seconds of its end, so none is finished by `isFinished`, and none had been
cleared, so none was played to its end on this Apple TV.

**And the other seven recordings do not appear.** The library holds **12** recordings in 4 shows;
five carry a position and five cards are drawn. The Proof Is Out There S6 E19 and S6 E18 are on the
screen's other shelves and **not** on Continue watching, and The Food That Built America's five
recordings put no card on it at all. That is "a recording with no saved position never appears",
observed rather than reasoned.

### 5.5 The two screenshots — `reports/assets/pass91/`

Exported with `xcrun xcresulttool export attachments` from the passing bundle, then converted from
3840 × 2160 PNG to 1920 × 1080 JPEG with `sips -Z 1920 -s format jpeg`, so 1 px is 1 pt.

| Screenshot | What it shows, as viewed |
|---|---|
| **`91a-recordings-continue-watching.jpg`** | The Recordings screen. Header "Recordings · 4 shows · 12 recordings". **"Continue watching"** is the first shelf, with the five cards left to right in the table's order; the first, *The Proof Is Out There* **S6 E17 · 40 min in**, is focused — grown box, 22 pt lift, accent ring. No card carries a "n new" badge. **"Recently Updated"** is the next heading down and its cards do carry their badges ("4 new", "5 new", "1 new", "1 new"). **There is no "Recently Watched" heading anywhere on the screen.** |
| **`91b-show-detail-for-the-first-card.jpg`** | Show detail for that card — *The Proof Is Out There*, "4 episodes · 4 unwatched · 7.96 GB · 9001 HISTORY" — with the primary button reading **"Resume S6 E17 · 40 min in"**, the same entry in the same words as the card. "Play newest" and "Series pass" beside it, the episode list on the right with S6 E17's and S6 E16's own resume bars under their thumbnails. Nothing on this screen was changed by this pass. |

### 5.6 What is run-verified and what is code-traced

| Claim | Status |
|---|---|
| The shelf is drawn, titled "Continue watching", first, with cards | **RUN** — Home Theater, `91a` |
| The server's "Recently Watched" shelf is not drawn | **RUN** — absent from `91a` and from the text dump |
| Only recordings with a saved position appear; the other 7 of 12 do not | **RUN** — §5.4 |
| Each listed recording is unfinished | **RUN** for the positions and the lengths; the comparison is §5.4's arithmetic |
| Selecting a card opens show detail, and show detail is unchanged | **RUN** — `91b` |
| Focus opens on the first card and returns to it | **RUN** |
| The card geometry is Pass 47's | **TRACED** — the same `PosterCard`, with the geometry lines untouched in the diff; the focused card in `91a` is visibly the grown, lifted, ringed one |
| **Newest position first** | **TRACED** — `sorted { $0.entry.savedAt > $1.entry.savedAt }`. `savedAt` is not drawn anywhere and a test process cannot open the app's `UserDefaults`, so the order on screen was not independently confirmed against the timestamps. It is consistent with the owner's viewing (S6 E17 is what he was last in). |
| An empty shelf is not drawn at all | **TRACED** — `if !model.continueWatching.isEmpty`. Home Theater has five positions, so the empty case could not be exercised without clearing his positions, which was not authorised and was not done. |
| A trashed recording, or one whose show is past `limit: 6`, does not appear | **TRACED** — it is simply never matched |
| Pass 31's re-read after a Keep/Delete still fires, and now refreshes this shelf too | **TRACED** — `loadContinueWatching()` is inside `load()`, which `reloadShelves()` calls. No write was made in this pass, by design |
| The other shelves, the click-and-hold Keep/Delete and the Player are unchanged | **TRACED** — outside the diff; `git diff` touches two files and neither is show detail, the menu or the Player |
| The bedroom Apple TV | **NOT TOUCHED** — it still runs `168d8a7` and will show its **own** positions when the owner installs this |

---

## 6. Files touched, by step number

| File | Step | What | Pushed? |
|---|---|---|---|
| `Marlin DVR TV/ResumeStore.swift` | 2, 3 | `saved()`, `isResumable`, `isFinished`; `latest(among:)` now calls `isResumable`. **No change to the stored format** | local |
| `Marlin DVR TV/RecordingsScreen.swift` | 3, 4, 5 | `ContinueItem`; `continueWatching` + `loadContinueWatching()` + `distinctShows`; `serverSections`, `continueShelf`, the empty-shelf guard, `firstCardID`, `cardIDs`; `PosterCard`'s two defaulted parameters | local |
| `Marlin DVR TVUITests/ContinueWatchingUITests.swift` | 6 | new — the evidence harness | local |
| `reports/assets/pass91/91a-recordings-continue-watching.jpg` | 6 | new — the shelf with its cards | local |
| `reports/assets/pass91/91b-show-detail-for-the-first-card.jpg` | 6 | new — show detail for the first of them | local |
| `reports/2026-09-16-pass91-continue-watching.md` | 6 | new — this report | local |
| `DECISIONS.md` | 6 | the 2026-09-16 (Pass 91) entry | local |
| `COLD-START.md` | 6 | "Next step", and the Recordings line under "What is built" | local |

**Nothing was pushed.** One commit on `main`, a fast-forward from `92a4770`; nothing forced,
rebased or amended. Not touched at all: `design/`, `~/Xcode/marlin-dvr-reference`, the Player,
`ShowDetailScreen.swift`, `EpisodeActionsMenu.swift`, the bedroom Apple TV, and the server beyond
GETs.

---

## 7. Open questions

1. **Should a recording the server calls `watched` drop off the shelf?** It does not today (§3.4),
   and *History's Greatest Mysteries* S4 E14 is on the shelf in exactly that state. The argument for
   leaving it is that `watched` is shared with the other Apple TV and the shelf is not. The argument
   against is that he may have finished it there and not want it back. **One line in
   `loadContinueWatching`**, and his call.
2. **The shelf is not re-read after a playback.** It is built when the screen opens and again after
   a Keep or Delete (Pass 31's path). Play something from show detail, press Menu twice, and the
   shelf is the one read on the way in. This is **exactly the staleness the server's "Recently
   Watched" shelf had** — the Player is a `fullScreenCover` over the screen
   (`ContentView.swift:53`) and does not end the screen's `.task` — so nothing regressed, but the
   new shelf makes it more noticeable, because it is the shelf a playback changes. Leaving
   Recordings and coming back rebuilds it (`ScreenShell`'s `.id(current)`). Not built: scope lock.
3. **Step 4 was read as applying to the new shelf only.** A server section that comes back empty
   still draws its "Nothing yet." line (`RecordingsScreen.swift:108-112`, untouched), because step 5
   says the other shelves do not change. If he meant the rule for every shelf, that is a separate
   small change.
4. **The `> 5 s` bar.** A recording opened and abandoned inside five seconds gets no card, because
   `ResumeStore` has drawn that line since Pass 7 for frame 5d's Resume button and the shelf now
   shares it. It is the store's existing rule, not a new one, but it is a rule, and he should know
   it is there.
5. **`limit: 6`.** The shelf can only find a position on a show that `GET /api/library?limit=6`
   answered with. His library is 4 shows, so nothing is out of reach today; with a large library a
   position on an older show would go undrawn. Raising the limit, or a per-recording server read,
   would fix it — the second is a server change and is **not** being raised.
6. **Four show reads per screen open.** Cheap here (~70 ms, §5.3) and skipped entirely when there
   are no positions, but it scales with the library, not with the number of positions. If that ever
   matters, the fix is server-side and belongs to marlin-dvr.

---

## 8. What I am least sure of

- **The order.** "Newest position first" is one `sorted` on `savedAt` and I could not watch the
  timestamps — nothing draws them and a UI test process cannot open the app's `UserDefaults`. The
  five cards came out in an order consistent with his viewing, which is suggestive, not proof.
  Everything else on the shelf was read off the television.
- **The empty shelf.** Step 4's behaviour is a one-line `if` and I am confident in it, but it was
  **not** exercised: doing so would have meant clearing his saved positions, which nobody
  authorised. It is the one behaviour in this pass that the owner will see before I do.
- **Whether "Continue watching" should be per recording at all.** The pass says recordings, and
  recordings is what it lists — so two cards for the same show sit side by side when two of its
  episodes are half-watched, which is what §5's first two cards are. It reads fine on the
  television, but it is the sort of thing that looks different when it is your own library, and
  collapsing it to one card per show would be a real decision, not a tweak.
- **`isFinished`'s three seconds.** It matches `saveResume` deliberately, but the only path that can
  produce an entry it rejects is `restart(at:)`, and no such entry existed on the device, so that
  branch is traced and not run.

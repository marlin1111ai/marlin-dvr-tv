# Pass 26 — Guide-data recon, for the marlin-dvr server project — 2026-09-07

**Verdict up front: deploy server Pass 41. This app is not affected — it already draws true
start/end times and already draws gaps as gaps, because it reads `block.program` and ignores the
rounded `span` entirely.** The one thing that would break it is not a time change at all; it is a
*field* change, and §4 names exactly which fields must survive.

Read-only pass. Nothing under `Marlin DVR TV/` was modified, no server call was made, and the
reference clone and `HLS-CLIENT-API.md` were read and never edited.

**Citation keys.** `File.swift:NN` = line NN of that file at `74afa40` (Pass 25). `guide.go:NN`,
`stream.go:NN` = the read-only reference clone `~/Xcode/marlin-dvr-reference` at `9325d94`.
**That clone is at server Pass 26 and does not contain Pass 41** — see §4's precondition.

---

## 1. Does the app gate live playback on guide data? **No. Nothing gates it.**

**A live session is created from the channel id alone.** The body is `kind`, `id`, `format`,
`client`, `start` — no programme, no guide field of any sort:

```
PlaybackSession.swift:41-51   struct CreateBody { let kind, id, format, client: …; let start: Double }
                              CreateBody(kind: request.kind, id: request.targetID, …)
PlayRequest.swift:36-41       case .live(let channel, _): return channel.id
```

`PlayRequest.live` carries `program: Program?` — **optional** (`PlayRequest.swift:13`), and the
program is used only for the Player's subtitle string, which returns `""` when it is nil
(`PlayRequest.swift:60-63`). Nothing reads it on the path to the session.

**There are exactly four places that start a live channel, and only two of them need a programme:**

| # | Entry point | Needs a programme? | Evidence |
|---|---|---|---|
| 1 | Guide, clicking a cell | **yes** — a cell *is* a programme | `GuideScreen.swift:212-219` |
| 2 | Airing sheet, "Watch live" | **yes**, and only while it is on | `AiringSheet.swift:217`, `:66-69` |
| 3 | On Now card | no — `item.program` is optional and passed through | `OnNowScreen.swift:146` |
| 4 | **Favorites row** | **no** | `FavoritesScreen.swift:118` |

**Favorites is the answer to "could a broadcasting channel with a guide hole be unwatchable".**
It cannot, if the channel is a favourite. The screen lists **every** favourite channel from
`GET /api/channels` and joins the guide read on top best-effort:

```
FavoritesScreen.swift:39      channels = all.filter(\.favorite)          // the channel list, not the guide
FavoritesScreen.swift:40-45   do { onNow = … } catch { onNow = [:] }     // the guide read cannot fail the screen
FavoritesScreen.swift:116-124 ForEach(model.channels) { … onPlay(.live(channel: channel,
                                                       program: model.onNow[channel.id]?.program)) }
```

There is no filter and no `.disabled` on that row — the six `.disabled(` in the whole app are all
modal/overlay guards (`GuideScreen.swift:274`, `OnNowScreen.swift:160`, `ShowDetailScreen.swift:103`,
`ScheduleManageView.swift:141`, `PassesManageView.swift:94`, `TrashManageView.swift:98`), none of
them about guide data. The screen's own header comment has said so since Pass 10:

> `FavoritesScreen.swift:11-12` — "The guide read is best-effort: a favourite with no listing still
> appears, just without a programme line."

**Where a guide hole *is* felt, and it is a reachability limit, not a playback gate.** For a
**non-favourite** channel sitting in a hole there is currently no way to reach it in this app:

- the **Guide** offers only programme cells; a plain click on the left-hand channel cell is wired
  to an empty action and does nothing (`GuideScreen.swift:450-456` — "A plain click is not in
  Pass 9's steps and does nothing", Pass 9 Open Question 1);
- **On Now** never lists it, because the server only emits an item when a programme covers `now`
  (`guide.go:740-746` — the loop `break`s on a match and adds nothing otherwise);
- the **airing sheet** cannot be opened without a programme to open it on.

That is a pre-existing gap in this app's navigation and **Pass 41 does not create it or worsen it**
— it is the same today. Making it worse is impossible; making it better would need a channel list
that plays, which does not exist here. Raised as Open Question 1.

**The server does not gate live playback on guide data either**, which closes the loop:

```
stream.go:214-218   x.Title = fmt.Sprintf("ch%s %s", ch.Number, ch.Name)
                    if now := a.onNow(ch); now != nil { x.Sub = now.Title }
```

A missing programme leaves the subtitle empty and the session proceeds. The only live refusals on
that path are DRM (403) and a bad channel input (400).

---

## 2. Does the app read the guide route? **Yes — three routes, six call sites, and it reads only true times.**

### 2.1 Every call site

| # | Route | Called from | What it takes from the answer |
|---|---|---|---|
| 1 | `GET /api/guide` | `GuideScreen.swift:111` (`ChannelFilter.swift:50-58`) | `start`, `slots`, `channels[].blocks[].program` |
| 2 | `GET /api/guide` | `OnNowScreen.swift:100` — the click-and-hold "next 6 hours" | `blocks[].program`, and `guide.start` for one label |
| 3 | `GET /api/guide/now` | `OnNowScreen.swift:87` (`ChannelFilter.swift:41-47`) | the item list: `program`, `title`, `endsIn`, `art` |
| 4 | `GET /api/guide/now` | `FavoritesScreen.swift:37` | the same, joined by channel id |
| 5 | `GET /api/guide/now` | `HomeView.swift:37` | **`items.count` only** — the tile reads "N programs live" |
| 6 | `GET /api/guide/later` | `OnLaterScreen.swift` (`ChannelFilter.swift:61-63`) | the server's own pre-formatted `when` string |

### 2.2 What it assumes about the times — the important part

**The app never reads `span`, and never reads `empty`.** Grepping the whole app for `block.` returns
exactly two lines, and both read `block.program` and nothing else:

```
GuideScreen.swift:137   guard let p = block.program, p.end > windowStart, p.start < windowEnd, …
OnNowScreen.swift:105   if let p = block.program, !seen.contains(p.start) {
```

`GuideBlock.span`, `.empty`, `.isLive`, `.title`, `.subtitle` and `.channelId` are decoded
(`Models.swift:93-101`) and **used nowhere**. The half-hour rounding lives entirely in `span`
(`guide.go:699` — `span := int((pe - cursor + 1799) / 1800)`), while the embedded programme is the
real one with the real XMLTV times (`guide.go:704` — `pp := p; … Program: &pp`, and
`guide.go:20-21` — `Start int64 \`json:"start"\` // unix seconds`). **So the app is already reading
the unrounded times that Pass 41 is about to start showing everywhere else.**

**Three half-hour assumptions do exist. All three are about the app's own column grid, not about
programme times, and none of them is what Pass 41 changes:**

1. `GuideModel.slotSeconds = 1800` and `fetchEnd = g.start + g.slots * 1800`
   (`GuideScreen.swift:66, :116`) — assumes one `slot` is 30 minutes, which is how the server builds
   `timeSlots` (`guide.go:667-670`). Only used to decide whether a page is already fetched.
2. `windowStart = TimeFormat.currentHalfHour` (`GuideScreen.swift:93`, `Formatting.swift:65` —
   `Int(now / 1800) * 1800`) and the four column labels `windowStart + i*1800`
   (`GuideScreen.swift:85`) — the app's own 2-hour, four-column window. The server truncates the
   `start` it is given the same way (`guide.go:659-663`), so the two agree.
3. `endOfListings = !rows.contains { $0.blocks.contains { $0.program != nil } }`
   (`GuideScreen.swift:117`) — "+12h" disappears when a whole page has no programme in it. This
   already treats a page of gap blocks as the end, which is exactly what it should do, and Pass 41
   does not change it: the server already emits gap blocks with no programme today
   (`guide.go:686-693`, `:710-712` — `Title: "No listing", Empty: true` and no `Program`).

**Nothing in the app relies on a programme starting or ending on a half hour.** The one place the
change will be *visible* is the "next 6 hours" list, which prints
`TimeFormat.timeRange(p.start, p.end)` (`OnNowScreen.swift:303`) — today those read as clean half
hours because the listings happen to be clean; after Pass 41 they will read as whatever the
broadcaster actually published. That is the change working, not breaking.

`GET /api/guide/later` does no time arithmetic at all: it prints the server's `when`
(`OnLaterScreen.swift:125`), and `LaterItem.start` is decoded and never used.

---

## 3. Our Guide screen: does it round? **No. And a gap draws as a gap.**

**It has never rounded.** The screen's own header has said so since it was built:

> `GuideScreen.swift:6-7` — "Rows are re-laid from each program's start/end, not the server's
> 30-minute `span` blocks (Pass 4 §3.4)."

Each cell's position and width come from the programme's true times as a fraction of the 2-hour
window, clipped to it:

```
GuideScreen.swift:57   var startFraction: CGFloat { CGFloat(max(program.start, windowStart) - windowStart) / CGFloat(windowEnd - windowStart) }
GuideScreen.swift:58   var endFraction:   CGFloat { CGFloat(min(program.end,   windowEnd)   - windowStart) / CGFloat(windowEnd - windowStart) }
GuideScreen.swift:478-483  static func frame(for cell:width:) -> (x: CGFloat, width: CGFloat)
```

**A gap draws as a gap, and cannot be covered by the preceding programme, for two independent
reasons:**

1. `cells(for:)` **skips every block with no programme** — `guard let p = block.program`
   (`GuideScreen.swift:137`). A gap contributes no cell at all.
2. Cells are **absolutely positioned** in a `ZStack(alignment: .topLeading)` with `.offset(x:)`
   (`GuideScreen.swift:458-471`), each sized to its own duration. Nothing stretches to fill, nothing
   flows on from its neighbour, and no cell's width is derived from the next cell's start. A
   programme that ends at 8:28 occupies the row up to 8:28 and the strip from 8:28 to the next
   programme is **empty background**.

So the app is already drawing exactly the picture Pass 41 is being written to produce. If anything,
the app has been right about this while the web UI was not.

**One cosmetic edge worth naming, because true times make it newly reachable.** The cell width has a
floor: `max(right - x, 24)` (`GuideScreen.swift:482`), with a 6 pt inset on each interior side. The
programme strip is **1286 pt** wide — 1920 less the 180 pt collapsed rail, the 56 pt content
clearance, the 300 pt channel column, the 18 pt gap and the 80 pt trailing margin
(`Theme.swift:61-65`, `GuideScreen.swift:240-242`), which matches the device: Pass 24 and Pass 25
both measured the first programme cell starting at x = 554 = 180+56+300+18. At 1286 pt for 7200 s,
**a programme shorter than about 3½ minutes** (`(end-start)/7200 × 1286 < 36`) hits the 24 pt floor
and can overlap the next cell by up to ~24 pt. Half-hour rounding made that impossible; true times
do not. It is a few points of visual overlap on a very short listing — both cells stay separately
focusable and selectable — not a functional fault, and not a reason to hold the deploy.

---

## 4. Verdict

**Safe to deploy server Pass 41 as far as this app is concerned.** The app never asks the guide
whether a channel may be played — a live session is created from the channel id alone
(`PlaybackSession.swift:41-51`), the server likewise treats a missing programme as an empty subtitle
rather than an error (`stream.go:214-218`), and Favorites deliberately lists and plays every
favourite channel whether or not the guide has a listing for it
(`FavoritesScreen.swift:39-45, :116-124`), so a channel that is broadcasting through a guide hole
stays watchable. On the display side the app is already doing what Pass 41 is meant to make the web
UI do: it reads `block.program`'s real start and end and ignores the half-hour `span` and the
`empty` flag completely — the only two lines in the app that touch a block read `block.program`
(`GuideScreen.swift:137`, `OnNowScreen.swift:105`) — and it lays every cell out by true time in an
absolutely-positioned row, so a listings gap already renders as empty space rather than being
swallowed by the programme before it (`GuideScreen.swift:57-58, :458-483`). Times becoming truthful
is therefore invisible to this app in the Guide and a small improvement in the "next 6 hours" list;
the only two things it changes anywhere are cosmetic, and both are noted above rather than hidden:
programmes under roughly three and a half minutes can overlap the next cell by a couple of dozen
points because of a 24 pt minimum cell width, and the app's own four column headings stay on the
half hour, which is correct — they are a ruler, not a claim about the listings.

**The one precondition, and it is not about times.** The reference clone available here is at server
Pass 26 (`9325d94`) and does not contain Pass 41, so this pass read the app completely and the
server as it stands, not the change itself. This app's decoder requires these guide fields to be
**present**, and will fail the whole screen with a decoding error if any is dropped or renamed —
even though it never uses most of them:

- `GuideBlock` (`Models.swift:93-101`): **`title`, `subtitle`, `span`, `isLive`, `channelId`** are
  required and non-optional; `program` and `empty` are the only optional ones. **Removing `span` or
  `empty`'s siblings as part of "showing gaps as gaps" would break the Guide screen outright**, so
  if Pass 41 restructures blocks rather than only recomputing them, say so and this app needs a
  one-line change per field.
- `GuideResponse` (`Models.swift:124-132`): `start`, `slots`, `timeSlots`, `channels`, `nowIndex`,
  `dayLabel`, `channelCount` — all required. `GuideTimeSlot`: `label`, `start`.
- `Program` (`Models.swift:43-63`): `channel`, `start`, `end`, `title` required; everything else
  optional.
- `GuideNowItem` (`Models.swift:66-85`): `title`, `endsIn`, `art` required; `program` optional.

Keep those keys and Pass 41 needs nothing from this app. Change their shape and this app wants a
pass of its own first.

---

## 5. Open Questions

1. **A non-favourite channel sitting in a guide hole cannot be reached in this app** (§1). Not
   caused by Pass 41 and true today, but it is the app-side half of the defect the server pass is
   fixing: the Guide's channel cell has an empty click action (`GuideScreen.swift:450-456`), so
   there is no "play this channel regardless of listings" anywhere except Favorites. Wiring a plain
   click on the channel cell to play live would close it, and is Pass 9's Open Question 1 still
   open. Not done here — read-only pass.
2. **Should the Guide draw something in a gap?** Today a hole is empty background with nothing
   focusable in it. The server sends `title: "No listing"` on those blocks and the app throws it
   away. Once Pass 41 makes real gaps common, an inert "No listing" cell might read better than a
   blank strip — but it is a design question and the approved design has no frame for it.
3. **The 24 pt minimum cell width** (§3) is the one place true times can look wrong. Worth a look
   once real unrounded listings are on the server; it needs a device screenshot of a very short
   programme, which does not exist yet.
4. **The reference clone is 15 server passes stale** (Pass 26 vs Pass 41). Nothing in this report
   depends on the missing passes except the field-shape precondition in §4, which is stated rather
   than assumed. Refreshing the clone would let a future pass check the contract instead of asking.

---

## 6. SCOPE CHECK

| File | What happened to it |
|---|---|
| `Marlin DVR TV/**` (`GuideScreen`, `OnNowScreen`, `FavoritesScreen`, `OnLaterScreen`, `HomeView`, `Models`, `ChannelFilter`, `ServerAPI`, `PlayRequest`, `PlaybackSession`, `PlayerModel`, `AiringSheet`, `Formatting`, `Theme`) | **read only** |
| `~/Xcode/marlin-dvr-reference` (`cmd/marlin-dvr/guide.go`, `stream.go`, `HLS-CLIENT-API.md`) | **read only** — never edited, never pushed, never run |
| `reports/2026-09-07-pass26-guide-recon.md` | **new** — this report |

**No app source was changed, no commit touches app code, and no server request was made** — the
server was read from the local reference clone only. Nothing on 192.168.1.250, 192.168.1.245,
192.168.1.105 or the UNAS4Pro share was contacted, and nothing in `design/` was read or written.

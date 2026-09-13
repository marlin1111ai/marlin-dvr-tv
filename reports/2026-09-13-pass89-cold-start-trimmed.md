# Pass 89 — COLD-START.md cut to current state

**Date:** 2026-09-13

**Notebook only. No app-target code changed.** This pass writes three files — `COLD-START.md`
(rewritten to current state), `COLD-START-HISTORY.md` (new, the moved history) and this report — in
one commit. `DECISIONS.md`'s existing entries are untouched, and no `DECISIONS.md` entry was added:
the brief names two notebook files and this report, and nothing here is a decision. `design/`,
`~/Xcode/marlin-dvr-reference`, `reports/*` and every app-target file were not touched, and no
request was made to the server.

**Pass number.** The highest-numbered report in `reports/` before this pass is **pass88**, so this is
**Pass 89**.

**The headline.** `COLD-START.md` goes from **1641 lines to 185**. Every one of the 1,607 lines
below its "How to build" section is either kept verbatim in place, or moved byte-for-byte into
`COLD-START-HISTORY.md` (1,529 lines), except one blank separator line — and the moved blocks were
diffed against the original and the diffs are empty (§V1–V2). The new "What is built" is 68 lines,
one per screen and one per standing fact, each citing its pass; every cited pass number and every
cited harness name was checked to exist in the history file (§V4).

---

## VERIFY — the evidence the brief asks to be shown

### V0. Step 1 — the gate, before anything was changed

```
$ git fetch origin
$ git status --porcelain
?? icon-source/
$ git rev-parse main origin/main
0d6effffd56f26e178582ea093799fc9024c4d29
0d6effffd56f26e178582ea093799fc9024c4d29
$ git ls-remote origin main
0d6effffd56f26e178582ea093799fc9024c4d29	refs/heads/main
$ wc -l COLD-START.md DECISIONS.md
    1641 COLD-START.md
    1692 DECISIONS.md
```

**All three read `0d6efff`.** The stop condition did not arise. The committed file was snapshotted
with `git show HEAD:COLD-START.md` and `cmp` confirmed the working copy was identical to it, so every
line range below refers to that snapshot.

### V1. Line counts and `git diff --stat`

```
$ wc -l COLD-START.md COLD-START-HISTORY.md
     185 COLD-START.md
    1529 COLD-START-HISTORY.md
    1714 total
$ git diff --stat
 COLD-START.md | 1588 +++------------------------------------------------------
 1 file changed, 66 insertions(+), 1522 deletions(-)
```

(`COLD-START-HISTORY.md` is a new file and does not appear in `git diff --stat` until staged.)

### V2. The moved blocks diffed against their original text — both diffs empty

The original file's section map, from `grep -n "^## \|^### "` on the snapshot:

```
35:## What is built            … 1198 (blank line before the next heading)
1199:## What is NOT built
1214:## Raised for the marlin-dvr project — recorded here, not acted on
1264:## Open questions
1268:## Next step               1270–1279 the newest paragraph (Pass 88); 1281–1641 everything after it
```

```
=== VERIFY 1: moved 'What is built' block (orig 35-1198) vs HISTORY lines 3-1166 — diff must be empty
$ diff <(sed -n '35,1198p' orig) <(sed -n '3,1166p' COLD-START-HISTORY.md)
EMPTY DIFF: What is built block byte-identical (1164 lines)

=== VERIFY 2: moved superseded Next step block (orig 1281-1641) vs HISTORY lines 1169-1529 — diff must be empty
$ diff <(sed -n '1281,1641p' orig) <(sed -n '1169,1529p' COLD-START-HISTORY.md)
EMPTY DIFF: Next step history block byte-identical (361 lines)
```

**Both blocks were produced by `sed -n` line-range extraction from the snapshot, never retyped**, so
they are byte-identical by construction; the diffs above are the proof rather than the method.

The history file's only text of its own is two lines: line 1, the one-sentence header the brief asks
for, and line 1167, a label over the moved "Next step" paragraphs (their original `## Next step`
heading stays in `COLD-START.md` over the kept paragraph):

```
$ sed -n '1,2p;1167,1168p' COLD-START-HISTORY.md | cat -v
This file is history moved out of `COLD-START.md` by Pass 89 (2026-09-13), byte-for-byte and in original order — the whole pass-by-pass "What is built" narrative and every superseded "Next step" paragraph — and `COLD-START.md` is the current state; nothing here was rewritten, summarised or corrected.

## Next step — the superseded paragraphs (the newest is in `COLD-START.md`)

```

### V3. The kept-verbatim sections diffed against the original — all diffs empty

```
=== VERIFY 4: kept-verbatim sections in new COLD-START.md vs orig
$ diff <(sed -n '1,34p' orig) <(sed -n '1,34p' COLD-START.md)
EMPTY DIFF: lines 1-34 (title, What the app is, Where things live, The rules, How to build)
new file: What is NOT built at 103, Next step at 172
$ diff <(sed -n '1199,1267p' orig) <(sed -n '103,171p' COLD-START.md)
EMPTY DIFF: What is NOT built + Raised + Open questions verbatim
$ diff <(sed -n '1268,1279p' orig) <(sed -n '172,183p' COLD-START.md)
EMPTY DIFF: Next step heading + newest paragraph verbatim
```

**Accounting for every original line** (orig 35–1641 is 1,607 lines): 1,164 moved as block A, 81
kept verbatim (1199–1279), 361 moved as block B — 1,606. **The one line not carried is orig 1280, a
blank line** between the newest "Next step" paragraph and the first superseded one; in the new file
that position is taken by the blank before the pointer line.

**A second, whole-file check on the history file**, sorted line-multisets rather than ranges — every
line of `COLD-START-HISTORY.md` other than its two added text lines, against the two old blocks
together — differs by exactly two blank lines, which are the blanks placed after the header sentence
and after the label:

```
$ diff <(sort COLD-START-HISTORY.md | grep -v -x -F "<line 1>" | grep -v -x -F "<line 1167>") \
       <(git show HEAD:COLD-START.md | sed -n '35,1198p;1281,1641p' | sort)
177,178d176
<
<
$ grep -c '^$' COLD-START-HISTORY.md ; git show HEAD:COLD-START.md | sed -n '35,1198p;1281,1641p' | grep -c '^$'
178
176
```

### V4. Every pass number and harness name cited in the new "What is built" exists in the history file

A script extracted every `Pass N` / `Passes N, M` / `Passes N–M` (ranges expanded) and every
`passNN` report filename from the new section, and the same from the whole of
`COLD-START-HISTORY.md`, then compared the sets:

```
pass numbers cited in the new What is built: [5, 6, 7, 8, 9, 10, 13, 14, 15, 16, 19, 20, 22, 25, 26,
  28, 29, 31, 32, 33, 34, 38, 39, 41, 42, 44, 47, 49, 51, 52, 53, 54, 55, 56, 60, 62, 63, 64, 65, 68,
  71, 72, 73, 74, 75, 76, 77, 78, 79, 80, 81, 82, 83, 85, 86, 87, 89]
cited but NOT found as a pass number anywhere in COLD-START-HISTORY.md: NONE
sanity: 88 in history? False | 89 in history? True
RemoteHoldUITests: in history = True          ManageDVRUITests: in history = True
RailManageUITests: in history = True          RadioUITests: in history = True
HomeRadioCountUITests: in history = True      WeatherKitEnabledUITests: in history = True
RailFocusRestoreUITests: in history = True    DeleteRefreshUITests: in history = True
StopRecordingUITests: in history = True       TrashRestoreUITests: in history = True
CommercialSkipUITests: in history = True      GuideCollectionsUITests: in history = True
GuideRightEdgeUITests: in history = True      OnLaterPillsUITests: in history = True
GuideChannelLogosUITests: in history = True
lines naming COLD-START-HISTORY.md in the new COLD-START.md: 1
new What is built section: 68 lines
```

- **Pass 88 is deliberately not cited.** Its only text in the old file is the newest "Next step"
  paragraph, which stays in `COLD-START.md` rather than moving to history, so a citation of it could
  not be traced to a history line. The bedroom install is therefore cited to Passes 54 and 83, and the
  capability list says "which build each runs is in 'Next step' below".
- **Pass 89 passes the check only because of the history file's own header sentence**, which names
  it; the one line that cites it says the harness run commands moved with the "Next step" paragraphs,
  which is this pass's own act.
- **`GuideSearchUITests` and `WeatherRadarUITests` exist in the test target but are named nowhere in
  the old `COLD-START.md`**, so they are not listed. They are in their passes' reports.

---

## 1. Steps 2–3 — what moved and what was written

- **`COLD-START-HISTORY.md`** (new): the header sentence; then the whole `## What is built` body,
  heading included, orig lines 35–1198; then the label line; then orig lines 1281–1641 — every
  superseded "Next step" paragraph, the "three named defects" block, "Waiting to be picked up", the
  Pass 41 open questions, "7.7's files", "Standing candidates", and every harness run command that
  sat among them. **In original order, byte-for-byte.**
- **`COLD-START.md`** (rewritten): orig 1–34 verbatim; the new `## What is built` (68 lines, §2 of
  this report describes it); orig 1199–1267 verbatim (`What is NOT built`, `Raised for the marlin-dvr
  project`, `Open questions`); orig 1268–1279 verbatim (`## Next step` and the Pass 88 paragraph);
  then the one pointer line:

  > The pass-by-pass narrative that was "What is built", and every superseded "Next step" paragraph
  > — with the harness run commands that sat among them — are in `COLD-START-HISTORY.md`, moved
  > there byte-for-byte by Pass 89.

  **Where the pointer sits, and why.** The kept Pass 88 paragraph ends *"The paragraph below,
  written by Pass 87, described its own state correctly when written and is kept as history."* That
  sentence is verbatim, as the brief requires, and the paragraph it names is now in the history
  file. Putting the one pointer line directly below it makes "the paragraph below" land on the line
  that says where those paragraphs went. The new "What is built" intro therefore does not name the
  file itself; it says "the pointer is the last line of this file". One line names
  `COLD-START-HISTORY.md`, measured.

## 2. Step 4 — the shape of the new "What is built"

Five sub-headings, every line ending in its pass citation:

| Sub-heading | Lines | What it carries |
|---|---|---|
| The server | 4 | 1.8.2; the three server facts the app depends on; the contract file behind the server; the clone at `eb0c098` |
| Foundation, packaging and the two Apple TVs | 6 | Pass 5's foundation; signing; icon and Top Shelf; both installs and the unchecked profile expiry; no handoff brief; the push-record rule |
| The screens — what each does today | 15 | Home, rail, On Now, Guide, airing sheet, On Later, Recordings and show detail, Cameras, Player, Favorites, Manage DVR, Edit series pass, Weather, Radar, Radio, Search |
| Standing state of the devices and the evidence | 5 | the four deleted recordings; the two authorised ids; the Pass 42 resume position; the harness list; citation drift |
| Known and unfixed — measured, still open | 18 | every still-open item from the three KNOWN AND UNFIXED blocks and the per-pass open questions the narrative recorded |

**Two structural calls, recorded here because the brief's "one line each" and its "drop nothing
that is still true" pulled in different directions:**

1. **The "Known and unfixed" sub-list.** The old file's three `### KNOWN AND UNFIXED` blocks and the
   per-pass open questions are still-true measured state that belongs to no single screen line. They
   are kept as one line each, cited, rather than dropped or folded into screen lines that would then
   be paragraphs. This records; it decides nothing. **Whether the owner wants them here, in
   `DECISIONS.md`, or nowhere is his call** (open question 5).
2. **No "Settings" line.** Every capability line must cite a pass, and Settings' parked state is
   recorded in `What is NOT built` (kept verbatim) and in `DECISIONS.md`, not in the narrative; a
   line here would have had nothing in the history file to cite. `What is NOT built` still says it.

## 3. Step 5 — the resolutions: what the old line said, what the new line says, which was kept

Every place the old file carried a later statement superseding an earlier one. **In every case the
later statement is what `COLD-START.md` now says; the earlier one survives, byte-for-byte, in
`COLD-START-HISTORY.md`.**

| # | The old (earlier) line said | The later line says | Kept |
|---|---|---|---|
| 1 | The server is **1.7.0** (owner install 2026-09-08), then **1.8.0** (owner's Status page), then **1.8.1** (Passes 71, 72) | **1.8.2**, measured from `GET /api/status` (Pass 85) | 1.8.2 |
| 2 | "Three server changes are built and undeployed; **the container still runs 1.4.0**" (Pass 26 corrections) | the server is 1.8.2 | 1.8.2; the 1.4.0 line not carried |
| 3 | The reference clone's `origin/main` read `fba51f2`, then `c417c60`, then `095de81` | `HEAD` = `origin/main` = **`eb0c098`**, 1.8.1 (Pass 72; still so at Pass 85) | `eb0c098` |
| 4 | The radar **"ships as one live frame, not a loop"** (Pass 14) | the radar **animates** by attach-and-detach (Pass 15) | Pass 15 |
| 5 | "**about 2,300 NOAA requests a minute** … unresolved" (Pass 15) | `RadarTileStore`: 53 a minute, ~5 at rest (Pass 16) | Pass 16 |
| 6 | "**WeatherKit is not enabled** for this app's bundle id" (Pass 13) | enabled on the explicit App ID; both screens draw real data (Pass 22) | Pass 22 |
| 7 | "step 1 **found no radar tile source**" (Pass 13) | NOAA MRMS (Pass 14) | Pass 14 |
| 8 | Pass 27's verdict that frame stepping was **unachievable** | overturned by Pass 28: an exact seek steps a frame | Pass 28 |
| 9 | Pass 8 Open Question 11: a show whose last episode is trashed "**stays in the library index with 0 visible episodes**" | overturned: `shows` went 1 → 0, the card disappears outright (Pass 31) | Pass 31 |
| 10 | Pass 31's consequence: a recording trashed as the **last** episode is **invisible in Manage DVR → Trash** | closed by `GET /api/library/trash` (Pass 33) | Pass 33 |
| 11 | Pass 32 item B: "**the server exposed no trash listing**" — STOP AND REPORT | "Superseded — this is history now": 1.6.0 added the endpoint and Pass 33 built on it | Pass 33 |
| 12 | Pass 33: "the per-show `?trash=1` read **no longer returns trashed episodes at all**" | corrected by the marlin-dvr project 2026-09-08: it still does; the cause is `showSummaries(false)` skipping trashed recordings, so the `showId` is undiscoverable | the correction (Pass 34 unchanged) |
| 13 | KNOWN AND UNFIXED after Pass 33, first entry: the airing sheet's series-pass chip is **wrong** for a pass-driven recording | "**CLOSED by Pass 49**" — the first control reports the airing's own state | Pass 49 |
| 14 | The same entry's citation `manualJob :71-74` | it was at `:70-73` when Pass 49 re-read it, and Pass 49 **removed** `manualJob` | removed; no line number carried |
| 15 | "Waiting to be picked up … **the series-pass sheet chip**, since it is a wrong control the owner can press today" (Next step) | closed by Pass 49 | not carried as waiting |
| 16 | KNOWN AND UNFIXED after Pass 38, first entry: **a resumed recording starts well past its resume point** | "**CLOSED by Pass 42**" — a complete MP4 has no live edge to join | Pass 42 |
| 17 | Pass 51's reading that the App Store icon slot is **"1x only"** | corrected by Pass 53 §4.3: the `tv-marketing` slot takes a 2x at 2560×1536 | Pass 53 |
| 18 | Pass 26: the guide-time change is "their **Pass 41**" | corrected 2026-09-07: their **Pass 42**, and it made **no server-side change** | the correction |
| 19 | Pass 39's and Pass 40's reports "**left untracked**" | committed and pushed by Pass 44 in `6fee5b5` | committed |
| 20 | Pass 72: "**The empty-collection state is built and unproven**" | proven on the device by Pass 73 | Pass 73 |
| 21 | Passes 72/73, 77, 79, 82, 86: "**committed locally and NOT pushed**" | pushed after acceptance by Passes 74, 78, 80, 83, 87 | pushed |
| 22 | The bedroom Apple TV runs `0b3589d` (Pass 54), then `070c9a5` (Pass 83) | the kept Pass 88 paragraph: both Apple TVs run `168d8a7` | `168d8a7` (in "Next step") |
| 23 | Pass 54's line-drawn "Nothing is unpushed as of Pass N" chain through Passes 55, 58, 66, 74, 76, 78, 80, 83, 85, 87 | "Nothing is unpushed as of Pass 88" | Pass 88's paragraph |
| 24 | `GuideScreen.swift:21`, `GuideSearchScreen.swift:46`, `:301` and `COLD-START.md:855` cite **`ScreenShell.swift:55`** (or `:51`) for `.id(current)` | it is **`:57`** (Pass 76 list) | `:57` |
| 25 | The Pass 76 citation-drift list gives current `GuideScreen.swift` numbers (`:193-198`, `:182-188`, `:165-167`, `:359-364`) | Pass 79: "the line numbers … for `GuideScreen.swift` have moved" — `:635` where Pass 77 recorded `:528` — and Pass 86 changed the file again | the drift statement; **no `GuideScreen.swift` line numbers are restated**, because computing current ones would be inference (step 4) |
| 26 | `AiringSheet.swift:76`/`:77` cite `Models.swift:170` and `GuideScreen.swift:173-178` | `Models.swift:288` and `GuideScreen.swift:193-198` per Pass 76 — themselves moved since (row 25) | the drift statement only |
| 27 | Pass 13: the Weather screen and Home glance "print that sentence instead of data" | Pass 22: both draw real data | Pass 22 |
| 28 | Pass 20's fallback description and Pass 5's "tiles … present as drawn, inert" for Radio | Pass 19: the Radio entry and tile are live; Pass 20: the tile shows the count | Passes 19, 20 |
| 29 | Pass 82: `GET /api/guide/later` read since sweep 2 (Pass 6's On Later) | Pass 82: no longer read; three pills on `/api/guide` | Pass 82 |
| 30 | Pass 33's `trashedAt` finding appears both under KNOWN AND UNFIXED after Pass 33 and under "Raised for the marlin-dvr project" | the "Raised" section is kept verbatim | once, in "Raised" — not duplicated in the new list |

**Not a supersession, and kept as still open on purpose:** "stepping is erratic near the end of the
prepared range — VERY LIKELY closed by Pass 42, not proven" is not overtaken by any later line; it is
carried as open, in the words the old file used.

## 4. Anything dropped, and why

- **Nothing that is still true was dropped from the notebook.** Everything that left `COLD-START.md`
  is in `COLD-START-HISTORY.md` byte-for-byte, except **one blank separator line** (orig 1280, §V3).
- **Not carried into the current-state file, because superseded:** the thirty earlier statements in
  §3. Each survives in history.
- **Moved rather than dropped, and worth the owner's attention:** the **harness run commands**
  (`xcodebuild … test -only-testing:…` blocks for `RemoteHoldUITests`, `RadioUITests`,
  `HomeRadioCountUITests`, `WeatherKitEnabledUITests`, `RailFocusRestoreUITests`,
  `TrashRestoreUITests`, `CommercialSkipUITests`, `GuideCollectionsUITests`, `OnLaterPillsUITests`,
  `GuideChannelLogosUITests`) sat inside "Next step" and among the "What is built" narrative, so
  they went with them. They are still in each pass's report. Open question 4.
- **Moved rather than dropped, superseded in part:** the "Six open questions from the Pass 41
  report" paragraph and "Waiting to be picked up" — their still-true content is one line each in
  the new "Known and unfixed" list; the closed item (row 15) is not.
- **Not written, because untraceable to history:** anything only `DECISIONS.md` or a report records
  — for example the Pass 86 open questions 2–5, the Pass 88 CPU-usage diagnostic, `GuideSearchUITests`
  and `WeatherRadarUITests`. They were never in `COLD-START.md`, so nothing was lost from it.

## 5. Step 6 — nothing decided

No rule and no decision was changed or restated in different words; the "push-record" line quotes
DECISIONS.md by entry. Two places would have wanted a decision and were **not** given one:

- The dangling *"The paragraph below … is kept as history"* sentence in the kept Pass 88 paragraph
  (open question 1) — left verbatim, resolved by pointer placement rather than by editing.
- The stale sentences inside the verbatim-kept `What is NOT built` (open question 2) — left verbatim.

---

## 6. Files touched, mapped to steps

| Path | Change | Step |
|---|---|---|
| `COLD-START-HISTORY.md` | **created** — header, orig 35–1198, label, orig 1281–1641 | 2 |
| `COLD-START.md` | **rewritten** — 1641 → 185 lines; orig 1–34, 1199–1279 verbatim; new "What is built"; one pointer line | 3, 4, 5 |
| `reports/2026-09-13-pass89-cold-start-trimmed.md` | **created** | report |

**Not touched:** `DECISIONS.md`, `CLAUDE.md`, every file under `reports/` other than this one, every
app-target and test-target file, the Xcode project, `design/`, `~/Xcode/marlin-dvr-reference`,
`icon-source/`, and the server.

## 7. What is pushed, and what stays local

- **Pushed by this pass:** its own commit, a fast-forward from `0d6efff`. The verification — fresh
  `git fetch`, then `git rev-parse main`, `git rev-parse origin/main` and `git ls-remote origin main`
  all matching — runs after the push, so its output and this pass's SHA are in the pass response
  (DECISIONS.md, 2026-09-11 (Pass 68)).
- **Stays local, untracked:** `icon-source/`.
- **Stays local, git-ignored:** `build/`.
- **Outside the repo:** the scratchpad — the HEAD snapshot of the old file, the new-section draft,
  the citation checker.

## 8. Open questions

1. **The kept Pass 88 paragraph's last sentence now points at the pointer line.** *"The paragraph
   below, written by Pass 87, described its own state correctly when written and is kept as
   history"* — the line below is now the one that says where that paragraph went. It reads
   coherently, but it is a dangling reference kept only because rewriting was forbidden. A one-clause
   edit would settle it; the owner's call.
2. **`What is NOT built`, kept verbatim, carries three sentences that later passes overtook:** it
   cites "**KNOWN AND UNFIXED after Pass 33**" (now in the history file); it says the airing sheet
   "shows a wrong 'Record this airing' control" beside Stop for a pass's airing (closed by Pass 49,
   row 13); and it says "Pass 8 Open Question 1" for show detail's inert "Series pass" button, which
   is still true. Editing that section was outside step 3's "keep verbatim". Should a later pass
   bring it current?
3. **`What the app is`** (verbatim) says *"What is built is listed under 'What is built' below"* —
   still true, and now more so.
4. **The harness run commands live only in the history file and in each pass's report.** Should
   `COLD-START.md` get a "How to run the harnesses" section — a current-state fact by any reading —
   or is the per-report copy enough?
5. **The "Known and unfixed" sub-list inside "What is built"** is this pass's structural call (§2).
   If the owner would rather those 18 lines live in `DECISIONS.md`, in a section of their own, or
   nowhere, that is a one-move change.
6. **The history file has no title line**, only the one-sentence header the brief asked for. A
   `# COLD-START-HISTORY — Marlin DVR TV` line would be this project's convention; adding one is
   two seconds and the owner's call.
7. **`Raised for the marlin-dvr project`** (verbatim) and the new "What is built" now say the same
   thing twice in two places — the audio/video desync, and the 1.8.1 library-count change. Not a
   contradiction; a duplication the verbatim rule created.

## 9. The things I am least sure of

1. **That the one-line compressions lost no nuance the owner relies on.** Each screen line stands in
   for between one and ten paragraphs; the pass citations are the safety net, and the full text is
   one file away. If a line reads wrong, the history file has the sentence it came from.
2. **The citation checker's range expansion.** It expands `Passes 62–65` to 62, 63, 64, 65 on both
   sides, so a number cited only inside a range could pass on a range elsewhere. Spot-checked by hand:
   `Pass 63` ("Pass 63 took it") and `Pass 64` ("the Pass 64 probe") both appear literally in the
   history text.
3. **That "one line each" was the right reading for the Guide and Player lines.** They are long —
   the Guide's carries five passes of behaviour — because splitting them would have made one screen
   several lines. If the owner wanted shorter lines and sub-bullets, that is a formatting change, not
   a content one.

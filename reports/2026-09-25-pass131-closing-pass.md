# Pass 131 — closing pass

**Date:** 2026-09-25 (21:24–21:45 EDT)
**Built on:** `d48af196c9c6777dc4ad36039772e439f39df3d3` (Pass 130). **One commit, pushed** as a fast-forward with
this report inside it.

**Result.** The notebook hands over with nothing open, nothing owed and nothing unpushed, both Apple TVs on
Pass 129's code. The bedroom install that followed Pass 130 is recorded; the owner's call of 2026-09-25,
closing eight items (a)–(h) as accepted, is recorded verbatim in its relayed form and added to
`COLD-START.md`'s closed section; the sweep found nothing open outside that call and the call of
2026-09-20, and two facts about this Mac stale against the disk, corrected in place; `COLD-START.md` was
brought current from 362 lines to 234 with 147 lines moved into `COLD-START-HISTORY.md` byte-for-byte; and
3.3 GB of this session's leftovers were deleted.

**What this pass did not do.** It did not touch either Apple TV. It sent **no request of any kind** to the
Marlin DVR server. It changed no app, test or project file, nothing in `design/` or `icon-source/`, and no
existing report. One build was made on this Mac — the simulator build line `COLD-START.md` quotes, to check
the claim beside it — into `build/p131sim`, deleted again in step 5.

---

## 1. Step 1 — the state before anything changed

`git fetch origin`, then `git rev-parse main`, `git rev-parse origin/main` and `git ls-remote origin main`
all read **`d48af196c9c6777dc4ad36039772e439f39df3d3`**. `git status --porcelain` showed only
`?? icon-source/`. **No stop condition.**

---

## 2. Step 2 — the entry

`DECISIONS.md`'s Pass 131 entry records, first, the bedroom install after Pass 130 — built from `d48af19`
by Pass 117's method, `** BUILD SUCCEEDED **` exit 0, `App installed` exit 0, the television reading
Marlin DVR TV 1.0 / build 1, Pass 129's `fetch` strings in the built dylib and first found by `git log -S`
in `1aa17eb`, not launched, both Apple TVs then on Pass 129's code — and then the owner's call of
2026-09-25, "a", relayed by the foreman, closing (a)–(h) as accepted. The entry's wording of the eight is
the prompt's relay, not his words, and says so.

---

## 3. Step 3 — the sweep

### 3.1 Open items, against the two calls

Every open question and least-sure item written since Pass 118, by source:

| Where | Item | Covered by |
|---|---|---|
| Pass 119 report §5 | S13 and the Player's info panel | answered by the owner, "aa" (Pass 120) |
| Pass 120 report | least sure: S1's unnamed case, S15's kept picture, S4's Settings round trip — traced | (h) |
| Pass 122 report | q1 the footer's "forward only" while ahead | built, Pass 123 (d) |
| Pass 122 report | q2 `testScrollThenRailRoundTrip` cannot pass | recorded stale by the owner's 3a (Pass 123) |
| Pass 122 report | least sure: the strip's geometry, swipes, the 7–13 ms blink | (h), and his test of G |
| Pass 123 report | q1 the at-now footer | (c) |
| Pass 123 report | q2 a held Left from one slot ahead | (a) |
| Pass 123 report | q3 the 202-row redraw sets the pace | (b) |
| Pass 123 report | least sure: the focus guide, the physical thumb, the swipe | (h) |
| Pass 125 report | q1 `armResumeSeek` reads its target out of `position` | the call of 2026-09-20 (Pass 98's question) |
| Pass 125 report | q2 the "kept" line never printed | (h) |
| Pass 127 report | q1 the scrub head at 0:00 after an early pause | (d) |
| Pass 127 report | q2 no position readable inside the Player under `launch()` | **a note, not an item** — see below |
| Pass 127 report | q3 `armResumeSeek` | the call of 2026-09-20 |
| Pass 129 report | q1 Menu inside a pick's read goes Home | (e) |
| Pass 129 report | q2 the pick's and the notice's discard traced | (h) |
| Pass 129 report | q3 the server line said 1.11.1 | done, Pass 130 |
| Pass 129 report | q4 the server's log is short | (f) |
| Pass 120 entry | *Hitler's DNA* past the shelves' six | (g) |
| Passes 122–129 entries | "raised, not decided", "not answered by his words" | each one of the above |

**The one note.** The Pass 127 report's open question 2 says that, since Pass 110 removed the recording
HUD, no position can be read inside the Player under `launch()` — Apple's bar can lie — and that a future
harness needing one could add a disclosed print. It asks nothing of the owner and owes no work; it is the
evidence method's limit, recorded. It is taken here as such and not as an open item, and this pass says so
in the entry so the owner can object.

### 3.2 Facts about this Mac and the repo, against the disk

| `COLD-START.md` said | On disk | Result |
|---|---|---|
| the tvOS 26.5 platform component, simulator runtime and device support, is installed (Pass 3) | Xcode 27.0; SDKs `appletvos27.0` and `appletvsimulator27.0`; `xcrun simctl list runtimes` lists **no runtime at all**; both Apple TVs build and install | **stale — corrected** |
| the simulator build line works | run: `** BUILD SUCCEEDED **` against `AppleTVSimulator27.0.sdk` | true; nothing can *run* in a simulator here, said now |
| the evidence-harness list, one per pass | 29 files; the list named 24 — `ResumeRoundTripUITests`, `FrameStepReadyUITests`, `GuideStaleReadUITests` (this session) and `WeatherRadarUITests`, `GuideSearchUITests` (never named) missing | **stale — all five named now** |
| `FocusClick.dataset` stays in `icon-source/` | `icon-source/Assets.xcassets/FocusClick.dataset` | true |
| `~/Xcode/marlin-dvr-reference` no longer exists | absent | true |
| the repo is `git@github.com:marlin1111ai/marlin-dvr-tv.git`, branch `main` | `git remote -v` | true |
| `build/` is git-ignored | `.gitignore:4` | true |
| `design/` holds `Marlin DVR TV.dc.html` and `ATV-DVR.zip` | both present | true |
| the scheme selects no test (S1) | `useTestSelectionWhitelist = "YES"` in the shared scheme | true |
| the provisioning profile expires `2027-09-07T03:40:41Z` | re-read from the bedroom build's `embedded.mobileprovision`, same name | true |
| which build each Apple TV runs | Home Theater Pass 129's (its runs); the bedroom `d48af19`'s app code (the install after Pass 130) | true, and *Next step* now says so |

`icon-source/` holds 10 entries today where Pass 76 counted 32; that count is in reports, not in the brief,
and history is not rewritten.

---

## 4. Step 4 — `COLD-START.md` brought current

| Region | Change |
|---|---|
| *How to build* | the platform sentence corrected: Xcode 27.0, the tvOS 27.0 SDKs, no simulator runtime; the build line still builds, nothing runs in a simulator here; the target/SDK form not re-run |
| *The server* | one current line — 1.11.6, with the standing facts the 1.10.0 and 1.9.1 readings carried (`/api/events`, the Guide alone listening, the `.mp4` sidecar, S10 measured against 1.11.1) — and the 1.11.1 and 1.10.0 lines **moved** to the history file |
| the Guide and Player lines | "an open question" for (e) and (d) now reads closed by the call of 2026-09-25 |
| the evidence-harness line | the five harnesses added; `ManageDVRUITests` and `RailManageUITests` noted as unable to run here today |
| *Closed by the owner's call of 2026-09-20* | one bullet added for the call of 2026-09-25, (a)–(h), each with its pass |
| *Open questions* | **None**, now naming both calls |
| *Next step* | one short current statement with the standing facts; the paragraphs of Passes 130 back to 118 **moved** to the history file |
| the last line | names Pass 131 among the movers |

**Byte-for-byte, checked by the script that moved them:** 143 *Next step* lines and 4 server lines were
removed from `COLD-START.md` and inserted verbatim into `COLD-START-HISTORY.md` — at the top of its *Next
step* section, which runs newest first, under *"Moved here by Pass 131 (2026-09-25), byte-for-byte — the
paragraphs of Passes 130 back to 118"*, and at its end under a heading for the server lines — with a note
under the file's header saying so. Of every line that left `COLD-START.md`, all but nine are in the history
file's insertions unchanged, and the nine are the lines edited in place above. `git diff --numstat`:
`COLD-START-HISTORY.md` **155 insertions, 0 deletions**; `COLD-START.md` 25 insertions, 153 deletions;
362 → 234 lines.

---

## 5. Step 5 — the deletions

```
--- before
222M build/p120      195M build/p121      190M build/p121probe   197M build/p122
191M build/p123      190M build/p123probe 191M build/p125        192M build/p127
191M build/p129      191M build/p129probe 328M build/p131sim
scratchpad: 107 entries, 1.1G
--- after
build/p12*: no matches found
scratchpad: 0 entries
--- kept
~/Library/Developer/Xcode/DerivedData/MarlinDVRTV-bedroom
```

Deleted: the DerivedData of every run and diagnostic of Passes 120–129 under `build/` (git-ignored),
this pass's own `build/p131sim`, and the session scratchpad — the raw consoles, harness and build logs,
result bundles, exported screenshots, the diagnostics' diffs and the `GET /api/logs` reads of Passes
119–130. Kept: the bedroom DerivedData path, every tracked file, and `build/`'s older folders from earlier
sessions, which this pass was not named for.

---

## 6. Git

One commit on `main`: `DECISIONS.md`, `COLD-START.md`, `COLD-START-HISTORY.md` and this report, pushed to
`origin main` as a fast-forward from `d48af19`. The verification — the four files in `git show --stat
HEAD`, the history file's diff insertions only, a clean tree, and the three SHAs equal after a fresh fetch
with `d48af19` an ancestor — is in the pass response, since a commit cannot contain its own SHA.

---

## Open questions

**None.**

## What I am least sure of

1. **The classification of the Pass 127 note** (§3.1). It sits under an "Open questions" heading and asks
   nothing; I have called it a recorded limit rather than an open item, and said so in the entry.
2. **The server line's consolidation.** The 1.10.0 line carried standing facts as well as a superseded
   reading; the facts were restated in the 1.11.6 line and the old line moved whole, so nothing is lost, but
   the restated words are mine and the old ones are in the history file.
3. **That "no tvOS simulator runtime" is the whole story.** `xcrun simctl list runtimes` lists none of any
   platform, which is what the corrected sentence says; whether Xcode would offer to download one on first
   use was not tried, since installs were off limits.

---

## SCOPE CHECK

| File | Step | Change |
|---|---|---|
| `DECISIONS.md` | 2 | the Pass 131 entry |
| `COLD-START.md` | 4 | brought current — §4; 25 insertions, 153 deletions |
| `COLD-START-HISTORY.md` | 4 | the moved paragraphs and server lines, and a header note — 155 insertions, 0 deletions |
| `reports/2026-09-25-pass131-closing-pass.md` | 6 | new — this report |
| `build/p120` … `build/p129probe`, `build/p131sim`, the session scratchpad | 5 | **deleted** (§5) |

**Nothing else was changed.** No app, test or project file, nothing in `design/`, `icon-source/` or
`REVIEW.md`, and no existing report.

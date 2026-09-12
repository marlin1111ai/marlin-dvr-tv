# Pass 78 — the Guide's scroll-right accepted, and Pass 77 pushed

**Date:** 2026-09-12
**Base commit:** `f0613e5` (Pass 77, "the Guide scrolls right").
**Result: the owner accepted the scroll-right on Home Theater and Pass 77 is pushed.**
**No app-target code changed in this pass** — `git diff HEAD --stat` over `Marlin DVR TV/` and
`Marlin DVR TVUITests/` is empty. This pass writes the notebook and this report, and pushes.

**No request of any kind was made to the live server by this pass**, no build, no install, no device
run. `~/Xcode/marlin-dvr-reference` and `design/` were not opened. No credential, token, device id or
client id appears here.

---

## 1. What the owner accepted

**"It all feels good"** (owner, 2026-09-12), tested on Home Theater against the binary Pass 77 built.

Named so a later pass does not have to infer it from the commit:

- **One Right press on the last visible cell of a row moves the window forward one slot (30 min)**,
  with the time strip, every row and the header moving together.
- **Forward only.** `Left`, `Menu`, `↩ Now`, `+12h` and a rail trip all behave as they did.
- **The window stops at the last slot that has a listing**, and a further Right does nothing.
- **The refetch happens on the existing rule** without disturbing the strip, the rows or focus.
- **The focus rule as built:** after a nudge **focus stays on the programme** while that programme is
  still in the window, and goes to the leftmost cell its row still has when it has left. The
  alternative — focus tracking the right-hand edge — was never built, and the acceptance of the ratio
  below means it is not to be revisited on that ground alone.
- **The press ratio, accepted.** Roughly three presses in five move the window, because focus staying
  on the same programme means the slot a nudge reveals often puts a new cell to its right and the next
  press is taken by the focus engine. Measured in Pass 77 at **1.00 slots per press on a long
  programme and 0.60 on half-hour programmes** (48 slots in 78 presses across a full day). **It was
  put to him before he accepted**, and he accepted it as built.

### 1.1 What this closes, and what it does not

**Closes: Pass 77 open question 2**, the press ratio. It is now a recorded, accepted property of the
feature — **not a defect and not an open item.**

**Closes nothing else.** These stay exactly as Pass 77 left them, and are listed rather than re-argued:

| Pass 77 OQ | Still open |
|---|---|
| 1 | The third focus case: a row can have **no** cell at all in the new window (the owner's 2.1 has a listings gap at 11:30 AM), and focus then falls back to `firstCellID` on another row. |
| 3 | Whether a **physical** held Right auto-repeats the move command. Pass 77 measured a synthesized 2-second and 4-second hold each advancing one slot. |
| 4 | The pre-existing header geometry: Up from a grid cell whose x falls between the collections button and the right-hand pills moves focus nowhere, so reaching `↩ Now` from the middle of a row needs a Left first (`WeatherScreen.swift:109-113` records the same shape). |
| 5 | `lastListedSlot` is computed from the current fetch only, so a 24-hour span with no listings on any channel would stop the scroll one fetch short of the true horizon. Unexercised. |
| 6 | The 150 ms settle is latency on every nudge, and a presser faster than ~150 ms would have the second press suppressed as the focus engine's. Not measured with a human hand. |

Also still open and untouched: the four items Passes 72–74 left (the overlay does not scroll,
"Collections unavailable" unproven, the stale-id revert unproven, and whether a collection should reach
`GET /api/guide/now` and `GET /api/channels`).

---

## 2. Step 1 — the pre-push verification, before anything was written

```
$ git rev-parse --abbrev-ref HEAD
main
$ git rev-parse main
f0613e508a1bab81a4309fcdc8b2cd05a16f5a0a
$ git rev-parse origin/main
38067c8327d14be183b8789069c3f6e0a2fd5304
$ git ls-remote origin main
38067c8327d14be183b8789069c3f6e0a2fd5304	refs/heads/main

$ git rev-list --left-right --count origin/main...main
0	1                      ← nothing behind, exactly one ahead

$ git log --oneline origin/main..main
f0613e5 Pass 77: the Guide scrolls right

$ git log --merges origin/main..main --oneline
(empty)

$ git rev-parse f0613e5^
38067c8327d14be183b8789069c3f6e0a2fd5304     ← its parent IS origin/main

$ git merge-base --is-ancestor 38067c8 main  → yes

$ git status --porcelain
?? icon-source/
```

**Exactly one commit ahead, zero behind, zero merges, and `f0613e5`'s parent is `38067c8` — a linear
fast-forward.** The readings were taken **after a `git fetch origin`**, and the local `origin/main`
ref and `git ls-remote` agreed, so the remote had not moved since Pass 77. `icon-source/` is the
standing untracked baseline, 32 entries, the owner's undecided call (`DECISIONS.md`, 2026-09-08).

**What `f0613e5` carries:**

```
 COLD-START.md                                    |  40 ++
 DECISIONS.md                                     |  63 ++
 Marlin DVR TV/GuideScreen.swift                  | 130 +++-
 Marlin DVR TVUITests/GuideRightEdgeUITests.swift | 727 ++++++++++++++++++++++-
 reports/2026-09-12-pass77-guide-scroll-right.md  | 439 ++++++++++++++
 5 files changed, 1394 insertions(+), 5 deletions(-)
```

---

## 3. Files touched, mapped to step numbers

| File | Step | What |
|---|---|---|
| — | **1** | nothing written; the git state was read and confirmed before step 2 began |
| `DECISIONS.md` | **2** | the Pass 78 acceptance entry — **31 insertions, 0 deletions** |
| `COLD-START.md` | **2** | the Pass 78 entry under "What is built", and a new first paragraph under "Next step" naming `f0613e5` and describing this pass's own commit without its SHA — **30 insertions, 0 deletions** |
| `reports/2026-09-12-pass78-scroll-accepted-and-pushed.md` | **3** | this report |
| — | **4** | the push, and the three verifying readings |

**Additions only**, as the step required: `git diff --numstat` shows `30 0` and `31 0`, so no existing
line in either file was rewritten, reworded, moved or removed. The Pass 77 entry's "committed locally
and NOT pushed" clause is **superseded by the new entry rather than edited** — the pattern Pass 74 used
for Passes 72 and 73, and the standing rule that the record is not rewritten to match a later moment
(`DECISIONS.md`, 2026-09-09 (Pass 56)).

**Not touched:** every Swift file in both targets, the Xcode project file, `Info.plist`, the
entitlements file, every build setting, the asset catalog, `design/`, `icon-source/`,
`~/Xcode/marlin-dvr-reference`, and every earlier report.

---

## 4. Git

One commit on `main` on top of `f0613e5`, carrying the two notebook files and this report together, per
the Pass 68 rule that a pass's report goes inside its own commit — then the push of both commits as a
fast-forward.

**This pass's own SHA is not written in this report and cannot be** — a commit cannot contain its own
hash (`DECISIONS.md`, 2026-09-11 (Pass 68); rule (b) of 2026-09-09 (Pass 60)). It is in the Pass 78
response and belongs in the next pass's notebook entry. The three post-push readings
(`git rev-parse main`, `git rev-parse origin/main`, `git ls-remote origin main`), taken after a fresh
`git fetch origin`, are in that response too.

**Nothing forced. No history rewritten. No branch other than `main`.**

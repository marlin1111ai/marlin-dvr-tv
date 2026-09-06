# Pass 11 — Acceptance recorded, Passes 8–10B pushed — 2026-09-06

The owner tested Passes 8, 9, 10 and 10B on Home Theater and accepted them. This pass writes
that into the notebook and pushes the four waiting commits, plus its own, to `origin main`.

**No code changed and no request was sent to the Marlin DVR server.** The only network traffic
was `git push` and `git fetch` / `git ls-remote` against GitHub.

---

## 1. What was recorded

### 1(a) DECISIONS.md — a new `## 2026-09-06 (sweep 4 + fixes)` entry

- Owner acceptance: Passes 8, 9, 10 and 10B tested on Home Theater 2026-09-06 — all accepted.
- The episode menu is **Keep and Delete**; Mark unwatched and the recording Favorite flag are
  dropped.
- A **channel** is favourited by click-and-hold on its cell in the Guide's left column; there
  is no favourite control on the airing sheet.
- **Watch live** appears only while the programme is airing at the current time.
- **Edit series pass** replaces "Record the series" when the show already has one, read from
  `GET /api/passes`; the server's 409 is never shown raw.
- The **Favorites screen** is built; a click plays the channel live.
- **Manage DVR** is built and lives in the bottom slot of the rail (the design's rail has no
  settings-area entry of its own — Settings is a Home tile only).
- **Weather, Radio and Settings stay parked**: present as drawn and inert.

### 1(b) COLD-START.md

- **What is built** — Passes 8, 9 and 10 now read "accepted by the owner on Home Theater and
  pushed in Pass 11" instead of "push gated"; Pass 10B and this pass are described. One
  correction on the way: the Pass 10B paragraph had been written into the *Open questions*
  section by mistake; it now sits with the other passes in *What is built*.
- **What is NOT built** — the parked screens named as parked, the still-inert items kept, and
  a new explicit list of **built but never exercised against the live server**: Restore, Empty
  Trash, and Cancel on a pass's airing, each with the reason it was not run and what does back
  it (Pass 10 §4c and Open Question 3). These were declared in the Pass 10 report; they are now
  in the notebook so no later pass assumes they are proven.
- **Next step** — none assigned; the owner directs. The standing candidates are listed, and the
  commands for the on-device hold tests are kept.

## 2. The commit

`git status --short` before it showed exactly two modified files, `COLD-START.md` and
`DECISIONS.md`, plus this untracked report.

## 3. What was pushed

Five commits, oldest first:

| SHA | What it is |
|---|---|
| `1a2fc97` | Pass 8: sweep 4 — the writes |
| `65a9fa1` | Pass 9: sweep 4 fixes from the owner's Home Theater test |
| `e973e96` | Pass 10: Favorites screen and the Manage DVR area |
| `ee3576d` | Pass 10B: Manage DVR moves from Recordings to the rail |
| `0cd2ac8` | Pass 11: acceptance recorded for sweep 4 and its fixes |

`origin/main` was `331e8c0` (Pass 7D) before the push and `0cd2ac8` after:

```
git push origin main
To github.com:marlin1111ai/marlin-dvr-tv.git
   331e8c0..0cd2ac8  main -> main
```

A normal push; nothing was forced, and no earlier commit was rewritten — `331e8c0` is still an
ancestor of `origin/main`.

## 4. The three-way check

`git fetch origin`, then the three values read back:

```
local HEAD      : 0cd2ac8686ff38c0c9e10764c6593d888f5f62e2
origin/main     : 0cd2ac8686ff38c0c9e10764c6593d888f5f62e2
ls-remote main  : 0cd2ac8686ff38c0c9e10764c6593d888f5f62e2
MATCH
```

`git status -sb` after the fetch: `## main...origin/main` — level with the remote, working
tree clean.

---

## SCOPE CHECK — every file touched

| Path | Step |
|---|---|
| `DECISIONS.md` — the `2026-09-06 (sweep 4 + fixes)` entry: the acceptance and the eight decisions | 1a |
| `COLD-START.md` — "What is built" (including moving the misplaced Pass 10B paragraph into it), "What is NOT built" (parked screens; the three untested-live paths), "Next step" | 1b |
| `reports/2026-09-06-pass11-acceptance-and-push.md` (this file) | deliverable |
| Local commit "Pass 11: acceptance recorded for sweep 4 and its fixes" | 2 |
| `git push origin main` and the three-way verification | 3, 4 |

No source file was touched: the app is byte-for-byte what Pass 10B left. `design/`, the
reference clone, `Info.plist`, the project file and every Swift file are unchanged. No request
was sent to 192.168.1.250, marlinpc, the HDHomeRun or the UNAS4Pro share. Nothing was
installed; no packages.

## Push verification

`0cd2ac8` is the commit that contains this report, so its SHA and the verification block above
were written by a follow-up commit — the convention Pass 4 set, because a report cannot carry
the hash of the commit that includes it. That follow-up touches this file only. It was pushed
and checked the same three ways, and its SHA is the current `origin/main`, stated in the
closing reply.

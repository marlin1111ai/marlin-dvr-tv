# Pass 30 — Passes 28 and 29 pushed, and the notebook caught up — 2026-09-07

The owner tested frame-by-frame on Home Theater and accepted it: stepping works and the 10-second
accumulation is gone. This pass pushed the two commits and brought the notebook up to date from
Pass 26 onward. **No code was changed** — the only files touched are `COLD-START.md`,
`DECISIONS.md` and this report.

---

## 1. The push, verified

Both commits went up as a **fast-forward**. Nothing was forced, rebased or amended.

```
before:  local HEAD   26f7e2bc227a731cb77b5ee49daafb6ccbc0e3f0
         origin/main  a7208588b91c7928a9f6565315d4894c237a7376
         fast-forward YES

push:    a720858..26f7e2b  main -> main
```

After `git fetch`, all three readings agree:

| | |
|---|---|
| `git rev-parse HEAD` | `26f7e2bc227a731cb77b5ee49daafb6ccbc0e3f0` |
| `git rev-parse origin/main` | `26f7e2bc227a731cb77b5ee49daafb6ccbc0e3f0` |
| `git ls-remote origin refs/heads/main` | `26f7e2bc227a731cb77b5ee49daafb6ccbc0e3f0` |

**All three match.** Both accepted commits are on `origin/main` — `58ebb12` (Pass 28, the exact
seek and the click binding) and `26f7e2b` (Pass 29, the recognizer ownership) — and `a720858`, the
tip before this push, is still an ancestor, so nothing in the history was rewritten.

The notebook commit made by this pass was pushed the same way and verified the same way; §5 has
its readings.

---

## 2. What went into COLD-START.md

Four passes were missing. They are now recorded between Pass 25 and "What is NOT built":

- **Pass 26** — the guide-data recon done for the marlin-dvr project: nothing in this app gates
  live playback on guide data, the app never reads `span` or `empty`, and the Guide screen has
  never rounded, so a listings gap already draws as a gap. The precondition given to the server
  project was about **field shape, not times**.
- **Pass 26's corrections**, received from the marlin-dvr project on 2026-09-07 and recorded in the
  notebook **rather than by editing the landed report**: the change is their **Pass 42, not Pass 41**;
  **Pass 42 made no server-side change at all** (`/api/guide`, the half-hour round-up at
  `guide.go:699` and the `span` values are byte-for-byte unchanged); **our field-shape clearance was
  verified against their repo and stands**; and their **Pass 45** added `GET /api/guide/find`, which
  is purely additive and which **this app does not call**.
- **Pass 27** — `step(byCount:)` is inert on this app's HLS recordings. The measurement stands; the
  verdict was overturned by Pass 28, and the Pass 27 report already carries an addendum saying so.
- **Passes 28 and 29** — frame-by-frame by exact seek (`currentTime() ± 1/fps`, zero tolerance),
  left/right **clicks** only, only while paused on a recording, with `AVPlayerViewController`'s own
  arrow gesture recognizers disabled while the app owns the arrow and restored otherwise. Accepted
  on Home Theater, with the measured per-click distances.

**A new "KNOWN AND UNFIXED after Pass 29" section** was added so no later pass mistakes any of these
for proven behaviour or spends a device run re-deriving them:

1. **Stepping is erratic near the end of the prepared range** — measured at 1:05:27 of a 1:11:10
   recording, clock moving backwards, counts 6/21/30 instead of a flat 30. **Not Apple**: the
   counters read `arrows=134 super=0 owns=true supp=2`. Suspect is the seek-past-the-prepared-range
   restart at `PlayerModel.swift:382`. Pass 28 Open Question 3, unfixed, wants its own pass.
2. **The recognizer-disabling fix depends on `AVPlayerViewController`'s internals** and **fails
   open** — back to Apple's skip and the old defect, not a crash — if a future tvOS changes them.
3. **Live playback was never driven on the device** across Passes 28–29; unchanged by diff, and
   `frameStep` bails when the item is not a recording.
4. **Nobody has diffed two stills** to prove the picture advances one frame of motion rather than
   the clock alone.

The stale **Next step** block, which still said Pass 25 was awaiting a test and Pass 22 was the last
accepted pass, now says what is actually true: Passes 28 and 29 are accepted and pushed, nothing is
committed locally and unpushed, and the end-of-range defect is the one thing waiting to be picked up.

---

## 3. What went into DECISIONS.md

A new **2026-09-07 (frame-by-frame)** section, recording the owner's decisions rather than the
implementation:

- **Frame-by-frame is recordings only; live is explicitly out.**
- **Clicks step; swipes keep their fixed skips** — the discrete press is the precise tool, matching
  the owner's earlier DVR app. While playing, left and right stay Apple's skip.
- **The step API is ruled out in favour of exact seeks** — `step(byCount:)` measured inert, and a
  frame is a seek to `currentTime() ± 1/fps` with both tolerances `.zero`.
- **The app takes the arrow from `AVPlayerViewController` while paused on a recording and gives it
  straight back otherwise**, with the note that this is a knowing dependency on another framework's
  internals that fails open, and that the transport bar itself is not suppressed.
- **The owner's acceptance of Passes 28 and 29**, the two commit SHAs, and the fast-forward push.
- A pointer to the **KNOWN AND UNFIXED** list in COLD-START.md.

---

## 4. SCOPE CHECK — every file touched

| File | What happened to it | Step |
|---|---|---|
| — (git) | `58ebb12` and `26f7e2b` **pushed** to `origin main`, fast-forward, verified three ways | 1 |
| `COLD-START.md` | **modified** — Passes 26–29, the Pass 26 corrections, the KNOWN AND UNFIXED section, and a corrected Next step | 2, 3 |
| `DECISIONS.md` | **modified** — the 2026-09-07 (frame-by-frame) decisions and the acceptance | 4 |
| `reports/2026-09-07-pass30-push-notebook.md` | **new** — this report | deliverable |

**Not one line of code was changed in this pass**: nothing under `Marlin DVR TV/` or
`Marlin DVR TVUITests/` was modified, created or deleted, and no build or device run was needed.
No work was done on the end-of-range defect. Nothing in `design/`, the reference clone, or on any
host outside this folder was read or written; the landed Pass 26 report was **not** edited — its
corrections live in the notebook.

---

## 5. The notebook push, verified

The notebook commit `604320d` ("Pass 30: push Passes 28 and 29, and catch the notebook up") went up
as a fast-forward from `26f7e2b`. After `git fetch`:

| | |
|---|---|
| `git rev-parse HEAD` | `604320d7076357a450d2192ab4ef882a76bff517` |
| `git rev-parse origin/main` | `604320d7076357a450d2192ab4ef882a76bff517` |
| `git ls-remote origin refs/heads/main` | `604320d7076357a450d2192ab4ef882a76bff517` |

**All three match.** `a720858`, `58ebb12` and `26f7e2b` are all still ancestors, so nothing was
rewritten, and the working tree is clean. The only files in that commit are `COLD-START.md`,
`DECISIONS.md` and this report — confirmed with `git diff --name-only 26f7e2b..604320d`, which lists
those three and nothing else.

This section was appended after `604320d` was pushed, because it records that push; it therefore
lands as a small follow-up commit of its own, and that commit is the new tip of `origin main`.

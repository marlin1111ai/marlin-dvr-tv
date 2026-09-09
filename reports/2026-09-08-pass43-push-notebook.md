# Pass 43 — Pass 42 accepted, recorded in the notebook, and pushed

**Date:** 2026-09-08
**Documentation and git only. No Swift source file was touched** — the code that ships is exactly
what the owner tested at `137f1de`. No build, no test, no device run, and **no request of any kind
to `192.168.1.250:8090`**. The reference clone was not read, fetched or otherwise touched. `design/`
was not touched. `reports/2026-09-08-pass40-session-start-values.md` was not opened, staged,
committed or amended.

**The acceptance this pass records:** the owner tested Pass 42 on Home Theater on 2026-09-08 and
reported that everything works and **the LIVE badge is no longer there**. That closes the one claim
only he could settle, and it opened the push gate.

---

## 1. The starting state, read-only — four raw outputs

Each run as its own command, in `~/Xcode/Marlin DVR TV`. Nothing was changed at this step.

```
$ git rev-parse HEAD
787f01e9daa99b2b022403bfb81f30208851ab63
```

```
$ git rev-parse origin/main
b11f4c62a7b1853d5d8ada0cf34c63f79d3d07e4
```

```
$ git ls-remote origin main
b11f4c62a7b1853d5d8ada0cf34c63f79d3d07e4	refs/heads/main
```

```
$ git status --porcelain
?? reports/2026-09-08-pass39-three-defects-recon.md
?? reports/2026-09-08-pass40-session-start-values.md
```

**Every expectation in the brief matched**, so the pass proceeded. `HEAD` is `787f01e`;
`origin/main` and the remote both read `b11f4c6`; no tracked file was modified; the only untracked
files are the two pre-existing report files.

The two-commit lead was confirmed to be a plain fast-forward before anything was written:

```
$ git rev-list --left-right --count origin/main...HEAD
0	2

$ git log --oneline origin/main..HEAD
787f01e Pass 42: record the build commit SHA in the report
137f1de Pass 42: recordings play as one seekable MP4 (steps 1-6; step 7 blocked)
```

`0` behind, `2` ahead — nothing to rebase, nothing to merge, nothing to force.

---

## 2. What was written into COLD-START.md

Five edits, all inside sections that already existed. Line numbers below are from the file as it now
stands.

**2.1 — the route is built and accepted** (the "What is built" narrative, after the Pass 38 entry).
A new **Pass 42** entry records what the route does, that recordings use it while live TV, cameras
and radio keep HLS, and the one line that chooses it — **`PlayRequest.swift:49`**, reaching the wire
at **`PlaybackSession.swift:70`**. It also records the `format` check
(`PlayerModel.swift:176-181`, called at `:135` and `:765`), the `Range: bytes=0-0` first fetch on
its own session (`PlaybackSession.swift:114-128`, `:24`, `:37`, `:50-54`), the device evidence, and
that steps 1–6 were built while step 7 was not. Short entries for Passes 39, 40 and 41 were added
ahead of it so the numbering does not jump, including the fact that the Pass 39 report file is
untracked (`git ls-files reports/ | grep -c pass39` → `0`, verified in Pass 41).

**2.2 — the server version.** The "What is built" header block now opens **"The server is marlin-dvr
1.8.0" (owner, 2026-09-08)**, citing his own Status-page reading of **VERSION 1.8.0, "up to date ·
checked 45m ago"**, and saying plainly that it was **not measured from here** because the running
server is on the do-not-touch list — the same form the file already uses for the marlin-dvr
project's other version facts. The 1.7.0 in-place update at 00:06 is kept as the previous state. The
single-file route is added to the list of things this app depends on.

**2.3 — their contract is behind their server.** A new paragraph in the same block records that
`HLS-CLIENT-API.md` is **byte-unchanged across the whole 1.8.0 delivery**
(`git diff --stat c417c60 095de81 -- HLS-CLIENT-API.md` returned nothing, Pass 41), still declares
itself **1.7.0**, and that its §2 table at **line 68** states the opposite of the new behaviour —
`"file"` appears nowhere in it. It names **§2.3 of the Pass 41 report as the only written
description of this route we have**, read from their Go source, and states that anyone building
against the contract file alone will be wrong about this route. The stale `c417c60` reference for
the clone's `origin/main` was updated to `095de81` in the same paragraph, since the byte-unchanged
claim rests on those two refs.

**2.4 — the entries this closes, edited in place.**

- **KNOWN AND UNFIXED after Pass 38** — the resume-overshoot entry is rewritten as **"CLOSED by
  Pass 42"**, keeping the original `start=1680` → 1988 s measurement as the record of what the HLS
  route did. The entry that depended on it ("a playback that starts inside a break offers it") is
  marked **still unproved**, because Pass 42 did not attempt it.
- **KNOWN AND UNFIXED after Pass 29** — the erratic end-of-range stepping entry is rewritten as
  **"VERY LIKELY closed by Pass 42, not proven"**: its named suspect cannot fire on a complete file
  because the guard requires `!fullyPrepared`, but the suspect was always a suspect, nobody has
  watched the same spot since, and if the real cause was something else Pass 42 changed nothing.
- **The LIVE badge and the fast-forward wait** live in the "Next step" section, where the owner's
  three named defects were listed. Both are now recorded as **CLOSED**, the badge on the owner's
  own 2026-09-08 confirmation.

**2.5 — what the route costs**, recorded as facts in the Pass 42 entry: the remux wait moves to the
front of playback and **has never been measured on the Unraid box** (the marlin-dvr project's
2.4 s / 11 s / 26 s figures are marlinpc, and their own report says they do not hold for Unraid); a
still-recording recording and a non-H.264/AAC recording are each **refused outright with a 502**
rather than played, neither exercised on the device; and nothing on screen distinguishes the wait
from a stall.

**2.6 — the desync.** Recorded in the same entry as **untouched by any of this and still open with
the marlin-dvr project**, with Pass 39's NOT OURS sorting, and that no client-side compensation has
ever been built or is to be.

**2.7 — the state of the record.** The two Pass 42 device runs left a resume position deep inside
the owner's *History's Greatest Mysteries* S4 E14 recording (1206 s → past 1484 s, plus 40 forward
skips), it is per-Apple-TV, playing to the end clears it, and
`CommercialSkipUITests/testPromptAppearsAndSelectSkips` will keep failing until it is — all four of
that recording's breaks end at 1478.54 s.

**2.8 — "Next step" rewritten.** It no longer claims the previous push state. It now records that
the owner accepted Pass 42 and Pass 43 pushed it, with **the dated, verified push check from §5**
rather than a standing SHA, in the same form the file already used for Pass 35's verification. The
three named defects are re-stated as two closed and one still open, and the **six still-unanswered
Pass 41 open questions** are listed by number.

**No proposal, recommendation or "worth considering" entry was added to either file.**

---

## 3. What was written into DECISIONS.md

One dated entry, **`## 2026-09-08 (Pass 42 — the single-file MP4 playback route)`**, appended in the
form every other entry uses. It records, in order:

**3.1** Recordings use the single-file route; live, cameras and radio keep HLS — with the one line
that decides it and the one line that sends it.

**3.2** That build-plan step 4 offered "fall back to HLS, **or** fail loudly" and picked neither,
that Pass 42's own scope lock banned an HLS fallback unless a step specified one, and that
**fail-loudly was therefore the only option the scope lock permitted** — taken on the scope lock's
authority, not on the builder's preference. Recorded as **a one-branch change if the owner ever
wants the other**, and that **he has not been asked**.

**3.3** That step 5's timeout needed its own `URLSession`, because a configuration's
`timeoutIntervalForRequest` can override a longer per-request one and the shared session's 25 s is
what `create`'s POST depends on — raising it would have changed the POST for live and cameras too.
The 11-minute value is derived from the server's 10-minute ceiling.

**3.4** That **step 7 was not built**: it is conditional on open question 7.2, which is unanswered,
and the builder stopped rather than choosing. No stub was left.

**3.5** The Pass 41 correction, plainly, as a correction to this project's own reporting: Pass 41
§4.3 claimed `start: N` would break `fullyPrepared`, the HUD and the commercial clamp; **that was
wrong**, because the server echoes the same `start` it trims with, so `startOffset` compensates
exactly. The device measurement is quoted — a skip landing at `t=272.538500` with the app reporting
`position 1478.54 s`, the break's exact `endSeconds` — and the conclusion recorded: **7.2 is a
wait-versus-cleanliness trade, not a correctness bug.**

**3.6** Owner acceptance on Home Theater, 2026-09-08, including the LIVE badge confirmed gone — and
that this **resolves the ambiguous `LIVE` string in the Pass 42 harness dump** as stale text from the
screen behind the player rather than a drawn badge, which is what the Pass 42 builder declined to
decide.

Two further facts already established by Pass 42 were included because the entry would misrepresent
the pass without them: that the two server-refused recording types are refused rather than worked
around and neither was exercised, and the disclosed cost of the evidence (the reverted diagnostic
and the resume position).

---

## 4. The commits

Two, both this pass's own:

<!--COMMITS-->

**Neither Pass 42 commit was amended, reworded or rebased.** `137f1de` and `787f01e` went to the
remote exactly as the owner tested them.

---

## 5. The push, and the three verification readings

<!--PUSH_EVIDENCE-->

---

## 6. The six open questions — all still open

None was answered, decided or narrowed in this pass. They are from
`reports/2026-09-08-pass41-single-file-route-recon.md` §7.

| # | Question | State |
|---|---|---|
| **7.2** | `start: 0` or `start: N` for resume | **Open.** Blocks build-plan step 7. Pass 42 added evidence that it is a wait-versus-cleanliness trade, not a correctness bug (DECISIONS 3.5) — but the choice is the owner's and was not made. |
| **7.3** | What the Starting screen should say during a long remux | **Open.** No step has ever named it; nothing on screen distinguishes the wait from a stall. |
| **7.4** | Should a refused recording fall back to HLS, or show the error | **Open.** Fail-loudly is what ships, on the scope lock's authority. The owner has not been asked. |
| **7.5** | Temp space on Unraid | **Open.** Not a client question and untested. |
| **7.6** | Ask the marlin-dvr project to document the route in `HLS-CLIENT-API.md` | **Open.** Their contract is still byte-unchanged and still says 1.7.0. |
| **7.7** | The two untracked report files | **Open.** Both still untracked; neither was staged this pass. |

7.1 was answered by the owner's Status-page reading and is what unblocked Pass 42. 7.8 (whether
`AVPlayerItem` tolerates a long silent connection) was overtaken rather than answered: the app's own
11-minute patience is built, but no long remux has been observed on the device.

---

## 7. Questions raised by this pass

Two, both recorded rather than acted on, because acting on either would have been outside the
numbered steps.

1. **One KNOWN AND UNFIXED entry is now arguably contradicted and was left standing.** "One skip
   landed 1.01 s past `endSeconds` instead of on it" (KNOWN AND UNFIXED after Pass 38) records that
   the two exact landings both came from sessions with `startOffset = 0` and the inexact one from
   `startOffset = 931.000155`. Pass 42's device run landed **exactly** on `endSeconds` from a
   session with `startOffset = 1206.001497533`, which is evidence against that correlation.
   **The entry was not edited**: step 2.4 names only the LIVE badge, the fast-forward wait, the
   resume overshoot and the frame stepping, and the scope lock forbids corrections beyond the
   numbered items. *What breaks without it:* a later pass may chase a correlation that one sample
   now argues against.
2. **`reports/2026-09-08-pass39-three-defects-recon.md` is still untracked**, and COLD-START now
   says so explicitly rather than implying the file was pushed. Committing it was not a numbered
   step here and it is not this pass's file. It remains open question 7.7's other half.

---

## 8. SCOPE CHECK — every file touched

| Path | Access | Required by |
|---|---|---|
| `COLD-START.md` | **modified** | step 2 (2.1–2.8) |
| `DECISIONS.md` | **modified** (one appended dated entry) | step 3 (3.1–3.6) |
| `reports/2026-09-08-pass43-push-notebook.md` | **created** | DELIVERABLE |
| `reports/2026-09-08-pass42-single-file-route.md` | read | required reading |
| `reports/2026-09-08-pass41-single-file-route-recon.md` | read | required reading |
| `reports/2026-09-08-pass40-session-start-values.md` | **not opened, not staged** | named do-not-touch |

**No Swift source file was modified** — `git diff --name-only | grep -c '\.swift$'` returned `0`
before the commit, and the pass's diffstat is `COLD-START.md` and `DECISIONS.md` only.

**Not touched:** every other folder under `~/Xcode`; the reference clone (not read, not fetched);
the Marlin DVR server, its data and its API — **zero requests of any kind**; Unraid, marlinpc, the
HDHomeRun, the UNAS4Pro share; `design/`; the Xcode project, `Info.plist`, the entitlements file,
every build setting; and every file under `Marlin DVR TV/` and `Marlin DVR TVUITests/`.

**No new dependency.** No credential, token, device id or account identifier appears in this report,
in either notebook file, or in any commit message from this pass.

---

## CLOSING SUMMARY FOR THE OWNER

**What is now on the remote.** Everything. The three source files you tested — the ones that put
recordings on the single-file MP4 route — plus the Pass 42 report, plus this pass's notebook work
and this report. It went up as a plain fast-forward: no commit was amended, reworded or rebased, and
nothing was force-pushed. The code on `origin/main` is byte-for-byte the code you approved.

**What the notebook now says about this route.** That recordings play as one complete, seekable MP4
and that live TV, the cameras and radio still use HLS, decided at a single line. That the server is
1.8.0 on your own Status-page reading. That **their contract file does not describe this route at
all** — it is byte-unchanged across the whole 1.8.0 release and still says 1.7.0, so our own Pass 41
report is the only written description of it that exists, and anyone trusting the contract file will
be wrong. Two of your three named defects are recorded as closed — the LIVE badge on your
confirmation, and the fast-forward wait — and the audio/video desync is recorded as still open and
still with the marlin-dvr project. The resume overshoot is closed. The end-of-range frame stepping
is recorded as **very likely** closed rather than fixed, because its suspect can no longer fire but
was never proven to be the cause. The costs are written down as facts: the wait now happens before
playback starts and has never been timed on your Unraid box, and two kinds of recording — one still
recording, one not H.264/AAC — are refused with an error rather than played.

**What this pass cost.** Two documentation files, 222 lines added and 50 removed, plus this report.
No build, no test, no device run, no server request. The two Pass 42 commits were pushed untouched.

**The three things I am least certain about.**

1. **The two refusals have still never been seen.** A recording that is still being written, and one
   that is not H.264/AAC, should now show a clear error instead of playing. I traced the path but
   never provoked either, because the only recording available was finished and H.264. If either
   behaves worse than "a clear error" you will find it before I do.
2. **How long the wait gets on a big recording.** Nothing has been measured on your Unraid box, and
   the Starting screen looks identical whether the server is working or stuck. If a long recording
   ever seems to hang on "Preparing the recording", that is the thing to tell me — what the screen
   should say during that wait is an open question nobody has answered.
3. **The frame stepping near the end of a recording.** I have recorded it as very likely fixed, and
   I want to be honest that "very likely" is doing real work in that sentence: the thing I suspected
   can no longer happen, but it was only ever a suspect, and nobody has gone back to the same spot
   in the same recording to check.

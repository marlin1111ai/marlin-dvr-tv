# Pass 50 — Pass 49 accepted, recorded in the notebook, and pushed

**Date:** 2026-09-08
**Documentation and git only. No Swift source file was touched** — what ships is exactly what the
owner tested at `d90de63`. No build, no test, no device run, and **no request of any kind to
`192.168.1.250:8090`**. The reference clone was not read, fetched or touched. `design/` was not
edited.

**The acceptance this pass records:** the owner tested Pass 49 on Home Theater on 2026-09-08 and said
it is **all good**. That opened the push gate.

---

## 1. The starting state, read-only — four raw outputs

Each run as its own command, in `~/Xcode/Marlin DVR TV`. Nothing was changed at this step.

```
$ git rev-parse HEAD
9334849bcf4e4345ee8913a4866d11555b996a08
```

```
$ git rev-parse origin/main
61257bcb30ab70fce2a07bf9594aed391eb5f4f4
```

```
$ git ls-remote origin main
61257bcb30ab70fce2a07bf9594aed391eb5f4f4	refs/heads/main
```

```
$ git status --porcelain --untracked-files=all
(no output — clean tree, nothing modified and nothing untracked)
```

**Every expectation in the brief matched**: `origin/main` and the remote both read `61257bc`, and
`HEAD` is two commits ahead. Confirmed a plain fast-forward before anything was written:

```
$ git rev-list --left-right --count origin/main...HEAD
0	2

$ git log --oneline origin/main..HEAD
9334849 Pass 49: record the build commit SHA in the report
d90de63 Pass 49: the airing sheet's first control reports the airing's own state

$ git diff --stat origin/main..HEAD
 Marlin DVR TV/AiringSheet.swift                    |  41 +-
 ...2026-09-08-pass49-airing-sheet-record-button.md | 419 +++++++++++++++++++++
```

0 behind, 2 ahead — nothing to rebase, nothing to merge, nothing to force.

---

## 2. What was written into COLD-START.md

Three edits: one KNOWN AND UNFIXED entry rewritten in place, one new narrative block, one "Next step"
edit.

**2.1 — the KNOWN AND UNFIXED entry is CLOSED, edited in place rather than left standing.** The first
entry under **KNOWN AND UNFIXED after Pass 33** now opens **"CLOSED by Pass 49"** and states what the
defect actually was: **the sheet asked whether a series pass existed instead of asking the airing's
own job what state it was in.** Stop turned on `Job.status == "Recording"` and correctly ignored
`passId`, while the chip and the Record button were gated on `passId == "manual"`, so a pass-driven
job fell through to the Record button while Stop was simultaneously offered. The original
measurement and its history (found in Pass 32, scoped out there and in Pass 33) are kept.
**The drifted citation is recorded**: the entry read `manualJob :71-74`, and the property was in fact
at **`:70-73`** when Pass 49 re-read it.

**2.2 — what was built.** A **Pass 49** entry records the owner's decision in his terms: the control
is **never hidden**, because a series pass covers a *show* and not every airing — if the pass is not
picking an episode up, hiding the button would leave no way to record it. The three states are given
("● Recording", "● Scheduled", "Record this airing"), with the first two marked **not pressable**.
The changed lines are cited from the Pass 49 report: `AiringSheet.swift` `:81` and `:83-88`
(`AiringState`/`airingState`, replacing the removed `manualJob`), `:251-256` (the three-way control)
and `:186` (`firstFocusID`, which had to follow the state or the sheet would open focusing a
`"record"` control that no longer exists). Non-focusability is recorded with its mechanism —
`StateChip` at `:447-475` is a plain `VStack` of `Text`s with no `Button`, no `.focusable()` and no
`.focused()`. That the other three controls and the amber line are **byte-identical** is recorded
too.

**2.3 — the state came from data already held.** Recorded as `Job.status` (`Models.swift:170`), the
same field `recordingJob` (`:79-82`) already used, taken from the `GET /api/schedule` read the sheet
already performs on open (`:154`, for the reason at `:149-153`). **No new request and no new model
field**, `passId` deliberately no longer consulted, and the statuses read exactly as the Guide's own
marks read them (`GuideScreen.swift:173-178`) — with **`GuideScreen.swift` not changed**.

**2.4 — the limit of the evidence, recorded as a limit and not as working.** Only the **unbooked**
case was proven on the device, by the write-free `RemoteHoldUITests` hold, and the notebook says why
that is a real assertion rather than a formality (a job would have rendered a chip instead).
**"Recording" and "Scheduled" are recorded as code-traced only**, with the reason: reaching them
needed either a new harness file or `StopRecordingUITests`, which books and stops a real recording on
the owner's DVR, and the photographed airing had stopped hours earlier. **The owner accepted both
branches by eye on Home Theater on 2026-09-08**, and that is what the notebook says covers them.

**2.5 — two behaviours recorded so they are not later read as defects.** A pass-scheduled airing
shows a **green "● Scheduled"** where the Guide grid shows **gold "◆ SERIES PASS"** — same meaning,
the amber pass line still names the pass, and a gold chip would have been a **fourth** state the
owner did not ask for; raised with him and left as built. And an airing whose recording has
**finished, failed or been stopped** now offers "Record this airing" again — correct by the owner's
rule, since such an airing is neither recording nor scheduled, and beyond the symptom he reported.

**2.6 — the appearance is carried over, not design-specified.** Recorded that `design/` frame 5c
draws its button row at **`dc:568-572`** as three pressable controls and **specifies no status label
of any kind**, so `StateChip` keeps the shape and typography it has had since Pass 8, accepted on
Home Theater in Pass 9.

**2.7 — "Next step".** Its opening now records that the owner accepted Pass 49 and Pass 50 pushed it,
carrying **the dated, verified push check from §5** in the form the file already used, with Pass 47's
acceptance and Pass 48's push kept beneath it.

**No proposal, recommendation or "worth considering" entry was added.**

---

## 3. What was written into DECISIONS.md

**One new dated entry, `## 2026-09-08 (Pass 49 — the airing sheet's first control)`**, appended in
the form the file uses. It now carries four same-day 2026-09-08 entries (Passes 38, 42, 47 and 49),
which is how it records distinct subjects on one date.

**3.1 — the owner's rule, in his own terms.** The control is **never hidden**; it reports the
airing's own state; **"Recording" and "Scheduled" are indicators, not actions** — not focusable and
inert on Select; the other three controls and the amber series-pass line are untouched.
**Hiding it was explicitly rejected, with the reason recorded**: a series pass covers a show, not
every airing, so hiding the button would leave no way to record an episode the pass is not picking
up. Also recorded: this is a **fallback, not the primary signal** — the Guide already shows gold and
green, and the point is that the sheet must not contradict it.

**3.2 — the green-versus-gold difference was raised to the owner and left as built.** Recorded with
the reason: the meaning is identical, the amber line still names the pass, and a gold chip would have
been a fourth state he did not ask for, so it was reported rather than invented.

**3.3 — two implementation decisions.** **`manualJob` was removed, not left as dead code** — it was
the defective predicate, and leaving it would have invited a later pass to reach for the wrong test.
**`firstFocusID` had to follow the state**, or the sheet would have opened trying to focus a
`"record"` control that no longer exists in two of the three cases, leaving focus nowhere.

The disclosed limit of the evidence (§2.4) is recorded in this entry as well, so the decision record
and the state record agree.

---

## 4. The commits

Two, both this pass's own:

<!--COMMITS-->

**Neither Pass 49 commit was amended, reworded or rebased.** `d90de63` and `9334849` went to the
remote exactly as the owner tested them.

---

## 5. The push, and the three verification readings

<!--PUSH_EVIDENCE-->

---

## 6. The six open Pass 41 questions — all still open

None was answered, decided or narrowed in this pass. They are from
`reports/2026-09-08-pass41-single-file-route-recon.md` §7 and are unrelated to the airing sheet.

| # | Question | State |
|---|---|---|
| **7.2** | `start: 0` or `start: N` for resume | **Open.** Still blocks build-plan step 7. |
| **7.3** | What the Starting screen should say during a long remux | **Open.** |
| **7.4** | Should a refused recording fall back to HLS, or show the error | **Open.** Fail-loudly is what ships, on the scope lock's authority; the owner has not been asked. |
| **7.5** | Temp space on Unraid | **Open.** |
| **7.6** | Ask the marlin-dvr project to document the route in `HLS-CLIENT-API.md` | **Open.** |
| **7.7** | The two untracked report files | **Open as a question; its subject is settled** — both committed in Pass 44, notebook corrected in Pass 45. |

---

## 7. Questions raised by this pass

None. Everything the numbered steps asked for was written, and nothing else was found that needed
raising.

The one item this pass was explicitly told to leave alone — the conditional sentence in the Pass 42
block that Pass 48 flagged, about the commercial harness failing until a resume clears — **was left
exactly as it stands**, and is not re-raised here.

---

## 8. SCOPE CHECK — every file touched

| Path | Access | Required by |
|---|---|---|
| `COLD-START.md` | **modified** — one KNOWN AND UNFIXED entry closed in place, one narrative block added, one "Next step" edit | step 2 (2.1–2.7) |
| `DECISIONS.md` | **modified** — one appended dated entry | step 3 (3.1–3.3) |
| `reports/2026-09-08-pass50-push-notebook.md` | **created** | DELIVERABLE |
| `reports/2026-09-08-pass49-airing-sheet-record-button.md` | read | required reading |

**No Swift source file was modified** — `git diff --name-only | grep -c '\.swift$'` returned `0`
before the commit, and the pass's diffstat is `COLD-START.md` and `DECISIONS.md` only.

**Not touched:** every other folder under `~/Xcode`; the reference clone (not read, not fetched); the
Marlin DVR server, its data and its API — **zero requests of any kind**; Unraid, marlinpc, the
HDHomeRun, the UNAS4Pro share; `design/`; the Xcode project, `Info.plist`, the entitlements file,
every build setting; and every file under `Marlin DVR TV/` and `Marlin DVR TVUITests/`.

**No new dependency.** No credential, token, device id or account identifier appears in this report,
in either notebook file, or in any commit message from this pass.

---

## CLOSING SUMMARY FOR THE OWNER

**What is now on the remote.** Everything. The one source file you tested — the airing sheet whose
first control now tells you what the airing is actually doing — plus the Pass 49 report, plus this
pass's notebook work and this report. It went up as a plain fast-forward: no commit amended, reworded
or rebased, and nothing force-pushed. The code on `origin/main` is byte-for-byte the code you
approved.

**What the notebook now records about the fix.** The backlog entry that had been sitting open since
Pass 32 is marked **closed**, with what the defect really was written down plainly: the sheet was
asking whether a *series pass* existed when it should have been asking what *that airing* was doing.
It records your rule — the control is never hidden, because a pass covers a show and not every
airing, so hiding it would leave you unable to record an episode the pass missed — and the three
states it now shows. It records that the two status states are labels rather than buttons and cannot
take focus, that nothing else in the sheet moved, and that the whole thing runs on information the
app already had, with no new call to the server.

**And what it records about the limits of the testing**, because that matters as much: **only the
ordinary case was proven on your Apple TV.** The two new states — "Recording" and "Scheduled" — were
checked by reading the code, not by watching them appear. Reaching them would have meant writing a
new test harness or running one that books and stops a real recording on your DVR, and neither
seemed worth it. Your own eyes on Home Theater are what covers those two, and the notebook says so
rather than implying they were machine-verified.

Two things are written down so nobody later mistakes them for bugs: a pass-scheduled airing shows a
**green** "● Scheduled" where the Guide shows a **gold** "◆ SERIES PASS" — same meaning, and a gold
chip would have been a fourth state you did not ask for — and an airing whose recording has already
finished or been stopped now offers "Record this airing" again, which is right by your rule but is
beyond the symptom you photographed.

**What this pass cost.** Two documentation files, 107 lines added and 9 removed, plus this report. No
build, no test, no device run, no server request, and no code touched.

**The three things I am least certain about.**

1. **The two new states still rest on your eyes, not on a test.** You said it is all good and I have
   recorded that as the acceptance — but if the "Recording" chip ever renders wrongly in some case
   you have not happened to hit yet, nothing in the automated evidence would catch it.
2. **The green-versus-gold difference.** I left it as built and told you rather than guessing. If the
   sheet showing green where the Guide shows gold turns out to read as a contradiction rather than a
   simplification, that is a small change and it is yours to call.
3. **The terminal-state case I changed without being asked.** An airing whose recording finished or
   was stopped now offers to record again. I am confident it follows your rule exactly, but it is the
   part of this change you never reported and therefore never looked for.

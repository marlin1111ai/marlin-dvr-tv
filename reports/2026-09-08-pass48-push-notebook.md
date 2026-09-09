# Pass 48 — Pass 47 accepted, recorded in the notebook, and pushed

**Date:** 2026-09-08
**Documentation and git only. No Swift source file was touched** — what ships is exactly what the
owner tested at `d285d5b`. No build, no test, no device run, and **no request of any kind to
`192.168.1.250:8090`**. The reference clone was not read, fetched or touched. `design/` was not
edited.

**The acceptance this pass records:** the owner tested Pass 47 on Home Theater on 2026-09-08 and
said it is **good to go**. That opened the push gate.

---

## 1. The starting state, read-only — four raw outputs

Each run as its own command, in `~/Xcode/Marlin DVR TV`. Nothing was changed at this step.

```
$ git rev-parse HEAD
405a376813957f816ba4c27ac860ddd3f76e6ad2
```

```
$ git rev-parse origin/main
65ae3726d33fc67312310eb931559a23a6798baf
```

```
$ git ls-remote origin main
65ae3726d33fc67312310eb931559a23a6798baf	refs/heads/main
```

```
$ git status --porcelain --untracked-files=all
(no output — clean tree, nothing modified and nothing untracked)
```

**Every expectation in the brief matched**: `origin/main` and the remote both read `65ae372`, and
`HEAD` is two commits ahead. Confirmed to be a plain fast-forward before anything was written:

```
$ git rev-list --left-right --count origin/main...HEAD
0	2

$ git log --oneline origin/main..HEAD
405a376 Pass 47: record the build commit SHA in the report
d285d5b Pass 47: the focused poster card grows its layout box, not a transform

$ git diff --stat origin/main..HEAD
 Marlin DVR TV/RecordingsScreen.swift         |  19 +-
 reports/2026-09-08-pass47-shelf-focus-fix.md | 329 +++++++++++++++++++++++++++
```

0 behind, 2 ahead — nothing to rebase, nothing to merge, nothing to force.

---

## 2. What was written into COLD-START.md

One new narrative block in the **"What is built"** section, placed after the Pass 42 entry and before
`### KNOWN AND UNFIXED after Pass 38`, plus one edit in **"Next step"**.

**2.1 — the fix, and what was wrong.** A **Pass 46** line records the read-only recon of the owner's
reported defect (a focused poster card's top edge cut off in "Recently Watched"). A **Pass 47** entry
records the fix as accepted on Home Theater 2026-09-08. What was wrong is stated as the recon
established it: `scaleEffect(296.0/252.0, anchor: .center)` is **a render transform that changes no
layout**, so it grew the card about its centre and threw roughly **38 pt upward** on top of the 22 pt
lift — about **60 pt into the 44 pt** that `.padding(.vertical, 44)` (`RecordingsScreen.swift:127`)
provides — and the horizontal `ScrollView` at **`RecordingsScreen.swift:114`**, which clips by
default with `.scrollClipDisabled()` absent from the app, cropped the excess. Only the top suffered
because the `-22` offset pulls the card away from the bottom and does nothing sideways.
**The three changed lines are cited**: `:196` (art `296:252` × `404:344`), `:222` (container width
`296:252`), and the deleted `scaleEffect`. `dc:1273` and `dc:382-383` are cited as the source of the
numbers, and the ring (`dc:1275`), shadow (`dc:1274`) and `-22` lift are recorded as already matching
and unchanged.

**2.2 — the arithmetic that now holds.** `HStack(alignment: .top)` (`:115`) aligns layout tops, so the
bigger box grows downward and the only upward displacement is the lift: **22 pt of overhang against
the 44 pt budget**, clearing by a factor of two. **The card-height term is gone entirely**, so Pass
46's threshold — "it clips whenever the card is taller than 252 pt" — **no longer applies at any card
height**. The bottom's 66 pt of clearance and the sides' inability to overhang are recorded with it.

**2.3 — two accepted behaviours, recorded so nobody later reads them as defects.** The row **reflows
sideways** (the focused box is 44 pt wider), which **the owner was told before choosing** and
accepted; and **the shelves below shift down 60 pt** while a card is focused (the box is 60 pt taller
and `HStack` takes its tallest child), which **the owner was told after Pass 47** and accepted. Both
are noted as `design/`'s own behaviour, `dc:383`.

**2.4 — the text no longer enlarges on focus.** The old `scaleEffect` enlarged the whole card
including its text; `dc:389` fixes the title at 26 px and `dc:390` the count at 23 px **in both
states**, and the app now matches. Recorded as a deliberate consequence of dropping the scale, not an
oversight.

**2.5 — what the device test did and did not establish.** It **did** establish that shelf focus
navigation survives a card whose layout box changes on focus — shelves reached, eight `.left` presses
delivered, focus read as a poster card, `.select` opened its show, the run passed in 128 s against
the binary built in that pass. It did **not** establish traversal across several reflowing cards:
`openShow` reads focus before each `.right` and matched on its first read, so **zero `.right` presses
were sent**. Written into the notebook as **"untested, not known to work"**, not as working.

**2.6 — "Next step".** Its opening now records that the owner accepted Pass 47 and Pass 48 pushed it,
carrying **the dated, verified push check from §5** in the form the file already used for Pass 43's,
and naming Passes 44, 45 and 46's verified pushes (`f167663`, `fd59d35`, `65ae372`) ahead of the
older history it already held.

**No proposal, recommendation or "worth considering" entry was added.**

---

## 3. What was written into DECISIONS.md

**One new dated entry, `## 2026-09-08 (Pass 47 — the Recordings shelf focus clipping)`**, appended in
the form every other entry uses. The file already carries two same-day 2026-09-08 entries (Pass 38
and Pass 42), so a third is how it records a distinct subject on the same date; folding shelf
decisions into the Pass 42 playback-route entry would have conflated two unrelated subjects.

**3.1** — **Option C was the owner's choice** from the three the Pass 46 recon offered, and
**options A (more padding) and B (`.scrollClipDisabled()`) were rejected and built in no form** — not
stubbed, not added as a safety net. Recorded with it: the recon deliberately declined to choose, and
the choice was the owner's.

**3.2** — **`RecordingsScreen.swift:114`'s ScrollView clipping and the `.padding(.vertical, 44)` at
`:127` were left untouched by owner instruction**, verified byte-identical after the change, with
`.scrollClipDisabled()` absent from the app. The fix had to work without either, and does.

**3.3** — **The 60 pt downward shift was not compensated for, and is recorded as an open item the
owner has seen and accepted — explicitly not as a decision to leave it forever.** The reason nothing
was built is stated: every way of absorbing it goes through `:114` or `:127`, the two lines he
instructed be left alone, so acting would have reopened them. It is recorded that if it turns out to
bother him, that is a later decision.

Three further facts already established by Pass 47 were included because the entry would misrepresent
the pass without them: that the `scaleEffect` was removed rather than kept alongside (keeping both
would have reintroduced the defect), that the sideways reflow is an accepted cost, that the title and
count no longer enlarge, and that multi-card traversal is untested.

---

## 4. The commits

Two, both this pass's own:

```
$ git log --oneline -2
a0097b5 Pass 48: Pass 47 accepted on Home Theater, recorded in the notebook
<the second>  Pass 48: record the verified push in the notebook and this report
```

`a0097b5` carries `COLD-START.md`, `DECISIONS.md` and this report — 3 files changed, 351 insertions,
2 deletions, **no Swift source among them**. The second commit records the SHAs below, which cannot
exist inside the commit they name.

**Neither Pass 47 commit was amended, reworded or rebased.** `d285d5b` and `405a376` went to the
remote exactly as the owner tested them.

---

## 5. The push, and the three verification readings

The push was a plain fast-forward. `git push` printed two dots — **not** a `+` and not
"forced update":

```
$ git push origin main
To github.com:marlin1111ai/marlin-dvr-tv.git
   65ae372..a0097b5  main -> main
```

Then `git fetch origin` (exit 0), and the three readings, each as its own command:

```
$ git rev-parse HEAD
a0097b5371dbeddf6c8d98ad2388cc0e295a6477
```

```
$ git rev-parse origin/main
a0097b5371dbeddf6c8d98ad2388cc0e295a6477
```

```
$ git ls-remote origin main
a0097b5371dbeddf6c8d98ad2388cc0e295a6477	refs/heads/main
```

**All three agree**, and the remote was read back rather than trusted from local state.

**What is now on `origin/main`.** Three commits went up together, in order:

| SHA | What |
|---|---|
| `d285d5b` | Pass 47's fix — `RecordingsScreen.swift`, exactly as the owner tested it |
| `405a376` | Pass 47's report recording that build commit's SHA |
| `a0097b5` | This pass's notebook work and this report |

**Nothing was force-pushed. No commit was amended, reworded or rebased**, and neither Pass 47 commit
was altered in any way between the owner's test and the remote.

---

## 6. The six open Pass 41 questions — all still open

None was answered, decided or narrowed in this pass. They are from
`reports/2026-09-08-pass41-single-file-route-recon.md` §7 and are unrelated to the shelf work.

| # | Question | State |
|---|---|---|
| **7.2** | `start: 0` or `start: N` for resume | **Open.** Still blocks build-plan step 7. |
| **7.3** | What the Starting screen should say during a long remux | **Open.** |
| **7.4** | Should a refused recording fall back to HLS, or show the error | **Open.** Fail-loudly is what ships, on the scope lock's authority; the owner has not been asked. |
| **7.5** | Temp space on Unraid | **Open.** |
| **7.6** | Ask the marlin-dvr project to document the route in `HLS-CLIENT-API.md` | **Open.** |
| **7.7** | The two untracked report files | **Open as a question; its subject is settled** — both were committed in Pass 44 and the notebook was corrected in Pass 45. |

---

## 7. Questions raised by this pass

One, recorded rather than acted on.

1. **A sentence about the Pass 38 harness is now overtaken, and I left it alone.** COLD-START's
   Pass 42 block says `CommercialSkipUITests/testPromptAppearsAndSelectSkips` "will keep failing
   until [the D.B. Cooper resume] is cleared". Pass 47's device run of that very test **passed**, with
   playback starting at clock `00:05` — so the resume was cleared at some point after Pass 42.
   The sentence is conditional rather than false, and the new Pass 47 block records that the run
   passed, so a reader can reconcile the two. **It was not edited**: the numbered items do not name
   it and the scope lock forbids corrections beyond them. *What breaks without a change:* very
   little — at worst someone reads the older paragraph alone and expects a failure that will not
   happen.

---

## 8. SCOPE CHECK — every file touched

| Path | Access | Required by |
|---|---|---|
| `COLD-START.md` | **modified** — one narrative block added, one "Next step" edit | step 2 (2.1–2.6) |
| `DECISIONS.md` | **modified** — one appended dated entry | step 3 (3.1–3.3) |
| `reports/2026-09-08-pass48-push-notebook.md` | **created** | DELIVERABLE |
| `reports/2026-09-08-pass47-shelf-focus-fix.md` | read | required reading |
| `reports/2026-09-08-pass46-shelf-focus-clipping-recon.md` | read | required reading |

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

**What is now on the remote.** Everything. The one source file you tested — the poster card that
grows its real size instead of being scaled up — plus the Pass 47 report, plus this pass's notebook
work and this report. It went up as a plain fast-forward: no commit amended, reworded or rebased, and
nothing force-pushed. The code on `origin/main` is byte-for-byte the code you approved.

**What the notebook now records about this fix.** That the card's top was being cut off because it
was enlarged like a photograph rather than actually made bigger — a scale is drawn outside the space
the layout reserves, and the shelf's scroller crops whatever spills out. That the fix takes the two
sizes your design already specifies, 252×344 becoming 296×404, so the only thing sticking up is the
22-point lift the design asks for, against 44 points of room. And that the old "it clips whenever the
card is taller than 252 points" rule is simply gone — the overhang no longer depends on the card's
height at all.

It also records the three things that changed in ways nobody asked for in those words, so they are
never later mistaken for bugs: the row shuffles sideways as focus moves, the shelves below drop
60 points while a card is focused, and the title and episode count no longer grow with the picture.
All three are your design's own behaviour. The 60-point shift is written down as an open item you
have seen and accepted — not as settled forever — along with the reason nothing was done about it:
every way to absorb it goes through the two lines you told me to leave alone.

**What this pass cost.** Two documentation files, 103 lines added and 2 removed, plus this report.
No build, no test, no device run, no server request, and no code touched.

**The three things I am least certain about.**

1. **Multi-card traversal is still untested, and the notebook now says so.** The device run proved
   focus navigation survives a card that changes size, but the harness matched the first card it
   looked at and never pressed right. If moving along a shelf of several cards misbehaves, nothing
   in my evidence would have caught it — you will find it before I do.
2. **Whether the 60-point vertical shift will wear well.** You accepted it, and it clips nothing, but
   it is the kind of thing that can be fine for a minute and irritating after a week. It is recorded
   as reopenable for exactly that reason.
3. **One older paragraph is now overtaken and I left it standing.** It says the Pass 38 commercial
   harness will keep failing until a resume is cleared; that resume has since cleared and the test
   passed in Pass 47. It is not wrong, just stale, and correcting it was outside what this pass was
   asked to touch — so it is a question rather than an edit.

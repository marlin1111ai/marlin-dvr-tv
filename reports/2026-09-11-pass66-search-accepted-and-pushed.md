# Pass 66 — Passes 62-65 accepted and pushed — 2026-09-11

**Result: the owner accepted the Search screen on Home Theater on 2026-09-11 — "all good" — the
notebook records it, and all three outstanding commits are on `origin main`, verified live.**

`origin/main` went from **`49a5672`** (Pass 61, 2026-09-09) to **`b028650`**. Three commits, a
fast-forward, nothing forced, rebased or amended.

Documentation and git only. No source file, asset, project setting, build, install or network
request; the Apple TVs were not touched and neither was the server.

---

## 1. Step 1 — what was outstanding before the push

`git fetch origin`, then three independent readings:

```
local main        d0ff5931a70da4a4b92116925ea423f18ff68d03
origin/main       49a5672a7a7854b407b1f00db257a5c3ecdd2868
ls-remote origin  49a5672a7a7854b407b1f00db257a5c3ecdd2868   refs/heads/main
```

**Both commits present locally and absent from the remote**, checked rather than assumed —
`git cat-file -t` for presence, `git merge-base --is-ancestor <c> origin/main` for absence:

| Commit | Present locally | On `origin/main` |
|---|---|---|
| `1107b12` Pass 63: the guide search screen | yes | **no** |
| `d0ff593` Pass 65: the search screen on .searchable | yes | **no** |

**The chain was linear.** `git log --merges origin/main..main` returned **0**, and each parent is
the commit before it: `d0ff593 → 1107b12 → 49a5672`. `git merge-base --is-ancestor origin/main
main` confirmed a fast-forward was possible.

**Pass 64 has no commit of its own, and that is correct.** It was a read-only probe that required
a clean working tree, so it deleted every probe file and restored `ScreenShell.swift` with
`git checkout` before reporting. Its report was deferred and written in Pass 65, which committed
it in `d0ff593`.

---

## 2. Step 2 — DECISIONS.md

One dated entry, **`## 2026-09-11 (Passes 62-65 — the Search screen)`**, appended at the end:
**65 insertions, 0 deletions.**

Eight bullets, each recording a decision or a measurement rather than a summary: the owner's
acceptance; Search as the eleventh rail entry under Radio with no Home tile; the two reads, with
`/api/guide` rejected for cause (its half-hour rounding drops about 3 % of listings, so search
would have been the only route to an airing and the one route that failed); DRM results filtered
silently; the "first 20 of N" line and that both numbers are the server's own; the query
surviving a trip to the rail and why that forced the model above `ScreenShell`; `.searchable`
over a hand-built `TextField`, with the takeover measured and `UISearchController` named and why
it lost; and the sheet-close focus rebuild, removed and measured to fail before being restored.

---

## 3. Step 3 — COLD-START.md

One entry in **"What is built"**, placed after Passes 51-55 and before the
**KNOWN AND UNFIXED after Pass 38** heading, in the style of the entries around it and citing all
four reports by name: **61 insertions, 0 deletions.**

It carries the same substance as the DECISIONS entry in the notebook's narrative voice, and ends
with the two behaviours the owner accepted, under the heading the file already uses for this —
**"Two behaviours the owner accepted on Home Theater — known, and not defects"**:

- **The screen's own header sits below tvOS's search field.** Field at y 60-130, keyboard strip
  at y 164-231, the app's `ScreenHeader` at y 306-368, clearing by 75 pt. Nothing obscured, but
  the screen carries two headings. `.automatic` is the only placement tvOS offers.
- **The keyboard strip scrolls off the top.** Eight rows down a 20-row result it sits at
  **y = -141**, and one Up press goes to the previous row, not the strip — **eight Up presses** to
  get back. Measured twice, the same both times.

**Additions only, in both files**, as the pass required: `git diff --numstat` reported `65 0` and
`61 0`. No existing line was rewritten, reworded, moved or removed, and **"Next step" was
deliberately not touched** — a pass records its own verified push in its report and its response,
not in the commit it describes (DECISIONS.md 2026-09-09 (Pass 60) rule (b)).

---

## 4. Step 4 — the commit, the push, and the verification

The notebook work is **`b028650c0090ae1701b84ec595f0af41e8468bcf`**, "Pass 66: Passes 62-65
accepted, and the notebook", 2 files changed, 126 insertions, 0 deletions.

```
git push origin main
   49a5672..b028650  main -> main
```

**Verified live after a fresh `git fetch origin`, three independent readings, all identical:**

```
local main        b028650c0090ae1701b84ec595f0af41e8468bcf
origin/main       b028650c0090ae1701b84ec595f0af41e8468bcf
ls-remote origin  b028650c0090ae1701b84ec595f0af41e8468bcf   refs/heads/main
```

**And that it is a clean fast-forward, checked five ways rather than asserted:**

| Check | Result |
|---|---|
| `git merge-base --is-ancestor 49a5672 b028650` | **yes** — the old head is an ancestor of the new one |
| `git cat-file -t 49a5672` | still a reachable commit; nothing was rewritten out from under it |
| `git log --merges 49a5672..b028650` | **0** merge commits |
| parent chain over the range | `b028650 → d0ff593 → 1107b12 → 49a5672`, linear |
| committer dates over the range | strictly ascending — 16:11, 18:40, 18:46 |
| `git reflog` | three plain `commit:` entries and nothing else — no `rebase`, `amend` or `reset` |

**The three commits now on `origin main`:**

```
b028650  Pass 66: Passes 62-65 accepted, and the notebook
d0ff593  Pass 65: the search screen on .searchable
1107b12  Pass 63: the guide search screen
```

`1107b12` also carried `reports/2026-09-11-pass62-guide-search-recon.md`, which Pass 62 had left
untracked; `d0ff593` carried the Pass 64 report Pass 65 wrote on its behalf. **So all four reports
for Passes 62-65 are now on the remote**, and none of the untracked-report debt Passes 39, 40 and
44 had to clean up was created.

---

## 5. What is on the remote now, and what is not

**Nothing of the Search work is unpushed.** `origin/main` is `b028650` and the working tree is
clean apart from the known untracked `icon-source/`, whose fate is the owner's call and which no
pass has committed (DECISIONS.md 2026-09-08, Passes 51-55).

**One thing is untracked and deliberately so: this report.** The pass's own steps put the report
after the push, and the push SHA cannot be written into a commit that precedes it. This is the
same shape as Pass 62's report, which Pass 63 committed, and Passes 39 and 40's, which Pass 44
committed. **It is the next pass's to pick up** — see §7.1.

---

## 6. Scope check — every path touched

| Path | What happened | Step |
|---|---|---|
| `DECISIONS.md` | one dated entry appended, **+65 / -0** | 2 |
| `COLD-START.md` | one entry in "What is built", **+61 / -0** | 3 |
| `reports/2026-09-11-pass66-search-accepted-and-pushed.md` | **new** — this file, untracked | 5 |
| `Marlin DVR TV/**`, `Marlin DVR TVUITests/**`, `*.xcodeproj`, `Info.plist`, entitlements | **not touched** | — |
| `design/`, `CLAUDE.md`, `icon-source/`, every earlier report | **read only**, never written | — |
| `~/Xcode/marlin-dvr-reference` | **not touched at all** this pass | — |

No request was made to 192.168.1.250, 192.168.1.245, 192.168.1.105 or the UNAS4Pro share, no
build was run, nothing was installed on either Apple TV, and no other folder under `~/Xcode` was
read or written. No credential, token or device id appears above.

---

## 7. Open questions

1. **This report is untracked.** The owner's 2026-09-08 decision is that a report the notebook
   cites by name belongs in the repo. This one is not cited by the notebook, but the next pass
   should commit it anyway, the way Pass 63 committed Pass 62's.
2. **"Next step" in `COLD-START.md` still stops at Pass 58.** It has not named a push since
   `67ec874`, and it now omits `2fd90cb` through `b028650`. Bringing it current is the job Pass 59
   did for Passes 55-58; nobody has done it for 62-66. Not done here — this pass's steps named
   "What is built" and nothing else, and scope lock binds changes as well as builds.
3. **The four open questions Pass 65 raised are still open** and none is a defect: the two
   headings, the keyboard strip scrolling away, the duplicated prompt wording, and Pass 63's own
   four (silent DRM filtering, `Watch live` from a search result closing the sheet rather than
   playing, `/api/guide/search` being uncapped, title-only matching).
4. **`GuideScreen` may carry the same latent focus defect** the search screen has now been fixed
   for twice. Raised in Pass 63 §9.1 and again in Pass 65 §9.4; still not investigated.

---

## 8. The things I am least sure of

1. **That the owner's "all good" covers everything this pass recorded as accepted.** He tested the
   screen and said so; the two behaviours in §3 are written down as accepted because they are
   plainly visible in normal use and he did not object. **He was not asked about either one by
   name.** If he meant only "it works", the two entries should be re-read as "known and not
   fixed" rather than "accepted".
2. **The placement of the new COLD-START entry.** "What is built" runs roughly chronologically and
   Passes 62-65 are the newest, so it went after Passes 51-55 and before the KNOWN AND UNFIXED
   block. That block is headed "after Pass 38" and now has newer material above it, which is how
   the file already reads elsewhere but is not tidy.
3. **Whether Pass 64 should have a commit at all.** It produced no tracked artefact of its own;
   its report was written and committed by Pass 65. Anyone reading `git log` will find no Pass 64
   commit and might read that as a gap rather than as a read-only pass working as intended.

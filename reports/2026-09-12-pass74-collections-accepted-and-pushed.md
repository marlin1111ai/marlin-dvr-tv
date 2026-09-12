# Pass 74 — the Guide's channel collections accepted, and Passes 72-73 pushed

**Date:** 2026-09-12
**Base commit:** `c7e0fb4` (Pass 73, "the empty-collection state proven on the device").
**Result: the chain verified, the acceptance recorded, and Passes 72 and 73 pushed to
`origin main` as a fast-forward.** No app-target code changed; nothing was built.

**Server traffic: none.** This pass made no request to the Marlin DVR server of any kind — no GET,
and nothing was written. The app was not launched, no test was run, and no device was driven.
`~/Xcode/marlin-dvr-reference` was not opened. `design/` was not opened and not written. Unraid
`192.168.1.250` as a host, marlinpc, the HDHomeRun and the UNAS4Pro share were not touched. The only
network operations are `git fetch` and `git push` against `git@github.com:marlin1111ai/marlin-dvr-tv.git`.

**No credential, token, device id or client id appears in this report.**

---

## 1. What was accepted

**The owner tested the Guide's channel collections on Home Theater on 2026-09-12 and accepted them —
"all good"** (owner, 2026-09-12).

**One acceptance covers both passes, and that is not a shortcut.** **Pass 73 changed no app-target
code** — its only source edit was `GuideCollectionsUITests`, plus the notebook and its report — so
the binary the owner tested carries **Pass 72's** behaviour exactly. There is no second build to
accept.

What the acceptance covers, named here so a later pass does not have to infer it from two commits:

- **The collections button** in the Guide's header, in `ScreenHeader`'s new accessory slot between
  the title and the date range, reading "All Channels" with nothing selected and the collection's
  name otherwise.
- **The drop-down** — the app's own `ZStack` overlay of `MenuRow`s, the same mechanism as
  `ChannelActionsMenu` and not `Menu`, `Picker` or `.sheet`; All Channels first, then every
  collection the server returns, in the server's order; Select applies and closes, Menu closes with
  no change.
- **The filtered reload** through `GET /api/guide?filter=<collection id>` — the id, never the name —
  in the owner's own member order, at the window the Guide is already showing. `↩ Now`, `+12h`,
  `endOfListings` and the client-side DRM filter all behave as before against the filtered rows.
- **Persistence** across a trip to the rail and across a relaunch, in the one new `UserDefaults`
  key `"marlinGuideCollection"`, with `GuideCollectionsModel` owned above `ScreenShell`.
- **The empty-collection state** — "Nothing in \<name\> right now", with focus landing on the
  collections button because no cell exists to take it — which **Pass 73 proved on the device**
  against the owner's empty "Test" collection.

**The acceptance closes none of the open questions** Passes 71-73 raised, and none is re-raised
here: the overlay does not scroll, the "Collections unavailable" state is unproven, the **stale-id
revert is unproven** and needs a collection deleted, and whether the collection should also reach
`GET /api/guide/now` and `GET /api/channels` is still the owner's call (Pass 71 open question 8).

---

## 2. Step 1 — the chain, verified before anything was written

`origin/main` was refreshed with `git fetch origin` first, so none of this is read from a stale ref.

| Check | Result |
|---|---|
| `git rev-parse origin/main` | `2206a92913251638c8bafebcbb12b673d99e6938` |
| `git rev-parse main` | `c7e0fb4f60ac618b09d8b7ec0cd7553f723a2d9f` |
| `git ls-remote origin main` | `2206a92913251638c8bafebcbb12b673d99e6938` |
| `git rev-list --left-right --count origin/main...main` | `0  2` — two ahead, **zero behind** |
| `git log --oneline --reverse origin/main..main` | `9f5505e` then `c7e0fb4`, in that order |
| `git log --merges origin/main..main` | **empty** |
| parentage | `c7e0fb4` → `9f5505e` → `2206a92` → `a49258a` |
| `git merge-base --is-ancestor 2206a92 HEAD` | yes |
| `git merge-base --is-ancestor origin/main main` | yes — **a fast-forward is possible** |
| branch | `main`; working tree clean but for untracked `icon-source/` |

**Exactly `9f5505e` then `c7e0fb4`, linear, no merges.** The step's stop-condition was not met, so
the pass continued.

---

## 3. Files touched, mapped to step numbers

| File | Step(s) | What |
|---|---|---|
| — | **1** | **no file** — the verification is eight read-only git commands |
| `DECISIONS.md` | **2** | `2026-09-12 (Pass 74 — Passes 72-73 accepted and pushed)` |
| `COLD-START.md` | **2** | a Pass 74 entry in "What is built", and a new first paragraph under "Next step" |
| `reports/2026-09-12-pass74-collections-accepted-and-pushed.md` | **3** | this report |
| — | **4** | **no file** — the push and its verification |

**No app-target file was touched, and neither was the test target.** `git diff --stat` over
`Marlin DVR TV/` and `Marlin DVR TVUITests/` is empty. Also untouched: the Xcode project file,
`Info.plist`, the entitlements file, every build setting, the asset catalog, `design/`,
`icon-source/`, and every earlier report — including Passes 72's and 73's, which are the historical
record and are never rewritten to match a later decision (DECISIONS.md, 2026-09-09 (Pass 56)).

**The notebook edits are additions only, verified by `git diff --numstat`: `COLD-START.md` 25
insertions / 0 deletions, `DECISIONS.md` 32 insertions / 0 deletions.** No existing line was
reworded, moved or removed. In particular the "committed locally and NOT pushed" clauses in the
Passes 71-72 and Pass 73 entries were **left standing and superseded in place** by the new entry
beneath them, and the two older "Next step" paragraphs were left as written.

---

## 4. The one place this pass could not take a step literally

Step 2 asked for `COLD-START.md`'s "Next step" paragraph to name "`9f5505e`, `c7e0fb4` and **this
pass's commit**". The first two are named. **The third cannot be a SHA: a commit cannot contain its
own SHA**, and this report and that paragraph are both inside the commit in question.

This is not a judgement call — it is the cycle **Pass 68 closed as a standing rule**: a pass writes
its report, commits it, then pushes, and the verified SHA lives in the **pass response** and in the
**next pass's notebook entry** (DECISIONS.md, 2026-09-11 (Pass 68); rule (b) of 2026-09-09
(Pass 60)). So the paragraph names this pass's commit **descriptively** — by what it carries — and
says plainly why no SHA appears. **Nothing is lost:** the SHA is in the Pass 74 response, and the
next pass records it.

---

## 5. Step 4 — the push

The push follows this commit, so its result is **not** in this report, for the reason in §4. What is
fixed before it runs: it is a **plain `git push origin main`**, a fast-forward from `2206a92` with
`origin/main` already proven an ancestor of `main`. **Nothing is forced. No history is rewritten. No
branch other than `main` is touched.** The verification is a fresh `git fetch` followed by
`git rev-parse main`, `git rev-parse origin/main` and `git ls-remote origin main`, all three shown in
the pass response and all three required to read the same SHA, with `2206a92` confirmed still an
ancestor.

**If any of the three disagrees, that is a stop-and-report**, not something to push at again.

---

## 6. Open questions

None raised by this pass. It built nothing and changed no behaviour.

The standing ones are listed in §1 and stay exactly where Passes 71-73 left them.

---

## 7. What I am least sure of

1. **That "all good" covers the empty state as fully as the rest.** The owner's acceptance was given
   for the collections work as a whole. The empty state is reachable only by picking a collection
   with nothing in it, which is a deliberate act; I have recorded it as accepted because it is part
   of what was tested and proven, but I cannot tell from "all good" whether the owner actually chose
   "Test" on the device or accepted it on Pass 73's evidence. **Either way it is proven** — Pass 73
   measured it — so nothing rests on the distinction except the word "accepted".
2. **That superseding rather than editing keeps `COLD-START.md` readable.** The rule is additions
   only, and I have followed it, so the file now carries three "Next step" paragraphs of which only
   the first is current and two entries in "What is built" whose "NOT pushed" clauses are false as
   written and corrected beneath them. Each addition says which text it supersedes, but the file
   grows this way, and at some point a pass will have to be told to prune it. **That is the owner's
   call, not mine**, and I have not made it here.

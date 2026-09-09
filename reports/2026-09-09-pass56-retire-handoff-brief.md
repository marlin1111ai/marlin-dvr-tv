# Pass 56 — the handoff brief retired into COLD-START.md

**Date:** 2026-09-09.
**Documentation and git only.** No Swift source file, no asset catalog file, no artwork and no
project setting was touched. **Nothing under `reports/` was edited or deleted** — including Pass 55's
own report, which still describes the brief this pass removed. No build, no install, no test, no
device run. **No request of any kind to `192.168.1.250:8090`.** `icon-source/`, `FocusClick.dataset`
and the empty template brandassets were all left exactly as they stand.

**The owner's decision:** on 2026-09-08 he decided this project no longer uses separate
handoff-brief files — `COLD-START.md` and `DECISIONS.md` are the whole record, matching how his other
projects run. Pass 55 wrote `MARLIN-DVR-TV-HANDOFF-2026-09-09.md` before that decision. This pass
retires it.

---

## 1. The starting state, read-only — four raw outputs

```
$ git rev-parse HEAD
48e8f91f9db127364d096fa4baca0dbd10bab4f2
```

```
$ git rev-parse origin/main
48e8f91f9db127364d096fa4baca0dbd10bab4f2
```

```
$ git ls-remote origin main
48e8f91f9db127364d096fa4baca0dbd10bab4f2	refs/heads/main
```

```
$ git status --porcelain --untracked-files=all
?? icon-source/AppIcon-1024-square.png
?? icon-source/AppIcon-800x480.png
?? icon-source/AppStore-1280x768.png
?? icon-source/AppStore-2560x1536.png
?? icon-source/Assets.xcassets/AccentColor.colorset/Contents.json
?? "icon-source/Assets.xcassets/AppIcon.brandassets/App Icon - App Store.imageset/AppStore-1280x768.png"
?? "icon-source/Assets.xcassets/AppIcon.brandassets/App Icon - App Store.imageset/AppStore-2560x1536.png"
?? "icon-source/Assets.xcassets/AppIcon.brandassets/App Icon - App Store.imageset/Contents.json"
?? "icon-source/Assets.xcassets/AppIcon.brandassets/App Icon.imagestack/Back.imagestacklayer/Content.imageset/AppIcon-400x240.png"
?? "icon-source/Assets.xcassets/AppIcon.brandassets/App Icon.imagestack/Back.imagestacklayer/Content.imageset/AppIcon-800x480.png"
?? "icon-source/Assets.xcassets/AppIcon.brandassets/App Icon.imagestack/Back.imagestacklayer/Content.imageset/Contents.json"
?? "icon-source/Assets.xcassets/AppIcon.brandassets/App Icon.imagestack/Back.imagestacklayer/Contents.json"
?? "icon-source/Assets.xcassets/AppIcon.brandassets/App Icon.imagestack/Contents.json"
?? "icon-source/Assets.xcassets/AppIcon.brandassets/App Icon.imagestack/Front.imagestacklayer/Content.imageset/AppIcon-400x240.png"
?? "icon-source/Assets.xcassets/AppIcon.brandassets/App Icon.imagestack/Front.imagestacklayer/Content.imageset/AppIcon-800x480.png"
?? "icon-source/Assets.xcassets/AppIcon.brandassets/App Icon.imagestack/Front.imagestacklayer/Content.imageset/Contents.json"
?? "icon-source/Assets.xcassets/AppIcon.brandassets/App Icon.imagestack/Front.imagestacklayer/Contents.json"
?? icon-source/Assets.xcassets/AppIcon.brandassets/Contents.json
?? "icon-source/Assets.xcassets/AppIcon.brandassets/Top Shelf Image Wide.imageset/Contents.json"
?? "icon-source/Assets.xcassets/AppIcon.brandassets/Top Shelf Image Wide.imageset/TopShelfWide-2320x720.png"
?? "icon-source/Assets.xcassets/AppIcon.brandassets/Top Shelf Image Wide.imageset/TopShelfWide-4640x1440.png"
?? "icon-source/Assets.xcassets/AppIcon.brandassets/Top Shelf Image.imageset/Contents.json"
?? "icon-source/Assets.xcassets/AppIcon.brandassets/Top Shelf Image.imageset/TopShelf-1920x720.png"
?? "icon-source/Assets.xcassets/AppIcon.brandassets/Top Shelf Image.imageset/TopShelf-3840x1440.png"
?? icon-source/Assets.xcassets/Contents.json
?? icon-source/Assets.xcassets/FocusClick.dataset/Contents.json
?? icon-source/Assets.xcassets/FocusClick.dataset/focus_click.caf
?? icon-source/TopShelf-1920x720.png
?? icon-source/TopShelf-3840x1440.png
?? icon-source/TopShelfWide-2320x720.png
?? icon-source/TopShelfWide-4640x1440.png
?? icon-source/marlin-dvr-icon.png
```

All three SHAs read `48e8f91`; clean but for the 32 untracked `icon-source/` entries.

**Pass 55's report is named `reports/2026-09-08-pass55-push-and-handoff.md`** — found by listing
`reports/`, not assumed. (This pass's brief guessed `…push-and-record.md`, which does not exist.)

---

## 2. Section-by-section: covered, or gap

The brief is 201 lines in eleven sections. Every substantive fact in it was checked against
`COLD-START.md`. **Two greps I ran early gave false negatives** — I had written alternations as
`\|` under `grep -E`, which matches a literal pipe rather than alternating — so **every "missing"
result was re-checked by reading the actual text** before being called a gap. That is how the
27-session item was confirmed and how six others were cleared.

| Brief § | Content | Verdict |
|---|---|---|
| **1. The project** | app, folder, repo, server URL | **Covered** — `## What the app is` and `## Where things live` |
| 1 | **server is marlin-dvr 1.8.0** on the owner's Status-page reading | **Covered** — "What is built" opening block |
| 1 | reference clone at 1.2.1, `origin/main` `095de81` | **Covered** — same block |
| 1 | `design/` read-only | **Covered** — `## Where things live` |
| 1 | deployment target tvOS 18.0, both Apple TVs on 26.6 | **Covered in `DECISIONS.md:12`**, not in COLD-START. Not moved — both files are the record, and this is a dated decision that belongs there. Raised in §4. |
| **2. Where the code is** | the verified `origin/main` SHA | **Covered** — `## Next step` carries `fd96b1d` with the three-command verification method |
| 2 | "verify rather than trust this number" | **Covered in substance**, not in that wording. The SHA is recorded *with* how it was verified, and `## The rules` requires reading the remote back. Raised in §4. |
| **3. What the session built** | single-file route, shelf focus fix, airing sheet control, icon | **Covered** — four narrative entries in "What is built" |
| **4. Three defects** | LIVE badge closed, fast-forward closed | **Covered** — `## Next step` |
| 4 | desync still open, NOT OURS, no compensation ever | **Covered** — Pass 42 entry |
| 4 | **their request that the owner match observed sessions to individual session records** | **GAP** — nothing in either notebook file mentioned it |
| **5. Contract behind their server** | byte-unchanged across 1.8.0, still says 1.7.0, §2 line 68 says the opposite, §2.3 of the Pass 41 report is the only written description, anyone using the contract alone will be wrong | **Covered in full** — COLD-START lines 61–71, added in Pass 43. Item 3.2 of this pass's brief was **already there**, so nothing was duplicated. |
| **6. KNOWN AND UNFIXED** | all three sections | **Covered** — they are the source the brief summarised |
| **7. Open questions** | the six, and which blocked step 7 | **Covered** — `## Next step`, lines 878–883 |
| 7 | Pass 42's correction of Pass 41's `start: N` claim | **Covered** — `DECISIONS.md`, 2026-09-08 (Pass 42) entry |
| 7 | **the 27-session table's standing state** | **GAP** — the only hits anywhere were the Pass 27 and Pass 40 *report filenames*, not the substance |
| **8. Partly proven** | multi-card traversal untested | **Covered** — Pass 47 entry |
| 8 | 60 pt shelf shift accepted | **Covered** — Pass 47 entry |
| 8 | airing sheet status states code-traced only | **Covered** — Pass 49 entry |
| 8 | icon never machine-checked for appearance | **Covered** — Passes 51–55 entry |
| 8 | green "● Scheduled" vs the Guide's gold "◆ SERIES PASS" | **Covered** — Pass 49 entry |
| 8 | second Apple TV, development-signed, expiry unknown | **Covered** — Passes 51–55 entry |
| **9. How this project runs** | recon before build, scope lock, push gate, never force-push, evidence rules, no secrets, do-not-touch | **Covered** — `## The rules`, lines 15–24 |
| **10. Context panel** | which files to load | **Moot** — the standing decision replaces it, recorded in `DECISIONS.md` (§6 below) |
| **11. Untracked** | `icon-source/`, 32 entries, fate undecided | **Covered** — `DECISIONS.md` 2026-09-08 (Passes 51–55) entry, and COLD-START's `FocusClick` note |

**Two gaps. Both were the two this pass's brief named in advance as known.**

---

## 3. Exactly what was added to COLD-START.md

Both gaps went into **`## Raised for the marlin-dvr project — recorded here, not acted on`**, which is
the section for "server behaviour this project measured and does not own". Quoted in full:

> - **The audio/video desync on recordings — and their outstanding request.** Pass 39 sorted it
>   **NOT OURS**: every parameter, setting and seek in this app was inventoried and none can shift
>   audio against video. Nothing in Passes 42–56 changed it, and **no client-side compensation has
>   ever been built for it, nor is any to be.** **The marlin-dvr project has asked the owner to match
>   the sessions in which he observed the desync to individual session records.** That request is
>   **outstanding and is the owner's to answer**; nothing has been done about it here.
> - **The 27-session start-values table is still unsettled with the marlin-dvr foreman.** They asked
>   for **the full 27 rows published in this repo with stable labels `S01`–`S27`**, and **explicitly
>   asked us NOT to re-capture and NOT to pursue the send-versus-apply question until they ask.** A
>   prompt to do that work was written and **the owner did not send it** — he is settling the shape
>   with them first. **IT MUST NOT BE RE-ISSUED UNPROMPTED.** The Pass 38 captures the rows would come
>   from live in a **session temp directory, not in this repo**
>   (`reports/2026-09-08-pass40-session-start-values.md` §1 records their path); **if they vanish, only
>   a fresh Apple TV capture could recover the rows — which is exactly what they asked us not to
>   spend.**

**One further edit, forced by the deletion.** `## Next step` pointed at the file this pass removes:
*"The cold-start brief for the next session is `MARLIN-DVR-TV-HANDOFF-2026-09-09.md` at the repo
root; it supersedes `MARLIN-DVR-TV-HANDOFF-2026-09-08b.md`, which should be removed from the Context
panel."* Leaving that would have made the notebook point at a deleted file — the same
self-contradiction Passes 44 and 45 had to clean up. It now reads:

> **This project keeps no separate handoff-brief file: `COLD-START.md` and `DECISIONS.md` are the
> whole record** (owner, 2026-09-08). Pass 55 wrote `MARLIN-DVR-TV-HANDOFF-2026-09-09.md` before that
> decision was taken; **Pass 56 moved what it carried that this file did not into here and deleted
> it** (`reports/2026-09-09-pass56-retire-handoff-brief.md`).

**Nothing else in COLD-START.md was changed.** No correction, tidy, reword or restructure beyond
these — including the conditional sentence in the Pass 42 block that Pass 48 flagged, which stands
untouched.

---

## 4. Does COLD-START.md stand alone now?

Checked by pattern after the edits. Every item this pass's step 4 named:

```
What the app is               PRESENT      Six open questions            PRESENT
Where things live             PRESENT      step 7 never built            PRESENT
The rules                     PRESENT      Multi-card untested           PRESENT
How to build                  PRESENT      60 pt shift                   PRESENT
Server is 1.8.0               PRESENT      Airing states by eye          PRESENT
Contract behind server        PRESENT      Desync open                   PRESENT
K&U after Pass 29 / 33 / 38   PRESENT      Their session-records request PRESENT
                                           27-session table              PRESENT
```

and separately: green-vs-gold chip, Master Bedroom ATV, development-signed, provisioning expiry,
the 32 untracked entries, and `FocusClick` — **all present in `COLD-START.md`**.

**Two things are in `DECISIONS.md` rather than `COLD-START.md`, and were deliberately not moved.**
Raised here rather than acted on, because the owner's decision is that **both files together** are
the record and neither item is a COLD-START-shaped fact:

1. **The deployment target (tvOS 18.0) and that both Apple TVs run tvOS 26.6** — `DECISIONS.md:12`,
   a dated decision from 2026-09-05.
2. **Pass 42's correction of Pass 41's `start: N` claim** — the 2026-09-08 (Pass 42) entry.

**Nothing else is missing.** No fact was invented to fill a gap.

---

## 5. Handoff files, before and after

**Before:**

```
$ git ls-files | grep -i handoff
MARLIN-DVR-TV-HANDOFF-2026-09-09.md
reports/2026-09-08-pass55-push-and-handoff.md

$ ls -1 | grep -i handoff
MARLIN-DVR-TV-HANDOFF-2026-09-09.md
```

**The deletion:**

```
$ git rm "MARLIN-DVR-TV-HANDOFF-2026-09-09.md"
rm 'MARLIN-DVR-TV-HANDOFF-2026-09-09.md'
```

**After:**

```
$ git ls-files | grep -i handoff | grep -v '^reports/'
(no output — no handoff brief tracked)

$ ls -1 | grep -i handoff
(no output — gone from disk)
```

`reports/2026-09-08-pass55-push-and-handoff.md` remains, untouched. **It is a report; reports are
never edited or deleted**, and it still describes writing the brief this pass removed. That is
correct — it is the historical record of what Pass 55 did, not a claim about the present.

**`MARLIN-DVR-TV-HANDOFF-2026-09-08b.md` was not deleted because it does not exist.** Pass 55
reported it is not on disk anywhere reachable; re-checked this pass —
`find . -maxdepth 2 -iname "*HANDOFF*08b*"` returns nothing. **It lives only in the owner's Context
panel, and removing it from there is his to do.**

---

## 6. What was added to DECISIONS.md

**A new dated entry, `## 2026-09-09 (Pass 56 — no more handoff briefs)`** — the first 2026-09-09
entry in the file. It records: that **this project uses `COLD-START.md` and `DECISIONS.md` only and
no further handoff-brief file is written by any pass** (owner, 2026-09-08), matching his other
projects; that the 09-09 brief was **retired into COLD-START and deleted** by this pass, with the
method (section-by-section comparison, two facts moved); **which two facts had to move**; that the
09-08b file was not deleted because it is not on disk and removing it from the Context panel is the
owner's to do; and that **no report was edited or deleted**, with the reason — reports are the
historical record and are never rewritten to match a later decision.

---

## 7. The push, and the three verification readings

The push was a plain fast-forward — two dots, **not** a `+`:

```
$ git push origin main
To github.com:marlin1111ai/marlin-dvr-tv.git
   48e8f91..10499e5  main -> main
```

Then `git fetch origin` (exit 0), and the three readings, each as its own command:

```
$ git rev-parse HEAD
10499e5eca227fef9d31c0fc3b46644dfa61d927
```

```
$ git rev-parse origin/main
10499e5eca227fef9d31c0fc3b46644dfa61d927
```

```
$ git ls-remote origin main
10499e5eca227fef9d31c0fc3b46644dfa61d927	refs/heads/main
```

**All three agree**, and the remote was read back rather than trusted from local state.

**What is now on `origin/main`:** commit `10499e5` — 4 files changed, 349 insertions, 204 deletions.
`COLD-START.md` and `DECISIONS.md` modified, `MARLIN-DVR-TV-HANDOFF-2026-09-09.md` **deleted**, and
this report added. **Nothing was force-pushed. No commit was amended, reworded or rebased**, and
nothing under `reports/` was edited or removed. A second commit records these SHAs, since they
cannot exist inside the commit they name.

---

## 8. SCOPE CHECK — every file touched

| Path | Access | Required by |
|---|---|---|
| `MARLIN-DVR-TV-HANDOFF-2026-09-09.md` | **read in full, then `git rm`** | steps 2, 5 |
| `COLD-START.md` | **read in full; modified** — two gap entries added, one Next-step sentence replaced | steps 2, 3, 4 |
| `DECISIONS.md` | **read in full; modified** — one appended dated entry | steps 2, 6 |
| `reports/2026-09-08-pass55-push-and-handoff.md` | **read only; not edited, not deleted** | required reading |
| `reports/2026-09-09-pass56-retire-handoff-brief.md` | **created** | DELIVERABLE |

**No Swift source file, asset catalog file, artwork or project setting was modified.** **Nothing
under `reports/` was edited or deleted** — one report was created, which is the deliverable.

**Not touched:** `icon-source/` (32 entries still untracked), `FocusClick.dataset`, the empty template
brandassets; every other folder under `~/Xcode`; the reference clone; `design/`; the Marlin DVR
server, its data and its API — **zero requests**; Unraid, marlinpc, the HDHomeRun, the UNAS4Pro
share; **both Apple TVs — no build, install or test.**

**No new dependency.** No credential, token, device id or account identifier appears in this report
or in either notebook file.

---

## CLOSING SUMMARY FOR THE OWNER

**Only two things had to move out of the brief.** I compared it against `COLD-START.md` section by
section, and almost everything in it was already there — the server being 1.8.0, all three
known-and-unfixed lists, the six open questions, the shelf and airing-sheet caveats, the icon work,
how the project runs. **The warning about their contract file was already in there too**, added back
in Pass 43, so nothing was duplicated.

The two genuine gaps were exactly the two you flagged in advance: **the 27-session table's standing
state** — that they want all 27 rows published here with `S01`–`S27` labels, that they asked us **not**
to re-capture and **not** to touch the send-versus-apply question until they ask, that the prompt was
written and you did not send it, and that **it must not be re-issued unprompted** — and **their
outstanding request that you match the sessions where you saw the desync to individual session
records.** Both now sit under "Raised for the marlin-dvr project" in `COLD-START.md`, which is where
things you own but this project does not already live.

I also had to fix one sentence: `Next step` pointed at the brief as the thing to read next, and that
would have been a pointer to a deleted file. It now records the standing decision instead.

**The brief is gone and the notebook is the whole record.** `COLD-START.md` and `DECISIONS.md` carry
everything a fresh session needs with no brief at all. The 09-08b file was not deleted because it
still is not on disk anywhere I can see — it only exists in your Context panel, so **taking it out of
there is yours to do**.

**What this pass cost.** Two documentation files edited, one file deleted, one report written. No
build, no install, no test, no server request, and not a line of app code or artwork touched. No
report was edited or deleted — Pass 55's still describes writing the brief, which is right, because
it is a record of what happened rather than a claim about now.

**The three things I am least certain about.**

1. **That the gap list caught everything.** It is the only thing standing between the deletion and
   losing something, and I found two of my own early greps giving false negatives through a quoting
   mistake — I re-checked every one by reading the text, but a fact worded very differently in both
   files could still have been passed over as "covered".
2. **Two items live in `DECISIONS.md` rather than `COLD-START.md`** — the tvOS deployment target and
   Pass 42's correction of Pass 41. I left them where they are because both files are now the record
   together, but if you ever read only `COLD-START.md`, they are not in it.
3. **The 09-08b file.** I can only report that it is not on disk anywhere I am allowed to look. If it
   is sitting somewhere I cannot see, it is still there and still stale.

# Pass 36 — fetch the server reference, then correct the notebook

**Date:** 2026-09-08
**Type:** one authorised `git fetch` in the reference clone, two files written to
the owner's Desktop, four notebook edits, one commit, one push.
**Working tree:** `~/Xcode/Marlin DVR TV`. **Second writable location, authorised
by step 2 only:** `~/Desktop/marlin-dvr-context/`.
**The running server was not contacted.** Every server fact below comes from the
clone's fetched objects or from the marlin-dvr project's own notebook.

Read first, not re-derived: this project's `COLD-START.md` and `DECISIONS.md`.

Every sentence named in steps 3, 4, 5 and 6 matched what the brief described, so
no stop-and-report condition fired and nothing was guessed at.

---

## 1. The clone, before and after the fetch

Each command was run on its own. Raw output.

**Before:**

```
$ cd ~/Xcode/marlin-dvr-reference
$ git rev-parse HEAD
9325d94439ef4c9db637c5014ff79f41d1f63956

$ git rev-parse origin/main
fba51f2504571147aefdc8e39ec67d1453d4c999

$ git status --porcelain
?? README-REFERENCE.md
```

A working-tree fingerprint was taken as well, so "byte-identical" is measured
rather than asserted — the md5 of the sorted md5s of all 257 non-`.git` files:

```
$ find . -path ./.git -prune -o -type f -print | sort | xargs md5 -q | md5 -q
b106585bee982f02546bf13e30487d82

$ find . -path ./.git -prune -o -type f -print | wc -l
     257
```

**The one authorised operation, and nothing else:**

```
$ git fetch origin
From github.com:marlin1111ai/marlin-dvr
   fba51f2..c417c60  main       -> origin/main
```

**After:**

```
$ git rev-parse HEAD
9325d94439ef4c9db637c5014ff79f41d1f63956

$ git rev-parse origin/main
c417c60a6d415fbacd7797490d43cba59338d414

$ git status --porcelain
?? README-REFERENCE.md

$ find . -path ./.git -prune -o -type f -print | sort | xargs md5 -q | md5 -q
b106585bee982f02546bf13e30487d82
```

| | Before | After | Verdict |
|---|---|---|---|
| `HEAD` | `9325d94` | `9325d94` | **unchanged** |
| `origin/main` | `fba51f2` | `c417c60` | **moved, as expected** |
| `git status --porcelain` | `?? README-REFERENCE.md` | `?? README-REFERENCE.md` | **identical** |
| worktree fingerprint | `b106585b…7d82` | `b106585b…7d82` | **byte-identical** |

`origin/main` reads **`c417c60a6d415fbacd7797490d43cba59338d414`**, which is the
`c417c60` the brief predicted. The fetch was a fast-forward of the remote-tracking
ref only (`fba51f2..c417c60`, two dots, no `+`). **No checkout, merge, pull,
rebase, reset, branch switch, stash, commit, push or file write happened in that
clone**, and the untracked `README-REFERENCE.md` was already there before this pass
and is untouched. No stop condition fired.

---

## 2. The two files on the owner's Desktop

`~/Desktop/marlin-dvr-context/` was created, and both files were written from the
clone's fetched objects without checking anything out:

```
$ mkdir -p ~/Desktop/marlin-dvr-context
$ cd ~/Xcode/marlin-dvr-reference
$ git show origin/main:COLD-START.md     > ~/Desktop/marlin-dvr-context/MARLIN-DVR-SERVER-COLD-START.md
$ git show origin/main:HLS-CLIENT-API.md > ~/Desktop/marlin-dvr-context/HLS-CLIENT-API.md

$ ls -l ~/Desktop/marlin-dvr-context/
-rw-r--r--  1 marlin1111  staff   30406 Sep  8 01:09 HLS-CLIENT-API.md
-rw-r--r--  1 marlin1111  staff  110593 Sep  8 01:09 MARLIN-DVR-SERVER-COLD-START.md
```

| File | Lines | Version it states | Newest pass it cites |
|---|---|---|---|
| `MARLIN-DVR-SERVER-COLD-START.md` | **1350** | **1.7.0** | **Pass 77** |
| `HLS-CLIENT-API.md` | **595** | **1.7.0** | **Pass 80** |

**`HLS-CLIENT-API.md` now says outright what version it describes** (`:6-13`),
which the old copy never did:

> **What this file describes, and how to check that for yourself.** It
> describes the server at version **1.7.0** — image
> `ghcr.io/marlin1111ai/marlin-dvr:1.7.0`, digest
> `sha256:76604afc…dbab9`
> — which is what the Unraid container has been running since the owner's
> in-place update at 00:06 on 2026-09-08 (Pass 76). **Do not take that on
> trust:** `GET /api/system` returns `version`; if it does not say `1.7.0`,

Its section list has grown from 8 to 11: §9 Radio stations (their Pass 33), **§10
Commercial segments** (their Pass 73, "live since Pass 76") and **§11 The Trash
list** (their Pass 61, "added to this file in Pass 80"). The header's stale
"running version 1.1.0" line, which Pass 35 flagged, is gone.

**`MARLIN-DVR-SERVER-COLD-START.md`** records the deploy this pass writes into our
notebook, at `:33`:

> **DEPLOYED 2026-09-08 00:06 BY THE OWNER PRESSING THE STATUS PAGE'S BUTTON — not by an Unraid switch** (Pass 76).

**Neither file was copied into `~/Xcode/Marlin DVR TV`** and neither was added to
git. The rename of the first is as the brief specified, so it cannot collide with
this project's own `COLD-START.md` in the Context panel.

---

## 3. Notebook edit 1 — the server version (step 3)

`COLD-START.md`, the opening paragraph of `## What is built`.

**Before:**

> **The server is marlin-dvr 1.6.0** (owner, 2026-09-07; `GET /api/system` → `version 1.6.0`,
> `build 2026.09.05`). Two things about that release this app depends on:

**After:**

> **The server is marlin-dvr 1.7.0** (marlin-dvr project, 2026-09-08): the owner installed it at
> **00:06 on 2026-09-08 from the app's own Status-page button**, an in-place update rather than an
> Unraid image switch. Not measured from here — the running server is on this project's
> do-not-touch list — so this is the marlin-dvr project's own record, cited the way their other
> corrections are. Two things this app depends on, both landed in 1.6.0 and carried into 1.7.0:

The two dependency bullets that follow are **untouched**. The lead-in clause moved
from "Two things about that release" to "Two things this app depends on, both
landed in 1.6.0 and carried into 1.7.0" for one reason: both bullets describe
things that arrived in **1.6.0**, and leaving "that release" pointing at 1.7.0
would have quietly reattributed them. Nothing was verified against the running
server, as instructed.

---

## 4. Notebook edit 2 — the clone's real state (step 4)

`COLD-START.md`, the paragraph after those bullets.

**Before:**

> Note that the read-only reference clone at `~/Xcode/marlin-dvr-reference` is **stale at 1.2.1**
> (`cmd/marlin-dvr/main.go:38`) and has none of this. Pulling it is the owner's job. Until it moves,
> server facts are measured against the running server's own responses and its `GET /api/logs`.

**After:**

> Note that the read-only reference clone at `~/Xcode/marlin-dvr-reference` has a **checked-out tree
> still at 1.2.1** (`cmd/marlin-dvr/main.go:38`), which has none of this — checking it out is the
> owner's job and Pass 36 did not do it. **Its `origin/main` was fetched on 2026-09-08 and now reads
> `c417c60`** (Pass 36; it read `fba51f2` before), so their current sources and notebook can be read
> out of the clone with `git show origin/main:<path>` without checking anything out. Server facts are
> still measured against the running server's own responses and its `GET /api/logs`, never against
> the checkout.

Both SHAs are this pass's own measurements from section 1, not inherited numbers.

---

## 5. Notebook edit 3 — the marlin-dvr correction (step 5)

`COLD-START.md`, a new block inserted after the Pass 33 narrative and before
`### THE OWNER'S FOUR TRASHED RECORDINGS ARE GONE`, following the precedent of the
"Corrections from the marlin-dvr project, received 2026-09-07" block under Pass 26.

**Before:** nothing — this is an insertion. The paragraph it follows is unchanged:

> **Fixed on the way:** restoring the *last* recording in the trash used to trap the user on the screen —
> rows gone, Empty Trash disabled, so nothing could take focus and Menu left the app instead of reaching
> `.onExitCommand`. The empty-state sentence is focusable now and holds the `"empty"` focus id. Present
> in the Pass 10 code too; nobody had ever emptied the trash from the Apple TV.

**After** — the three paragraphs added directly beneath it:

> **Corrections from the marlin-dvr project, received 2026-09-08 and recorded here rather than by
> editing the landed report:** Pass 33's finding that **"the per-show `?trash=1` read no longer
> returns trashed episodes at all" is wrong as to cause.** The symptom was real; the explanation was
> not. **The per-show read still returns trashed episodes** — `GET /api/library/shows/{id}` still
> takes `?trash=1` (`library.go:609`), still keeps exactly the episodes whose trash flag matches the
> request (`library.go:626`), and still answers with `showingTrash` (`library.go:659`). What Pass 33
> actually hit is one route earlier: **`GET /api/library` builds its show list with
> `showSummaries(false)`, which skips a trashed recording *before* it creates that show's entry**
> (`library.go:409`), so a show whose recordings are all trashed never appears in the library and
> **its `showId` cannot be learned from anywhere** — and the per-show read needs that id in its
> path. Same symptom, different cause: not a read that stopped answering, but an id that cannot be
> discovered to ask it with.
>
> **Pass 34's decision is unchanged.** Trash is built on `GET /api/library/trash` and stays there. The
> per-show walk was rejected on the undiscoverable-`showId` grounds *as well as* on the cause now
> corrected, and this correction confirms that ground rather than weakening it — the server's own
> source says the same thing at `library.go:689-693`. **Nothing in the app changes.**
>
> **`GET /api/library/trash` landed in their `b98a4a2`** ("Pass 61: GET /api/library/trash — list
> every trashed recording", 2026-09-07), which is **after both refs this project's clone held** —
> its checkout `9325d94` and the `fba51f2` it had already fetched — so no ref available to Passes
> 32-35 could have shown the endpoint. Verified in the clone with `git merge-base --is-ancestor`.

**Every citation in that block was verified this pass against `origin/main`, not
copied from the brief.** Raw output:

```
$ git show origin/main:cmd/marlin-dvr/library.go | sed -n '405,412p'
		st := states[r.ID]
		if st == nil {
			st = &RecState{}
		}
		if st.Trash && !includeTrash {      <-- :409, the skip
			continue
		}
		s := byShow[r.ShowID]

$ git show origin/main:cmd/marlin-dvr/library.go | sed -n '609p'
	wantTrash := r.URL.Query().Get("trash") == "1"

$ git show origin/main:cmd/marlin-dvr/library.go | sed -n '626p'
		if st.Trash != wantTrash {

$ git show origin/main:cmd/marlin-dvr/library.go | sed -n '659p'
	writeJSON(w, map[string]any{"id": id, "title": title, "episodes": eps, "count": len(eps), "trashCount": trashCount, "showingTrash": wantTrash,

$ git show origin/main:cmd/marlin-dvr/library.go | grep -n "showSummaries"
401:func (a *App) showSummaries(includeTrash bool) []showSummary {
450:	shows := a.showSummaries(false)
500:	s := a.showSummaries(false)
689:// showSummaries skips a trashed recording BEFORE it creates that show's
```

`library.go:450` is the `/api/library` call site that passes `false`. The server's
own source comment states the same conclusion in its own words
(`library.go:689-693`):

> // showSummaries skips a trashed recording BEFORE it creates that show's
> // entry (library.go:388), so a show whose only remaining recordings are
> // trashed is absent from GET /api/library — and its id, which every other
> // trash-aware read needs in its path, cannot be learned from anywhere.
> // This walks the recordings themselves instead, so nothing can hide.

And §11 of the new `HLS-CLIENT-API.md` says it a third time, independently, naming
the same two line numbers this pass measured:

> `GET /api/library` builds its show list from `showSummaries(false)`
> (`library.go:450`), and `showSummaries` skips a trashed recording **before**
> it creates that show's entry (`library.go:409`).

**The `b98a4a2` claim, verified rather than inherited:**

```
$ git log -1 --format='%H %cd %s' b98a4a2
b98a4a245545865b092bc28bb2bdde6e8bbb92e6 Mon Sep 7 15:09:20 2026 -0400 Pass 61: GET /api/library/trash — list every trashed recording

$ git show b98a4a2 --stat
 cmd/marlin-dvr/library.go                        |  92 +++++
 cmd/marlin-dvr/main.go                           |   3 +
 reports/2026-09-07-pass61-trash-list-endpoint.md | 488 +++++++++++++++++++++++

$ git merge-base --is-ancestor fba51f2 b98a4a2 && echo yes
yes
$ git merge-base --is-ancestor 9325d94 b98a4a2 && echo yes
yes
```

So `b98a4a2` is a descendant of **both** refs the clone held before today —
neither the checkout nor the previously fetched `origin/main` could have contained
the endpoint. Pass 35's conclusion that no ref in the clone knew about it stands,
and is now explained rather than merely observed.

---

## 6. Notebook edit 4 — DECISIONS.md (step 6)

`DECISIONS.md`, under `## 2026-09-07 (pass 33)`, the first bullet.

**Before:**

> - The Trash screen reads `GET /api/library/trash` (marlin-dvr 1.6.0). The show-by-show walk it used
>   since Pass 10 is deleted; against 1.6.0 that walk returns nothing at all, because the per-show
>   `?trash=1` read no longer surfaces trashed episodes.

**After:**

> - The Trash screen reads `GET /api/library/trash` (marlin-dvr 1.6.0). The show-by-show walk it used
>   since Pass 10 is deleted; against 1.6.0 that walk returns nothing at all — **not** because the
>   per-show `?trash=1` read stopped surfacing trashed episodes, which it still does
>   (`library.go:609`, `:626`, `:659`), but because `GET /api/library` builds its show list with
>   `showSummaries(false)`, which skips a trashed recording before it creates that show's entry
>   (`library.go:409`), so a show whose recordings are all trashed has no discoverable `showId` for
>   the walk to ask about (cause corrected by the marlin-dvr project, 2026-09-08).

**The decision itself is unaltered** — the Trash screen still reads
`GET /api/library/trash`, the Pass 10 walk is still deleted, and the walk still
returns nothing. Only the stated *cause* changed. No other entry in the file was
touched.

---

## 7. The commit and the push (step 7)

Four hunks across two files, plus this report.

```
$ git diff --stat
 COLD-START.md | 34 ++++++++++++++++++++++++++++++----
 DECISIONS.md  |  8 ++++++--
```

Commit and push:

```
$ git commit -F -
[main 4f54588] Pass 36: server reference fetched, notebook corrected to 1.7.0

$ git push origin main
To github.com:marlin1111ai/marlin-dvr-tv.git
   784e8a3..4f54588  main -> main
```

**Verification, each command on its own, after `git fetch`:**

```
$ git fetch
(no output)

$ git rev-parse HEAD
4f545881eed3524a0409860ce8c050a0b5a9e097

$ git rev-parse origin/main
4f545881eed3524a0409860ce8c050a0b5a9e097

$ git ls-remote origin main
4f545881eed3524a0409860ce8c050a0b5a9e097	refs/heads/main

$ git status --porcelain
?? reports/2026-09-08-pass36-server-context-refresh.md

$ git rev-list --left-right --count origin/main...HEAD
0	0
```

| Value | SHA |
|---|---|
| local `HEAD` | `4f545881eed3524a0409860ce8c050a0b5a9e097` |
| `origin/main` (after fetch) | `4f545881eed3524a0409860ce8c050a0b5a9e097` |
| `git ls-remote origin main` | `4f545881eed3524a0409860ce8c050a0b5a9e097` |

**All three agree at `4f54588`**, and the branch is level in both directions —
0 ahead, 0 behind. The push was a **fast-forward**, `784e8a3..4f54588`; nothing was
forced, rebased or amended. The one line in `git status` is **this report**, which
was still being written at that moment and lands in the commit that follows —
a commit cannot contain its own SHA, so its verification is reported to the owner
directly, the same shape Passes 30, 34 and 35B used.

---

## OPEN QUESTIONS

Raised, not acted on. Nothing below was built, changed or worked around.

1. **§10 of the new `HLS-CLIENT-API.md` — commercial segments — is live and this
   app does nothing with it.** `GET /api/library/recordings/{id}/commercials`
   (their Pass 73) has been running on the container since the 00:06 update. The
   brief puts it explicitly out of scope and says it is the owner's to raise, so
   this pass did not read past its status block, did not evaluate it, and changed
   nothing. **Recorded here only so it is not forgotten.**

2. **§11 of the new contract documents the trash endpoint this app already built
   on, and the two accounts should be reconciled by a later pass.** Pass 33
   measured the response shape from the live server; §11 now states it from the
   source. They agree on everything this pass compared (no parameters honoured,
   the whole list every time, no paging), but **nobody has diffed our `TrashItem`
   field by field against §11.1's response block.** Not done here — out of scope.
   What breaks without it: nothing today; a field we decode strictly could differ
   from what the contract now promises.

3. **The server's own source comment cites a stale line number.**
   `library.go:690` says the skip is at `library.go:388`; at `origin/main` it is
   at `library.go:409` — 388 is where it sat in the 1.2.1 checkout. Our notebook
   uses the measured `:409`. A marlin-dvr matter, reported not fixed.

4. **The two Desktop files disagree about how far each has been carried.**
   `MARLIN-DVR-SERVER-COLD-START.md` cites up to their Pass 77;
   `HLS-CLIENT-API.md` cites up to their Pass 80 and says §11 was "added to this
   file in Pass 80". So the contract is three passes ahead of their cold-start on
   this ref. Nothing here depends on it; noted so neither file is treated as the
   newer of the two by default.

5. **This project's notebook now carries a server version it did not measure.**
   1.7.0 is the marlin-dvr project's statement, cited as such, exactly as the
   brief required — the running server is on the do-not-touch list. Everything
   this app actually exercises was last measured against 1.6.0. **If a later pass
   needs certainty, `GET /api/system` is the check, and it needs the owner's
   authorisation.**

6. **Our two dependency bullets were re-attributed to 1.6.0 rather than left
   pointing at "that release".** Both things they describe arrived in 1.6.0, and
   the paragraph above them now says 1.7.0. This was a wording change inside the
   paragraph the brief told me to correct, made so the bullets stay true; flagged
   because it was not spelled out. One-line revert if unwanted.

---

## SCOPE CHECK

| Path | Access | Required by |
|---|---|---|
| `~/Xcode/Marlin DVR TV/COLD-START.md` | read, then **edited** (3 hunks) | "WHAT TO READ FIRST"; steps 3, 4, 5 |
| `~/Xcode/Marlin DVR TV/DECISIONS.md` | read, then **edited** (1 hunk) | "WHAT TO READ FIRST"; step 6 |
| `~/Xcode/Marlin DVR TV/reports/2026-09-08-pass36-server-context-refresh.md` | **written** (this file) | DELIVERABLE |
| `~/Desktop/marlin-dvr-context/MARLIN-DVR-SERVER-COLD-START.md` | **written**, then read | step 2 |
| `~/Desktop/marlin-dvr-context/HLS-CLIENT-API.md` | **written**, then read | step 2 |
| `~/Xcode/marlin-dvr-reference` | `git fetch origin` **once**; otherwise read-only (`git rev-parse`, `status`, `log`, `show`, `grep`, `merge-base`, `find`+`md5`) | steps 1, 2, 5 |

**Writes outside the working tree: two, both in `~/Desktop/marlin-dvr-context/`,
the one location step 2 authorises.** A snapshot of each notebook file was taken
into the session scratchpad before editing; that is outside the project and outside
the Desktop folder.

**Git actions in this repo:** `add`, `commit`, `push origin main`, `fetch`,
`rev-parse`, `ls-remote`, `status`, `rev-list`, `diff`. **No force, no rebase, no
amend, no reset.**

**Git actions in the clone:** `fetch origin` **once**, and read-only queries.
**No checkout, merge, pull, rebase, reset, branch switch, stash, commit, push or
file write.** Proven by section 1: HEAD unchanged, status identical, worktree
fingerprint identical.

**Not done, per the scope lock:** no Swift, project, entitlement or config file
edited — none was opened; neither Desktop file copied into this repo or added to
git; §10's commercials route not acted on; no other difference between the new
files and this notebook acted on (all six are questions above); no handoff brief
file touched; no part of `COLD-START.md` or `DECISIONS.md` tidied, reformatted or
reordered beyond the four named edits; `design/` not opened; **no contact of any
kind with 192.168.1.250 or any other host on the do-not-touch list.** No processes
left running, no half-written files.

**Credential scan.** Everything quoted was reviewed first. No tokens, passwords,
tuner DeviceAuth values, source URLs, camera credentials or account identifiers
appear. Two things were deliberately **not** reproduced although this pass read the
lines holding them: the UNAS4Pro share's device id in the server cold-start's
Unraid mount path, and the full text of that file's line 33, which is a single
2,000-word cell. The image digest in section 2 is truncated for the same reason it
is quoted at all — it identifies a public image, not a secret. Git SHAs, LAN
addresses already in this notebook, and repo-relative paths are kept: they are the
evidence.

---

## CLOSING SUMMARY FOR THE OWNER

**(a) The two files are on your Desktop.** In a new folder called
`marlin-dvr-context`, there are two files. `MARLIN-DVR-SERVER-COLD-START.md` is
the DVR project's own cold-start notes, 1350 lines, and it describes the server at
version **1.7.0**. `HLS-CLIENT-API.md` is the client contract, 595 lines, and it
also describes **1.7.0** — and unlike the old copy, it now says so in its opening
lines instead of leaving you to guess. The first file is deliberately renamed so it
cannot be confused with this app project's own cold-start notes when both are open
in your Context panel.

**(b) What the notebook now says about the server.** It says the server is
**1.7.0**, installed by you at 00:06 on 8 September by pressing the button on the
app's own Status page rather than by switching the image in Unraid. It also says
plainly that this project did not check that itself — the server is on the
do-not-touch list — and that the source is the DVR project's own record. The two
things this app relies on, the trash list and the end of automatic pruning, are
noted as having arrived in 1.6.0 and still being there.

Two more corrections went in. The notebook used to say the reference copy of the
server code was simply "stale"; it now says the files sitting on disk are still the
old 1.2.1 ones, but that the newer material has been downloaded and can be read
without disturbing anything. And the DVR project told us we had the right symptom
but the wrong reason for something Pass 33 found: the per-show trash read never
stopped working — what actually happens is that a show whose recordings are all in
the trash disappears from the library listing, so there is no id left to ask about
it with. That correction is recorded in both notebook files. **The decision it
touches does not change**, because we rejected that approach for the missing-id
reason as well, which is exactly what the correction confirms.

**(c) The SHA on the remote.** `4f54588` for the notebook corrections, checked three separate ways
after the upload with all three agreeing. Everything was added on top; nothing was
overwritten or forced. One further save carries this write-up, and it is checked
the same way.

**(d) The three things I am least certain about.**

1. **The commercials feature is live and we are ignoring it.** The new contract
   has a whole section on a route the server is now running that this app does not
   call. Your brief said that one is yours to raise, so I read only enough to know
   it exists and left it completely alone. It is the most obvious thing waiting.
2. **Nobody has compared our trash code against the new written contract.** We
   built it from what the live server actually returned; the contract now describes
   the same thing from the source. They agreed on everything I compared, but I did
   not check every field, and our decoder is deliberately strict — so a difference
   would show up as a broken screen rather than a quiet one.
3. **The version in the notebook is now something we were told, not something we
   measured.** That is what you asked for and it is labelled as such. But it is a
   different kind of fact from the rest of the file, and if it ever matters, the
   only way to settle it is a single read of the server that needs your say-so.

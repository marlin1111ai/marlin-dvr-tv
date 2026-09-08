# Pass 35 — context refresh recon

**Date:** 2026-09-08
**Type:** read-only recon. No edits, no commits, no pushes, no network beyond one
`git fetch` in this repo (step 1 required it).
**Working tree:** `~/Xcode/Marlin DVR TV`. Exactly one file written: this report.
**Reference clone:** `~/Xcode/marlin-dvr-reference` — read this pass, as the brief
explicitly permits. Not fetched, not pulled, not edited, not run from.

Read first, and not re-derived: `COLD-START.md` and `DECISIONS.md` in this repo.
This pass adds no facts to either.

---

## 1. The true remote state of `marlin-dvr-tv`

`git fetch` was run first and exited 0 with no output (nothing to bring down).

```
$ cd ~/Xcode/Marlin\ DVR\ TV
$ git fetch
(no output, exit 0)

$ git rev-parse HEAD
aad7992e1765463561f26d3b290cb2e5f5489018

$ git rev-parse origin/main
aad7992e1765463561f26d3b290cb2e5f5489018

$ git ls-remote origin main
aad7992e1765463561f26d3b290cb2e5f5489018	refs/heads/main

$ git status --porcelain
(no output)
```

| Value | SHA |
|---|---|
| local `HEAD` | `aad7992e1765463561f26d3b290cb2e5f5489018` |
| `origin/main` (local remote-tracking ref, after fetch) | `aad7992e1765463561f26d3b290cb2e5f5489018` |
| `git ls-remote origin main` (the remote's own answer) | `aad7992e1765463561f26d3b290cb2e5f5489018` |

**The three SHAs agree.** All three are `aad7992`. The working tree is clean —
`git status --porcelain` printed nothing, so there are no modified, staged or
untracked files. The stop-and-report condition for step 1 did **not** fire.

**The answer is `aad7992`, not `93de296`.**

```
$ git log -1 --format='%H %cd %s'
aad7992e1765463561f26d3b290cb2e5f5489018 Mon Sep 7 22:16:06 2026 -0400 Pass 34: record the notebook push's own verification
```

`93de296` is the previous commit and was correct at the moment Pass 34's notebook
text was written; Pass 34 then made one further commit (recording its own push
verification) and pushed it. `COLD-START.md` therefore still says
`origin/main` is at `93de296` — one commit behind the truth. **Nothing was
changed about that this pass**; it is reported, not fixed. See OPEN QUESTIONS 1.

---

## 2. What version the reference clone is at

The clone exists and is a git repository (`git rev-parse --is-inside-work-tree`
→ `true`). No fetch or pull was run in it.

**a. The version string**

```
$ cd ~/Xcode/marlin-dvr-reference
$ sed -n '38p' cmd/marlin-dvr/main.go
	appVersion = "1.2.1"
```

In context (`cmd/marlin-dvr/main.go:35-41`):

```go
const (
	appName    = "marlin-dvr"
	appVersion = "1.2.1"
	appBuild   = "2026.09.05"
	webDir     = "web"
)
```

**b. The clone's HEAD**

```
$ git log -1 --format='%H %cd %s'
9325d94439ef4c9db637c5014ff79f41d1f63956 Sun Sep 6 09:36:55 2026 -0400 Pass 26 report: pushed SHA
```

Branch `main`. `git status --porcelain` in the clone shows one untracked file,
`?? README-REFERENCE.md` — pre-existing, not created or touched by this pass.
`git diff --stat HEAD -- COLD-START.md HLS-CLIENT-API.md` is empty, so the
working-tree copies of both files are byte-identical to the checked-out commit.

**c. Does `GET /api/library/trash` appear in the clone's Go source?**

**No.**

```
$ grep -rn "GET /api/library/trash" --include="*.go" .
(no matches, exit 1)
```

The only occurrences of that path in Go source are the **POST** empty-trash
route, which is a different endpoint:

```
cmd/marlin-dvr/trash.go:217:// POST /api/library/trash/empty — General → Quick Actions → "Empty Trash".
cmd/marlin-dvr/main.go:285:	mux.HandleFunc("POST /api/library/trash/empty", a.handleEmptyTrash)
```

Every `/api/library` route registered in the clone's checkout
(`cmd/marlin-dvr/main.go`):

```
220:	mux.HandleFunc("POST /api/library/recreate", a.handleLibraryRecreate)
275:	mux.HandleFunc("GET /api/library", a.handleLibrary)
276:	mux.HandleFunc("POST /api/library/scan", a.handleLibraryScan)
277:	mux.HandleFunc("GET /api/library/shows/{id}", a.handleShow)
278:	mux.HandleFunc("PUT /api/library/recordings/{id}", a.handleRecordingState)
279:	mux.HandleFunc("PUT /api/library/recordings/{id}/metadata", a.handleRecordingMeta)
280:	mux.HandleFunc("GET /api/library/recordings/{id}/mediainfo", a.handleMediaInfo)
281:	mux.HandleFunc("GET /api/library/recordings/{id}/segments", a.handleSegments)
282:	mux.HandleFunc("GET /api/library/recordings/{id}/thumb.jpg", a.handleThumb)
283:	mux.HandleFunc("POST /api/library/recordings/{id}/thumb", a.handleUpdateThumb)
285:	mux.HandleFunc("POST /api/library/trash/empty", a.handleEmptyTrash)
```

There is no trash **listing** route of any kind.

**The clone's checkout has not moved past 1.2.1.** It is at 1.2.1, dated
2026-09-06 09:36, and has none of 1.6.0.

**d. A finding the brief did not ask for, but which changes step 4's answer**

The clone holds a **fetched-but-unmerged `origin/main`** — objects a previous
pass downloaded and never checked out. Reading it is a local object read; no
network was used and nothing in the clone was modified.

```
$ git for-each-ref --format='%(refname) %(objectname:short) %(committerdate:iso)'
refs/heads/main 9325d94 2026-09-06 09:36:55 -0400
refs/remotes/origin/HEAD fba51f2 2026-09-06 19:42:50 -0400
refs/remotes/origin/main fba51f2 2026-09-06 19:42:50 -0400

$ git log -1 --format='%H %cd %s' origin/main
fba51f2504571147aefdc8e39ec67d1453d4c999 Sun Sep 6 19:42:50 2026 -0400 Pass 34 report: pushed SHA
```

That ref is marlin-dvr's own **Pass 34**, and it is what Pass 18 of this project
read (`reports/2026-09-06-pass18-radio-recon.md:10-12` names `fba51f2` and the
same file md5). It is newer than the checkout — but it is **still not 1.6.0**:

```
$ git show origin/main:cmd/marlin-dvr/main.go | sed -n '38p'
	appVersion = "1.4.0"

$ git grep -n "GET /api/library/trash" origin/main -- "*.go"
(no matches, exit 1)
```

At `origin/main` the `/api/library` route list is unchanged in kind — still no
listing route, and `POST /api/library/trash/empty` (`main.go:312`) is still the
only trash path. **Nothing anywhere in the clone, at any ref, knows about
1.6.0 or about `GET /api/library/trash`.**

---

## 3. The clone's two context files

### 3a. `~/Xcode/marlin-dvr-reference/COLD-START.md` (working-tree copy, 524 lines)

**The version it states.** The file carries no "this document describes version
X" header. The version it records is the one the container is running, at
`COLD-START.md:32`:

> The Unraid container runs `:1.2.1` since 2026-09-06 09:30 (Pass 26)

The highest version number anywhere in the file is **1.2.1**. Every
`1.x.y` marlin-dvr version string it contains is one of 1.1.0, 1.2.0, 1.2.1
(`grep -o` over the whole file; the only other match, `1.27.1`, is the Go
toolchain version on marlinpc).

**The newest dated entry / pass number.** Newest pass is **Pass 26**; newest date
is **2026-09-06**. `COLD-START.md:506-510`:

> Published as 1.2.1
> (`reports/2026-09-06-pass25-version-1-2-1.md`) and running on Unraid
> since 09:30 on 2026-09-06 — the container refreshed the credential 20
> seconds after start and loaded 163 programmes on 21 channels
> (`reports/2026-09-06-pass26-deploy-record.md`).

`grep -o "Pass [0-9]\+"` sorted numerically ends at Pass 26.
`grep -o "2026-[0-9][0-9]-[0-9][0-9]"` sorted ends at 2026-09-06.

**Does it mention the container running `:1.6.0`?** **No.**

```
$ grep -n "1\.6" COLD-START.md
(no matches, exit 1)
```

The string `1.6` does not occur in the file at all — not as a version, not
anywhere.

**Does it mention `GET /api/library/trash`?** **No.**

```
$ grep -n "GET /api/library/trash" COLD-START.md
(no matches, exit 1)
$ grep -n "library/trash" COLD-START.md
(no matches, exit 1)
```

### 3b. `~/Xcode/marlin-dvr-reference/HLS-CLIENT-API.md` (working-tree copy, 275 lines)

**The version it states.** Stated outright in its own header, `HLS-CLIENT-API.md:3-6`:

> For the builder of the Marlin DVR TV (tvOS) app. Everything here is a
> fact about the server as pushed at `ed49d64`, running version **1.1.0**
> (image `ghcr.io/marlin1111ai/marlin-dvr:1.1.0`); every claim cites the
> file and line it comes from. Nothing here is a proposal.

`grep -n "1\.[0-9]\.[0-9]"` over the whole file returns **only** lines 4 and 5 —
those two. **1.1.0 is the only version number in the document.**

**The newest dated entry / pass number.** Newest pass referenced is **Pass 21**,
at `HLS-CLIENT-API.md:132`:

> * **Live channels — the time-shift buffer (Pass 21).** Output arguments

The only other pass numbers in the file are Pass 4 (`:13`) and Pass 16 (`:237`).
Its two commits in the clone confirm it:

```
$ git log --format='%H %cd %s' -- HLS-CLIENT-API.md
1bb416c58bf2a80b4a5899fb962cd0bedf923974 Sun Sep 6 01:43:51 2026 -0400 Pass 21: live time-shift buffer
82c705509c32e47ea94cfc320e805060f4963865 Sat Sep 5 19:55:26 2026 -0400 Pass 19: 1.1.0 deployed, HLS client note
```

Its section list stops at 8 — `grep -n "^#"` gives §1 Registering a client,
§2 Starting an HLS session, §3 Recordings, §4 Live channels and cameras,
§5 Playlist and segments, §6 Idle watchdog, §7 Errors, §8 What is not there.
There is **no §9 and no radio content**: `grep -in "radio"` returns no matches.
`grep -n "hint only"` returns no matches.

**This matters, because this project has already cited a newer copy.** Pass 18/19
of this project quote `HLS-CLIENT-API.md:297` and `HLS-CLIENT-API.md:310-312,316`
and refer to "the contract's §9" (`DECISIONS.md`, 2026-09-06 Pass 19;
`COLD-START.md`, Pass 18). **Those citations do not resolve against the copy
sitting in the clone's working tree** — that copy is 275 lines and has no §9. They
resolve against the clone's fetched `origin/main`, which is a different, longer
document:

```
$ git show origin/main:HLS-CLIENT-API.md | wc -l
     320
$ git show origin/main:HLS-CLIENT-API.md | md5
0726d2c2bd3010d84e3a75846501c5f8
$ git show origin/main:HLS-CLIENT-API.md | sed -n '277p'
## 9. Radio stations (Pass 33 — not HLS, not a play session)
$ git show origin/main:HLS-CLIENT-API.md | sed -n '297p'
| `format` | the label the owner typed (e.g. `AAC`, `MP3`) — **a hint only** |
```

That is exactly the 320 lines and md5 `0726d2c2bd3010d84e3a75846501c5f8` that
Pass 18 recorded. So the app's radio citations are sound — but anyone reading the
clone's **checked-out** file, as step 3 asks, will not find them, and will not
find §9 at all.

**The `origin/main` copies, for completeness.** Neither is 1.6.0-era either:

| File, at `origin/main` (`fba51f2`) | Version it states | Newest pass | `1.6.0`? | `GET /api/library/trash`? |
|---|---|---|---|---|
| `COLD-START.md` | container running `:1.3.1`; `:1.4.0` published, pinned, **not yet deployed** (`:32`) | Pass 34 (`:579`) | no (`grep "1\.6"` → no matches) | no (`grep "library/trash"` → no matches) |
| `HLS-CLIENT-API.md` | still **1.1.0** in its header (`:4-5`), unchanged, though §9 was added at their Pass 33 | Pass 33 (§9 heading, `:277`) | no | no (`grep -i trash` → no matches) |

`COLD-START.md` at `origin/main`, line 32, verbatim fragment:

> `:1.4.0` (radio stations) is published and pinned but not yet deployed

---

## 4. Conclusion

**No. There are no 1.6.0-era copies of `COLD-START.md` or `HLS-CLIENT-API.md`
anywhere in the reference clone — not in its checkout (1.2.1, their Pass 26) and
not even in the newer `origin/main` it has already fetched (1.4.0, their Pass 34,
still describing a container running 1.3.1) — so current copies have to be
requested from the marlin-dvr project, or the owner has to move the clone
forward and the marlin-dvr project has to have written them in the first place.**

---

## OPEN QUESTIONS

Raised, not acted on. Nothing below was built, changed or worked around.

1. **This repo's `COLD-START.md` says `origin/main` is at `93de296`; it is at
   `aad7992`.** The next-step section reads "`origin/main` is at **`93de296`**,
   verified against local HEAD and `git ls-remote`". That was true when Pass 34
   wrote the sentence and stopped being true when Pass 34 made its final commit
   and pushed it. What breaks without a fix: a future pass trusting the notebook
   over `git` starts from a commit that is one behind, and may believe there is
   an unpushed commit when there is not. One-line notebook edit; **out of scope
   this pass and deliberately not made.**

2. **The clone's checked-out `HLS-CLIENT-API.md` does not contain the §9 this
   project cites.** `DECISIONS.md` (Pass 19) cites `HLS-CLIENT-API.md:297` for
   the `format` "a hint only" rule; the clone's working-tree file is 275 lines
   with no §9 and no radio section. The citation resolves only against the
   clone's fetched `origin/main` (320 lines). What breaks without a fix: anyone
   verifying a radio decision by opening the file in the clone concludes the
   citation is wrong. The clone's working tree needs to be moved forward — the
   owner's job, explicitly out of scope here. **Should this project's notebook
   record which ref its contract citations are against?**

3. **Is 1.6.0 documented at all on the marlin-dvr side yet?** This pass can only
   say the clone does not have it. The clone's newest fetched object is their
   Pass 34 from 2026-09-06 19:42, and 1.6.0 reached this project as owner
   statements on 2026-09-07 plus measurements against the running server. Whether
   marlin-dvr has since written a 1.6.0 `COLD-START.md`, and whether
   `HLS-CLIENT-API.md` has been updated past its 1.1.0 header at all, is
   **unknown from here** and cannot be learned without fetching — which this pass
   is forbidden to do. It is the first thing to ask the marlin-dvr project.

4. **`HLS-CLIENT-API.md`'s header has never been updated.** Even at their Pass 34
   (1.4.0 published) the document still opens "as pushed at `ed49d64`, running
   version **1.1.0**", while its body has gained Pass 16, 21 and 33 material.
   Pass 18 of this project noted the same thing. A refreshed copy may therefore
   still carry a stale version header even when its content is current — so
   "what version does it say" is not a reliable freshness test for that file;
   its newest pass number is. Nothing to fix here; a caution for whoever asks.

5. **Nothing was verified against the running server.** The brief forbids
   contacting 192.168.1.250, and nothing did. Every 1.6.0 fact in this project's
   notebook rests on earlier passes' measurements, and this pass neither
   confirmed nor challenged any of them.

---

## SCOPE CHECK

**Files written in `~/Xcode/Marlin DVR TV`: exactly one.**

| Path | Access | Required by |
|---|---|---|
| `reports/2026-09-08-pass35-context-refresh-recon.md` | **written** (this file) | DELIVERABLE |

**Files read (no writes anywhere else, in either tree).**

| Path | Access | Required by |
|---|---|---|
| `~/Xcode/Marlin DVR TV/COLD-START.md` | read | "WHAT TO READ FIRST" |
| `~/Xcode/Marlin DVR TV/DECISIONS.md` | read | "WHAT TO READ FIRST" |
| `~/Xcode/Marlin DVR TV/reports/2026-09-06-pass18-radio-recon.md` | read (lines 8-32) | step 3 / step 4 — to identify which copy of `HLS-CLIENT-API.md` this project's §9 citations were made against |
| `~/Xcode/marlin-dvr-reference/cmd/marlin-dvr/main.go` | read | step 2 (version string; route list) |
| `~/Xcode/marlin-dvr-reference/**/*.go` | read via `grep`/`find` | step 2 (`GET /api/library/trash` search) |
| `~/Xcode/marlin-dvr-reference/COLD-START.md` | read | step 3 |
| `~/Xcode/marlin-dvr-reference/HLS-CLIENT-API.md` | read | step 3 |
| `~/Xcode/marlin-dvr-reference` git objects at `origin/main` | read via `git show`/`git grep`/`git log` (local objects only, no network) | step 4 — whether a 1.6.0-era copy is already present in the clone |

**Commands that touched the network: one.** `git fetch` in
`~/Xcode/Marlin DVR TV`, required by step 1. It brought nothing down and moved
nothing.

**Not done, per the scope lock:** no fetch, pull or update in the reference clone;
no file copied out of the clone; no edit to `COLD-START.md`, `DECISIONS.md` or any
notebook file; no edit to any Swift, project or config file; no commit and no push,
including of this report; no contact with 192.168.1.250 or any other host on the
do-not-touch list; nothing fixed, tidied or flagged in code. `design/` was not
opened. No processes left running; no half-written files.

**Credential scan.** All command output was reviewed before it was quoted here.
No tokens, passwords, tuner DeviceAuth values, source URLs or account credentials
appear in this report. Two identifier classes were deliberately **not** reproduced
even though they sit in lines this pass read: the UNAS4Pro share's device id in
the clone's `COLD-START.md:32` Unraid mount path, and the full text of that line
generally. Image digests, git SHAs, LAN addresses already in this project's
notebook, and repo-relative paths are kept — they are the evidence.

---

## CLOSING SUMMARY FOR THE OWNER

**(a) What the real commit number is.**
`aad7992`. Your computer, your local record of GitHub, and GitHub itself all say
the same thing, so there is no disagreement to sort out and nothing waiting to be
sent. The older number `93de296` is the commit just before it. The project's own
notes still say `93de296`, because that note was written moments before the last
commit of Pass 34 was made — the note is one step behind, the code is not. I did
not change the note, as fixing things was not part of this job.

**(b) Whether the server reference copy knows about 1.6.0 yet.**
No. The copy of the server code on this Mac is at version **1.2.1** and dated
2 September days ago in project terms — 6 September. It does not contain the new
trash-listing feature, and the words "1.6" do not appear in it anywhere. There is
also a slightly newer batch of server code already downloaded onto this Mac but
never opened up — that one is at **1.4.0** — and it does not know about 1.6.0
either. So there is nothing on this machine that describes the server you are
actually running.

**(c) Whether we can refresh those two context files ourselves.**
No — they have to come from the marlin-dvr project. The two files we want are
their cold-start notes and their client API note. The newest versions on this
machine describe a server running 1.3.1 with 1.4.0 waiting to be installed, which
is behind where you actually are. Updating the local copy is your job, not this
project's, and even if it were updated, someone on the marlin-dvr side has to have
written the 1.6.0 versions in the first place — which we cannot tell from here.

**(d) The three things I am least certain about.**

1. **Whether marlin-dvr has actually written 1.6.0 versions of those two files.**
   I can only prove what is on this Mac. If nobody over there has updated them,
   asking will not produce anything and the facts will have to keep coming from
   you and from measuring the live server, the way they have since 7 September.
2. **Whether the client API note is trustworthy as a version marker.** Its
   opening line has said "version 1.1.0" through at least three server releases
   while its contents kept growing. So a refreshed copy might still be labelled
   with an old version and yet be current — or be labelled anything and be stale.
   I would not judge that file by its header.
3. **Whether the mismatch I found in the radio section matters in practice.**
   The project's notes cite a part of the client API note that is simply not in
   the copy sitting on this Mac's disk — it exists only in the downloaded-but-not-
   opened newer batch. The app was built correctly against the right text, so I
   do not think anything is broken; but if a future session checks that citation
   by opening the obvious file, it will look wrong, and I could not rule out that
   some other citation has the same problem without checking every one.

---

# Pass 35B — notebook fix

**Date:** 2026-09-08
**Type:** notebook only. No code changes. Two sentences in `COLD-START.md`, then a
commit and a push in the same pass (notebook work has no separate push gate).
**Facts:** every fact written into the notebook this pass comes from the Pass 35
report above. Nothing new was measured, no host was contacted, and the reference
clone was not read, fetched, pulled or entered.

Both sentences named in the brief matched what was described, so neither
stop-and-report condition fired. Neither was guessed at.

---

## 1. The "Next step" SHA sentence

Found at `COLD-START.md:455-456`, inside `## Next step` (`:451`).

**Before** (verbatim, the two lines as they wrapped):

> and Pass 34 pushed all of them. `origin/main` is at **`93de296`**, verified against local HEAD and
> `git ls-remote` (`reports/2026-09-07-pass34-push-notebook.md`).

**After** (verbatim):

> and **Pass 34 pushed Passes 31, 32, 32A and 33** on 2026-09-07
> (`reports/2026-09-07-pass34-push-notebook.md`). **On 2026-09-08 Pass 35 verified that push:** local
> HEAD, `origin/main` and `git ls-remote origin main` all read `aad7992`, and the working tree was
> clean (`reports/2026-09-08-pass35-context-refresh-recon.md`).

It now records **a dated event that was verified**, not a value that claims to be
current. `93de296` was never wrong as history — it was wrong as a standing claim,
because Pass 34 wrote the line and then made one further commit and pushed it, so
the sentence was already one behind when it landed. The new form survives every
later commit: `aad7992` is what Pass 35 measured on 2026-09-08, and it stays what
Pass 35 measured on 2026-09-08 no matter where `main` goes afterwards.

**The forbidden form is gone from the whole file**, asserted rather than assumed:

```
$ grep -n "origin/main\` is at\|origin/main is at" COLD-START.md
(no matches, exit 1)
```

The preceding sentence in the same paragraph — "The owner accepted Passes 31, 32,
32A and 33 on Home Theater — delete refresh, Stop recording from the Guide, the
trash list off the new server endpoint, and Restore —" — is untouched, and the
paragraph now names those four passes twice: once as what the owner accepted, once
as what Pass 34 pushed. That repetition is deliberate, so the push sentence stands
on its own if the acceptance sentence is ever moved.

## 2. The "What the app is" paragraph

Found at `COLD-START.md:5`, the whole of the paragraph under `## What the app is`.

**Before** (verbatim, one line):

> Marlin DVR TV is a tvOS app (SwiftUI) that will be a client of the Marlin DVR server — a Go DVR server running as a Docker container on Unraid at http://192.168.1.250:8090/ , source repo git@github.com:marlin1111ai/marlin-dvr.git . Pass 1 (2026-09-05) created the empty Xcode project and the plumbing only. No app features are written.

**After** (verbatim, one line):

> Marlin DVR TV is a tvOS app (SwiftUI) and a client of the Marlin DVR server — a Go DVR server running as a Docker container on Unraid at http://192.168.1.250:8090/ , source repo git@github.com:marlin1111ai/marlin-dvr.git . What is built is listed under "What is built" below.

Three changes, and nothing else in the paragraph moved:

- **"that will be a client" → "and a client"**. The app has been a working client
  since Pass 5.
- **"No app features are written." → removed.** False since Pass 5 and the most
  actively misleading sentence in the file, since it is the fourth line a new
  reader sees.
- **"Pass 1 (2026-09-05) created the empty Xcode project and the plumbing only."
  → replaced by a pointer to "What is built".** Disclosed plainly because it is a
  deletion the brief did not spell out: that Pass 1 history is **not lost**, it is
  carried verbatim by the sentence at the head of `## What is built`, which the
  brief protects and which this pass did not touch. Keeping both would have left
  an opening paragraph that describes a built app and then immediately says only
  the plumbing exists. If the owner wants the Pass 1 clause back in the opening
  paragraph, it is a one-line restore. See OPEN QUESTIONS 1.

**The protected sentence is untouched**, asserted:

```
$ sed -n '56p' COLD-START.md
The empty project — Pass 1 was plumbing. One app entry point (`Marlin_DVR_TVApp.swift`) and one `ContentView` showing the app name.
```

The server URL and the source repo the paragraph already carried are both kept,
character for character, including the file's existing spacing around them. The
`"What is built"` quotation marks are straight, matching the file's convention —
one curly pair was introduced by the first draft of this edit and normalised
before the commit; the file now contains none (`grep -c '[“”]'` → `0`).

## 3. The diff, in full

Two hunks. Nothing else in the file changed.

```diff
--- a/COLD-START.md
+++ b/COLD-START.md
@@ -2,7 +2,7 @@
 
 ## What the app is
 
-Marlin DVR TV is a tvOS app (SwiftUI) that will be a client of the Marlin DVR server — a Go DVR server running as a Docker container on Unraid at http://192.168.1.250:8090/ , source repo git@github.com:marlin1111ai/marlin-dvr.git . Pass 1 (2026-09-05) created the empty Xcode project and the plumbing only. No app features are written.
+Marlin DVR TV is a tvOS app (SwiftUI) and a client of the Marlin DVR server — a Go DVR server running as a Docker container on Unraid at http://192.168.1.250:8090/ , source repo git@github.com:marlin1111ai/marlin-dvr.git . What is built is listed under "What is built" below.
 
 ## Where things live
 
@@ -452,8 +452,10 @@
 
 **Nothing is unpushed.** The owner accepted Passes 31, 32, 32A and 33 on Home Theater — delete
 refresh, Stop recording from the Guide, the trash list off the new server endpoint, and Restore —
-and Pass 34 pushed all of them. `origin/main` is at **`93de296`**, verified against local HEAD and
-`git ls-remote` (`reports/2026-09-07-pass34-push-notebook.md`).
+and **Pass 34 pushed Passes 31, 32, 32A and 33** on 2026-09-07
+(`reports/2026-09-07-pass34-push-notebook.md`). **On 2026-09-08 Pass 35 verified that push:** local
+HEAD, `origin/main` and `git ls-remote origin main` all read `aad7992`, and the working tree was
+clean (`reports/2026-09-08-pass35-context-refresh-recon.md`).
 
 Waiting to be picked up, in no particular order: **the series-pass sheet chip**, the first thing a
 later pass should take, since it is a wrong control the owner can press today; **stopping a pass's
```

## 4. The commit and the push

One commit carrying both edits and the Pass 35 report exactly as it already stood,
then a push to `origin main`.

```
$ git commit -F - (message: "Pass 35: context refresh recon, and two stale notebook sentences fixed")
[main c8ae078] Pass 35: context refresh recon, and two stale notebook sentences fixed
 2 files changed, 436 insertions(+), 3 deletions(-)
 create mode 100644 reports/2026-09-08-pass35-context-refresh-recon.md

$ git push origin main
To github.com:marlin1111ai/marlin-dvr-tv.git
   aad7992..c8ae078  main -> main
```

**A fast-forward**, `aad7992..c8ae078` — the two dots and no `+` are git's own way
of saying so. Nothing was forced, rebased or amended.

## 5. Push verification (step 4)

Run after the push, `git fetch` first. Each command was run on its own; the raw
output follows.

```
$ git fetch
(no output)

$ git rev-parse HEAD
c8ae078c46023a268e58238db215fad17041cdf6

$ git rev-parse origin/main
c8ae078c46023a268e58238db215fad17041cdf6

$ git ls-remote origin main
c8ae078c46023a268e58238db215fad17041cdf6	refs/heads/main

$ git status --porcelain
(no output)

$ git rev-list --left-right --count origin/main...HEAD
0	0
```

| Value | SHA |
|---|---|
| local `HEAD` | `c8ae078c46023a268e58238db215fad17041cdf6` |
| `origin/main` (after fetch) | `c8ae078c46023a268e58238db215fad17041cdf6` |
| `git ls-remote origin main` (the remote's own answer) | `c8ae078c46023a268e58238db215fad17041cdf6` |

**All three agree at `c8ae078`.** The working tree is clean, and the branch is
level in both directions — 0 commits ahead, 0 behind. The stop-and-report
condition for step 4 did **not** fire.

Note on what this section can and cannot prove: **a commit cannot contain its own
SHA**, so the verification above measures commit `c8ae078` and is itself written
into the commit that follows it — the same shape Pass 30 and Pass 34 used. That
following commit — this section — is pushed and verified the same way, but its
verification cannot live inside itself: it is reported to the owner in this pass's
closing summary, and read from git by any later pass that wants it in the notebook.

---

## OPEN QUESTIONS

Raised, not acted on.

1. **The Pass 1 clause was dropped from the opening paragraph, not just reworded.**
   The brief protected "the Pass 1 sentence at the head of that section" — read as
   the one in `## What is built`, which is untouched. The *other* Pass 1 clause,
   the one inside the paragraph being rewritten, was removed as part of the
   rewrite. Nothing is lost: the sentence below carries the same history verbatim.
   What breaks if that reading was wrong: the opening paragraph no longer dates the
   project's start. One-line restore if the owner wants it back.

2. **"Nothing is unpushed." is the same class of standing claim, and was left
   alone.** It opens the paragraph edited in step 1 and will go stale the moment a
   pass commits without pushing — exactly the failure mode step 1 was written to
   remove. It happens to be **true right now** (verified in section 5), so it was
   not touched: the brief named one sentence and the scope lock forbids improving
   the rest. **Should a later pass give it a date too, or delete it as a claim the
   notebook cannot keep honest?**

3. **Pass 35B's own push is recorded in this report, not in `COLD-START.md`.**
   Step 1 fixed the wording of an existing sentence; it did not ask for a new
   event to be added, and none was invented. So `COLD-START.md` still names
   `aad7992`/2026-09-08 as its most recent verification, while the remote moved on to
   `c8ae078` and then to the commit carrying this section. That is correct under the new form — it is a dated record of what
   Pass 35 verified, not a claim about the present — but a reader wanting the
   current SHA must run `git`, which is the intended behaviour. Flagged so nobody
   later reads it as a second staleness bug and "fixes" it back into a standing
   value.

4. **Open Question 2 of the Pass 35 report is untouched**, as the brief requires:
   the `HLS-CLIENT-API.md:297` citation still resolves only against the reference
   clone's fetched `origin/main`, not against its checked-out file. Nothing was
   done about it and nothing about it changed.

---

## SCOPE CHECK

| Path | Access | Required by |
|---|---|---|
| `~/Xcode/Marlin DVR TV/COLD-START.md` | read, then **edited** — two sentences, two diff hunks | steps 1 and 2 (and "WHAT TO READ FIRST") |
| `~/Xcode/Marlin DVR TV/reports/2026-09-08-pass35-context-refresh-recon.md` | read, **committed as it stood**, then **appended to** (this section) | "WHAT TO READ FIRST", step 3, DELIVERABLE |

**Nothing else in either tree was read, opened or changed.** A copy of
`COLD-START.md` was taken into the session scratchpad before the edit as a
pre-change snapshot; it is outside the repo and outside the project folder.

**Git actions:** `git add`, `git commit`, `git push origin main`, `git fetch`,
`git rev-parse`, `git ls-remote`, `git status`, `git rev-list`, `git diff`,
`git log`. **No force, no rebase, no amend, no reset, no merge.** Both pushes were
fast-forwards.

**Not done, per the scope lock:** no Swift, project, entitlement or config file
edited — none was opened; `DECISIONS.md` not edited; no other file under
`reports/` edited; `HLS-CLIENT-API.md`, `MARLIN-DVR-SERVER-COLD-START.md` and
`MARLIN-DVR-TV-HANDOFF-2026-09-08.md` not edited; Open Question 2 of the Pass 35
report not acted on; nothing copied out of the reference clone, which was not
read, entered, fetched or pulled this pass; `design/` not opened; no contact of
any kind with 192.168.1.250 or any other host on the do-not-touch list; no other
part of `COLD-START.md` tidied, reformatted, reordered or improved. No processes
left running, no half-written files.

**Credential scan.** Every line quoted above was reviewed before it was written.
No tokens, passwords, tuner DeviceAuth values, source URLs, account identifiers or
device ids appear. The two identifiers that do appear — the LAN address
`192.168.1.250:8090` and the public source repo `marlin1111ai/marlin-dvr` — were
already in the edited paragraph before this pass, are the owner's own, and are
kept because removing them was not asked for and they are what the paragraph is
for.

---

## CLOSING SUMMARY FOR THE OWNER

**What the two sentences now say.**

The first one, in "Next step", used to say the project's latest saved point *is*
a number. It now says what happened and when: Pass 34 sent up the four accepted
pieces of work on 7 September, and on 8 September Pass 35 checked that it had
really arrived — your machine, your record of GitHub, and GitHub itself all
agreed. Written that way it stays true forever, because it describes a check that
happened on a day rather than making a claim about right now that goes out of date
the next time anything is saved.

The second one, the very first paragraph of the file, used to say the app "will
be" a client of your DVR and that no features were written. That was true on day
one and has been wrong since the fifth work session. It now says plainly that the
app *is* a tvOS client of your DVR server, and points the reader down to the "What
is built" list for the details. The server address and the server's source repo
are unchanged. The sentence recording that the first session built only the empty
project is still in the file, in the "What is built" section, exactly as it was.

**What is on the remote.** `c8ae078` — checked three separate ways after the
upload, all three agreeing, with nothing left over on this machine. Everything
was added on top; nothing was overwritten, rewritten or forced. There will be one
more save straight after this one, carrying this write-up, and it is checked the
same way.

**The three things I am least certain about.**

1. **Whether you wanted the "first session built only the plumbing" line kept in
   that opening paragraph.** I took it out, because the identical fact sits a few
   lines further down in a section you told me not to touch, and keeping both
   would have had the paragraph contradict itself. If you want it back, it is a
   one-line change.
2. **Whether "Nothing is unpushed." should have been fixed at the same time.** It
   sits at the front of the very paragraph I rewrote and it is the same kind of
   promise that cannot stay true on its own. It happens to be true today, and you
   named one sentence, so I left it. It is the obvious next thing to tidy.
3. **Whether the file should carry the current save number at all.** As it stands,
   the notebook records checks that happened on dates, and anyone wanting today's
   number has to ask git. I think that is right — it is what stopped the file
   being wrong in the first place — but it does mean the file will never again
   tell you at a glance where things stand.

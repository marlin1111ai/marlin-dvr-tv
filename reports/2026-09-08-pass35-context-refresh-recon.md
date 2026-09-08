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

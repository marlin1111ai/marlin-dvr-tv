# Pass 60 — one source of truth for the rules

**Date:** 2026-09-09.
**Documentation and git only.** No Swift source file, no asset catalog file, no artwork and no
project setting was touched. **No build, no install, no test, no device run. No request of any kind
to `192.168.1.250:8090`.** `design/`, `~/Xcode/marlin-dvr-reference` and every other folder under
`~/Xcode` were not opened; no existing report was edited or deleted; `icon-source/` was left
untouched. Files were staged by name.

**What the pass does:** the standing rules existed in two hand-maintained copies —
`COLD-START.md`'s "The rules" and `CLAUDE.md` — which had already drifted apart in three places.
Passes 57, 58 and 59 each raised it. This pass makes `CLAUDE.md` the only copy, and settles the
second recurring question: **who records a pass's own push.**

---

## 1. Step 1 — the pre-pass state

```
$ git fetch origin
(no output)

$ git rev-parse main
77bf616bf995759cc8e3e693080fb5642a1d01c4
$ git rev-parse origin/main
77bf616bf995759cc8e3e693080fb5642a1d01c4
$ git ls-remote origin main
77bf616bf995759cc8e3e693080fb5642a1d01c4	refs/heads/main
```

**They match**, at Pass 59's commit `77bf616`, read back from GitHub as well as from the
remote-tracking ref.

```
$ git diff HEAD --stat
(empty — no uncommitted tracked changes)

$ git status --porcelain
?? icon-source/
```

**No uncommitted tracked changes**, so the step 1 stop did not fire.

## 2. The two lists, before anything was deleted

```
$ sed -n '18,25p' COLD-START.md | wc -l      # COLD-START.md "The rules"
8
$ grep -c "^- " CLAUDE.md                     # CLAUDE.md bullets
9
```

## 3. Step 3 — no rule lost, checked bullet by bullet before deleting

Every one of `COLD-START.md`'s eight rules was tested for a byte-identical match in `CLAUDE.md`
**before** the deletion in step 2 was applied:

```
$ while IFS= read -r line; do
    if grep -Fxq -e "$line" claude9.txt; then echo "IDENTICAL -> CLAUDE.md:$(...)"; 
    else echo "NO EXACT MATCH -> $line"; fi; done < cold8.txt
[1] IDENTICAL -> CLAUDE.md:5
[2] NO EXACT MATCH -> - Scope lock: nothing not named in a pass's steps gets built or changed; anything extra goes in the report as a question.
[3] IDENTICAL -> CLAUDE.md:7
[4] IDENTICAL -> CLAUDE.md:8
[5] NO EXACT MATCH -> - Nothing force-pushed, ever.
[6] NO EXACT MATCH -> - No secrets in the repo, logs, or reports.
[7] IDENTICAL -> CLAUDE.md:13
[8] IDENTICAL -> CLAUDE.md:12
```

Five matched byte-for-byte. The other three were then examined individually rather than assumed:

```
$ case "$claude10" in "$cold6"*) echo "EXACT PREFIX: yes";; *) echo "EXACT PREFIX: no";; esac
EXACT PREFIX: yes
  COLD-START : - No secrets in the repo, logs, or reports.
  CLAUDE.md  : - No secrets in the repo, logs, or reports. Redact tokens, credentials and device IDs before any commit or report.
  remainder  :  Redact tokens, credentials and device IDs before any commit or report.
```

### The table

| # | COLD-START.md rule | Carried by | Wording |
|---|---|---|---|
| 1 | `Recon before build.` | **CLAUDE.md:5** | **byte-identical** |
| 2 | `Scope lock: nothing not named in a pass's steps gets built or changed; anything extra goes in the report as a question.` | **CLAUDE.md:6** — *"Scope lock: build only what the pass names. Anything extra is a question in the report, never built, not even disabled."* | **reworded** — both clauses carried; adds "never built, not even disabled". See the nuance in §3.1 |
| 3 | `No installs without owner authorization.` | **CLAUDE.md:7** | **byte-identical** |
| 4 | `Separate push gate for code the owner tests.` | **CLAUDE.md:8** | **byte-identical** |
| 5 | `Nothing force-pushed, ever.` | **CLAUDE.md:9** — *"Never force-push and never rewrite history."* | **reworded, strictly stronger** — adds history rewriting |
| 6 | `No secrets in the repo, logs, or reports.` | **CLAUDE.md:10** | **exact prefix** — the original sentence survives verbatim; a redaction clause is appended |
| 7 | `The server repo is read-only reference; server changes, if ever needed, are raised as decisions for the marlin-dvr project.` | **CLAUDE.md:13** | **byte-identical** |
| 8 | `Do not touch: the other folders under ~/Xcode, …` | **CLAUDE.md:12** | **byte-identical** |

**Eight of eight carried. Five byte-identical, one an exact prefix, two reworded and no weaker.
Nothing was lost, so the step 3 stop did not fire.** `CLAUDE.md` additionally holds a ninth bullet of
its own — *"If anything blocks, stop and report. Do not work around it."* — which never existed here.

### 3.1 The one wording nuance, flagged rather than smoothed over

Rule 2 is the only one where `COLD-START.md`'s phrasing is in one respect broader: it said "gets
built **or changed**", and `CLAUDE.md` says "build only what the pass names". The word *changed* is
not literally present. In practice most passes edit documentation rather than build anything, so a
pedantic reading of the surviving wording binds less than the original did. **The rest of that
bullet — "Anything extra is a question in the report, never built, not even disabled" — is stronger
than the original**, and the rule plainly has a counterpart, so this is not a lost rule and step 3's
stop did not apply. **Nothing was changed about it**: step 2 confined this pass to the rules body and
step 4's sentence. Raised in §7.

## 4. Step 2 — the rules body replaced

```
$ git diff -- COLD-START.md
@@ -15,14 +15,7 @@
 ## The rules
 
-- Recon before build.
-- Scope lock: nothing not named in a pass's steps gets built or changed; anything extra goes in the report as a question.
-- No installs without owner authorization.
-- Separate push gate for code the owner tests.
-- Nothing force-pushed, ever.
-- No secrets in the repo, logs, or reports.
-- The server repo is read-only reference; server changes, if ever needed, are raised as decisions for the marlin-dvr project.
-- Do not touch: the other folders under `~/Xcode`, the Marlin DVR server and its data, the Unraid host 192.168.1.250, marlinpc 192.168.1.245, the HDHomeRun 192.168.1.105, the UNAS4Pro share.
+The standing builder rules live in `CLAUDE.md` at the project root. Read it. This file no longer keeps its own copy of them; a rule change is made in `CLAUDE.md` only (DECISIONS.md, 2026-09-09 (Pass 60)).
 
 ## How to build
```

**The heading is kept**, the blank lines around the section are unchanged, and "## How to build"
still follows immediately. The edit was applied by a script that asserted all six surrounding anchors
by content before writing, so it could not have removed the wrong lines.

## 5. Step 4 — one sentence qualified

```
@@ -863,7 +856,7 @@
-**Nothing is unpushed.** The owner accepted **the app icon and Top Shelf art** on Home Theater on
+**Nothing was unpushed as of Pass 55.** The owner accepted **the app icon and Top Shelf art** on Home Theater on
 2026-09-08 and **Pass 55 pushed it** together with Pass 54's report and this notebook work
```

**One sentence, on one line.** The script asserted the old sentence occurred exactly once on that
line before replacing it. The rest of the paragraph — every clause about Pass 55, Pass 50, Pass 48
and back — is byte-for-byte untouched. This closes the double-"nothing is unpushed" reading that
Pass 59 raised: the newer paragraph says "as of Pass 58", this one now says "as of Pass 55".

## 6. The whole COLD-START.md diff — two hunks, nothing else

```
$ git diff --stat -- COLD-START.md
 COLD-START.md | 11 ++---------
 1 file changed, 2 insertions(+), 9 deletions(-)
```

**Two hunks only:** the rules body (step 2) and the one sentence (step 4). Nine deletions = the eight
bullets plus the replaced sentence line; two insertions = the pointer line plus the replaced sentence.
**No other section of the file was touched.** Unlike Pass 59, this pass deletes on purpose — that is
what step 2 asked for, and step 3 proved it safe first.

## 7. Step 5 — the two standing rules recorded

```
$ git diff --stat -- DECISIONS.md
 DECISIONS.md | 32 ++++++++++++++++++++++++++++++++
 1 file changed, 32 insertions(+)
```

**Insertions only.** A new dated section, "2026-09-09 (Pass 60 — one source of truth for the rules)",
recording (a) and (b) explicitly as **standing rules rather than observations**, so a later pass reads
them as binding:

- **(a)** `CLAUDE.md` is the single source of truth for the standing builder rules; `COLD-START.md`
  points at it and no longer carries a copy; **a rule change is made in `CLAUDE.md` only.**
- **(b)** A pass records its own verified push **in its report and in its response to the owner, not
  in a second commit.** Passes 55 and 56 used a follow-up commit; that is not the pattern going
  forward, and **no later pass should re-raise it.** This pass follows (b) itself: one commit, and the
  post-push SHA reported live rather than committed.

## 8. The working tree before the commit

```
$ git status --porcelain --untracked-files=all | grep -v "icon-source/"
 M COLD-START.md
 M DECISIONS.md
?? reports/2026-09-09-pass60-rules-source-of-truth.md

$ git status --porcelain --untracked-files=all | wc -l
35
```

35 entries: **32 are `icon-source/`**, unchanged and untouched, and the other three are this pass's.
**`CLAUDE.md` was read but not modified** — the rules moved *to* it by deletion elsewhere, not by
editing it.

## 9. Open questions — raised, not acted on

1. **A dangling reference this pass creates and was not allowed to fix.** The Pass 58 paragraph in
   "Next step" still reads *"the server-repo rule from the rules list above"* and *"this file's rules
   list holds **eight** rules and the server-repo rule is its seventh"*. **That list no longer exists
   in `COLD-START.md`.** The sentences are true of the moment they describe, and step 2 forbade
   changing anything else in the file, so they stand as written. **Rewording them is a one-line change
   on the owner's word.** Also recorded in `DECISIONS.md` under Pass 60 so it is not mistaken for
   drift.
2. **Scope lock lost the word "changed".** §3.1: `COLD-START.md` bound what "gets built **or
   changed**"; the surviving `CLAUDE.md` wording says "build only what the pass names". Most passes
   edit documentation rather than build, so the literal reading is narrower than the original. The
   rest of that bullet is stronger, and no rule was lost, but **if the owner wants the original
   breadth back it is one word in `CLAUDE.md`** — which, under rule (a), is now the only place to
   change it.
3. **`icon-source/` is still 32 untracked entries** and its fate is still undecided.

**Not carried forward:** the "who records a pass's push" question that Passes 57, 58 and 59 each
raised is **settled** by Pass 60 (b) and is not repeated here.

## 10. Files touched, mapped to step numbers

| File | Step | What happened |
|---|---|---|
| `COLD-START.md` | 2, 4 | **2 insertions, 9 deletions** — "The rules" body replaced by one pointer line (step 2); one sentence in "Next step" qualified (step 4) |
| `DECISIONS.md` | 5 | **32 insertions, 0 deletions** — one new dated Pass 60 section |
| `reports/2026-09-09-pass60-rules-source-of-truth.md` | 6 | **created** — this file |
| `CLAUDE.md` | 3 | **read for the comparison, not modified** |
| `reports/…pass59….md` | — | **read only, not modified** |
| everything else | — | **not touched** |

No Swift source, no asset catalog, no `.pbxproj`, no `.gitignore`, no `design/`, no
`~/Xcode/marlin-dvr-reference`, no `icon-source/` entry, nothing outside this folder, nothing on the
network.

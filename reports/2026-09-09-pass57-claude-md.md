# Pass 57 — the project's CLAUDE.md

**Date:** 2026-09-09.
**Documentation and git only.** No Swift source file, no asset catalog file, no artwork and no
project setting was touched. **No build, no install, no test, no device run. No request of any kind
to `192.168.1.250:8090`.** Nothing under `reports/` was read-modified or deleted; the only write
there is this new file. `design/` was not opened. `icon-source/`, `FocusClick.dataset` and the empty
template brandassets were left exactly as they stand.

**What the pass does:** the standing rules for this project have only ever been stated inside each
pass prompt and in `COLD-START.md`'s "The rules" section. This pass puts them in a `CLAUDE.md` at the
project root, so the builder reads them automatically at the start of every session without the
owner restating them.

---

## 1. Step 1 — the four memory locations, all four absent

Each of the four was checked individually. **None exists.** No project-level `CLAUDE.md` was
present, so the stop-and-report condition in step 1 did not fire and the pass proceeded.

```
$ for f in ./CLAUDE.md ./.claude/CLAUDE.md ./CLAUDE.local.md ~/.claude/CLAUDE.md; do
    if [ -e "$f" ]; then echo "EXISTS: $f"; else echo "ABSENT: $f"; fi; done
ABSENT: ./CLAUDE.md
ABSENT: ./.claude/CLAUDE.md
ABSENT: ./CLAUDE.local.md
ABSENT: /Users/marlin1111/.claude/CLAUDE.md
```

```
$ ls -lad ./.claude
ls: ./.claude: No such file or directory
```

| Location | Result |
|---|---|
| `./CLAUDE.md` | **absent** |
| `./.claude/CLAUDE.md` | **absent** (no `.claude/` directory at all) |
| `./CLAUDE.local.md` | **absent** |
| `~/.claude/CLAUDE.md` | **absent** |

So nothing was overwritten, and no pre-existing instructions were displaced by this pass.

## 2. Step 2 — the pre-pass SHAs, and the one thing in the working tree

```
$ git fetch origin
(no output)
```

```
$ git rev-parse main
8f371a63086dd5fe86ec3dff1d5c05cead250e7f
$ git rev-parse origin/main
8f371a63086dd5fe86ec3dff1d5c05cead250e7f
```

**They match.** Local `main` and `origin/main` were both at `8f371a6` before the pass — the Pass 56
commit.

```
$ git status
On branch main
Your branch is up to date with 'origin/main'.

Untracked files:
  (use "git add <file>..." to include in what will be committed)
	icon-source/

nothing added to commit but untracked files present
```

### 2.1 Why `icon-source/` was not treated as an uncommitted change

Step 2 says not to proceed if there are uncommitted changes. **There were no uncommitted changes.**
The evidence, taken before anything was written:

```
$ git diff HEAD --stat
(empty — no tracked file modified, nothing staged)
```

The single porcelain entry was `?? icon-source/` — an **untracked** directory, not a modification.
It is not this pass's doing and not any pass's doing: `DECISIONS.md` records under
"2026-09-08 (Passes 51–55)" that **"The fate of `icon-source/` is the owner's call and has not been
decided. All 32 of its entries remain untracked … Nothing there has been deleted, moved, renamed or
committed by any pass."** Passes 51, 52, 55 and 56 each recorded the same directory in the same
untracked state.

So it is the repo's standing baseline rather than work in progress, and it carries no risk of being
swept into this pass's commit, because step 7 names three files explicitly and they were added by
name. **It is reported here rather than silently passed over, and it remains untracked and untouched
after the pass** — see §6.

## 3. Step 3 — CLAUDE.md as written

Created at the project root. **12 lines, 883 bytes.** It contains the specified text and nothing
more — no project state, no build notes, no pass history.

```
$ cat CLAUDE.md
# Marlin DVR TV — standing rules for the builder

The record of this project is COLD-START.md and DECISIONS.md at the project root. Read both before any work and do not re-derive what they settle. Per-pass reports live in reports/.

- Recon before build.
- Scope lock: build only what the pass names. Anything extra is a question in the report, never built, not even disabled.
- No installs without owner authorization.
- Separate push gate for code the owner tests.
- Never force-push and never rewrite history.
- No secrets in the repo, logs, or reports. Redact tokens, credentials and device IDs before any commit or report.
- If anything blocks, stop and report. Do not work around it.
- Do not touch: the other folders under `~/Xcode`, the Marlin DVR server and its data, the Unraid host 192.168.1.250, marlinpc 192.168.1.245, the HDHomeRun 192.168.1.105, the UNAS4Pro share.
```

### 3.1 The do-not-touch line is `COLD-START.md`'s, copied word for word

`COLD-START.md` does carry such a list, at line 24 under "The rules", so the stop condition attached
to step 3 did not fire. The line was copied rather than retyped, and the two were then compared as
strings:

```
$ a=$(grep -n "^- Do not touch:" COLD-START.md | head -1 | cut -d: -f2-)
$ b=$(grep "^- Do not touch:" CLAUDE.md)
$ [ "$a" = "$b" ] && echo IDENTICAL || echo DIFFERENT
IDENTICAL
```

Byte-for-byte identical, backticks and all, including the four host addresses as
`COLD-START.md` states them. **No path was added to the list, none was dropped, none reworded.**

### 3.2 What is deliberately *not* in it

The eight rules are the standing ones. **`COLD-START.md`'s ninth rule — "The server repo is
read-only reference; server changes … are raised as decisions for the marlin-dvr project" — is not
in `CLAUDE.md`**, because step 3 specified the file's contents exactly and did not include it. It
remains in force via `COLD-START.md`, which `CLAUDE.md`'s first paragraph points at. Flagged as an
open question in §8 rather than acted on.

## 4. Step 4 — the DECISIONS.md entry

Appended as a new dated section, matching the file's one-section-per-pass convention. It sits under
2026-09-09 directly after "2026-09-09 (Pass 56 — no more handoff briefs)", which it references.

```
$ git diff --stat -- DECISIONS.md
 DECISIONS.md | 19 +++++++++++++++++++
 1 file changed, 19 insertions(+)
```

**Insertions only — no existing line of `DECISIONS.md` was edited, reworded or removed.** The new
section records the three things step 4 named: that the project has a `CLAUDE.md`; that it holds the
standing builder rules and a pointer to the notebook only, never project state; and that the
notebook remains the record.

## 5. Step 5 — nothing else created, .gitignore untouched

```
$ git diff HEAD --stat -- .gitignore
(empty — unchanged)

$ grep -i claude .gitignore
(no match)

$ git check-ignore -v CLAUDE.md
(no output, exit 1 — CLAUDE.md is not ignored)

$ ls -la .claude CLAUDE.local.md
ls: .claude: No such file or directory
ls: CLAUDE.local.md: No such file or directory
```

`CLAUDE.md` is tracked and committed, so every session on any machine gets the same rules. **No
`.claude/` directory, no `CLAUDE.local.md`, and no other file was created by this pass.**

## 6. The full working tree, before the commit

```
$ git status --porcelain --untracked-files=all | grep -v "icon-source/"
 M DECISIONS.md
?? CLAUDE.md

$ git status --porcelain --untracked-files=all | wc -l
34
```

34 entries, of which **32 are `icon-source/`** — the exact count `DECISIONS.md` records for it — and
the remaining two are this pass's. **`icon-source/` is byte-for-byte as it was: nothing in it was
read into the project, written, renamed, deleted or staged.** The report file in §7 is the third
change, untracked at the moment of this snapshot because it was still being written.

## 7. Step 7 — the commit and the push

Three files, one commit, added by name so `icon-source/` could not be swept in:

```
$ git add CLAUDE.md DECISIONS.md reports/2026-09-09-pass57-claude-md.md
```

**The post-push SHA is not in this file.** A commit cannot contain its own hash, and step 7 said one
commit, so the before-and-after SHA comparison is verified live and reported to the owner in the
pass response rather than written back in here. What this file can fix is the **pre-pass** side of
that comparison, which §2 records: **local `main` and `origin/main` both at
`8f371a63086dd5fe86ec3dff1d5c05cead250e7f`.** The push is verified by `git fetch origin` followed by
`git rev-parse main` and `git rev-parse origin/main` immediately after, and the pass reports whether
they match.

**Passes 55 and 56 each recorded the verified push in a second, follow-up commit.** This pass did
not, because step 7 named one commit and scope lock forbids adding what a pass did not name. Raised
as a question in §8 instead.

## 8. Open questions — raised, not acted on

1. **Should the ninth rule be in `CLAUDE.md`?** `COLD-START.md`'s rules list ends with "The server
   repo is read-only reference; server changes, if ever needed, are raised as decisions for the
   marlin-dvr project." Step 3 fixed this file's contents exactly and did not include it, so **it
   was not added.** It is arguably the rule most specific to this project and the easiest for a
   fresh session to get wrong. Adding it is a one-line change on the owner's word.
2. **Should the verified push be recorded in a follow-up commit, as Passes 55 and 56 did?** That is
   now this project's habit but was not a numbered step here. If the owner wants it standing, it
   belongs in `DECISIONS.md` as a rule rather than being re-decided each pass.
3. **`icon-source/` is still 32 untracked entries** and its fate is still undecided — unchanged by
   this pass, restated only so it is not mistaken for drift.
4. **`CLAUDE.md` duplicates `COLD-START.md`'s rules rather than pointing at them.** Two copies can
   drift. The alternative — a `CLAUDE.md` that only says "read COLD-START.md" — was not what step 3
   specified. If the owner wants one source of truth, the rules should live in `CLAUDE.md` and
   `COLD-START.md`'s section should point *there*, since `CLAUDE.md` is the file a session reads
   automatically. **Not changed.**

## 9. Files touched, mapped to step numbers

| File | Step | What happened |
|---|---|---|
| `CLAUDE.md` | 3 | **created** — 12 lines, 883 bytes, exactly the specified text |
| `DECISIONS.md` | 4 | **appended** — one new dated section, 19 insertions, 0 deletions |
| `reports/2026-09-09-pass57-claude-md.md` | 6 | **created** — this file |
| `.gitignore` | 5 | **not touched** — verified unchanged against HEAD |
| everything else | — | **not touched** |

No Swift source, no asset catalog, no `.pbxproj`, no `design/`, no other report, no `icon-source/`
entry, nothing outside this folder, nothing on the network.

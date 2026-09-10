# Pass 59 — COLD-START.md brought up to date

**Date:** 2026-09-09.
**Documentation and git only.** No Swift source file, no asset catalog file, no artwork and no
project setting was touched. **No build, no install, no test, no device run. No request of any kind
to `192.168.1.250:8090`.** `design/` was not opened, no existing report was edited or deleted, and
`icon-source/` was left untouched. Files were staged by name.

**What the pass does:** `COLD-START.md`'s "Next step" section is the project's running record of what
has been pushed, and it stopped at Pass 55. Three passes have landed since. This pass brings that
section and "Where things live" current, **by addition only**.

---

## 1. Step 1 — the pre-pass state

```
$ git fetch origin
(no output)

$ git rev-parse main
67ec874cb59383baae2e06917876281c3ea1e9c7
$ git rev-parse origin/main
67ec874cb59383baae2e06917876281c3ea1e9c7
$ git ls-remote origin main
67ec874cb59383baae2e06917876281c3ea1e9c7	refs/heads/main
```

**They match**, at Pass 58's commit `67ec874`, read back from GitHub as well as from the
remote-tracking ref.

```
$ git diff HEAD --stat
(empty — no uncommitted tracked changes)

$ git status --porcelain
?? icon-source/
```

**No uncommitted tracked changes**, so the step 1 stop did not fire. `icon-source/` is the known
baseline, left untouched.

## 2. The SHAs, read from git rather than recalled

Step 2 required the SHAs to come from `git log` and `git ls-remote`. They were:

```
$ git log --reverse --format='%H  %s' fd96b1d~1..HEAD
fd96b1dfe16c33029230c4a1f054ce11c69e0b42  Pass 55: the icon accepted and recorded, and the cold-start brief for 09-09
48e8f91f9db127364d096fa4baca0dbd10bab4f2  Pass 55: record the verified push in the notebook, the brief and the report
10499e5eca227fef9d31c0fc3b46644dfa61d927  Pass 56: retire the handoff brief into COLD-START.md
8f371a63086dd5fe86ec3dff1d5c05cead250e7f  Pass 56: record the verified push in the report
be0cae910d9e8a44408eb6fafd6a991e22fac026  Pass 57: the project's CLAUDE.md
67ec874cb59383baae2e06917876281c3ea1e9c7  Pass 58: CLAUDE.md's ninth rule

$ git ls-remote origin main
67ec874cb59383baae2e06917876281c3ea1e9c7	refs/heads/main
```

### 2.1 A commit the old text never named

The pass brief described "Next step" as stopping at Pass 55 (`fd96b1d`), and it does — but
**`fd96b1d` is not Pass 55's only commit.** `48e8f91`, "record the verified push in the notebook, the
brief and the report", is also Pass 55's and is not named anywhere in that section. It is included in
the new paragraph rather than passed over, so the section accounts for **every** commit in the range,
not only the three passes the step listed.

### 2.2 The chain, checked rather than assumed

```
$ for r in fd96b1d 48e8f91 10499e5 8f371a6 be0cae9 67ec874; do
    git merge-base --is-ancestor $r origin/main && echo "$r: ON origin/main"; done
fd96b1d: ON origin/main
48e8f91: ON origin/main
10499e5: ON origin/main
8f371a6: ON origin/main
be0cae9: ON origin/main
67ec874: ON origin/main

$ git log --merges fd96b1d~1..HEAD --oneline
(empty — no merge commits)

$ git log --format='%h parent=%p  %s' fd96b1d~1..HEAD
67ec874 parent=be0cae9  Pass 58: CLAUDE.md's ninth rule
be0cae9 parent=8f371a6  Pass 57: the project's CLAUDE.md
8f371a6 parent=10499e5  Pass 56: record the verified push in the report
10499e5 parent=48e8f91  Pass 56: retire the handoff brief into COLD-START.md
48e8f91 parent=fd96b1d  Pass 55: record the verified push in the notebook, the brief and the report
fd96b1d parent=3c7da42  Pass 55: the icon accepted and recorded, and the cold-start brief for 09-09
```

Every commit is on `origin/main`, there is no merge commit, and each parent is the commit before it.
**Linear, nothing forced, rebased or amended** — and that is what the new paragraph claims, no more.

**On the two Pass 56 SHAs:** the fast-forward wording for `be0cae9` and `67ec874` comes from push
output observed when those pushes were made (`8f371a6..be0cae9`, `be0cae9..67ec874`). For `10499e5`
the new text instead cites where that verification is recorded —
`reports/2026-09-09-pass56-retire-handoff-brief.md`, which shows `git ls-remote origin main` reading
`10499e5` — rather than asserting a push this pass did not witness.

## 3. Steps 2 and 3 — the diff, additions only

```
$ git diff --stat -- COLD-START.md
 COLD-START.md | 19 +++++++++++++++++++
 1 file changed, 19 insertions(+)

$ git diff -U0 -- COLD-START.md | grep -c "^-[^-]"
0
```

**19 insertions, 0 deletions**, and a direct count of deletion lines in the diff body returns **zero**.
No existing line of `COLD-START.md` was rewritten, reworded, moved or removed.

### 3.1 Step 3 — "Where things live"

```
 - This folder: `~/Xcode/Marlin DVR TV` — the Xcode project, the notebook (this file, DECISIONS.md, reports/), and the git repo. The only writable tree.
+- Standing rules: `CLAUDE.md` at the project root — the builder's standing rules and a pointer to this notebook. Never project state; the notebook stays the record (DECISIONS.md, 2026-09-09 (Pass 57)).
 - Repo: `git@github.com:marlin1111ai/marlin-dvr-tv.git` (branch `main`).
```

One bullet, placed directly after the "This folder" bullet it belongs with, in the list's existing
`label: path — description` style and citing the decision that governs it.

### 3.2 Step 2 — "Next step"

The new paragraph was inserted at the **head** of the section, directly under the heading, because
the section is written most-recent-first: its existing text runs "… Before that … Before that …"
backwards through the passes. Putting the newest state first continues that order and, being a whole
new paragraph, touches no existing line.

## 4. Step 4 — the DECISIONS.md entry

```
$ git diff --stat -- DECISIONS.md
 DECISIONS.md | 21 +++++++++++++++++++++
 1 file changed, 21 insertions(+)
```

**Insertions only.** A new dated section, "2026-09-09 (Pass 59 — COLD-START.md brought current
through Pass 58)", appended after Pass 58's, matching the file's one-section-per-pass convention.

## 5. The working tree before the commit

```
$ git status --porcelain --untracked-files=all | grep -v "icon-source/"
 M COLD-START.md
 M DECISIONS.md
?? reports/2026-09-09-pass59-cold-start-refresh.md

$ git status --porcelain --untracked-files=all | wc -l
35
```

35 entries: **32 are `icon-source/`**, unchanged, and the other three are this pass's. **Nothing in
`icon-source/` was read into the project, written, renamed, deleted or staged.**

## 6. Step 6 — the commit and the push

Three files, one commit, staged by name:

```
$ git add COLD-START.md DECISIONS.md reports/2026-09-09-pass59-cold-start-refresh.md
```

**The post-push SHA is not in this file** — a commit cannot contain its own hash, and step 6 named
one commit. The pre-pass side is fixed here: **local `main` and `origin/main` both at
`67ec874cb59383baae2e06917876281c3ea1e9c7`** (§1). The push is verified live by `git fetch origin`
followed by `git rev-parse main`, `git rev-parse origin/main` and `git ls-remote origin main`, and
the pass reports both SHAs and whether they match.

**This means "Next step" is current through Pass 58 and not through Pass 59.** That is what step 2
asked for — "nothing is unpushed as of Pass 58" — and it is the same self-reference problem the
report has: a section committed in a commit cannot describe that commit's own push. Pass 59's own
push will need naming by a later pass, exactly as Pass 55's and Pass 56's follow-up commits did.
Raised in §7.

## 7. Open questions — raised, not acted on

1. **"Next step" now opens with two paragraphs that each declare nothing unpushed** — the new one
   scoped "as of Pass 58", the older one written when `fd96b1d` was head and still reading
   "**Nothing is unpushed.**" unqualified. Both are true of their own moment, and the pass forbade
   rewriting the old text, so both stand. **Whether the section should be consolidated, or the older
   paragraphs date-stamped, is the owner's call.** Left alone.
2. **Who names Pass 59's push?** The section is current through Pass 58 by design. Passes 55 and 56
   each used a second commit to record their own verified push; Passes 57, 58 and 59 have not,
   because no numbered step called for it. **This is the third pass to raise it** — it would be
   settled once by a rule in `DECISIONS.md` rather than re-decided each time.
3. **Which file is the source of truth for the rules?** Still open from Passes 57 and 58: the rules
   are duplicated between `COLD-START.md` and `CLAUDE.md`, three of them worded differently, both
   maintained by hand. **Not changed.**
4. **`icon-source/` is still 32 untracked entries** and its fate is still undecided.

## 8. Files touched, mapped to step numbers

| File | Step | What happened |
|---|---|---|
| `COLD-START.md` | 2, 3 | **19 insertions, 0 deletions** — one paragraph at the head of "Next step" (step 2), one bullet in "Where things live" (step 3) |
| `DECISIONS.md` | 4 | **21 insertions, 0 deletions** — one new dated Pass 59 section |
| `reports/2026-09-09-pass59-cold-start-refresh.md` | 5 | **created** — this file |
| `CLAUDE.md` | — | **not touched** — read only, as step 0 required |
| `reports/…pass56….md`, `…pass57….md`, `…pass58….md` | — | **read only, not modified** |
| everything else | — | **not touched** |

No Swift source, no asset catalog, no `.pbxproj`, no `.gitignore`, no `design/`, no `icon-source/`
entry, nothing outside this folder, nothing on the network.

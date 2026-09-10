# Pass 61 — two corrections

**Date:** 2026-09-09.
**Documentation and git only.** No Swift source file, no asset catalog file, no artwork and no
project setting was touched. **No build, no install, no test, no device run. No request of any kind
to `192.168.1.250:8090`.** `design/`, `~/Xcode/marlin-dvr-reference` and every other folder under
`~/Xcode` were not opened; no existing report was edited or deleted; `icon-source/` was left
untouched. Files were staged by name.

**What the pass does:** it closes the two open questions Pass 60 left behind — a rule that had
quietly narrowed, and two references left pointing at a list Pass 60 deleted.

---

## 1. Step 1 — the pre-pass state

```
$ git fetch origin
(no output)

$ git rev-parse main
4f789061593bbf0dc632acfcc20f4ff6fa4ca7c4
$ git rev-parse origin/main
4f789061593bbf0dc632acfcc20f4ff6fa4ca7c4
$ git ls-remote origin main
4f789061593bbf0dc632acfcc20f4ff6fa4ca7c4	refs/heads/main
```

**They match**, at Pass 60's commit `4f78906`, read back from GitHub as well as from the
remote-tracking ref.

```
$ git diff HEAD --stat
(empty — no uncommitted tracked changes)

$ git status --porcelain
?? icon-source/
```

**No uncommitted tracked changes**, so the step 1 stop did not fire.

## 2. Step 2 — scope lock binds changes again

```
BEFORE: - Scope lock: build only what the pass names. Anything extra is a question in the report, never built, not even disabled.
AFTER : - Scope lock: build or change only what the pass names. Anything extra is a question in the report, never built, not even disabled.
```

```
$ git diff -- CLAUDE.md
@@ -3,7 +3,7 @@
 - Recon before build.
-- Scope lock: build only what the pass names. Anything extra is a question in the report, never built, not even disabled.
+- Scope lock: build or change only what the pass names. Anything extra is a question in the report, never built, not even disabled.
 - No installs without owner authorization.
```

**One line, two words.** The rest of the bullet is byte-for-byte as it was, including "never built,
not even disabled". The edit script asserted the old line matched exactly and occurred exactly once
before writing.

```
$ grep -c "^- " CLAUDE.md
9
```

Still nine bullets — nothing added, nothing removed.

### 2.1 Measured against the wording this restores

The rule Pass 60 deleted from `COLD-START.md`, read back from git rather than memory:

```
$ git show 77bf616:COLD-START.md | sed -n '19p'
- Scope lock: nothing not named in a pass's steps gets built or changed; anything extra goes in the report as a question.
```

| Clause of the original | Now carried? |
|---|---|
| binds what gets **built** | **yes** — "build … only what the pass names" |
| binds what gets **changed** | **yes** — "…or change only what the pass names" — **this is what was missing** |
| anything extra goes in the report as a question | **yes** — "Anything extra is a question in the report" |
| — | **and stronger:** "never built, not even disabled", which the original never said |

**Both verbs are back and the tail is still stronger than the original.** Pass 60 §3.1 raised exactly
this gap; it is closed.

### 2.2 The change was made in one place

`CLAUDE.md` was the only file edited for this rule. That is **Pass 60 rule (a)** working as intended:
one copy, one edit, nothing to keep in step. `COLD-START.md`'s "The rules" still holds only its
pointer line — it was not touched by step 2.

## 3. Step 3 — the dangling references repointed

```
$ git diff -- COLD-START.md
@@ -849,12 +849,15 @@
-**Pass 58 added that file's ninth bullet**, the server-repo rule from the rules list above, copied
-word for word and proved byte-identical (`reports/2026-09-09-pass58-claude-md-ninth-rule.md`) —
-pushed as `67ec874`, a fast-forward from `be0cae9`. **Pass 58 also corrected a miscount:** the Pass 57
-report called that rule "COLD-START.md's ninth", but this file's rules list holds **eight** rules and
-the server-repo rule is its seventh; `CLAUDE.md` has nine bullets because one of them — "If anything
-blocks, stop and report" — has no counterpart here (DECISIONS.md, 2026-09-09 (Pass 58)).
+**Pass 58 added that file's ninth bullet**, the server-repo rule, copied word for word from this
+file's rules list as it then stood and proved byte-identical
+(`reports/2026-09-09-pass58-claude-md-ninth-rule.md`) — pushed as `67ec874`, a fast-forward from
+`be0cae9`. That rule is now the last of `CLAUDE.md`'s nine bullets. **Pass 58 also corrected a
+miscount:** the Pass 57 report called it "COLD-START.md's ninth", but this file's rules list then held
+**eight** rules and the server-repo rule was its seventh; `CLAUDE.md` has nine bullets because one of
+them — "If anything blocks, stop and report" — had no counterpart in that list. **Pass 60 has since
+removed this file's rules list**, so `CLAUDE.md`'s bullets are now the only copy (DECISIONS.md,
+2026-09-09 (Pass 58) and 2026-09-09 (Pass 60)).
```

**One hunk, inside the Pass 58 paragraph only.** The edit script asserted all six original lines
matched exactly **and** that the lines either side — the Pass 57 sentence ending `a fast-forward from
`8f371a6`.` and the blank line before "Nothing was unpushed as of Pass 55." — were untouched.

### 3.1 What it records is unchanged — clause by clause

| Fact the paragraph carried | Still there? |
|---|---|
| Pass 58 added `CLAUDE.md`'s ninth bullet | **yes** |
| it was the server-repo rule, copied word for word, proved byte-identical | **yes** |
| `reports/2026-09-09-pass58-claude-md-ninth-rule.md` | **yes** |
| pushed as `67ec874`, a fast-forward from `be0cae9` | **yes** |
| Pass 58 corrected a miscount | **yes** |
| the Pass 57 report called it "COLD-START.md's ninth" | **yes** |
| this file's list held **eight** rules; server-repo was its **seventh** | **yes** — now past tense |
| `CLAUDE.md` has nine bullets; one has no counterpart | **yes** |
| DECISIONS.md citation | **yes**, plus the Pass 60 entry |

**Nothing recorded was dropped, weakened or restated.** What changed is tense — "holds" → "then
held", "is its seventh" → "was its seventh", "has no counterpart" → "had no counterpart" — and the
pointers: "from the rules list above" became "from this file's rules list **as it then stood**", and
the paragraph now says where the rules live today.

### 3.2 No dangling reference survives

```
$ grep -n "rules list above\|rules list holds\|this file's rules list" COLD-START.md
856:miscount:** the Pass 57 report called it "COLD-START.md's ninth", but this file's rules list then held
859:removed this file's rules list**, so `CLAUDE.md`'s bullets are now the only copy (DECISIONS.md,
```

Two mentions remain and **neither is dangling**: one is explicitly past tense ("**then held**"), the
other explicitly states the list's removal ("**Pass 60 has since removed** this file's rules list").
The phrase "the rules list above", which pointed at deleted text, is gone.

## 4. Step 4 — the DECISIONS.md entry

```
$ git diff --stat -- DECISIONS.md
 DECISIONS.md | 25 +++++++++++++++++++++++++
 1 file changed, 25 insertions(+)
```

**Insertions only.** A new dated section, "2026-09-09 (Pass 61 — two corrections)", recording both
fixes and closing both of Pass 60's open questions.

## 5. The working tree before the commit

```
$ git status --porcelain --untracked-files=all | grep -v "icon-source/"
 M CLAUDE.md
 M COLD-START.md
 M DECISIONS.md
?? reports/2026-09-09-pass61-two-corrections.md

$ git status --porcelain --untracked-files=all | wc -l
36
```

36 entries: **32 are `icon-source/`**, unchanged and untouched, and the other four are this pass's.

```
$ git diff --stat
 CLAUDE.md     |  2 +-
 COLD-START.md | 15 +++++++++------
 DECISIONS.md  | 25 +++++++++++++++++++++++++
```

## 6. Step 6 — the commit and the push

Four files, one commit, staged by name:

```
$ git add CLAUDE.md COLD-START.md DECISIONS.md reports/2026-09-09-pass61-two-corrections.md
```

**This pass follows Pass 60 rule (b): one commit, no follow-up commit recording the push.** The
verification is done live after pushing — `git fetch origin`, then `git rev-parse main`,
`git rev-parse origin/main` and `git ls-remote origin main` — and the result is recorded in the
pass's response to the owner.

**The post-push SHA is not in this file, and cannot be:** this report is inside the commit being
pushed, and a commit cannot contain its own hash. That is a property of git, not an open question,
and rule (b) is what settles where the record goes. What is fixed here is the pre-push side:
**local `main` and `origin/main` both at `4f789061593bbf0dc632acfcc20f4ff6fa4ca7c4`** before this
pass (§1). The next pass's notebook update names this pass's commit, as Pass 59 did for Passes
56–58.

## 7. Open questions

**None from this pass.** It closed both of Pass 60's:

1. **The dangling references** — fixed in step 3, verified in §3.2.
2. **Scope lock's lost breadth** — fixed in step 2, verified in §2.1.

Neither should be re-raised. The one standing item unrelated to this pass:

- **`icon-source/` is still 32 untracked entries** and its fate is still the owner's undecided call —
  unchanged by this pass, restated only so it is not mistaken for drift.

## 8. Files touched, mapped to step numbers

| File | Step | What happened |
|---|---|---|
| `CLAUDE.md` | 2 | **1 insertion, 1 deletion** — the scope-lock bullet now binds "build **or change**"; rest of the bullet unchanged |
| `COLD-START.md` | 3 | **9 insertions, 6 deletions** — one hunk, the Pass 58 paragraph's references repointed at `CLAUDE.md`; what it records unchanged |
| `DECISIONS.md` | 4 | **25 insertions, 0 deletions** — one new dated Pass 61 section |
| `reports/2026-09-09-pass61-two-corrections.md` | 5 | **created** — this file |
| `reports/…pass60….md` | — | **read only, not modified** |
| everything else | — | **not touched** |

`COLD-START.md`'s "The rules" section was **not** touched by this pass — it still holds only the
pointer line Pass 60 put there. No Swift source, no asset catalog, no `.pbxproj`, no `.gitignore`, no
`design/`, no `~/Xcode/marlin-dvr-reference`, no `icon-source/` entry, nothing outside this folder,
nothing on the network.

# Pass 58 — CLAUDE.md's ninth rule

**Date:** 2026-09-09.
**Documentation and git only.** No Swift source file, no asset catalog file, no artwork and no
project setting was touched. **No build, no install, no test, no device run. No request of any kind
to `192.168.1.250:8090`.** `design/` was not opened, no existing report was edited or deleted, and
`icon-source/` was left untouched. Files were staged by name.

**What the pass does:** Pass 57 built `CLAUDE.md` to a fixed spec that did not include
`COLD-START.md`'s server-repo rule, and raised its absence as the first open question. This pass adds
it. **One line.**

---

## 1. Step 1 — the pre-pass state

```
$ git fetch origin
(no output)
```

```
$ git rev-parse main
be0cae910d9e8a44408eb6fafd6a991e22fac026
$ git rev-parse origin/main
be0cae910d9e8a44408eb6fafd6a991e22fac026
$ git ls-remote origin main
be0cae910d9e8a44408eb6fafd6a991e22fac026	refs/heads/main
```

**They match**, at Pass 57's commit `be0cae9`, confirmed against GitHub as well as the
remote-tracking ref.

```
$ git diff HEAD --stat
(empty — no uncommitted tracked changes)

$ git status --porcelain
?? icon-source/
```

**No uncommitted tracked changes**, so the step 1 stop did not fire. The single untracked entry is
`icon-source/`, the known baseline; it was left untouched and is untouched after the pass (§6).

## 2. Step 2 — the rule added, and proved word for word

The bullet was **not retyped**. It was extracted from `COLD-START.md` by pattern and appended, so
byte-fidelity is structural rather than a matter of careful copying:

```
$ grep -c "^- The server repo is read-only reference" COLD-START.md
1
$ grep -n "^- The server repo is read-only reference" COLD-START.md
23:- The server repo is read-only reference; server changes, if ever needed, are raised as decisions for the marlin-dvr project.

$ grep "^- The server repo is read-only reference" COLD-START.md >> CLAUDE.md
```

Exactly one match in the source, so there was no ambiguity about which line was copied.

### 2.1 The string comparison, two ways

```
$ a=$(grep "^- The server repo is read-only reference" COLD-START.md)
$ b=$(grep "^- The server repo is read-only reference" CLAUDE.md)
$ [ "$a" = "$b" ] && echo IDENTICAL || echo DIFFERENT
IDENTICAL
```

```
$ cmp a.txt b.txt      # the two extracted lines, byte for byte
cmp: BYTE-IDENTICAL
```

**Result: identical.** Both the shell string compare step 2 asked for and a byte-level `cmp` agree.

### 2.2 Nothing else in the file changed

```
$ git diff -- CLAUDE.md
@@ -10,3 +10,4 @@
 - No secrets in the repo, logs, or reports. Redact tokens, credentials and device IDs before any commit or report.
 - If anything blocks, stop and report. Do not work around it.
 - Do not touch: the other folders under `~/Xcode`, the Marlin DVR server and its data, the Unraid host 192.168.1.250, marlinpc 192.168.1.245, the HDHomeRun 192.168.1.105, the UNAS4Pro share.
+- The server repo is read-only reference; server changes, if ever needed, are raised as decisions for the marlin-dvr project.

$ git diff --stat -- CLAUDE.md
 CLAUDE.md | 1 +
 1 file changed, 1 insertion(+)
```

**One insertion, zero deletions**, placed after the "Do not touch:" line as step 2 specified. The
heading, the pointer paragraph and the other eight bullets are untouched — the diff shows no `-`
line at all.

## 3. The counting claim, checked rather than repeated

Step 3 described the result as "all nine of `COLD-START.md`'s rules". **`COLD-START.md` has eight
rules, not nine.** Counted:

```
$ sed -n '17,24p' COLD-START.md | grep -c "^- "
8
$ grep -c "^- " CLAUDE.md
9
```

`CLAUDE.md` has nine bullets because **one of them is its own and has no counterpart in
`COLD-START.md`'s rules list**. Every bullet was tested for a byte-identical match in that list:

```
VERBATIM     : - Recon before build.
NOT-VERBATIM : - Scope lock: build only what the pass names. Anything extra is a question in the report, never built, not even disabled.
VERBATIM     : - No installs without owner authorization.
VERBATIM     : - Separate push gate for code the owner tests.
NOT-VERBATIM : - Never force-push and never rewrite history.
NOT-VERBATIM : - No secrets in the repo, logs, or reports. Redact tokens, credentials and device IDs before any commit or report.
NOT-VERBATIM : - If anything blocks, stop and report. Do not work around it.
VERBATIM     : - Do not touch: the other folders under `~/Xcode`, ...
VERBATIM     : - The server repo is read-only reference; server changes, if ever needed, are raised as decisions for the marlin-dvr project.
```

and the reverse direction, `COLD-START.md`'s rules with no byte-identical bullet in `CLAUDE.md`:

```
MISSING-VERBATIM : - Scope lock: nothing not named in a pass's steps gets built or changed; anything extra goes in the report as a question.
MISSING-VERBATIM : - Nothing force-pushed, ever.
MISSING-VERBATIM : - No secrets in the repo, logs, or reports.
```

So the accurate statement, which is what went into `DECISIONS.md`:

| | |
|---|---|
| `COLD-START.md` rules | **8** |
| …of those, now in `CLAUDE.md` **byte-identical** | **5** — recon, no installs, push gate, do-not-touch, server repo |
| …now in `CLAUDE.md` **reworded or strengthened** | **3** — scope lock; "Nothing force-pushed, ever" → "Never force-push and never rewrite history"; no-secrets + the redaction clause |
| …**missing in substance** | **0** |
| `CLAUDE.md`-only bullets | **1** — "If anything blocks, stop and report. Do not work around it." |
| `CLAUDE.md` bullets total | **9** |

**"The ninth rule" is the ninth bullet of `CLAUDE.md`, not a ninth rule of `COLD-START.md`.** The
off-by-one starts in this project's own paperwork: `reports/2026-09-09-pass57-claude-md.md` §3.2 and
§8 called it "`COLD-START.md`'s ninth rule" when it is that file's **seventh of eight**. **The Pass 57
report was not edited** — reports are the historical record and are never rewritten to match a later
finding. The correction is in `DECISIONS.md` under Pass 58, which is what governs.

## 4. Step 3 — the DECISIONS.md entry

```
$ git diff --stat -- DECISIONS.md
 DECISIONS.md | 26 ++++++++++++++++++++++++++
 1 file changed, 26 insertions(+)
```

**Insertions only — no existing line was edited, reworded or removed.** A new dated section,
"2026-09-09 (Pass 58 — CLAUDE.md's ninth rule)", appended after Pass 57's, matching the file's
one-section-per-pass convention. It records the rule added and the measured coverage above, in the
corrected form rather than the "nine rules" form.

## 5. CLAUDE.md as it now stands

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
- The server repo is read-only reference; server changes, if ever needed, are raised as decisions for the marlin-dvr project.
```

13 lines. Still rules and a pointer only — **no project state**, per the Pass 57 decision.

## 6. The working tree before the commit

```
$ git status --porcelain --untracked-files=all | grep -v "icon-source/"
 M CLAUDE.md
 M DECISIONS.md
?? reports/2026-09-09-pass58-claude-md-ninth-rule.md

$ git status --porcelain --untracked-files=all | wc -l
35
```

35 entries: **32 are `icon-source/`** — the count `DECISIONS.md` records for it, unchanged — and the
other three are this pass's. **Nothing in `icon-source/` was read into the project, written, renamed,
deleted or staged.**

## 7. Step 5 — the commit and the push

Three files, one commit, staged by name so `icon-source/` could not be swept in:

```
$ git add CLAUDE.md DECISIONS.md reports/2026-09-09-pass58-claude-md-ninth-rule.md
```

**The post-push SHA is not in this file** — a commit cannot contain its own hash, and step 5 named
one commit. The pre-pass side is fixed here: **local `main` and `origin/main` both at
`be0cae910d9e8a44408eb6fafd6a991e22fac026`** (§1). The push is verified live by `git fetch origin`
followed by `git rev-parse main` and `git rev-parse origin/main`, and the pass reports both SHAs and
whether they match. Pass 57 raised whether that verification should get a follow-up commit, as
Passes 55 and 56 did; it is still not a numbered step, so again there is **one commit**.

## 8. Open questions — raised, not acted on

1. **Which file is the source of truth for the rules?** Still open from Pass 57, and now measured:
   three of the eight rules are worded differently in `CLAUDE.md` than in `COLD-START.md`, and the
   two lists are maintained by hand. `CLAUDE.md` is the file a session reads automatically, so the
   cleaner arrangement is the rules living there with `COLD-START.md`'s section pointing at it.
   **Not changed.**
2. **Should "If anything blocks, stop and report. Do not work around it." be added to
   `COLD-START.md`'s rules list?** It is a real standing rule, it is in `CLAUDE.md`, and it is the one
   bullet with no counterpart in the notebook. Editing `COLD-START.md` was not a numbered step here.
   **Not done.**
3. **`icon-source/` is still 32 untracked entries** and its fate is still undecided — restated only
   so it is not mistaken for drift.

## 9. Files touched, mapped to step numbers

| File | Step | What happened |
|---|---|---|
| `CLAUDE.md` | 2 | **1 insertion, 0 deletions** — the server-repo rule, byte-identical to `COLD-START.md:23`, after the do-not-touch line |
| `DECISIONS.md` | 3 | **26 insertions, 0 deletions** — one new dated Pass 58 section |
| `reports/2026-09-09-pass58-claude-md-ninth-rule.md` | 4 | **created** — this file |
| `COLD-START.md` | — | **not touched** — read only, as the source of the copied line |
| `reports/2026-09-09-pass57-claude-md.md` | — | **not touched**, including the "ninth rule" wording §3 corrects |
| everything else | — | **not touched** |

No Swift source, no asset catalog, no `.pbxproj`, no `.gitignore`, no `design/`, no `icon-source/`
entry, nothing outside this folder, nothing on the network.

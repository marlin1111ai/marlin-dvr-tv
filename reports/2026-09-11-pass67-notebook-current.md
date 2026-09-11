# Pass 67 — the Pass 66 report, and "Next step" brought current — 2026-09-11

**Result: `COLD-START.md`'s push history is current through Pass 66, the Pass 66 report is in the
repo unmodified, and the commit is on `origin main`, verified live.**

`origin/main` went from **`b028650`** to **`dabb5da`**. One commit, a fast-forward, nothing
forced, rebased or amended.

Documentation and git only. No source file, asset, project setting, build, install or network
request; neither Apple TV was touched and neither was the server.

---

## 1. Step 1 — the starting point

`git fetch origin`, then three independent readings, **all identical**:

```
local main        b028650c0090ae1701b84ec595f0af41e8468bcf
origin/main       b028650c0090ae1701b84ec595f0af41e8468bcf
ls-remote origin  b028650c0090ae1701b84ec595f0af41e8468bcf   refs/heads/main
```

Nothing was unpushed. `git status --porcelain --untracked-files=all`, with the known
`icon-source/` baseline filtered out, showed exactly one entry:
`?? reports/2026-09-11-pass66-search-accepted-and-pushed.md` — the file this pass was to commit.
**Everything was staged by name**; `git add -A` was never used, so `icon-source/` could not be
swept in.

---

## 2. Step 2 — "Next step", current through Pass 66

The section runs most-recent-first and its newest paragraph stopped at Pass 58's `67ec874`,
leaving **six landed commits unnamed**. A new paragraph at the head of the section names them.

**Every SHA was read from `git log` and `git ls-remote`, none from memory:**

| Commit | Pass | What it carried |
|---|---|---|
| `77bf616` | 59 | this section brought current through Pass 58 |
| `4f78906` | 60 | `CLAUDE.md` made the single source of truth for the rules |
| `49a5672` | 61 | two corrections to it |
| `1107b12` | 63 | the Search screen — **and the Pass 62 report** |
| `d0ff593` | 65 | that screen moved onto `.searchable` — **and the Pass 64 report** |
| `b028650` | 66 | the owner's acceptance and the notebook |

**The chain was checked rather than assumed**, four ways:

- all six are ancestors of `origin/main` (`git merge-base --is-ancestor <c> origin/main`, one at
  a time, six for six);
- `git log --merges 67ec874..b028650` returns **0**;
- each commit's parent is the one before it —
  `67ec874 → 77bf616 → 4f78906 → 49a5672 → 1107b12 → d0ff593 → b028650`;
- `67ec874` is still an ancestor of the current head, so nothing was rewritten out from under it.

The paragraph also records **why Passes 62 and 64 have no commit of their own**, so no later
reader mistakes it for a gap: both were read-only. Pass 62 wrote a report and nothing else; Pass
64 deleted every probe file and restored `ScreenShell.swift` with `git checkout` before
reporting. Their reports ride in `1107b12` and `d0ff593`, each committed by the pass that
followed.

**Additions only**, as the pass required: `git diff --numstat COLD-START.md` reported
**22 insertions, 0 deletions**, and the diff shows the new paragraph inserted between the
`## Next step` heading and the Pass 58 paragraph, with no other hunk. **No existing line was
rewritten, reworded, moved or removed.**

---

## 3. Step 3 — the Pass 66 report, scanned and committed unmodified

`reports/2026-09-11-pass66-search-accepted-and-pushed.md`, 9,765 bytes, 188 lines.

**Scanned before staging. Nothing found.** Four checks:

| Check | Result |
|---|---|
| `password`, `secret`, `api_key`, `bearer`, `authorization`, `token`, `credential`, private-key headers, `ssh-rsa`, the team id, the client id, `udid`, `serial` | **one match**, and it is the report's own sentence *"No credential, token or device id appears above."* |
| UUID-shaped strings (`8-4-4-4-12` hex) | **none** — no device identifier of any kind |
| IP addresses | `192.168.1.250`, `192.168.1.245`, `192.168.1.105` — the do-not-touch LAN addresses the report names in order to state it did **not** contact them. Already throughout `COLD-START.md` and `CLAUDE.md`; not secrets. |
| every 40-hex string | all three (`49a5672…`, `d0ff593…`, `b028650…`) resolve with `git cat-file -t` to commits **in this repo** |

**It went in byte-identical.** `git hash-object` of the working copy and the staged blob both
read `aec0df31c83e0492b7bcd88cc736d32be7e5c4c4`. Not a character of it was edited.

---

## 4. Step 4 — DECISIONS.md

One dated entry, **`## 2026-09-11 (Pass 67 — the notebook brought current)`**, appended:
**25 insertions, 0 deletions.** It records "Next step" current through Pass 66 with the six SHAs,
that every one was read from git and the chain checked, the additions-only count, and the Pass 66
report committed unmodified after a clean scan.

It also **names the pattern rather than treating it as an oversight**: a pass whose report records
its own verified push necessarily leaves that report untracked, because a push SHA cannot be
written into a commit that precedes it — so the next pass commits it. Pass 63 did that for Pass
62's, Pass 65 for Pass 64's, and this pass for Pass 66's. The owner's 2026-09-08 decision that a
`reports/` file belongs in the repo is unchanged; this only says **when** the committing happens.

---

## 5. Step 6 — the commit, the push, and the verification

**`dabb5da66b1790dce1c387b66e8c12ed65f5fbaa`**, "Pass 67: Next step brought current, and the
Pass 66 report" — 3 files changed, **235 insertions, 0 deletions**.

```
git push origin main
   b028650..dabb5da  main -> main
```

**Verified after a fresh `git fetch origin`, three independent readings, all identical:**

```
local main        dabb5da66b1790dce1c387b66e8c12ed65f5fbaa
origin/main       dabb5da66b1790dce1c387b66e8c12ed65f5fbaa
ls-remote origin  dabb5da66b1790dce1c387b66e8c12ed65f5fbaa   refs/heads/main
```

**And a clean fast-forward, checked five ways rather than asserted:**

| Check | Result |
|---|---|
| `git merge-base --is-ancestor b028650 dabb5da` | **yes** |
| `git cat-file -t b028650` | still a reachable commit — nothing rewritten |
| `git log --merges b028650..dabb5da` | **0** |
| parent | `dabb5da → b028650`, one commit, linear |
| `git reflog` | four plain `commit:` entries and nothing else — no `rebase`, `amend`, `reset` or force |

`git status --porcelain --untracked-files=all` afterwards showed **nothing at all** outside
`icon-source/`, and `git status -sb` read `## main...origin/main` with no ahead/behind marker.

---

## 6. Scope check — every path touched

| Path | What happened | Step |
|---|---|---|
| `COLD-START.md` | one paragraph at the head of "Next step", **+22 / -0** | 2 |
| `reports/2026-09-11-pass66-search-accepted-and-pushed.md` | **committed unmodified**, blob `aec0df3` | 3 |
| `DECISIONS.md` | one dated entry appended, **+25 / -0** | 4 |
| `reports/2026-09-11-pass67-notebook-current.md` | **new** — this file, untracked | 5 |
| `Marlin DVR TV/**`, `Marlin DVR TVUITests/**`, `*.xcodeproj`, `Info.plist`, entitlements | **not touched** | — |
| `design/`, `CLAUDE.md`, `icon-source/`, every earlier report | **read only**, never written | — |
| `~/Xcode/marlin-dvr-reference` | **not touched at all** this pass | — |

No request was made to 192.168.1.250, 192.168.1.245, 192.168.1.105 or the UNAS4Pro share, no
build was run, nothing was installed on either Apple TV, and no other folder under `~/Xcode` was
read or written. No credential, token or device id appears above.

---

## 7. Open questions

1. **This report is untracked**, for the reason §4 names, and is the next pass's to commit. It is
   the third in a row — Pass 66's, and now this one. **If the owner would rather the cycle
   stopped, the fix is a step ordering that writes the report before the push and accepts that
   the push SHA lives only in the pass response and the next notebook entry**, which is what
   DECISIONS.md 2026-09-09 (Pass 60) rule (b) already says. Not decided here.
2. **"Next step" now opens with three paragraphs that each say nothing is unpushed** — as of
   Pass 66, as of Pass 58, and as of Pass 55. Each is true of its own moment and the older two
   were left exactly as written, as the pass required. **Whether the section should be
   consolidated is the owner's call**, and Pass 59 raised the same question when it added the
   second one.
3. **Passes 59, 60 and 61's pushes were never recorded in the notebook at the time.** This pass
   names their SHAs and proves they are on `origin/main` today, but *when* each was pushed is not
   recoverable from git and is not claimed.
4. The open questions from Passes 63, 65 and 66 are untouched and still open.

---

## 8. The things I am least sure of

1. **That naming Passes 59-61's commits in a "pushes since Pass 58" paragraph reads correctly.**
   What git proves is that they are ancestors of `origin/main` now. The paragraph says they
   landed, which is true, but it does not say when each was pushed, because nothing available
   here establishes that.
2. **The placement of the new paragraph.** It went at the head of the section because the section
   runs most-recent-first and Pass 59 set that precedent. That leaves the reader three
   "nothing is unpushed" claims to date-match before finding the current one.
3. **Whether the untracked-report pattern should have been written into DECISIONS.md as
   settled.** It is recorded as an observation of what three passes have now done, not as a rule.
   If the owner wants it to be a rule — or wants it eliminated — that is a decision this pass did
   not have the standing to take, and §7.1 raises it rather than assuming either way.

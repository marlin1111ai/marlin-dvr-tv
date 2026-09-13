# Pass 87 — Pass 86 accepted and pushed

**Date:** 2026-09-13

**No app-target code changed.** This pass writes three files — `DECISIONS.md`, `COLD-START.md` and
this report — in one commit, and pushes it together with Pass 86's `29afca5`. `design/` and
`~/Xcode/marlin-dvr-reference` were not opened, and no request was made to the server. There was no
build, no device run and no install.

**Pass number.** The highest-numbered report in `reports/` before this pass is **pass86**, so this is
**Pass 87**.

---

## 1. Step 1 — the acceptance entry in `DECISIONS.md`

**Added: 2026-09-13 (Pass 87 — Pass 86 accepted and pushed).** It records:

- **The acceptance:** the owner tested Pass 86 on Home Theater on 2026-09-13 and accepted it —
  "good to go".
- **What was accepted, named:**
  - the logo in the 62 pt tile, aspect-fitted with a 6 pt inset, on the `Nocturne.neutral200`
    (`#E4E7F5`) backing;
  - the initials tile with no backing, for an empty or a failed logo;
  - requests only through `/api/art/feed?u=`.
- **The white antenna logos' faint contrast** on the backing (`86a`; 1.23:1 and 1.14:1): it was shown
  to the owner before he accepted, and it is **accepted as built — not an open item**. That closes
  Pass 86 open question 1.
- **Pass 86's open questions 2-5:** neither closed nor re-raised.

## 2. Step 2 — `COLD-START.md` "Next step"

A new head paragraph says:
- nothing is unpushed as of Pass 87;
- `29afca5` (Pass 86) is pushed together with this pass's commit, a fast-forward from `3342b1d`;
- this pass's own SHA is not written, per DECISIONS.md, 2026-09-11 (Pass 68).

The Pass 86 paragraphs below it are kept, word for word, as history.

## 3. Step 3 — the gate, before anything was changed

```
$ git fetch origin
$ git status --porcelain
?? icon-source/
$ git rev-parse main origin/main
29afca5fa1d3e6b857d055de68df170202273ca8
3342b1da4aa43af33257aa716c4245bd3ed8ea32
$ git rev-list --left-right --count main...origin/main
1	0
$ git log --oneline origin/main..main
29afca5 Pass 86: channel logos in the Guide's channel cell — committed, NOT pushed
$ git log --format="%h parent=%p %s" -1 main
29afca5 parent=3342b1d Pass 86: channel logos in the Guide's channel cell — committed, NOT pushed
$ git ls-remote origin main
3342b1da4aa43af33257aa716c4245bd3ed8ea32	refs/heads/main
```

**`origin/main` reads `3342b1d`, and local `main` is exactly one commit ahead, at `29afca5`**, whose
parent is `3342b1d`. The live remote agrees. The stop condition did not arise.

## 4. Step 4 — commit and push

This report, `DECISIONS.md` and `COLD-START.md` are staged by name and committed in one commit on
top of `29afca5`. `git push origin main` then carries both commits as a fast-forward from `3342b1d`:
no force, no rebase, no amend.

The verification is a fresh `git fetch`, then `git rev-parse main`, `git rev-parse origin/main`,
`git ls-remote origin main` and `git log --oneline 3342b1d..origin/main`. It happens after the push,
so its output — and this pass's own SHA — is in the pass response, not here. A commit cannot contain
its own SHA (DECISIONS.md, 2026-09-11 (Pass 68)).

---

## 5. Files touched, mapped to steps

| Path | Change | Step |
|---|---|---|
| `DECISIONS.md` | one entry appended | 1 |
| `COLD-START.md` | one head paragraph under "Next step" | 2 |
| `reports/2026-09-13-pass87-channel-logos-accepted-pushed.md` | created | 4 |

**Not touched:** every app-target file, the UI-test target, the Xcode project, `design/`,
`~/Xcode/marlin-dvr-reference`, `icon-source/`, `reports/assets/`, and every earlier report.

## 6. What is pushed, and what stays local

- **Pushed by this pass:** `29afca5` (Pass 86 — the code, harness, screenshots, report and notebook)
  and this pass's own commit.
- **Stays local, untracked:** `icon-source/`, the standing baseline.
- **Stays local, git-ignored:** `build/p86/`, the Pass 86 device build and its result bundle.
- **Outside the repo:** the session scratchpad.

## 7. Open questions

**None is raised by this pass.** Pass 86's open questions 2-5 stand as that report wrote them; they
are not re-raised here.

## 8. The things I am least sure of

1. **The acceptance wording is the brief's.** "Good to go", and that the faint contrast was shown to
   the owner before he accepted, come from the Pass 87 brief. This pass did not witness them.
2. **Nothing in the app was re-checked.** No build or device run was made, because none was asked
   for. The pushed code is exactly the tree the owner tested, since `29afca5` is unchanged — but that
   is by commit identity, not by a new measurement.
